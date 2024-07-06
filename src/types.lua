export type ToolCall = {
	tool_id: string,
	tool_call_id: string,
	args: any?,
}

export type ToolArgs = {
	type: "object",
	properties: { [string]: any },
	required: { string },
}

export type ToolSchema = {
	name: string,
	description: string,
	args: ToolArgs,
}

export type Tool = {
	id: string,
	func: (any?) -> { [any]: any },
	name: string,
	description: string,
	args: ToolArgs,
}

export type SystemMessage = {
	role: "system",
	content: string,
}

export type UserMessage = {
	role: "user",
	content: string,
}

export type AIMessage = {
	role: "ai",
	content: string,
	tool_calls: { ToolCall }?,
}

export type ToolMessage = {
	role: "tool",
	tool_id: string,
	tool_call_id: string,
	content: { [any]: any },
}

export type Message = SystemMessage | UserMessage | AIMessage | ToolMessage

export type MessageMetadata = {
	id: string,
	timestamp: number?,
}

export type TokenUsage = {
	input: number,
	output: number,
}

export type GenerationOptions = {
	stop_sequences: { string }?,
	max_tokens: number?,
	temperature: number?,
}

export type ProviderResponse = {
	token_usage: TokenUsage,
	content: string,
	tool_calls: { ToolCall }?,
	id: string,
}

export type SafetyErrors = "safety_filter" | "text_filter"
export type ProviderErrors = "http_err" | "decode_fail" | "rate_limit" | "token_limit" | "other" | SafetyErrors
export type ToolErrors = "tool_missing" | "tool_crash"

type SuccessResult<T> = { success: true, value: T }
type FailureResult<E> = { success: false, error: E, details: any? }
export type Result<T, E> = SuccessResult<T> | FailureResult<E>

return {}
