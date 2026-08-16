--[[
[metadata]
description=Get a plugin's class table (by ref if unlocked, shallow copy if locked)
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

-- single-depth copy (matches v6 behavior/expectation)
local shallow_copy = function(t)
	local out = {}
	for k, v in pairs(t or {}) do
		out[k] = v
	end
	return out
end

lib.get_class = function(id, ver)
	-- normalize args / error text matches v6
	id, ver = lib.pass_ini_identifier(id, ver)
	if lib.err_handle(type(id) ~= "string", "lib.get_class expected a string for its first argument, got " .. type(id)) then
		return false, "plugin ID not a string"
	end

	ver = tostring(ver or "0")
	if ver == "0" then
		local sub = reg.substitute_zero(id, "0")
		if not sub or sub == "?" then
			return false, "Mod doesn't exist"
		end
		ver = sub
	end

	-- look up record
	local ok, _, rec = reg.find_plugin(id, ver)
	if not ok or not rec then
		return false, "Mod doesn't exist"
	end

	if rec.complete ~= true then
		return false, "Mod isn't complete"
	end

	-- grab the stored class table
	local class_tbl = reg.get_container(id, ver) or {}

	-- if locked, return a shallow copy; else return the live reference
	if rec.container_locked then
		return shallow_copy(class_tbl)
	else
		return class_tbl
	end
end
