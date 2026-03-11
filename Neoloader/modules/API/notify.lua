--[[
[metadata]
description=Send a unified notification to the current notifier front-end
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local get_conf = neo.api.config.get_config


lib.notify = function(status, ...)
	args = ...
	if type(args) ~= "table" then
		args = {args}
	end
	
	local notif_id = get_conf("current_notif")
	
	if lib.is_ready(notif_id) then
		lib.execute(notif_id, "0", "notif", status, ...)
	else
		lib.require({{id = notif_id, version = "0"}}, function()
			lib.notify(status, args)
		end)
	end
end