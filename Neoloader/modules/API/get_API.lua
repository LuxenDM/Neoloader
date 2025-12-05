--[[
[metadata]
description=Obtains the major version level of the LME API; this will be deprecated eventually
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

--marked for deprecation in LME version 4.0.0; information available in lib.get_gstate()

local neo = ...

neo.lib.get_API = function()
	return neo.lme_ver[1]
end