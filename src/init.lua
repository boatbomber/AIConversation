--!strict

local HttpService = game:GetService("HttpService")

export type model =
	"gpt-4"
	| "gpt-4-32k"
	| "gpt-4-1106-preview"
	| "gpt-3.5-turbo"
	| "gpt-3.5-turbo-1106"
	| "gpt-3.5-turbo-16k"

export type role = "system" | "user" | "assistant" | "tool"

export type moderation_category =
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

export type response_format = {
	["type"]: "text" | "json",
}

export type moderation_result = {
	flagged: boolean,
	categories: { [moderation_category]: boolean },
	category_scores: { [moderation_category]: number },
}

export type tool_call = {
	["id"]: string,
	["type"]: "function",
	["function"]: {
		name: string,
		arguments: string,
	},
}

export type message = {
	role: role,
	content: string,
	tool_calls: { tool_call }?,
	name: string?,
	tool_call_id: string?,
}

export type function_schema = {
	name: string,
	description: string?,
	parameters: any,
	callback: (({ [string]: any }) -> any)?,
}

export type tool_schema = {
	-- Future OpenAI updates may add more supported types but it's just function for now.
	["type"]: "function",
	["function"]: function_schema,
}

export type token_usage = {
	prompt_tokens: number?,
	completion_tokens: number?,
	total_tokens: number?,
}

export type metadata = { [any]: any }

export type config = {
	id: string,
	key: string,
	model: model?,
	prompt: string,
	response_format: response_format?,
	tools: { tool_schema }?,
}

export type request_options = {
	max_tokens: number?,
	temperature: number?,
	presence_penalty: number?,
	frequency_penalty: number?,
	stop: string? | { string }?,
}

local AIConversation = {}

