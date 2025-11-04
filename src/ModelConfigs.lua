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
	["gpt-4o"] = {
		price = {
			input = 5.00,
			output = 15.00,
		},
		tool_support = true,
	},
	["gpt-4o-mini"] = {
		price = {
			input = 0.15,
			output = 0.60,
		},
		tool_support = true,
	},
	["gpt-4.1"] = {
		price = {
			input = 2.00,
			output = 8.00,
		},
		tool_support = true,
	},
	["gpt-4.1-mini"] = {
		price = {
			input = 0.40,
			output = 1.60,
		},
		tool_support = true,
	},
	["gpt-4.1-nano"] = {
		price = {
			input = 0.10,
			output = 0.40,
		},
		tool_support = true,
	},
	["o1"] = {
		price = {
			input = 15.00,
			output = 60.00,
		},
		tool_support = true,
	},
	["o3-mini"] = {
		price = {
			input = 1.10,
			output = 4.40,
		},
		tool_support = true,
	},

	-- Google models
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
	["gemini-2.0-flash"] = {
		price = {
			input = 0.10,
			output = 0.40,
		},
		tool_support = true,
	},
	["gemini-2.0-flash-lite"] = {
		price = {
			input = 0.075,
			output = 0.30,
		},
		tool_support = true,
	},
	["gemini-2.5-pro-preview-03-25"] = {
		price = {
			input = 1.25,
			output = 10.00,
		},
		tool_support = true,
	},

	-- Together AI models
	["deepseek-ai/DeepSeek-R1"] = {
		price = {
			input = 3.00,
			output = 7.00,
		},
		tool_support = false,
	},
	["deepseek-ai/DeepSeek-R1-Distill-Llama-70B"] = {
		price = {
			input = 2.00,
			output = 2.00,
		},
		tool_support = true,
	},
	["deepseek-ai/DeepSeek-R1-Distill-Qwen-14B"] = {
		price = {
			input = 1.60,
			output = 1.60,
		},
		tool_support = true,
	},
	["deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B"] = {
		price = {
			input = 0.18,
			output = 0.18,
		},
		tool_support = true,
	},
	["deepseek-ai/DeepSeek-V3"] = {
		price = {
			input = 1.25,
			output = 1.25,
		},
		tool_support = true,
	},
	["meta-llama/Meta-Llama-Guard-3-8B"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},
	["meta-llama/Llama-3.3-70B-Instruct-Turbo"] = {
		price = {
			input = 0.88,
			output = 0.88,
		},
		tool_support = true,
	},
	["meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo"] = {
		price = {
			input = 0.18,
			output = 0.18,
		},
		tool_support = true,
	},
	["meta-llama/Llama-3.2-3B-Instruct-Turbo"] = {
		price = {
			input = 0.06,
			output = 0.06,
		},
		tool_support = true,
	},
	["Qwen/QwQ-32B"] = {
		price = {
			input = 1.20,
			output = 1.20,
		},
		tool_support = true,
	},
	["Qwen/Qwen2.5-7B-Instruct-Turbo"] = {
		price = {
			input = 0.30,
			output = 0.30,
		},
		tool_support = true,
	},
	["Qwen/Qwen2.5-Coder-32B-Instruct"] = {
		price = {
			input = 0.80,
			output = 0.80,
		},
		tool_support = false,
	},
	["Qwen/Qwen2.5-72B-Instruct-Turbo"] = {
		price = {
			input = 1.20,
			output = 1.20,
		},
		tool_support = true,
	},
	["mistralai/Mistral-Small-24B-Instruct-2501"] = {
		price = {
			input = 0.80,
			output = 0.80,
		},
		tool_support = true,
	},
	["mistralai/Mistral-7B-Instruct-v0.3"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},

	-- OpenRouter models (pricing from OpenRouter)
	["anthropic/claude-3.5-sonnet"] = {
		price = {
			input = 3.00,
			output = 15.00,
		},
		tool_support = true,
	},
	["anthropic/claude-3-opus"] = {
		price = {
			input = 15.00,
			output = 75.00,
		},
		tool_support = true,
	},
	["anthropic/claude-3-sonnet"] = {
		price = {
			input = 3.00,
			output = 15.00,
		},
		tool_support = true,
	},
	["anthropic/claude-3-haiku"] = {
		price = {
			input = 0.25,
			output = 1.25,
		},
		tool_support = true,
	},
	["openai/gpt-4-turbo"] = {
		price = {
			input = 10.00,
			output = 30.00,
		},
		tool_support = true,
	},
	["openai/gpt-3.5-turbo"] = {
		price = {
			input = 0.50,
			output = 1.50,
		},
		tool_support = true,
	},
	["google/gemini-pro-1.5"] = {
		price = {
			input = 2.50,
			output = 10.00,
		},
		tool_support = true,
	},
	["google/gemini-flash-1.5"] = {
		price = {
			input = 0.075,
			output = 0.30,
		},
		tool_support = true,
	},
	["meta-llama/llama-3.1-405b-instruct"] = {
		price = {
			input = 2.70,
			output = 2.70,
		},
		tool_support = true,
	},
	["meta-llama/llama-3.1-70b-instruct"] = {
		price = {
			input = 0.52,
			output = 0.75,
		},
		tool_support = true,
	},
	["meta-llama/llama-3.1-8b-instruct"] = {
		price = {
			input = 0.06,
			output = 0.06,
		},
		tool_support = true,
	},
	["mistralai/mistral-large"] = {
		price = {
			input = 3.00,
			output = 9.00,
		},
		tool_support = true,
	},
	["mistralai/mistral-medium"] = {
		price = {
			input = 2.70,
			output = 8.10,
		},
		tool_support = true,
	},
	["x-ai/grok-beta"] = {
		price = {
			input = 5.00,
			output = 15.00,
		},
		tool_support = true,
	},
	["deepseek/deepseek-chat"] = {
		price = {
			input = 0.14,
			output = 0.28,
		},
		tool_support = true,
	},
	["perplexity/llama-3.1-sonar-large-128k-online"] = {
		price = {
			input = 1.00,
			output = 1.00,
		},
		tool_support = true,
	},
}

return ModelConfigs
