--[[
[metadata]
description=Create a random key string
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...

local step = os.time() + math.random(0, 10) + gkmisc.GetGameTime()
neo.lib.generate_key = function()
	step = step + 1
	return SHA1(tostring(gkmisc.GetGameTime() + math.random() + step))
end
