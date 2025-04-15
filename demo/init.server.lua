local Secrets = require(script.secrets)
local AIConversation = require(script.AIConversation)

local tools = {
	["get_weather"] = function(args)
		if type(args) ~= "table" or type(args.location) ~= "string" then
			return {
				success = false,
				error = "Invalid arguements",
			}
		end

		return {
			success = true,
			result = {
				temperature = 79,
				temperature_unit = "F",
				humidity = 30,
			},
		}
	end,
}

-- local Convo = AIConversation.new("deepseek-ai/DeepSeek-R1-Distill-Qwen-14B", Secrets.TogetherAI)
-- local Convo = AIConversation.new("openai/gpt-4.1-nano", Secrets.OpenAI)
local Convo = AIConversation.new("google/gemini-2.0-flash", Secrets.Google)

Convo:addTool("get_weather", tools["get_weather"], {
	name = "get_weather",
	description = "Get the current weather information for the given location",
	args = {
		type = "object",
		properties = {
			location = {
				type = "string",
				description = "The city and state, e.g. San Francisco, CA or a zip code e.g. 95616",
			},
		},
		required = {
			"location",
		},
	},
})

Convo:addUserMessage("What's the weather in New York City?")

print("AI Message:", Convo:requestAIMessage())
print("Messages:", Convo._messages)
print("Formatted Messages:", Convo._formatted_messages)
