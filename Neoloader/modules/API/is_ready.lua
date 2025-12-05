--[[
[metadata]
description=Check if a plugin version is ready (registered and complete==true)
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.is_ready = function(id, version)
  id, version = lib.pass_ini_identifier(id, version)
  if lib.err_handle(type(id) ~= "string",
      "lib.is_ready expected a string for its first argument, got " .. type(id)) then
    return false, "plugin ID not a string"
  end

  if not reg.has_id(id) then
    return false, "plugin doesn't exist"
  end
  
  -- "0" → latest (active if available)
  version = tostring(version or "0")
  if version == "0" then
    local status, lv = reg.get_latest_ver(id)
	if not status then
		return false, lv
	end
	version = lv
  end

  -- Specific version must exist
  local ok, _, rec = reg.find_plugin(id, version)
  if not ok or not rec then
    return false, "plugin doesn't exist"
  end

  -- Ready iff complete==true
  return rec.complete == true
end
