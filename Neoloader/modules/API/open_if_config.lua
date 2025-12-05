--[[
[metadata]
description=Opens the current interface configuration menu
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local get_conf = neo.api.config.get_config
local rs = neo.api.recovery_system

lib.open_if_config = function()
	local if_id = get_conf("current_if")
	if not if_id or if_id == "" then
		-- no interface configured - most users will be stuck with a blank screen if this happens!
		-- NORMALLY neoloader will detect this and manually launch the default game interface directly, but the 'management' of the default IF is provided by a mod distrubuted with Neoloader. 
		-- It must be disabled or erroring, so if the user tries to manage it, we handle panic state here.
		-- fallback to opening the recovery system which can provide minimal management
		rs.error = "No interface is configured!"
		rs.critical = true
		rs.push_error()
		return
	end
	
	if lib.is_ready(if_id, "0") then
		lib.execute(if_id, "0", "open")
		return
	end
	
	lib.require({{id = if_id, version = "0"}}, function()
		lib.execute(if_id, "0", "open")
	end)
end