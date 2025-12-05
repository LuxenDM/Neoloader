--[[
[metadata]
description=Normalize (id,ver) pairs; accept INI path previously parsed by registry
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.pass_ini_identifier = function(id, ver)
  -- if caller already supplied a known ID, keep it
  if type(id) == "string" and reg.has_id(id) then
    return id, ver
  end

  -- if id looks like a previously parsed INI pointer, translate it
  if type(id) == "string" then
    local ok, inidata = reg.from_ini_pointer(id)
	if not ok then
		--no idea what this ID is, but it isn't an existing pointer, return as is
		return id, ver
	end
	
	--ID stores known INI pointer, send back true ID/Ver
    local rid = inidata.plugin_id
	local rver = inidata.plugin_version
	return rid, rver
  end

  -- default: unchanged
  return id, ver
end
