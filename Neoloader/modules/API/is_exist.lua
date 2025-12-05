--[[
[metadata]
description=Check if a plugin (optionally a specific version) exists in the registry
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.is_exist = function(name, version)
	name, version = lib.pass_ini_identifier(name, version)
	if lib.err_handle(type(name) ~= "string",
		"lib.is_exist expected a string for its first argument, got " .. type(name)) then
		return false, "plugin ID not a string"
	end

	-- ID known?
	if not reg.has_id(name) then
		return false, "doesn't exist as ID only"
	end

	-- "0" → pick latest active, else newest known
	version = tostring(version or "0")
	if version == "0" then
		local status, lv = reg.get_latest_ver(name)
		if not status then
			return false, lv
		end
		version = lv
	end

	local ok = false
	do
		local found, _, rec = reg.find_plugin(name, version)
		ok = (found and rec ~= nil)
	end
	if not ok then
		return false, "specific version doesn't exist"
	end
	return true
end
