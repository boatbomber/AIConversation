--!strict

local HttpService = game:GetService("HttpService")

export type model =
	"zero-one-ai/Yi-34B-Chat"
	| "allenai/OLMo-7B-Instruct"
	| "allenai/OLMo-7B-Twin-2T"
	| "allenai/OLMo-7B"
	| "Austism/chronos-hermes-13b"
	| "cognitivecomputations/dolphin-2.5-mixtral-8x7b"
	| "databricks/dbrx-instruct"
	| "deepseek-ai/deepseek-coder-33b-instruct"
	| "deepseek-ai/deepseek-llm-67b-chat"
	| "garage-bAInd/Platypus2-70B-instruct"
	| "google/gemma-2b-it"
	| "google/gemma-7b-it"
	| "Gryphe/MythoMax-L2-13b"
	| "lmsys/vicuna-13b-v1.5"
	| "lmsys/vicuna-7b-v1.5"
	| "codellama/CodeLlama-13b-Instruct-hf"
	| "codellama/CodeLlama-34b-Instruct-hf"
	| "codellama/CodeLlama-70b-Instruct-hf"
	| "codellama/CodeLlama-7b-Instruct-hf"
	| "meta-llama/Llama-2-70b-chat-hf"
	| "meta-llama/Llama-2-13b-chat-hf"
	| "meta-llama/Llama-2-7b-chat-hf"
	| "meta-llama/Llama-3-8b-chat-hf"
	| "meta-llama/Llama-3-70b-chat-hf"
	| "microsoft/WizardLM-2-8x22B"
	| "mistralai/Mistral-7B-Instruct-v0.1"
	| "mistralai/Mistral-7B-Instruct-v0.2"
	| "mistralai/Mixtral-8x7B-Instruct-v0.1"
	| "mistralai/Mixtral-8x22B-Instruct-v0.1"
	| "NousResearch/Nous-Capybara-7B-V1p9"
	| "NousResearch/Nous-Hermes-2-Mistral-7B-DPO"
	| "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO"
	| "NousResearch/Nous-Hermes-2-Mixtral-8x7B-SFT"
	| "NousResearch/Nous-Hermes-llama-2-7b"
	| "NousResearch/Nous-Hermes-Llama2-13b"
	| "NousResearch/Nous-Hermes-2-Yi-34B"
	| "openchat/openchat-3.5-1210"
	| "Open-Orca/Mistral-7B-OpenOrca"
	| "Qwen/Qwen1.5-0.5B-Chat"
	| "Qwen/Qwen1.5-1.8B-Chat"
	| "Qwen/Qwen1.5-4B-Chat"
	| "Qwen/Qwen1.5-7B-Chat"
	| "Qwen/Qwen1.5-14B-Chat"
	| "Qwen/Qwen1.5-32B-Chat"
	| "Qwen/Qwen1.5-72B-Chat"
	| "snorkelai/Snorkel-Mistral-PairRM-DPO"
	| "togethercomputer/alpaca-7b"
	| "teknium/OpenHermes-2-Mistral-7B"
	| "teknium/OpenHermes-2p5-Mistral-7B"
	| "togethercomputer/Llama-2-7B-32K-Instruct"
	| "togethercomputer/RedPajama-INCITE-Chat-3B-v1"
	| "togethercomputer/RedPajama-INCITE-7B-Chat"
	| "togethercomputer/StripedHyena-Nous-7B"
	| "Undi95/ReMM-SLERP-L2-13B"
	| "Undi95/Toppy-M-7B"
	| "WizardLM/WizardLM-13B-V1.2"
	| "upstage/SOLAR-10.7B-Instruct-v1.0"

export type role = "system" | "user" | "assistant" | "tool"

export type moderation_category = "self-harm" | "sexual" | "hate/threatening" | "criminal" | "drugs"

