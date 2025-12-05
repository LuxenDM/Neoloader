--[[
[metadata]
description=Lock a plugin's class, preventing external modification (returns key)
version=1.0.1
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

neo.lib.lock_class = function(id, version, key)
  id, version = lib.pass_ini_identifier(id, version)
  if lib.err_handle(type(id) ~= "string",
      "lib.lock_class expected a string for its first argument, got " .. type(id)) then
    return false, "plugin ID not a string"
  end

  version = tostring(version or "0")
  if version == "0" then
    version = lib.get_latest(id)
  end

  if not lib.is_exist(id, version) then
    return false, "mod doesn't exist"
  end

  -- ask the registry to lock; it will generate a key if nil
  reg.toggle_lock(id, version, true, key)
end
