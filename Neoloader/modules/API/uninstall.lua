--[[
[metadata]
description=Uninstall Neoloader (stub; requires auth)
version=0.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib

lib.uninstall = function(auth)
  if not neo.api.check_auth(auth) then
    lib.log_error("uninstall: unauthorized caller", 1)
    return false, "unauthorized"
  end
  lib.log_error("uninstall is not implemented yet", 1)
  return false, "unimplemented"
end
