--!strict

local textFilter = require(script.Parent.Parent.Util.textFilter)
local getModelConfig = require(script.Parent.Parent.Util.getModelConfig)
local types = require(script.Parent.Parent.types)

local BaseChat = {}
BaseChat.__index = BaseChat

type BaseChatProto = {
	model_id: string,
	convo_id: string,
	filter_threshold: number,
	context_length_limit: number,
	_api_key: string,
	_messages: { types.Message },
	_message_metadata: { [types.Message]: types.MessageMetadata },
	_formatted_messages: { types.Message },
	_context_length: number,
	_tools: { [string]: types.Tool },
	_toolMiddleware: { (tool_id: string, args: any) -> any? },
	_subscribers: { [(types.Message, types.MessageMetadata) -> ()]: boolean },
	_system_prompt: string,
	_token_usage: types.TokenUsage,
}

export type BaseChat = typeof(setmetatable({} :: BaseChatProto, BaseChat))

function BaseChat.new(): BaseChat
	local self = setmetatable({}, BaseChat)

	self.model_id = "base"
	self.convo_id = "convo"
	self.filter_threshold = 0.4
	self.context_length_limit = 100_000
	self._api_key = ""

	self._messages = {}
	self._message_metadata = {}
	self._formatted_messages = {}
	self._context_length = 0
	self._tools = {}
	self._toolMiddleware = {}
	self._subscribers = {}
	self._system_prompt = "You are a helpful AI assistant."
	self._token_usage = {
		input = 0,
		output = 0,
	}

	self:clearMessages()

	return self
end

function BaseChat.getMessages(self: BaseChat): { types.Message }
	return table.clone(self._messages)
end

function BaseChat.clearMessages(self: BaseChat): ()
	self._messages = {}
	self._formatted_messages = {}
	self._message_metadata = {}
	self._token_usage = {
		input = 0,
		output = 0,
	}
end

function BaseChat.getCost(self: BaseChat): number
	local model_config = getModelConfig(self.model_id)
	local model_price = model_config.price or getModelConfig("default").price

	local input_price = model_price.input
	local output_price = model_price.output

	local input_tokens = self._token_usage.input
	local output_tokens = self._token_usage.output

	-- Price is provided in $/1M tokens
	local input_cost = input_tokens * input_price / 1e6
	local output_cost = output_tokens * output_price / 1e6

	return input_cost + output_cost
end

function BaseChat.subscribeToNewMessages(
	self: BaseChat,
	callback: (types.Message, types.MessageMetadata) -> ()
): () -> ()
	assert(type(callback) == "function", "subscribeToNewMessages expects a function")

	self._subscribers[callback] = true
	return function()
		self._subscribers[callback] = nil
	end
end

function BaseChat._insertMessage(
	self: BaseChat,
	message: types.Message,
	metadata: types.MessageMetadata?
): types.Message
	assert(type(message) == "table", "message must be a table")
	table.freeze(message)

	local _metadata: types.MessageMetadata = (metadata or { id = "unknown" })
	_metadata.timestamp = DateTime.now().UnixTimestamp

	table.insert(self._messages, message)
	self._message_metadata[message] = _metadata

	local formatted_message = self:_formatMessage(message)
	table.insert(self._formatted_messages, formatted_message)

	for subscriberCallback in self._subscribers do
		task.spawn(subscriberCallback, message, _metadata)
	end

	return message
end

function BaseChat.addUserMessage(
	self: BaseChat,
	content: string,
	userId: number
): types.Result<types.UserMessage, types.SafetyErrors>
	local filteredContent = textFilter(content, userId)

	local newHashtags = select(2, string.gsub(filteredContent, "#", "#")) - select(2, string.gsub(content, "#", "#"))

	if newHashtags / #content >= self.filter_threshold then
		return {
			success = false,
			error = "text_filter",
		}
	end

	return {
		success = true,
		value = self:_insertMessage({
			role = "user",
			content = content,
		}) :: types.UserMessage,
	}
end

