--[[
[metadata]
description=handles log and notification history
#other metadata stuff here#
]]--

local neo = ...
local log = neo.log

--[[
to-do: 
appending to log already happens automatically by lib.log_error(). This file should construct functions for manipulating, reading, and viewing the log. To that end, it shouldn't really be a 'core' module, and maybe even optional
]]--
