--[[
[metadata]
description=Configure Neoloader settings via the v7 config manager
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local config = neo.api.config

-- Returns:
--	 true, "ok"						on success (and logs the change)
--	 false, "reason"			 on failure (invalid key/value or unauthorized)
lib.lme_configure = function(cfg_option, new_val, auth)
	cfg_option = tostring(cfg_option or "")
	local ok, msg = config.set_config(auth, cfg_option, tostring(new_val))

	if ok then
		lib.log_error("Configuration change: " .. cfg_option .. " >> " .. tostring(new_val), 1)
		return true, "ok"
	else
		-- preserve v6-ish behavior of returning failure without side effects
	console_print("config change failure: " .. tostring(msg))
		return false, msg or "failed"
	end
end