function BaseChat.addSystemMessage(self: BaseChat, content): types.Result<types.SystemMessage, types.SafetyErrors>
	return {
		success = true,
		value = self:_insertMessage({
			role = "system",
			content = content,
		}) :: types.SystemMessage,
	}
end

function BaseChat.requestAIMessage(
	self: BaseChat,
	generation_options: types.GenerationOptions?
): types.Result<types.AIMessage, types.ProviderErrors | types.ToolErrors>
	if self._context_length >= self.context_length_limit then
		return {
			success = false,
			error = "token_limit",
			details = "Token limit reached",
		}
	end

	-- Call the endpoint of the provider, receiving a standardized response
	local providerResult = self:_callProvider(generation_options or {})

	if not providerResult.success then
		return providerResult
	end

	local response = providerResult.value

	-- Update the token usage info
	self._token_usage.input += response.token_usage.input
	self._token_usage.output += response.token_usage.output

	self._context_length = response.token_usage.input + response.token_usage.output

	-- Add this message to the chat
	local message = self:_insertMessage({
		role = "ai",
		content = response.content,
		tool_calls = response.tool_calls,
	}, {
		id = response.id,
	}) :: types.AIMessage

	-- Use tools if called
	if response.tool_calls then
		for _, tool_call in response.tool_calls do
			local tool_id = tool_call.tool_id
			local args = tool_call.args

			local tool_result = self:useTool(tool_id, args)
			if not tool_result.success then
				return tool_result
			end

			self:_insertMessage(
				{
					role = "tool",
					tool_id = tool_id,
					tool_call_id = tool_call.tool_call_id,
					content = tool_result.value,
				} :: types.ToolMessage,
				{
					caller_id = response.id,
					id = tool_call.tool_call_id,
				}
			)
		end

		-- Now that the tool calls are in the messages, call the AI again
		return self:requestAIMessage(generation_options)
	end

	return {
		success = true,
		value = message,
	}
end

function BaseChat.setSystemPrompt(self: BaseChat, prompt: string): ()
	self._system_prompt = prompt
end

function BaseChat.addTool(
	self: BaseChat,
	tool_id: string,
	callback: (any?) -> { [any]: any },
	schema: types.ToolSchema
): ()
	assert(type(tool_id) == "string", "tool_id must be a string")
	assert(type(callback) == "function", "callback must be a function")

	self._tools[tool_id] = {
		id = tool_id,
		func = callback,
		name = schema.name,
		description = schema.description,
		args = schema.args,
	}
end

function BaseChat.addToolMiddleware(self: BaseChat, middlware: (tool_id: string, args: any) -> any?): () -> ()
	assert(type(middlware) == "function", "middleware must be a function")

	table.insert(self._toolMiddleware, middlware)

	return function()
		local index = table.find(self._toolMiddleware, middlware)
		if index then
			table.remove(self._toolMiddleware, index)
		end
	end
end

function BaseChat.removeTool(self: BaseChat, tool_id: string): ()
	self._tools[tool_id] = nil
end

function BaseChat.useTool(self: BaseChat, tool_id: string, args: any): types.Result<{}, types.ToolErrors>
	local tool = self._tools[tool_id]
	if not tool then
		return {
			success = false,
			error = "tool_missing",
			details = "Tool ID " .. tostring(tool_id) .. " not found in tools map",
		}
	end

	for _, middlware in self._toolMiddleware do
		local success, result = pcall(middlware, tool_id, args)
		if not success then
			return {
				success = false,
				error = "tool_crash",
				details = tostring(result),
			}
		end

		args = result
	end

	local success, result = pcall(tool.func, args)
	if not success then
		return {
			success = false,
			error = "tool_crash",
			details = tostring(result),
		}
	end

	return {
		success = true,
		value = result,
	}
end

function BaseChat._formatMessage(self: BaseChat, message: types.Message): types.Message
	error("Provider subclasses must implement _formatMessage")
end

function BaseChat._callProvider(
	self: BaseChat,
	generation_options: types.GenerationOptions
): types.Result<types.ProviderResponse, types.ProviderErrors>
	error("Provider subclasses must implement _callProvider")
end

return BaseChat
