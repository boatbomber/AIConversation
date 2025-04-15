--!strict

local HttpService = game:GetService("HttpService")

local BaseChat = require(script.Parent.BaseChat)
local types = require(script.Parent.Parent.types)
local safeRequest = require(script.Parent.Parent.Util.safeRequest)
local getModelConfig = require(script.Parent.Parent.Util.getModelConfig)

type ToolCall = {
	id: string,
	type: "function",
	["function"]: {
		name: string,
		arguments: string,
	},
}
type OpenAIUserMessage = {
	role: "user",
	content: string,
}

type OpenAIAIMessage = {
	role: "assistant",
	content: string,
	tool_calls: nil,
}

type OpenAIAIToolCall = {
	role: "assistant",
	content: nil,
	tool_calls: { ToolCall },
}

type OpenAISystemMessage = {
	role: "system",
	content: string,
}

type OpenAIToolMessage = {
	role: "tool",
	tool_call_id: string,
	name: string,
	content: string,
}

type OpenAIMessage = OpenAIUserMessage | OpenAIAIMessage | OpenAIAIToolCall | OpenAISystemMessage | OpenAIToolMessage

type ModerationCategory =
	"sexual"
	| "hate"
	| "harassment"
	| "self-harm"
	| "sexual/minors"
	| "hate/threatening"
	| "violence/graphic"
	| "self-harm/intent"
	| "self-harm/instructions"
	| "harassment/threatening"
	| "violence"

type ModerationResult = {
	id: string,
	model: string,
	results: {
		{
			flagged: boolean,
			categories: { [ModerationCategory]: boolean },
			category_scores: { [ModerationCategory]: number },
		}
	},
}

type OpenAIFunctionDeclaration = {
	type: "function",
	["function"]: {
		name: string,
		description: string,
		parameters: {
			type: "object",
			properties: { [string]: any },
			required: { string },
		},
	},
}

type ToolDefinitions = { OpenAIFunctionDeclaration }

type FinishReason = "stop" | "length" | "content_filter" | "tool_calls" | "function_call"

type Choice = {
	finish_reason: FinishReason,
	index: number,
	message: OpenAIAIMessage | OpenAIAIToolCall,
}
type ChatCompletionObject = {
	id: string,
	object: "chat.completion",
	created: number,
	model: string,
	choices: { Choice },
	usage: {
		prompt_tokens: number,
		completion_tokens: number,
		total_tokens: number,
	},
}

local OpenAI = {}
OpenAI.__index = OpenAI

type OpenAIProto = {
	_url: string,
	_formatted_messages: { OpenAIMessage },
	_filter_cache: { [string]: boolean },
}

export type OpenAI = typeof(setmetatable({} :: OpenAIProto, OpenAI)) & BaseChat.BaseChat

setmetatable(OpenAI, BaseChat)

function OpenAI.new(model_id: string, api_key: string): OpenAI
	local self = setmetatable(BaseChat.new() :: OpenAI, OpenAI)

	self.model_id = model_id
	self._api_key = api_key
	self._url = "https://api.openai.com/v1/chat/completions"
	self._filter_cache = {}

	return self
end

