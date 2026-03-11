--[[
[metadata]
description=wraps and exposes ReloadInterface with an additional management step
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local get_conf = neo.api.config.get_config

neo.lib.reload = function()
	if not neo.api.get_statelock_value() then
		--cannot reload() until statelock is set (START/PLUGINS_LOADED event)
		return
	end
	
	ProcessEvent("PRE_RELOAD_INTERFACE")
	
	-- command clearing: is now tied to the PLUGINS_LOADED event in the game, we don't trigger it manually here
	
	ReloadInterface()
end

RegisterUserCommand("reload", neo.lib.reload)