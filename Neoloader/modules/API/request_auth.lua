--[[
[metadata]
description=Request manager authorization key (UAC-style; stub)
version=0.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib

-- cb(key) on approval; not called on denial
lib.request_auth = function(cb)
  -- TODO: implement modal prompt; for now, NO-OP stub
  lib.log_error("request_auth is not implemented yet", 1)
  return false, "unimplemented"
end
