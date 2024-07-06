--!strict

local HttpService = game:GetService("HttpService")

local BaseChat = require(script.Parent.BaseChat)
local ModelConfigs = require(script.Parent.Parent.ModelConfigs)
local types = require(script.Parent.Parent.types)
local safeRequest = require(script.Parent.Parent.Util.safeRequest)

type TextPart = {
	text: string,
	inlineData: nil,
	functionCall: nil,
}

type FilePart = {
	text: nil,
	inlineData: {
		mimeType: string,
		data: string,
	},
	functionCall: nil,
}

type ToolCallPart = {
	text: nil,
	inlineData: nil,
	functionCall: {
		name: string,
		args: any,
	},
}

type ToolPart = {
	functionResponse: {
		name: string,
		response: {
			name: string,
			content: { [any]: any },
		},
	},
}

type Part = TextPart | FilePart | ToolCallPart

type GoogleUserMessage = {
	role: "user",
	parts: { Part },
}

type GoogleAIMessage = {
	role: "model",
	parts: { Part },
}

type GoogleToolMessage = {
	role: "function",
	parts: { ToolPart },
}

type GoogleMessage = GoogleUserMessage | GoogleAIMessage | GoogleToolMessage

type GoogleFunctionDeclaration = {
	name: string,
	description: string,
	parameters: {
		type: "object",
		properties: { [string]: any },
		required: { string },
	},
}

type ToolDefinitions = {
	function_declarations: { GoogleFunctionDeclaration },
}

type BlockReason = "BLOCK_REASON_UNSPECIFIED" | "SAFETY" | "OTHER"

type HarmProbability = "HARM_PROBABILITY_UNSPECIFIED" | "NEGLIGIBLE" | "LOW" | "MEDIUM" | "HIGH"

type HarmCategory =
	"HARM_CATEGORY_UNSPECIFIED"
	| "HARM_CATEGORY_DEROGATORY"
	| "HARM_CATEGORY_TOXICITY"
	| "HARM_CATEGORY_VIOLENCE"
	| "HARM_CATEGORY_SEXUAL"
	| "HARM_CATEGORY_MEDICAL"
	| "HARM_CATEGORY_DANGEROUS"
	| "HARM_CATEGORY_HARASSMENT"
	| "HARM_CATEGORY_HATE_SPEECH"
	| "HARM_CATEGORY_SEXUALLY_EXPLICIT"
	| "HARM_CATEGORY_DANGEROUS_CONTENT"

type SafetyRating = {
	category: HarmCategory,
	probability: HarmProbability,
	blocked: boolean,
}

type FinishReason = "FINISH_REASON_UNSPECIFIED" | "STOP" | "MAX_TOKENS" | "SAFETY" | "RECITATION" | "OTHER"

type Candidate = {
	content: GoogleAIMessage,
	finishReason: FinishReason?,
	safetyRatings: { SafetyRating },
	citationMetadata: {
		citationSources: {
			{
				startIndex: number?,
				endIndex: number?,
				uri: string?,
				license: string?,
			}
		},
	},
	tokenCount: number,
	index: number,
}

type GenerateContentResponse = {
	candidates: { Candidate },
	promptFeedback: {
		blockReason: BlockReason?,
		safetyRatings: { SafetyRating },
	},
	usageMetadata: {
		promptTokenCount: number,
		candidatesTokenCount: number,
		totalTokenCount: number,
	},
}

local Google = {}
Google.__index = Google

type GoogleProto = {
	_url: string,
	_formatted_messages: { GoogleMessage },
}

export type Google = typeof(setmetatable({} :: GoogleProto, Google)) & BaseChat.BaseChat

setmetatable(Google, BaseChat)

function Google.new(model_id: string, api_key: string): Google
	local self = setmetatable(BaseChat.new() :: Google, Google)

	self.model_id = model_id
	self._api_key = api_key
	self._url = "https://generativelanguage.googleapis.com/v1beta/models/"
		.. model_id
		.. ":generateContent?key="
		.. api_key

	return self
end

