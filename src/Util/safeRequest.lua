--!strict

local HttpService = game:GetService("HttpService")

local types = require(script.Parent.Parent.types)

export type Params = {
	Url: string,
	Method: string,
	Headers: { [string]: string },
	Body: string,
}

local function safeRequest<Response>(params: Params): types.Result<Response, types.ProviderErrors>
	local requestSuccess, requestResponse = pcall(HttpService.RequestAsync, HttpService, params)

	if not requestSuccess then
		return {
			success = false,
			error = "http_err",
			details = requestResponse,
		}
	end

	local decodeSuccess, decodeResponse = pcall(HttpService.JSONDecode, HttpService, requestResponse.Body)

	if (not decodeSuccess) or (type(decodeResponse) ~= "table") then
		return {
			success = false,
			error = "decode_fail",
			details = decodeResponse,
		}
	end

	if requestResponse.StatusCode ~= 200 then
		if decodeResponse.error and decodeResponse.error.type == "moderation_block" then
			return {
				success = false,
				error = "safety_filter",
				details = decodeResponse.error.message,
			}
		end

		return {
			success = false,
			error = "http_err",
			details = decodeResponse,
		}
	end

	return {
		success = true,
		value = decodeResponse :: Response,
	}
end

return safeRequest
