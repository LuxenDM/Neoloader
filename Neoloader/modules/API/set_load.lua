--[[
[metadata]
description=Set a plugin's load state (YES/NO/FORCE/AUTH); unauthorized calls return nothing
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.set_load = function(auth, id, version, state)
  id, version = lib.pass_ini_identifier(id, version)

  -- v6 behavior: if unauthorized, silently return (no explicit false)
  if not neo.api.check_auth(auth) then
    return
  end

  auth = tostring(auth or "")
  id   = tostring(id or "")
  version = tostring(version or "0")

  if version == "0" then
    version = lib.get_latest(id)
  end

  local valid_states = {
    YES = true, NO = true, FORCE = true, AUTH = true,
  }
  if not valid_states[state] then
    state = "NO"
  end

  if lib.is_exist(id, version) then
    -- persist like v6
    gkini.WriteString("Neo-pluginstate", id .. "." .. version, state)

    local ok, _, rec = reg.find_plugin(id, version)
    if ok and rec then
      rec.nextload = state
    end
    lib.log_error("Set load state for " .. id .. " v" .. version .. " to " .. state, 1, id, version)
  end
end
