--[[
[metadata]
description=Send a unified notification to the current notifier front-end. Will be deprecated in the future.
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local get_conf = neo.api.config.get_config


lib.notify = function(status, ...)
	local args = {...}
	local notif_id = get_conf("current_notif")

	if not notif_id or notif_id == "" then
		return
	end

	if not lib.is_exist(notif_id, "0") then
		return
	end

	if lib.is_ready(notif_id) then
		lib.execute(notif_id, "0", "notif", status, ...)
	else
		lib.require({{id = notif_id, version = "0"}}, function()
			lib.notify(status, unpack(args))
		end)
	end
end