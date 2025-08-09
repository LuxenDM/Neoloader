--[[
[metadata]
description=This is Neoloader's recovery environment. This handles most errors in Neoloader, and if the error isn't marked as 'critical', offers the user a selection of choices that may help fix the issue.
version=2.0.0

]]--

local fs_flag = false --true if initial LME file check was successful
local flagged_state = "RECOVERY_LOADING" --displays where in INIT is processing

local rs = {
	ready = false, --set true at end of file
	critical = false, --set true if error popup is triggered by a system stopping handler
	push_error = nil, --function to push an error to display stack, non-critical errors can be stacked for later view
	file_check_success = function() --called when initial check for base files succeeds
		fs_flag = true
	end,
	init_flag = function(new_state) --set current status of INIT process
		flagged_state = new_state
	end,
}
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

local cp = console_print

Font = {
	Default = (gkinterface.GetYResolution()/1080) * 24,
}
local height_scale = gkinterface.IsTouchModeEnabled() and (Font.Default * 2) or Font.Default

local create_list_control = function(intable)
	--vscroll of static iup objects
end

--[[
	interfaces:
	plugin selector, manually get list of plugins and their states. can toggle them, can delete entries, can perform a 'clean' operation
	primitive table explorer for debugging
	config editor, display config entries in table explorer view, show edited and seperated apply, can select 'safe' settings
	embedded console with multiline input (or, find a way to reroute console input?)
	root window

	LME config things might need to use LME API depending on current 'state'

	attempt launch and START/SHOW_STATION/HUD_SHOW
	uninstall Neoloader
	Nuclear reset
		requires confirmation; resets config.ini by wiping a lot of baseline entries

	State machine:
	LME can provide status updates 
]]--