function AIConversation.new(config: config)
	assert(type(config) == "table", "AIConversation.new must be called with a config table")
	assert(type(config.key) == "string", "config.key must be an OpenAI API key string")
	assert(type(config.prompt) == "string", "config.prompt must be a system prompt string")
	assert(type(config.id) == "string", "config.id must be an identifying string")

	local conversation = {}

	conversation._key = config.key
	conversation._subscriptions = {}

	conversation.token_usage = {
		prompt_tokens = 0,
		completion_tokens = 0,
		total_tokens = 0,
	}
	conversation.id = config.id
	conversation.model = config.model or "gpt-3.5-turbo"
	conversation.response_format = config.response_format or { type = "text" }
	conversation.messages = {
		{ role = "system", content = config.prompt },
	}
	conversation.message_metadata = {}

	function conversation:SetTools(tools: { tool_schema })
		conversation.tools = tools
		conversation.tools_map = {}

		for _, tool in conversation.tools do
			local func = tool["function"]
			conversation.tools_map[func.name] = func.callback
			func.callback = nil
		end
	end

	if config.tools then
		conversation:SetTools(config.tools)
	end

	function conversation:_addTokens(tokens: token_usage)
		if not tokens then
			return
		end
		self.token_usage.prompt_tokens = (self.token_usage.prompt_tokens or 0) + (tokens.prompt_tokens or 0)
		self.token_usage.completion_tokens = (self.token_usage.completion_tokens or 0) + (tokens.completion_tokens or 0)
		self.token_usage.total_tokens = (self.token_usage.total_tokens or 0) + (tokens.total_tokens or 0)
	end

	function conversation:_addMessage(message: message, metadata: metadata?)
		metadata = metadata or {}
		table.insert(self.messages, table.freeze(message))
		self.message_metadata[message] = metadata

		for callback in self._subscriptions do
			task.spawn(callback, message, metadata)
		end
	end

	function conversation:AppendUserMessage(content: string): (boolean, message)
		local message = { role = "user" :: role, content = content }
		self:_addMessage(message)

		return true, message
	end

	function conversation:AppendSystemMessage(content: string): (boolean, message)
		local message = { role = "system" :: role, content = content }
		self:_addMessage(message)

		return true, message
	end

	function conversation:RequestAppendAIMessage(request_options: request_options): (boolean, string | message)
		assert(
			type(request_options) == "table",
			"conversation:RequestAppendAIMessage must be called with a request_options table"
		)

		local success, response = pcall(HttpService.RequestAsync, HttpService, {
			Url = "https://api.openai.com/v1/chat/completions",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. self._key,
			},
			Body = HttpService:JSONEncode({
				-- We can't support streaming with HttpService.
				stream = false,
				-- Number of messages to generate
				n = 1,
				-- A list of messages comprising the conversation so far.
				messages = self.messages,
				-- A list of functions the model may generate JSON inputs for.
				tools = self.tools,
				-- A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
				user = self.id,
				-- ID of the model to use.
				model = self.model,
				-- An object specifying the format that the model must output.
				response_format = self.response_format,
				-- What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.
				temperature = request_options.temperature or 0.7,
				-- The maximum number of tokens to generate in the chat completion.
				max_tokens = request_options.max_tokens or 200,
				-- Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics.
				presence_penalty = request_options.presence_penalty,
				-- Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim.
				frequency_penalty = request_options.frequency_penalty,
				-- Up to 4 sequences where the API will stop generating further tokens.
				stop = request_options.stop,
			}),
		})

		if not success then
			return false, "Failed to get reply from OpenAI: " .. tostring(response)
		end

		if response.StatusCode ~= 200 then
			return false,
				"OpenAI responded with error code: " .. tostring(response.StatusCode) .. " " .. tostring(
					response.StatusMessage
				) .. "\n" .. tostring(response.Body)
		end

		local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not decodeSuccess then
			return false,
				"Failed to decode OpenAI response body: " .. tostring(decodeResponse) .. "\n" .. tostring(response.Body)
		end

		self:_addTokens(decodeResponse.usage)

		local choice = decodeResponse.choices[1]
		local message = choice.message
		message.content = message.content or ""

		-- Add call to history
		self:_addMessage(message, {
			id = decodeResponse.id,
		})

		if message.tool_calls then
			-- Handle each tool call
			for _, tool_call in message.tool_calls do
				if tool_call.type ~= "function" then
					return false,
						"AI attempted a tool call type '"
							.. tostring(tool_call.type)
							.. "', which is not supported yet."
				end

				local funcName = tool_call["function"].name
				local func = self.tools_map[funcName]

				if not func then
					return false,
						"AI tried to call function '" .. tostring(funcName) .. "' but no function exists by that name"
				end

				local decodeArgsSuccess, decodeArgsResponse =
					pcall(HttpService.JSONDecode, HttpService, tool_call["function"].arguments)
				if not decodeArgsSuccess then
					return false,
						"Failed to decode OpenAI function args: " .. tostring(decodeArgsResponse) .. "\n" .. tostring(
							message.function_call.arguments
						)
				end

				local funcSuccess, funcResponse = pcall(func, decodeArgsResponse)
				if not funcSuccess then
					return false,
						"AI called function '"
							.. tostring(funcName)
							.. "' with args "
							.. tostring(decodeArgsResponse)
							.. " but it errored: "
							.. tostring(funcResponse)
				end

				-- Add tool response to history
				self:_addMessage({
					tool_call_id = tool_call.id,
					role = "tool",
					name = funcName,
					content = HttpService:JSONEncode(funcResponse),
				}, {
					id = "tool_" .. decodeResponse.id,
				})
			end

			-- Now that the AI can read the function response, get their final message
			return self:RequestAppendAIMessage(request_options)
		end

		return true, message
	end

	function conversation:DoesTextViolateContentPolicy(text: string): (boolean, string | boolean, moderation_result?)
		assert(type(text) == "string", "conversation:DoesTextViolateContentPolicy must be called with a string")

		local success, response = pcall(HttpService.RequestAsync, HttpService, {
			Url = "https://api.openai.com/v1/moderations",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. self._key,
			},
			Body = HttpService:JSONEncode({
				input = text,
			}),
		})

		if not success then
			return false, "Failed to get reply from OpenAI: " .. tostring(response)
		end

		if response.StatusCode ~= 200 then
			return false,
				"OpenAI responded with error code: " .. tostring(response.StatusCode) .. tostring(
					response.StatusMessage
				) .. "\n" .. tostring(response.Body)
		end

		local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not decodeSuccess then
			return false,
				"Failed to decode OpenAI response body: " .. tostring(decodeResponse) .. "\n" .. tostring(response.Body)
		end

		return true, decodeResponse.results[1].flagged, decodeResponse.results[1]
	end

	function conversation:RequestVectorEmbedding(text: string): (boolean, string | { number })
		assert(type(text) == "string", "conversation:RequestVectorEmbedding must be called with a string")

		local success, response = pcall(HttpService.RequestAsync, HttpService, {
			Url = "https://api.openai.com/v1/embeddings",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. self._key,
			},
			Body = HttpService:JSONEncode({
				model = "text-embedding-ada-002",
				input = text,
			}),
		})

		if not success then
			return false, "Failed to get reply from OpenAI: " .. tostring(response)
		end

		if response.StatusCode ~= 200 then
			return false,
				"OpenAI responded with error code: " .. tostring(response.StatusCode) .. tostring(
					response.StatusMessage
				) .. "\n" .. tostring(response.Body)
		end

		local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not decodeSuccess then
			return false,
				"Failed to decode OpenAI response body: " .. tostring(decodeResponse) .. "\n" .. tostring(response.Body)
		end

		self:_addTokens(decodeResponse.usage)

		return true, decodeResponse.data[1].embedding :: { number }
	end

	function conversation:ClearMessages()
		self.message_metadata = {}
		self.messages = {
			{ role = "system", content = config.prompt },
		}
		self.token_usage = {
			prompt_tokens = 0,
			completion_tokens = 0,
			total_tokens = 0,
		}
	end

	function conversation:GetMessages(): { message }
		return table.clone(self.messages)
	end

	function conversation:SubscribeToNewMessages(callback: (message: message, metadata: metadata) -> ()): () -> ()
		self._subscriptions[callback] = true
		return function()
			self._subscriptions[callback] = nil
		end
	end

	return conversation
end

return AIConversation
