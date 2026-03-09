--[[
[metadata]
description=Set a plugin's load state (YES/NO/FORCE/AUTH); unauthorized calls return nothing
version=1.0.1
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

local valid_states = {
	YES		= true,
	NO		= true,
	FORCE	= true,
	AUTH	= true,
	REM		= false, --used when Neoloader is uninstalled
}

lib.set_load = function(auth, id, version, state)
	id, version = lib.pass_ini_identifier(id, version)

	if not neo.api.check_auth(auth) then
		return
	end

	auth = tostring(auth or "")
	id   = tostring(id or "")
	version = tostring(version or "0")
	state = tostring(state or "NO")

	if version == "0" then
		version = lib.get_latest(id)
	end
	if (not valid_states[state]) and (not neo.api.validity_override) then
		state = "NO"
	end

	if lib.is_exist(id, version) then
		gkini.WriteString("Neo-pluginstate", id .. "." .. version, state)

		local ok, _, rec = reg.find_plugin(id, version)
		if ok and rec then
			rec.nextload = state
		end
		lib.log_error("Set load state for " .. id .. " v" .. version .. " to " .. state, 1, id, version)
	end
end
