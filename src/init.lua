--!strict

local HttpService = game:GetService("HttpService")

export type model = "gpt-4" | "gpt-4-32k" | "gpt-3.5-turbo" | "gpt-3.5-turbo-16k"

export type role = "system" | "user" | "assistant" | "function"

export type functionSchema = {
	name: string,
	description: string?,
	parameters: any,
	callback: (({[string]: any}) -> any)?,
}

export type config = {
	key: string,
	prompt: string,
	id: string,
	model: model?,
	temperature: number?,
	functions: { functionSchema }?,
}

export type message = {
	role: role,
	content: string,
	name: string?,
	function_call: {arguments: string, name: string}?,
}

export type request_options = {
	max_tokens: number?,
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

	conversation.token_usage = 0
	conversation.id = config.id
	conversation.model = config.model or "gpt-3.5-turbo"
	conversation.temperature = config.temperature or 0.75
	conversation.messages = {
		{ role = "system", content = config.prompt },
	}
	if config.functions then
		conversation.functions = config.functions
		conversation.functions_map = {}

		for _, func in conversation.functions do
			conversation.functions_map[func.name] = func.callback
			func.callback = nil
		end
	end

	function conversation:_addMessage(message: message)
		table.insert(self.messages, table.freeze(message))

		for callback in self._subscriptions do
			task.spawn(callback, message)
		end
	end

	function conversation:AppendUserMessage(content: string)
		self:_addMessage({ role = "user", content = content })
	end

	function conversation:AppendSystemMessage(content: string)
		self:_addMessage({ role = "system", content = content })
	end

	function conversation:RequestAppendAIMessage(request_options: request_options)
		assert(type(request_options) == "table", "conversation:RequestAppendAIMessage must be called with a request_options table")

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
				-- A list of messages comprising the conversation so far.
				messages = self.messages,
				-- A list of functions the model may generate JSON inputs for.
				functions = self.functions,
				-- A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
				user = self.id,
				-- ID of the model to use.
				model = self.model,
				-- What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.
				temperature = self.temperature,
				-- The maximum number of tokens to generate in the chat completion.
				max_tokens = request_options.max_tokens or 100,
				-- Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics.
				presence_penalty = request_options.presence_penalty,
				-- Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim.
				frequency_penalty = request_options.frequency_penalty,
				-- Up to 4 sequences where the API will stop generating further tokens.
				stop = request_options.stop,
			}),
		})

		if not success then
			warn("Failed to get reply from OpenAI:", response)
			return
		end

		if response.StatusCode ~= 200 then
			warn("OpenAI responded with error code:", response.StatusCode, response.StatusMessage, response.Body)
			return
		end

		local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not decodeSuccess then
			warn("Failed to decode OpenAI response body:", decodeResponse, response.Body)
			return
		end

		self.token_usage = (self.token_usage or 0) + (decodeResponse.usage.total_tokens or 0)

		for _, choice in decodeResponse.choices do
			local message = choice.message
			message.content = message.content or ""

			self:_addMessage(message)

			if message.function_call then
				local funcName = message.function_call.name
				local func = self.functions_map[funcName]

				if not func then
					warn("AI tried to call function", funcName, "but no function exists by that name")
					continue
				end

				local decodeArgsSuccess, decodeArgsResponse = pcall(HttpService.JSONDecode, HttpService, message.function_call.arguments)
				if not decodeArgsSuccess then
					warn("Failed to decode OpenAI function args", decodeArgsResponse)
					continue
				end

				local funcSuccess, funcResponse = pcall(func, decodeArgsResponse)
				if not funcSuccess then
					warn("AI called function", funcName, "with args", decodeArgsResponse, "but it errored:", funcResponse)
					continue
				end

				-- Add function response to history
				self:_addMessage({
					role = "function", name = funcName, content = HttpService:JSONEncode(funcResponse)
				})

				-- Now that the AI can read the function response, get their final message
				self:RequestAppendAIMessage(request_options)
			end
		end
	end

	function conversation:ClearMessages()
		self.messages = {
			{ role = "system", content = config.prompt },
		}
		self.token_usage = 0
	end

	function conversation:GetMessages(): { message }
		return table.clone(self.messages)
	end

	function conversation:SubscribeToNewMessages(callback: (message: message) -> ()): () -> ()
		self._subscriptions[callback] = true
		return function()
			self._subscriptions[callback] = nil
		end
	end

	return conversation
end

return AIConversation