function OpenAI._callProvider(
	self: OpenAI,
	generation_options: types.GenerationOptions
): types.Result<types.ProviderResponse, types.ProviderErrors>
	local user_message = self:_getLastUserMessage()
	if user_message then
		local filtered = self:_isMessageFiltered(user_message)
		if filtered.success and filtered.value then
			return {
				success = false,
				error = "safety_filter",
			}
		end
	end

	local messages_with_system_prompt: { OpenAIMessage } = table.create(#self._formatted_messages + 1)
	messages_with_system_prompt[1] = {
		role = "system",
		content = self._system_prompt,
	}
	table.move(self._formatted_messages, 1, #self._formatted_messages, 2, messages_with_system_prompt)

	local api_response: types.Result<ChatCompletionObject, types.ProviderErrors> = safeRequest({
		Url = self._url,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. self._api_key,
		},
		Body = HttpService:JSONEncode({
			-- We can't support streaming with HttpService.
			stream = false,
			-- Number of messages to generate
			n = 1,
			-- A list of messages comprising the conversation so far.
			messages = messages_with_system_prompt,
			-- A list of functions the model may generate JSON inputs for.
			tools = self:_getToolDefinitions(),
			-- A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
			user = self.convo_id,
			-- ID of the model to use.
			model = self.model_id,
			-- What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.
			temperature = generation_options.temperature or 0.9,
			-- The maximum number of tokens to generate in the chat completion.
			max_tokens = generation_options.max_tokens or 2048,
			-- Up to 4 sequences where the API will stop generating further tokens.
			stop = generation_options.stop_sequences,
		}),
	})

	if not api_response.success then
		return api_response
	end

	local chatCompletion = api_response.value

	if not chatCompletion.choices or #chatCompletion.choices == 0 then
		return {
			success = false,
			error = "other",
			details = "No choices returned",
		}
	end

	local candidate = chatCompletion.choices[1]

	if candidate.finish_reason == "content_filter" then
		return {
			success = false,
			error = "safety_filter",
			details = candidate.finish_reason,
		}
	end

	local tool_calls = self:_getToolCalls(candidate.message)
	if not tool_calls.success then
		return tool_calls
	end

	return {
		success = true,
		value = {
			id = chatCompletion.id,
			content = candidate.message.content or "",
			tool_calls = tool_calls.value,
			token_usage = {
				input = chatCompletion.usage.prompt_tokens,
				output = chatCompletion.usage.completion_tokens,
			},
		},
	}
end

function OpenAI:_isMessageFiltered(message: OpenAIMessage): types.Result<boolean, types.ProviderErrors>
	local text = message.content or ""
	if not string.find(text, "%S") then
		-- Empty message can't be filtered
		return {
			success = true,
			value = false,
		}
	end

	if self._filter_cache[text] ~= nil then
		return {
			success = true,
			value = self._filter_cache[text],
		}
	end

	local api_response: types.Result<ModerationResult, types.ProviderErrors> = safeRequest({
		Url = "https://api.openai.com/v1/moderations",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. self._api_key,
		},
		Body = HttpService:JSONEncode({
			input = text,
		}),
	})

	if not api_response.success then
		return api_response
	end

	if not api_response.value.results or #api_response.value.results == 0 then
		return {
			success = false,
			error = "other",
			details = "No moderation results returned",
		}
	end

	local filtered = api_response.value.results[1].flagged

	self._filter_cache[text] = filtered

	return {
		success = true,
		value = filtered,
	}
end

function OpenAI:_getLastUserMessage(): OpenAIUserMessage?
	for i = #self._formatted_messages, 1, -1 do
		local message: OpenAIMessage = (self._formatted_messages :: any)[i]
		if message.role == "user" then
			return message
		end
	end
	return nil
end

function OpenAI._getToolCalls(
	self: OpenAI,
	content: OpenAIAIMessage | OpenAIAIToolCall
): types.Result<{ types.ToolCall }?, types.ProviderErrors>
	if not content.tool_calls then
		return {
			success = true,
			value = nil,
		}
	end

	local tool_calls = {}
	for _, tool_call in pairs(content.tool_calls) do
		local argsSuccess, args = pcall(HttpService.JSONDecode, HttpService, tool_call["function"].arguments)
		if not argsSuccess then
			return {
				success = false,
				error = "decode_fail",
				details = args,
			}
		end

		table.insert(tool_calls, {
			tool_id = tool_call["function"].name,
			tool_call_id = tool_call.id,
			args = args,
		})
	end

	if #tool_calls == 0 then
		return {
			success = true,
			value = nil,
		}
	end
	return {
		success = true,
		value = tool_calls,
	}
end

function OpenAI._getToolDefinitions(self: OpenAI): ToolDefinitions?
	if not next(self._tools) then
		return nil
	end

	if not getModelConfig(self.model_id).tool_support then
		return nil
	end

	local tool_definitions = {}

	for tool_id, tool in self._tools do
		table.insert(tool_definitions, {
			["type"] = "function" :: "function",
			["function"] = {
				name = tool.name,
				description = tool.description,
				parameters = tool.args,
			},
		})
	end

	return tool_definitions
end

function OpenAI._formatMessage(self: OpenAI, message: types.Message): OpenAIMessage
	local formattedMessage: OpenAIMessage
	if message.role == "user" then
		formattedMessage = {
			role = "user",
			content = message.content,
		}
	elseif message.role == "ai" then
		if message.tool_calls then
			local tool_calls = {}
			for _, tool_call in message.tool_calls do
				table.insert(tool_calls, {
					id = tool_call.tool_call_id,
					type = "function",
					["function"] = {
						name = tool_call.tool_id,
						arguments = HttpService:JSONEncode(tool_call.args),
					},
				})
			end

			formattedMessage = (
				{
					role = "assistant",
					content = nil,
					tool_calls = tool_calls,
				} :: any
			) :: OpenAIAIToolCall
		else
			formattedMessage = {
				role = "assistant",
				content = message.content,
			}
		end
	elseif message.role == "tool" then
		formattedMessage = {
			role = "tool",
			tool_call_id = message.tool_call_id,
			name = message.tool_id,
			content = HttpService:JSONEncode(message.content),
		}
	elseif message.role == "system" then
		formattedMessage = {
			role = "system",
			content = message.content,
		}
	end
	return formattedMessage
end

return OpenAI
