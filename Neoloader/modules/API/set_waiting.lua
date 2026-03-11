--[[
[metadata]
description=Freeze/unfreeze a plugin, blocking dependents until released
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.set_waiting = function(id, ver, state, key)
	id, ver = lib.pass_ini_identifier(id, ver)

	local valid_state = {
		["YES"] = 1, ["NO"] = 0,
		[true] = 1, [false] = 0,
		["ON"] = 1, ["OFF"] = 0,
		[1] = 1, [0] = 0,
	}
	state = valid_state[state] or 0
	id = tostring(id or "null")
	ver = tostring(ver or "0")
	if ver == "0" then ver = lib.get_latest(id) end

	if not key then
		return false, "waiting state key must be provided"
	elseif not lib.is_exist(id, ver) then
		return false, "mod to set waiting needs to exist"
	end

	local ok, _, rec = reg.find_plugin(id, ver)
	if not ok or not rec then
		return false, "registry lookup failed"
	end

	local mod = id .. "." .. ver
	if state > 0 then
		lib.log_error(mod .. " is now waiting", 1, id, ver)
		rec.dependents_frozen = true
		rec.freeze_key = key
	elseif rec.dependents_frozen and key == rec.freeze_key then
		lib.log_error(mod .. " has reactivated", 1, id, ver)
		rec.dependents_frozen = false
		rec.freeze_key = nil
		lib.check_queue()
	end

	return true
end
