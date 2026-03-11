--[[
[metadata]
description=Read a string from a plugin's original INI file (registry-sourced path)
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.plugin_read_str = function(name, version, header, key)
	name, version = lib.pass_ini_identifier(name, version)
	if lib.err_handle(type(name) ~= "string",
			"lib.plugin_read_str expected a string for its first argument, got " .. type(name)) then
		return false, "plugin ID not a string"
	end

	version = tostring(version or "0")
	if version == "0" then
		version = lib.get_latest(name)
	end

	-- ensure the specific version exists
	local ok, _, rec = reg.find_plugin(name, version)
	if not ok or not rec then
		return nil
	end

	local ifp = rec.plugin_regpath
	return gkini.ReadString2(
		tostring(header or "modreg"),
		tostring(key or "name"),
		"",
		ifp
	)
end
