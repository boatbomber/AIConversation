--!strict

local TextService = game:GetService("TextService")

local cache = {}

local function textFilter(text: string, recipientId: number): string
	if type(text) ~= "string" then
		return ""
	end
	if not string.find(text, "%S") then
		return ""
	end

	if cache[text] then
		return cache[text]
	end

	local filterSuccess, filterResult = pcall(function()
		local TextFilterResult = TextService:FilterStringAsync(text, recipientId)
		return TextFilterResult:GetNonChatStringForUserAsync(recipientId)
	end)
	if not filterSuccess then
		return "[Filter Error]: " .. filterResult
	end

	cache[text] = filterResult
	return filterResult
end

return textFilter
