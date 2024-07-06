--!strict

export type Price = {
	input: number,
	output: number,
}

export type Config = {
	price: Price,
	tool_support: boolean,
}

local ModelConfigs: { [string]: Config } = {
	["default"] = {
		price = {
			input = 1.00,
			output = 1.00,
		},
		tool_support = true,
	},

	-- OpenAI models
	["gpt-3.5-turbo"] = {
		price = {
			input = 0.50,
			output = 1.50,
		},
		tool_support = true,
	},
	["gpt-4-turbo"] = {
		price = {
			input = 10.00,
			output = 30.00,
		},
		tool_support = true,
	},
	["gpt-4"] = {
		price = {
			input = 30.00,
			output = 60.00,
		},
		tool_support = true,
	},
	["gpt-4o"] = {
		price = {
			input = 5.00,
			output = 15.00,
		},
		tool_support = true,
	},

	-- Google models
	["gemini-1.0-pro"] = {
		price = {
			input = 0.50,
			output = 1.50,
		},
		tool_support = true,
	},
	["gemini-1.5-pro"] = {
		price = {
			input = 3.50,
			output = 10.50,
		},
		tool_support = true,
	},
	["gemini-1.5-flash"] = {
		price = {
			input = 0.35,
			output = 1.05,
		},
		tool_support = true,
	},

	-- Together AI models
	["Meta-Llama/Llama-Guard-7b"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},
	["mistralai/Mistral-7B-Instruct-v0.2"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},
	["mistralai/Mistral-7B-Instruct-v0.3"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},
	["meta-llama/Llama-3-8b-chat-hf"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},
	["meta-llama/Llama-3-70b-chat-hf"] = {
		price = {
			input = 0.90,
			output = 0.90,
		},
		tool_support = false,
	},
	["Qwen/Qwen2-72B-Instruct"] = {
		price = {
			input = 0.90,
			output = 0.90,
		},
		tool_support = false,
	},
}

return ModelConfigs
