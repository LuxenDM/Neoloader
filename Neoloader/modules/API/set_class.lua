--[[
[metadata]
description=Replace a plugin's class table (fails if locked); returns true on success or false,reason
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.set_class = function(name, version, ftable)
	name, version = lib.pass_ini_identifier(name, version)
	if lib.err_handle(type(name) ~= "string",
		"lib.set_class expected a string for its first argument, got " .. type(name)) then
		return false, "plugin ID not a string"
	end

	version = tostring(version or "0")
	if version == "0" then
		version = reg.substitute_zero(name, "0")
		lib.log_error("Plugin " .. name .. " registered its class using wildcard version '0'. This is deprecated for self-registration and may resolve unpredictably across installed versions. It is also a very bad practice. Use the plugin’s literal version instead.", 3)
	end

	lib.log_error("Setting class for " .. name .. " v" .. tostring(version), 1)

	if type(ftable) ~= "table" then
		ftable = { ftable }
	end

	if not lib.is_exist(name, version) then
		return false, "mod doesn't exist"
	end

	local ok, _, rec = reg.find_plugin(name, version)
	if not ok or not rec then
		return false, "mod doesn't exist"
	end

	if rec.container_locked then
		return false, "locked"
	end

	reg.set_container(name, version, ftable)
	return true
end
