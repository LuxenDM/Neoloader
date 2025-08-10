--[[
[metadata]
description=This is Neoloader's recovery environment.
version=2.0.0
owner=Neoloader|7.0.0

]]--

local fs_flag = false --true if initial LME file check was successful

local errors_list = {}

local rs
rs = {
	error = "", --current error being processed
	ready = false, --set true at end of file
	critical = false, --set true if error popup is triggered by a system stopping handler
	push_error = function() --function to push an error to display stack, non-critical errors can be stacked for later view. if critical, opens interface
		table.insert(errors_list, rs.error)
		if critical then
			rs.open()
			--pause execution via popup? momentarily safer than using error() due to blocking nature, but needs to ensure game can continue to run after in a safe manner
		end
	end,
	file_check_success = function() --called when initial check for base files succeeds
		fs_flag = true
	end,
	open = nil, --opens interface (can be called even if no error is triggered)
}
--[[
This is the "recovery system" table, which is returned to Neoloader.

rs.error: This is the error string to display when visible

rs.critical: This boolean informs the resolution system that Neoloader has a core issue and cannot run. self-fix options will be reduced to reload, reset Neoloader, reset game, etc.

rs.push_error()
	This function triggers the recovery menu to display immediately (using popup if critical or immediate booleans are true). non-immediate errors are pushed onto a stack in case multiple errors are being triggered, allowing all to be viewed.

rs.file_check_success()
	This informs the recovery system (if it has been loaded) that the initial check for files has succeeded, and Neoloader will begin loading. The recovery system recieves the auth key at this time.
]]--

local cp = console_print

Font = {
	Default = (gkinterface.GetYResolution()/1080) * 24,
}
local height_scale = gkinterface.IsTouchModeEnabled() and (Font.Default * 2) or Font.Default

local create_slider_control = function(intable)
	local scroll_timer = Timer()
	local scroll_flag = false
	local defaults = {
		ymin = 0,
		ymax = 100,
		dy = 30,
		posy = 0,
		scrollbar = "VERTICAL",
		expand = "VERTICAL",
		scroll_event_cb = function() end,
		scroll_cb = function(self)
			scroll_flag = true
		end,
		border = "NO",
	}

	for k, v in pairs(intable) do
		default[k] = v
	end

	local scroll = iup.canvas(default)
	scroll.get_pos = function(self)
		return self.posy
	end

	local scroll_update
	scroll_update = function()
		if scroll_flag then
			default.scroll_event_cb(scroll)
			scroll_flag = false
		end
		scroll_timer:SetTimeout(1, scroll_update)
	end

	scroll.init_timer = scroll_update

	return scroll
end

local create_list_control = function(intable)
	--vscroll of static iup objects
	local imposter = iup.frame { --get size of parent
		image = "",
		bgcolor = "0 0 0 0 *",
		segmented = "0 0 1 1",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
			},
		},
	}

	local content_container = iup.vbox {}
	for i, v in ipairs(intable) do
		iup.Append(content_container, v)
	end

	local match_widths = function(root_w)
		--only call after map
		for i, v in ipairs(intable) do
			v.size = tostring(root_w - Font.Default) .. "x" .. tostring(v.h)
		end
	end

	local content_frame = iup.stationsubframe {
		cx = 0,
		cy = 0,
		content_container,
	}

	local slider
	slider = create_slider_control {
		scroll_event_cb = function()
			content_frame.cy = ((slider:get_pos() * (content_frame.h - scroller.h)) / 100) * -1
			iup.Refresh(content_frame)
		end,
	}

	--more here
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

