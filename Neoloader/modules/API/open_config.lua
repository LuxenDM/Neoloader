--[[
[metadata]
description=Opens the current LME management front-end
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local get_conf = neo.api.config.get_config
local rs = neo.api.recovery_system

local cp = console_print

lib.open_config = function()
	local mgr_id = get_conf("current_mgr")
	
	cp("mgr_id is " .. mgr_id)
	
	if not mgr_id
		or mgr_id == ""
		or not lib.is_exist(mgr_id, "0")
	then
		rs.push_error(
			"RECOV_STARTUP_MGR_CHECK_FAILURE_OPEN_CONFIG_CALLED|lib.open_config was called but no management front-end was available. The recovery system was opened instead.",
			{
				tag = "startup",
				critical = true,
			}
		)
		return
	end
	
	cp("\tnot fail")
	
	if lib.is_ready(mgr_id, "0") then
		cp("\tcalling lib.execute('" .. mgr_id .. "', '0', 'open')")
		lib.execute(mgr_id, "0", "open")
		return
	end
	
	cp("\tnot ready")
	
	lib.require({{id = mgr_id, version = "0"}}, function()
		lib.execute(mgr_id, "0", "open")
	end)
end