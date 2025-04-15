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
type TogetherAIUserMessage = {
	role: "user",
	content: string,
}

type TogetherAIAIMessage = {
	role: "assistant",
	content: string,
	tool_calls: nil,
}

type TogetherAIAIToolCall = {
	role: "assistant",
	content: nil,
	tool_calls: { ToolCall },
}

type TogetherAISystemMessage = {
	role: "system",
	content: string,
}

type TogetherAIToolMessage = {
	role: "tool",
	tool_call_id: string,
	name: string,
	content: string,
}

type TogetherAIMessage =
	TogetherAIUserMessage
	| TogetherAIAIMessage
	| TogetherAIAIToolCall
	| TogetherAISystemMessage
	| TogetherAIToolMessage

type TogetherAIFunctionDeclaration = {
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

type ToolDefinitions = { TogetherAIFunctionDeclaration }

type FinishReason = "stop" | "eos" | "length" | "tool_calls"

type Choice = {
	finish_reason: FinishReason,
	index: number,
	message: TogetherAIAIMessage | TogetherAIAIToolCall,
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

type CompletionObject = {
	id: string,
	object: "text_completion",
	created: number,
	model: string,
	choices: { { text: string, finish_reason: FinishReason } },
	usage: {
		prompt_tokens: number,
		completion_tokens: number,
		total_tokens: number,
	},
}

local TogetherAI = {}
TogetherAI.__index = TogetherAI

type TogetherAIProto = {
	_url: string,
	_formatted_messages: { TogetherAIMessage },
	_filter_cache: { [string]: boolean },
}

export type TogetherAI = typeof(setmetatable({} :: TogetherAIProto, TogetherAI)) & BaseChat.BaseChat

setmetatable(TogetherAI, BaseChat)

function TogetherAI.new(model_id: string, api_key: string): TogetherAI
	local self = setmetatable(BaseChat.new() :: TogetherAI, TogetherAI)

	self.model_id = model_id
	self._api_key = api_key
	self._url = "https://api.together.xyz/v1/chat/completions"
	self._filter_cache = {}

	return self
end

function TogetherAI._callProvider(
	self: TogetherAI,
	generation_options: types.GenerationOptions
): types.Result<types.ProviderResponse, types.ProviderErrors>
	local messages_with_system_prompt: { TogetherAIMessage } = table.create(#self._formatted_messages + 1)
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
			-- A unique identifier representing your end-user, which can help TogetherAI to monitor and detect abuse.
			user = self.convo_id,
			-- ID of the model to use.
			model = self.model_id,
			-- What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.
			temperature = generation_options.temperature or 0.9,
			-- The maximum number of tokens to generate in the chat completion.
			max_tokens = generation_options.max_tokens or 2048,
			-- Up to 4 sequences where the API will stop generating further tokens.
			stop = generation_options.stop_sequences,
			-- The moderation model to guard against policy violations.
			safety_model = "Meta-Llama/Llama-Guard-7b",
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

function TogetherAI._getToolCalls(
	self: TogetherAI,
	content: TogetherAIAIMessage | TogetherAIAIToolCall
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

function TogetherAI._getToolDefinitions(self: TogetherAI): ToolDefinitions?
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

function TogetherAI._formatMessage(self: TogetherAI, message: types.Message): TogetherAIMessage
	local formattedMessage: TogetherAIMessage
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
			) :: TogetherAIAIToolCall
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

return TogetherAI