export type response_format = {
	-- Future TogetherAI updates may add more supported types but it's just json_object for now.
	["type"]: "json_object",
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
	-- Future TogetherAI updates may add more supported types but it's just function for now.
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

local MODERATION_CATEGORY_MAP: { [string]: moderation_category } = {
	["01"] = "hate/threatening",
	["02"] = "sexual",
	["03"] = "criminal",
	["05"] = "drugs",
	["06"] = "self-harm",
}

local TogetherAIConversation = {}
TogetherAIConversation.__index = TogetherAIConversation

function TogetherAIConversation.new(config: config)
	assert(type(config) == "table", "TogetherAIConversation.new must be called with a config table")
	assert(type(config.key) == "string", "config.key must be an TogetherAI API key string")
	assert(type(config.prompt) == "string", "config.prompt must be a system prompt string")
	assert(type(config.id) == "string", "config.id must be an identifying string")

	local conversation = setmetatable({}, TogetherAIConversation)

	conversation._key = config.key
	conversation._subscriptions = {}

	conversation.token_usage = {
		prompt_tokens = 0,
		completion_tokens = 0,
		total_tokens = 0,
	}
	conversation.id = config.id
	conversation.model = config.model or "meta-llama/Llama-3-8b-chat-hf"
	conversation.response_format = config.response_format
	conversation.prompt = config.prompt
	conversation.messages = {
		{ role = "system", content = config.prompt },
	}
	conversation.message_metadata = {}
	conversation.tools = {} :: { tool_schema }
	conversation.tools_map = {} :: { [string]: (({ [string]: any }) -> any)? }

	if config.tools then
		conversation:SetTools(config.tools)
	end

	return conversation
end

function TogetherAIConversation:SetTools(tools: { tool_schema })
	self.tools = tools
	self.tools_map = {}

	for _, tool in self.tools do
		local func = tool["function"]
		self.tools_map[func.name] = func.callback
		func.callback = nil
	end
end

function TogetherAIConversation:_addTokens(tokens: token_usage)
	if not tokens then
		return
	end
	self.token_usage.prompt_tokens = (self.token_usage.prompt_tokens or 0) + (tokens.prompt_tokens or 0)
	self.token_usage.completion_tokens = (self.token_usage.completion_tokens or 0) + (tokens.completion_tokens or 0)
	self.token_usage.total_tokens = (self.token_usage.total_tokens or 0) + (tokens.total_tokens or 0)
end

function TogetherAIConversation:_addMessage(message: message, metadata: metadata?)
	metadata = metadata or {}
	table.insert(self.messages, table.freeze(message))
	self.message_metadata[message] = metadata

	for callback in self._subscriptions do
		task.spawn(callback, message, metadata)
	end
end

function TogetherAIConversation:AppendUserMessage(content: string): (boolean, message)
	local message = { role = "user" :: role, content = content }
	self:_addMessage(message)

	return true, message
end

function TogetherAIConversation:AppendSystemMessage(content: string): (boolean, message)
	local message = { role = "system" :: role, content = content }
	self:_addMessage(message)

	return true, message
end

function TogetherAIConversation:RequestAppendAIMessage(request_options: request_options): (boolean, string | message)
	assert(
		type(request_options) == "table",
		"TogetherAIConversation:RequestAppendAIMessage must be called with a request_options table"
	)

	local success, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = "https://api.together.xyz/v1/chat/completions",
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
			tools = if #self.tools > 0 then self.tools else nil,
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
		return false, "Failed to get reply from TogetherAI: " .. tostring(response)
	end

	if response.StatusCode ~= 200 then
		return false,
			"TogetherAI responded with error code: " .. tostring(response.StatusCode) .. " " .. tostring(
				response.StatusMessage
			) .. "\n" .. tostring(response.Body)
	end

	local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if not decodeSuccess then
		return false,
			"Failed to decode TogetherAI response body: " .. tostring(decodeResponse) .. "\n" .. tostring(response.Body)
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
					"AI attempted a tool call type '" .. tostring(tool_call.type) .. "', which is not supported yet."
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
					"Failed to decode TogetherAI function args: " .. tostring(decodeArgsResponse) .. "\n" .. tostring(
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

function TogetherAIConversation:DoesTextViolateContentPolicy(
	text: string
): (boolean, string | boolean, moderation_result?)
	assert(type(text) == "string", "TogetherAIConversation:DoesTextViolateContentPolicy must be called with a string")

	local success, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = "https://api.together.xyz/completions",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. self._key,
		},
		Body = HttpService:JSONEncode({
			model = "Meta-Llama/Llama-Guard-7b",
			stream = false,
			max_tokens = 30,
			stop = { "</s>" },
			prompt = [=[<s>[INST]Task: Check if there is unsafe content in 'user' messages in conversations according our safety policy with the below categories.
<BEGIN UNSAFE CONTENT CATEGORIES>
O1: Violence and Hate.
Should not
- Help people plan or engage in violence.
- Encourage people to engage in violence.
- Express hateful, derogatory, or demeaning sentiments against people based on sensitive personal characteristics like their race, color, religion, national origin, sexual orientation, gender, gender identity, or disability.
- Encourage discrimination against people based on those characteristics and should not use slurs or create insults based on those characteristics.
Can
-  Provide information on violence and discrimination.
- Discuss the topics of hate and violence, and can discuss historical events involving violence.
O2: Sexual Content.
Should not
- Engage in sexually explicit (i.e., erotic) conversations and should not encourage people to engage in sexual activities.
Can
- Discuss topics related to sexuality and sexual education.
- Provide general information regarding sexual activities.
- Provide guidance on topics related to sexual health.
O3: Criminal Planning.
Should not
- Help people plan or engage in criminal activities like theft, kidnapping, or financial crimes, especially when the person indicates that they may act on the information provided to them.
- Encourage people to engage in criminal activities or condone criminal behavior.
Can
- Help people understand how crimes are committed, provided that the response is not so detailed that it could be used to provide a roadmap for future crimes.
- Help people understand how systems work that are used to prevent crimes, provided those descriptions do not provide detailed information on how to defeat those systems.
O4: Guns and Illegal Weapons.
Should not
- Assist in the planning or execution of firearm or illegal weapons crimes, especially when the person indicates that they may act on the information provided to them.
- Encourage people to engage in firearm or illegal weapons crimes or condone such behavior.
Can
- Discuss firearms and the arguments for and against firearm ownership.
O5: Regulated or Controlled Substances.
Should not
- Encourage or assist people in the trafficking, consumption, or use of regulated or controlled substances, including but not limited to illegal drugs, tobacco, alcohol, and cannabis.
- Assist or encourage people to create such substances when it is illegal to do so.
Can
- Discuss the use of regulated or controlled substances, and can provide general information on those substances (ex: what their chemical composition is and what their effects are).
- Provide information on how those substances are manufactured, provided that the information is not so detailed as to provide step-by-step instructions for their creation.
O6: Self-Harm.
Should not
- Encourage people to harm themselves.
- Romanticize or condone self-harm or suicide.
- Provide information regarding the methods of suicide or self-harm.
- Provide any information or advice, other than information regarding appropriate health resources, to people who express or imply that they wish to harm themselves.
Can
- Provide general information regarding self-harm and suicide (ex: statistics, the mental health challenges faced by those who take these actions).
Should
- Provide information regarding appropriate health resources to people who imply or express the desire to harm themselves.
<END UNSAFE CONTENT CATEGORIES>

<BEGIN CONVERSATION>

user: ]=]
				.. text
				.. [=[

<END CONVERSATION>

Provide your safety assessment for user in the above conversation:
- First line must read 'safe' or 'unsafe'.
- If unsafe, a second line must include a comma-separated list of violated categories.[/INST]]=],
		}),
	})

	if not success then
		return false, "Failed to get reply from TogetherAI: " .. tostring(response)
	end

	if response.StatusCode ~= 200 then
		return false,
			"TogetherAI responded with error code: " .. tostring(response.StatusCode) .. tostring(
				response.StatusMessage
			) .. "\n" .. tostring(response.Body)
	end

	local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if not decodeSuccess then
		return false,
			"Failed to decode TogetherAI response body: " .. tostring(decodeResponse) .. "\n" .. tostring(response.Body)
	end

	local generated = decodeResponse.choices[1].text
	local moderation_result = {
		flagged = false,
		categories = {} :: { [moderation_category]: boolean },
		category_scores = {} :: { [moderation_category]: number },
	}
	if string.find(generated, "unsafe") then
		moderation_result.flagged = true
		for categoryId in string.gmatch(generated, "%d%d") do
			local category: moderation_category = MODERATION_CATEGORY_MAP[categoryId]
			if category then
				moderation_result.categories[category] = true
				moderation_result.category_scores[category] = 1
			end
		end
	end

	return true, moderation_result.flagged, moderation_result
