--[[
[metadata]
description=Helps break down a semantic-like version string into its parts
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--


local neo = ...
local lib = neo.lib

lib.compare_sem_ver = function(semantic_version_string)
	return neo.api.registry.break_version(semantic_version_string)
end