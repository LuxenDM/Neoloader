--[[
[metadata]
description=Execute a function (or fetch a value) from a plugin's class table
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib

-- v7 execute:
-- - pass_ini_identifier normalization
-- - "0" version & readiness checks are delegated to lib.get_class
-- - if func key maps to a function → call with ... and return the result
-- - if func key maps to a non-function value → return that value
-- - otherwise log and return nil
-- - returns false,reason only for bad arguments (matches your pattern)

lib.execute = function(id, ver, func, ...)
	id, ver = lib.pass_ini_identifier(id, ver)

	if lib.err_handle(type(id) ~= "string",
			"lib.execute expected a string for its first argument, got " .. type(id)) then
		return false, "plugin ID not a string"
	end
	if lib.err_handle(func == nil,
			"lib.execute expected a value for its third argument, got nil") then
		return false, "function key is nil"
	end

	-- get_class handles:
	--	* "0" -> latest active
	--	* existence check
	--	* complete==true gate
	local class, err = lib.get_class(id, ver)
	if class == false then
		-- keep v6-style logging flavor for common cases
		if err == "Mod isn't complete" then
			lib.log_error("Attempted to call " .. id .. " v" .. tostring(ver) .. " but it isn't loaded", 1)
		elseif err == "Mod doesn't exist" then
			lib.log_error("Attempted to call " .. id .. " v" .. tostring(ver) .. " but it doesn't exist", 1)
		else
			lib.log_error("Attempted to call " .. id .. " v" .. tostring(ver) .. " but failed: " .. tostring(err), 1)
		end
		return nil
	end

	local action = class[func]
	if type(action) == "function" then
		return action(...)
	elseif action ~= nil then
		return action
	else
		lib.log_error("Attempted to call " .. id .. " v" .. tostring(ver) .. " class function " .. tostring(func) .. " but it doesn't exist", 1)
		return nil
	end
end