end

function TogetherAIConversation:RequestVectorEmbedding(text: string): (boolean, string | { number })
	assert(type(text) == "string", "TogetherAIConversation:RequestVectorEmbedding must be called with a string")

	local success, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = "https://api.together.xyz/v1/embeddings",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. self._key,
		},
		Body = HttpService:JSONEncode({
			model = "togethercomputer/m2-bert-80M-8k-retrieval",
			input = text,
		}),
	})

	if not success then
		return false, "Failed to get reply from TogetherAI: " .. tostring(response)
	end

	if response.StatusCode ~= 200 then
		return false,
			"TogetherAI responded with error code: " .. tostring(response.StatusCode) .. tostring(
				response.StatusMessage
			) .. "\n" .. tostring(response.Body)
	end

	local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if not decodeSuccess then
		return false,
			"Failed to decode TogetherAI response body: " .. tostring(decodeResponse) .. "\n" .. tostring(response.Body)
	end

	self:_addTokens(decodeResponse.usage)

	return true, decodeResponse.data[1].embedding :: { number }
end

function TogetherAIConversation:ClearMessages()
	self.message_metadata = {}
	self.messages = {
		{ role = "system", content = self.prompt },
	}
	self.token_usage = {
		prompt_tokens = 0,
		completion_tokens = 0,
		total_tokens = 0,
	}
end

function TogetherAIConversation:GetMessages(): { message }
	return table.clone(self.messages)
end

function TogetherAIConversation:SubscribeToNewMessages(callback: (message: message, metadata: metadata) -> ()): () -> ()
	self._subscriptions[callback] = true
	return function()
		self._subscriptions[callback] = nil
	end
end

return TogetherAIConversation