function Google._callProvider(
	self: Google,
	generation_options: types.GenerationOptions
): types.Result<types.ProviderResponse, types.ProviderErrors>
	local api_response: types.Result<GenerateContentResponse, types.ProviderErrors> = safeRequest({
		Url = self._url,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = HttpService:JSONEncode({
			systemInstruction = {
				role = "system",
				parts = { { text = self._system_prompt } },
			},
			contents = self._formatted_messages,
			generationConfig = {
				stopSequences = generation_options.stop_sequences or nil,
				maxOutputTokens = generation_options.max_tokens or 2048,
				temperature = generation_options.temperature or 0.9,
			},
			tools = self:_getToolDefinitions(),
		}),
	})

	if not api_response.success then
		return api_response
	end

	local generateContentResponse = api_response.value

	if generateContentResponse.promptFeedback and generateContentResponse.promptFeedback.blockReason ~= nil then
		return {
			success = false,
			error = "safety_filter",
			details = generateContentResponse.promptFeedback.safetyRatings,
		}
	end

	if not generateContentResponse.candidates or #generateContentResponse.candidates == 0 then
		return {
			success = false,
			error = "other",
			details = "No candidates returned",
		}
	end

	local candidate = generateContentResponse.candidates[1]

	return {
		success = true,
		value = {
			id = "chatcmpl-" .. HttpService:GenerateGUID(false),
			content = self:_getTextContent(candidate.content),
			tool_calls = self:_getToolCalls(candidate.content),
			token_usage = {
				input = generateContentResponse.usageMetadata.promptTokenCount,
				output = generateContentResponse.usageMetadata.candidatesTokenCount,
			},
		},
	}
end

function Google._getTextContent(self: Google, content: GoogleAIMessage): string
	local textBuffer: { string } = {}
	for _, part in pairs(content.parts) do
		if part.text then
			table.insert(textBuffer, part.text)
		end
	end
	return table.concat(textBuffer)
end

function Google._getToolCalls(self: Google, content: GoogleAIMessage): { types.ToolCall }?
	local toolCalls: { types.ToolCall } = {}
	for _, part in pairs(content.parts) do
		if part.functionCall then
			table.insert(toolCalls, {
				tool_id = part.functionCall.name,
				tool_call_id = "call-" .. HttpService:GenerateGUID(false),
				args = part.functionCall.args,
			})
		end
	end
	if #toolCalls == 0 then
		return nil
	end
	return toolCalls
end

function Google._getToolDefinitions(self: Google): ToolDefinitions?
	if not next(self._tools) then
		return nil
	end

	if not ModelConfigs[self.model_id].tool_support then
		return nil
	end

	local function_declarations = {}

	for tool_id, tool in self._tools do
		table.insert(function_declarations, {
			name = tool_id,
			description = tool.description,
			parameters = tool.args,
		})
	end

	return {
		function_declarations = function_declarations,
	}
end

function Google._formatMessage(self: Google, message: types.Message): GoogleMessage
	local formattedMessage: GoogleMessage
	if message.role == "user" then
		formattedMessage = {
			role = "user",
			parts = {
				{
					text = message.content,
				},
			},
		}
	elseif message.role == "ai" then
		local parts: { Part } = {
			{
				text = message.content,
			},
		}

		if message.tool_calls then
			for _, tool_call in message.tool_calls do
				table.insert(parts, {
					functionCall = {
						name = tool_call.tool_id,
						args = tool_call.args,
					},
				})
			end
		end

		formattedMessage = {
			role = "model",
			parts = parts,
		}
	elseif message.role == "tool" then
		formattedMessage = {
			role = "function",
			parts = {
				{
					functionResponse = {
						name = message.tool_id,
						response = {
							name = message.tool_id,
							content = message.content,
						},
					},
				},
			},
		}
	elseif message.role == "system" then
		formattedMessage = {
			role = "user",
			parts = {
				{
					text = "[SYSTEM_CONTEXT]" .. message.content .. "[/SYSTEM_CONTEXT]",
				},
			},
		}
	end
	return formattedMessage
end

return Google
