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

	-- OpenAI models (Standard tier, per 1M tokens)
	["gpt-5.5"] = {
		price = {
			input = 5.00,
			output = 30.00,
		},
		tool_support = true,
	},
	["gpt-5.4"] = {
		price = {
			input = 2.50,
			output = 15.00,
		},
		tool_support = true,
	},
	["gpt-5.4-mini"] = {
		price = {
			input = 0.75,
			output = 4.50,
		},
		tool_support = true,
	},
	["gpt-5.4-nano"] = {
		price = {
			input = 0.20,
			output = 1.25,
		},
		tool_support = true,
	},
	["gpt-5.2"] = {
		price = {
			input = 1.75,
			output = 14.00,
		},
		tool_support = true,
	},
	["gpt-5.1"] = {
		price = {
			input = 1.25,
			output = 10.00,
		},
		tool_support = true,
	},
	["gpt-5"] = {
		price = {
			input = 1.25,
			output = 10.00,
		},
		tool_support = true,
	},
	["gpt-5-mini"] = {
		price = {
			input = 0.25,
			output = 2.00,
		},
		tool_support = true,
	},
	["gpt-5-nano"] = {
		price = {
			input = 0.05,
			output = 0.40,
		},
		tool_support = true,
	},
	["gpt-4o"] = {
		price = {
			input = 2.50,
			output = 10.00,
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
	["o3"] = {
		price = {
			input = 2.00,
			output = 8.00,
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
	["o4-mini"] = {
		price = {
			input = 1.10,
			output = 4.40,
		},
		tool_support = true,
	},

	-- Google models (Standard paid tier, per 1M tokens)
	["gemini-3.5-flash"] = {
		price = {
			input = 1.50,
			output = 9.00,
		},
		tool_support = true,
	},
	["gemini-3.1-flash-lite"] = {
		price = {
			input = 0.25,
			output = 1.50,
		},
		tool_support = true,
	},
	["gemini-3.1-pro-preview"] = {
		price = {
			input = 2.00,
			output = 12.00,
		},
		tool_support = true,
	},
	["gemini-3-flash-preview"] = {
		price = {
			input = 0.50,
			output = 3.00,
		},
		tool_support = true,
	},
	["gemini-2.5-pro"] = {
		price = {
			input = 1.25,
			output = 10.00,
		},
		tool_support = true,
	},
	["gemini-2.5-flash"] = {
		price = {
			input = 0.30,
			output = 2.50,
		},
		tool_support = true,
	},
	["gemini-2.5-flash-lite"] = {
		price = {
			input = 0.10,
			output = 0.40,
		},
		tool_support = true,
	},

	-- Together AI models
	["zai-org/GLM-5.2"] = {
		price = {
			input = 1.40,
			output = 4.40,
		},
		tool_support = true,
	},
	["MiniMaxAI/MiniMax-M3"] = {
		price = {
			input = 0.30,
			output = 1.20,
		},
		tool_support = true,
	},
	["moonshotai/Kimi-K2.7-Code"] = {
		price = {
			input = 0.95,
			output = 4.00,
		},
		tool_support = true,
	},
	["deepseek-ai/DeepSeek-V4-Pro"] = {
		price = {
			input = 1.74,
			output = 3.48,
		},
		tool_support = true,
	},
	["zai-org/GLM-5.1"] = {
		price = {
			input = 1.40,
			output = 4.40,
		},
		tool_support = true,
	},
	["nvidia/nemotron-3-ultra-550b-a55b"] = {
		price = {
			input = 0.60,
			output = 3.60,
		},
		tool_support = true,
	},
	["moonshotai/Kimi-K2.6"] = {
		price = {
			input = 1.20,
			output = 4.50,
		},
		tool_support = true,
	},
	["MiniMaxAI/MiniMax-M2.7"] = {
		price = {
			input = 0.30,
			output = 1.20,
		},
		tool_support = true,
	},
	["Qwen/Qwen3.7-Max"] = {
		price = {
			input = 1.25,
			output = 3.75,
		},
		tool_support = false,
	},
	["Qwen/Qwen3.5-397B-A17B"] = {
		price = {
			input = 0.60,
			output = 3.60,
		},
		tool_support = true,
	},
	["google/gemma-4-31B-it"] = {
		price = {
			input = 0.39,
			output = 0.97,
		},
		tool_support = true,
	},
	["pearl-ai/gemma-4-31b-it"] = {
		price = {
			input = 0.28,
			output = 0.86,
		},
		tool_support = true,
	},
	["openai/gpt-oss-120b"] = {
		price = {
			input = 0.15,
			output = 0.60,
		},
		tool_support = true,
	},
	["openai/gpt-oss-20b"] = {
		price = {
			input = 0.05,
			output = 0.20,
		},
		tool_support = true,
	},
	["zai-org/GLM-5"] = {
		price = {
			input = 1.00,
			output = 3.20,
		},
		tool_support = true,
	},
	["Qwen/Qwen3.5-9B"] = {
		price = {
			input = 0.17,
			output = 0.25,
		},
		tool_support = true,
	},
	["Qwen/Qwen3-235B-A22B-Instruct-2507-tput"] = {
		price = {
			input = 0.20,
			output = 0.60,
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
	["meta-llama/Llama-3.3-70B-Instruct-Turbo"] = {
		price = {
			input = 1.04,
			output = 1.04,
		},
		tool_support = true,
	},
	["meta-llama/Meta-Llama-3-8B-Instruct-Lite"] = {
		price = {
			input = 0.14,
			output = 0.14,
		},
		tool_support = false,
	},
	["google/gemma-3n-E4B-it"] = {
		price = {
			input = 0.06,
			output = 0.12,
		},
		tool_support = false,
	},
	["LiquidAI/LFM2-24B-A2B"] = {
		price = {
			input = 0.03,
			output = 0.12,
		},
		tool_support = true,
	},
	["essentialai/rnj-1-instruct"] = {
		price = {
			input = 0.15,
			output = 0.15,
		},
		tool_support = true,
	},
	["deepcogito/cogito-v2-1-671b"] = {
		price = {
			input = 1.25,
			output = 1.25,
		},
		tool_support = true,
	},
	["Qwen/Qwen3.6-Plus"] = {
		price = {
			input = 0.50,
			output = 3.00,
		},
		tool_support = false,
	},
	["Qwen/Qwen3.7-Plus"] = {
		price = {
			input = 0.32,
			output = 1.28,
		},
		tool_support = false,
	},
	["meta-llama/Llama-Guard-4-12B"] = {
		price = {
			input = 0.20,
			output = 0.20,
		},
		tool_support = false,
	},
}

return ModelConfigs
