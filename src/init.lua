local BaseChat = require(script.Providers.BaseChat)

export type Converation = BaseChat.BaseChat

local EXCLUDED_PROVIDERS = {
	BaseChat = true,
}

local Providers = {}
local KnownProviders = {}
for _, provider in script:FindFirstChild("Providers"):GetChildren() do
	if not EXCLUDED_PROVIDERS[provider.Name] then
		Providers[provider.Name] = require(provider)
		table.insert(KnownProviders, provider.Name)
	end
end
table.sort(KnownProviders)
local KnownProvidersString = table.concat(KnownProviders, ", ")

local AIConversation = {}

function AIConversation.new(provider: string, model_id: string, api_key: string): BaseChat.BaseChat
	local providerModule = Providers[provider]
	if not providerModule then
		error(`Unknown provider "{provider}". Valid providers: {KnownProvidersString}`)
	end

	return providerModule.new(model_id, api_key)
end

return AIConversation
