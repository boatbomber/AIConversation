local AIConversation = {}

AIConversation.OpenAI = require(script.Providers.OpenAI)
AIConversation.TogetherAI = require(script.Providers.TogetherAI)

return AIConversation
