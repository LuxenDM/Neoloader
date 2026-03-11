--[[
[metadata]
description=Capture/log an error; route to recovery (no hard throws)
version=1.0.3
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib
local get_config = neo.api.config.get_config
local recovery = neo.api.recovery_system  -- guaranteed loaded before API

-- Returns:
--   false -> no error condition
--   true  -> handled (logged; forwarded to recovery; popup/open per config)
lib.err_handle = function(test, log_msg)
	-- v6 one-arg convenience
	if log_msg == nil and type(test) == "string" then
		log_msg = test
		test = true
	end
	if type(test) ~= "boolean" then
		test = (test ~= nil)
	end
	if not test then
		return false
	end

	-- Compose + log
	local err = debug.traceback("Neoloader captured an error: " .. tostring(log_msg))
	lib.log_error(err, 4)
	lib.notify("CAPTURED_ERROR", err)

	-- Always record the error in recovery
	recovery.error = err
	recovery.push_error()

	-- User-facing behavior
	local mode = get_config("do_err_popup") or "NO"  -- "NO" | "YES" | "INTERRUPT"
	if mode == "INTERRUPT" then
		recovery.popup()      -- interrupt load safely, no CTD
	elseif mode == "YES" then
		recovery.open()       -- show the recovery UI, non-blocking
	end

	return true
end
