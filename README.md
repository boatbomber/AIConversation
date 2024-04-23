# AI Conversation

A module for interacting with OpenAI chatbots from Roblox

## Usage Example

```Lua
local AIConversation = require(script.AIConversation)

local tutorConvo = AIConversation.OpenAI.new({
	id = "UsageExample",
	key = API_KEY,
	prompt = PROMPT,
	tools = {
		{
			["type"] = "function",
			["function"] = {
				name = "Concatenate",
				description = "Returns the concatenation of two strings.",
				parameters = {
					type = "object",
					properties = {
						a = { type = "string", description = "The lefthand string" },
						b = { type = "string", description = "The righthand string" },
					},
					required = {"a", "b"},
				},
				callback = function(props)
					return (props.a or "") .. (props.b or "")
				end,
			},
		},
	},
})

tutorConvo:SubscribeToNewMessages(function(message: AIConversation.message, metadata: AIConversation.metadata)
	print(message.role .. ":", message.content)
end)

tutorConvo:AppendUserMessage("Can you explain how to use a for loop?")
tutorConvo:RequestAppendAIMessage({ max_tokens = 250 })

tutorConvo:AppendUserMessage("I don't really understand that last part, can you rephrase just that bit?")
tutorConvo:RequestAppendAIMessage({ max_tokens = 150 })
```
Output:
> user: Can you explain how to use a for loop?

> assistant: Of course, I'd be happy to explain how to use a for loop in Lua!
A for loop is used to execute a block of code a specific number of times. Here's the basic syntax:
> ```lua
> for variable = start_value, end_value, step do
>   -- code to be executed
> end
> ```
> The `variable` is a variable that you define to control the number of iterations. It is typically used to track the current iteration. The `start_value` is the initial value of the variable. The `end_value` is the value at which the loop should stop iterating. The `step` is the amount by which the variable should be incremented (or decremented) after each iteration.
>
> Here's an example to help illustrate how a for loop works:
>
> ```lua
> for i = 1, 5, 1 do
>   print(i)
> end
> ```

> user: I don't really understand that last part, can you rephrase just that bit?

> assistant: Certainly! The `step` is the amount by which the variable should change after each iteration. For example, if the `step` is 1, the variable will increase by 1 after each iteration. If the `step` is -1, the variable will decrease by 1 after each iteration. The `step` determines the direction and magnitude of the change to the variable.

## API

### Types

```Lua
type role = "system" | "user" | "assistant" | "tool"

type response_format = {
	["type"]: "text" | "json",
}

type moderation_result = {
	flagged: boolean,
	categories: { [moderation_category]: boolean },
	category_scores: { [moderation_category]: number },
}

type tool_call = {
	["id"]: string,
	["type"]: "function",
	["function"]: {
		name: string,
		arguments: string,
	},
}

type message = {
	role: role,
	content: string,
	tool_calls: { tool_call }?,
	name: string?,
	tool_call_id: string?,
}

type function_schema = {
	name: string,
	description: string?,
	parameters: any,
	callback: (({ [string]: any }) -> any)?,
}

type tool_schema = {
	["type"]: "function",
	["function"]: function_schema,
}

type token_usage = {
	prompt_tokens: number?,
	completion_tokens: number?,
	total_tokens: number?,
}

type metadata = { [any]: any }

type config = {
	-- A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
	id: string,
	-- An OpenAI API Key.
	key: string,
	-- ID of the AI model to use.
	model: model?,
	-- The system prompt to start the conversation.
	prompt: string,
	-- An object specifying the format that the model must output.
	response_format: response_format?,
	-- A list of tools the model may generate calls for.
	tools: { tool_schema }?,
}

type request_options = {
    -- The maximum number of tokens to generate in the chat completion.
    max_tokens: number?,
	-- What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.
    temperature: number?,
    -- Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics.
    presence_penalty: number?,
    -- Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim.
    frequency_penalty: number?,
    -- Up to 4 sequences where the API will stop generating further tokens.
    stop: string? | { string }?,
}
```

-----

```Lua
function AIConversation.OpenAI.new(config: config): Conversation
function AIConversation.TogetherAI.new(config: config): Conversation
```

Creates a new Conversation object with the given configuration

### Conversation

```Lua
string Conversation.id
```
A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.

```Lua
model Conversation.model
```
ID of the AI model to use.

```Lua
number Conversation.temperature
```
What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.

```Lua
tokenUsage Conversation.token_usage
```
How many tokens this conversation has used thus far.

```Lua
function Conversation:AppendUserMessage(content: string): (boolean, message)
```
Appends a new message to the conversation from the 'user' role.

```Lua
function Conversation:AppendSystemMessage(content: string): (boolean, message)
```
Appends a new message to the conversation from the 'system' role.

```Lua
function Conversation:RequestAppendAIMessage(request_options: request_options): (boolean, string | message)
```
Appends a new message from the AI to the conversation, using OpenAI web endpoints.

```Lua
function conversation:DoesTextViolateContentPolicy(text: string) : (boolean, string | boolean, moderationResult?)
```
Returns whether the text violates OpenAI's content policy, along with the Moderation response.

```Lua
function conversation:RequestVectorEmbedding(text: string): (boolean, string | { number })
```
Returns an array of numbers representing a high dimensionality vector embedding of the text.

```Lua
function conversation:SetFunctions(functions: { functionSchema })
```
Same as passing `functions` in config, but can be done at any time.

```Lua
function Conversation:ClearMessages()
```
Wipes the messages and sets token_usage to 0. Retains the initial system prompt.

```Lua
function Conversation:GetMessages(): { message }
```
Returns a list of messages comprising the conversation so far.

```Lua
function Conversation:SubscribeToNewMessages(callback: (message: message, metadata: metadata) -> ()): () -> ()
```
Subscribes the given callback to all new message appends, and returns an unsubscribe function.
