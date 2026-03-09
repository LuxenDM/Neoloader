--[[
[metadata]
description=Get the latest version of a plugin, optionally with lower and upper bounds
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local reg = neo.api.registry

neo.lib.get_latest = function(id, min, max)
	id = tostring(id or "null")

	-- fast existence check
	if not reg.has_id(id) then
		return "?"
	end

	local status, ver = reg.get_latest_ver(id, min, max)
	if not status then
		return "?"
	end
	return ver
end