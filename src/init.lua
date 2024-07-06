local BaseChat = require(script.Providers.BaseChat)

local Providers = {}
for _, provider in script:FindFirstChild("Providers"):GetChildren() do
	Providers[provider.Name] = require(provider)
end

local ProviderPrefixes = {
	["^google/"] = Providers["Google"],
	["^openai/"] = Providers["OpenAI"],
}

local AIConversation = {}

function AIConversation.new(model_id, ...): BaseChat.BaseChat
	for prefix, provider in ProviderPrefixes do
		if string.find(model_id, prefix) then
			model_id = string.gsub(model_id, prefix, "")
			return provider.new(model_id, ...)
		end
	end

	return Providers["TogetherAI"].new(model_id, ...)
end

return AIConversation
