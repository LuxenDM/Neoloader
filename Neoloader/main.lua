--[[
[metadata]
description=Default loader entrypoint for Neoloader
version=2.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-7-1
]]--

local lme_flag = false

if type(lib) == "table" and lib[0] == "LME" then
	lme_flag = true
end

local launch_mode_cfg = gkini.ReadString("Neoloader", "launch_mode", "cooperative")
local my_path = "plugins/!Neoloader/init.lua"



if launch_mode_cfg == "cooperative" then
	if lme_flag then
		--Either another LME is running or Neoloader was launched by a custom loading system
	else
		dofile("init.lua")
	end
elseif (launch_mode_cfg == "independent") and (not lme_flag) then
	--find out if we need to force Neoloader to run via interface reroute
	--todo: ask player how to reroute, don't assume
	if gkini.ReadString("Vendetta", "if", "") == "" then
		gkini.WriteString("Vendetta", "if", my_path)
	end
end