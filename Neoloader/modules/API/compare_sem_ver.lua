--[[
[metadata]
description=Makes comparing semantic-like version strings easy
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08

because I keep forgetting:
-1 -- obj1 older / less than obj2
 0 -- equal
 1 -- obj1 newer / greater than obj2
]]--


local neo = ...
local lib = neo.lib

lib.compare_sem_ver = function(obj1, obj2)
	return neo.api.registry.compare_ver(obj1, obj2)
end