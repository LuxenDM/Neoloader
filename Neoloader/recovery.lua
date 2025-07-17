--[[
[metadata]
description=This is Neoloader's recovery environment. This handles most errors in Neoloader, and if the error isn't marked as 'critical', offers the user a selection of choices that may help fix the issue.

]]--

local rs = {}
--[[
This is the "recovery system" table, which is returned to Neoloader.

rs.error: This is the error string to display when visible

rs.critical: This boolean informs the resolution system that Neoloader has a core issue and cannot run. self-fix options will be reduced to reload, reset Neoloader, reset game, etc.

rs.push_error()
	This function triggers the recovery menu to display immediately (using popup if critical or immediate booleans are true). non-immediate errors are pushed onto a stack in case multiple errors are being triggered, allowing all to be viewed.

rs.file_check_success()
	This informs the recovery system (if it has been loaded) that the initial check for files has succeeded, and Neoloader will begin loading. The recovery system recieves the auth key at this time.

rs.init_flag()
	This flags various 
]]--
