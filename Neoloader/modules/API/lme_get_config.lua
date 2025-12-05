--[[
[metadata]
description=Read Neoloader configuration values via config manager
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local config = neo.api.config

lib.lme_get_config = function(cfg_option)
	-- No argument → return list of all known keys
	if not cfg_option then
		local keys = {}
		for k, _ in pairs(config.get_all_keys()) do
			table.insert(keys, k)
		end
		return keys
	end

	cfg_option = tostring(cfg_option)
	local val = config.get_config(cfg_option)
	if val == nil then
		return false, "option does not exist"
	end
	return val
end
