local ModelConfigs = require(script.Parent.Parent.ModelConfigs)

local function getModelConfig(model_id: string): ModelConfigs.Config
    return ModelConfigs[model_id] or ModelConfigs["default"]
end

return getModelConfig