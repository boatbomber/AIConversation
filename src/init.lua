--!strict

local HttpService = game:GetService("HttpService")

export type model = "gpt-4" | "gpt-4-32k" | "gpt-3.5-turbo" | "gpt-3.5-turbo-16k"

export type role = "system" | "user" | "assistant"

export type config = {
	key: string,
	prompt: string,
	id: string,
	model: model?,
	temperature: number?,
}

export type message = {
	role: role,
	content: string,
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

	conversation.id = config.id
	conversation.model = config.model or "gpt-3.5-turbo"
	conversation.temperature = config.temperature or 0.75
	conversation.messages = {
		{ role = "system", content = config.prompt },
	}
	conversation.token_usage = 0

	function conversation:_addMessage(role: role, content: string)
		local message: message = table.freeze({ role = role, content = content })
		table.insert(self.messages, message)

		for callback in self._subscriptions do
			task.spawn(callback, message)
		end
	end

	function conversation:AppendUserMessage(content: string)
		self:_addMessage("user", content)
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
			warn("OpenAI responded with error code:", response.StatusCode, response.StatusMessage)
			return
		end

		local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
		if not decodeSuccess then
			warn("Failed to decode OpenAI response body:", response)
			return
		end

		self.token_usage = (self.token_usage or 0) + (decodeResponse.usage.total_tokens or 0)

		for _, choice in decodeResponse.choices do
			self:_addMessage("assistant", choice.message.content)
		end
	end

	function conversation:ClearMessages()
		self.messages = {}
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
