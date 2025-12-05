--[[
[metadata]
description=Return true/false if all deps in the list are present, within bounds, and complete
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

local function shallow_copy(t)
  local o = {}
  for i=1,#t do o[i] = t[i] end
  return o
end

lib.resolve_dep_table = function(intable)
  if lib.err_handle(type(intable) ~= "table",
      "lib.resolve_dep_table expected a table for argument 1, got " .. type(intable)) then
    return false, "input not a table"
  end

  local status = true
  for _, v in ipairs(shallow_copy(intable)) do
    if lib.err_handle(type(v) ~= "table",
        "lib.resolve_dep_table was given an improperly formatted table; table values should be tables!") then
      return false, "bad table format"
    end

    local id      = tostring(v.name or v.id or "null")
    local ver     = tostring(v.version or "0")
    local ver_max = tostring(v.ver_max or "~")

    -- ID must exist at all
    local order = reg.get_version_list(id)
    if not order or #order == 0 then
      return false
    end

    -- Resolve "0" and "0" for ver_max the same way v6 did
    if ver == "0" then
      ver = lib.get_latest(id)
    end
    if ver_max == "0" then
      ver_max = lib.get_latest(id)
    end
    if ver_max ~= "~" then
      -- constrain chosen version to <= ver_max (and >= provided min if any)
      ver = lib.get_latest(id, ver, ver_max)
    end

    -- quick checks mirroring v6
    local ready = lib.is_ready(id, ver)
    local frozen = false
    do
      local ok, _, rec = reg.find_plugin(id, ver)
      frozen = (ok and rec and rec.dependents_frozen) and true or false
    end

    for _, test in ipairs{
      ready,
      (not frozen),
      (ver ~= "?"),
    } do
      if test == false then
        status = false
        break
      end
    end

    if not status then break end
  end

  return status
end
