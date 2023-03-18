--[[
This is the bundled management UI for the Neoloader engine. It uses Neoloader's API to show the status of Neo-compatible plugins, and allows the user to allow/prevent plugins from loading.

This is only meant to provide minimal functionality, and should be replaced with a more featured manager by the user, but is not entirely neccesary for the functionality of Neoloader.
]]--

local key
local lastNotif = ""
local ready = false
local public = {}
local diag_timer = Timer()

local margin_setting = tonumber(lib.plugin_read_str("neomgr", "0", "data", "margin"))
local auto_open = lib.plugin_read_str("neomgr", "0", "data", "OpenOnGameLaunch")
local open_on_notif = lib.plugin_read_str("neomgr", "0", "data", "HandleNotifications")
local default_state = gkini.ReadString("Neoloader", "rDefaultLoadState", "NO")

margin_setting = gkini.ReadInt("neomgr", "margin", margin_setting)
auto_open = gkini.ReadString("neomgr", "OpenOnGameLaunch", auto_open)
open_on_notif = gkini.ReadString("neomgr", "HandleNotifications", open_on_notif)



neo_diag = nil

--[[
As a manager, neomgr needs to have a standardized API in its "class". these functions are stored in public{}, and if neomgr is the active manager, Neoloader will activate these functions. We can also provide other functions for other plugins to use here, but since this is a minimally featured management system for Neoloader, we won't do this.

functions needed:
	open:
		Opens the neomgr display
	mgr_key:
		Neoloader is sending neomgr the "key" used to activate plugins or run the uninstaller.
	notif:
		A notification that requires user attention was triggered
		
		Possible notifications:
			A new plugin was registered (lib.register after ADVANCED_PLUGIN_LOADER_COMPLETE)
			A plugin failed to load during init (Activation failure)
			No root-level plugins are available (No plugins can be activated)
			Startup successful (Everything's A-OK) (self-hides after 5 seconds)
			<other>
				other plugins could use the notif but provide a status that neomgr isn't expecting; a generic message will be opened instead.
	???
]]--

function public.mgr_key(new_key)
	if not key then
		key = new_key
	end
end

local valid_status = {
	--[[
	EXAMPLE = {
		[1] = "Message to display",
		[2] = bool "Is a timeout expected?"
			true: window self-hides after 5 seconds
	}
	]]--
	NEW_REGISTRY = {
		[1] = "A new plugin has been registered; open the Neoloader manager to configure your plugins!",
		[2] = true,
	},
	PLUGIN_FAILURE = {
		[1] = "Neoloader failed to load a plugin! You can view the Neoloader status log in your manager.",
		[2] = false,
	},
	ROOT_FAILURE = {
		[1] = "No dependent-less plugins were set to be loaded, so Neoloader had no plugins to load. Open the Neoloader manager to configure your plugins.",
		[2] = true,
	},
	SUCCESS = {
		[1] = "Neoloader finished successfully! To configure your plugins, open the Neoloader manager.",
		[2] = true,
	},
}










--notification handler

local function createNotification(status)
	
	
	local visibleMsg = "The Neoloader manager has a notification..."
	local doTimeout = true
	
	if type(status) == "string" and valid_status[status] then
		visibleMsg = valid_status[status][1]
		doTimeout = valid_status[status][2]
	else
		--neomgr doesn't offer support for other notifications; its only supposed to handle the most basics
		return
	end
	
	local diag = iup.dialog {
		topmost = "YES",
		iup.frame {
			iup.vbox {
				alignment = "ACENTER",
				iup.label {
					title = visibleMsg,
				},
				iup.fill {
					size = "1%",
				},
				iup.label {
					title = "To manage your plugins, use the button in the options menu or use the /neo command",
				},
				iup.button {
					title = "Hide Notification",
					action = function(self)
						iup.GetDialog(self):hide()
						if not PlayerInStation() and IsConnected()  and HUD and HUD.dlg then
							HideAllDialogs()
							ShowDialog(HUD.dlg)
						end
					end,
				},
			},
		},
	}
	
	diag:map()
	diag:showxy(iup.CENTER, iup.CENTER)
	
	diag_timer:SetTimeout(10000, function()
		diag:hide()
	end)
end

RegisterEvent(function() 
	--print("triggered; last: " .. lastNotif .. "; open_ " .. open_on_notif .. "; auto_ " .. auto_open)
	ready = true
	if lastNotif ~= "" then
		if open_on_notif == "YES" then
			if PlayerInStation() or not IsConnected() then
				createNotification(lastNotif)
			else
				if valid_status[lastNotif] then
					print(valid_status[lastNotif][1])
				else
					print("neomgr caught an unhandled notification...")
				end
			end
		end
	end
	if auto_open == "YES" then
		public.open()
	end
end, "PLUGINS_LOADED")

function public.notif(status)
	if ready == false then
		lastNotif = status
		--console_print("Not ready to show notifications")
	else
		if open_on_notif == "YES" then
			if PlayerInStation() or not IsConnected() then
				createNotification(lastNotif)
			else
				if valid_status[lastNotif] then
					print(valid_status[lastNotif][1])
				else
					print("neomgr caught an unhandled notification...")
				end
			end
		end
	end
end









--main display

local function create_subdlg(ctrl)
	local dlg = iup.dialog{ctrl, border="NO", menubox="NO", resize="NO", bgcolor="0 0 0 0 *",}
	dlg.visible = "YES"
	return dlg
end

local function create_scrollbox(content)
	local scrollbox = iup.stationsublist{{}, control = "YES", expand = "YES",}
	iup.Append(scrollbox, create_subdlg(content))
	scrollbox[1] = 1
	return scrollbox
end --thank you Draugath for making these



function public.open()
	
	if neo_diag then
		neo_diag:show()
		return
	end
	
	
	local gstate = lib.get_gstate()
	local pluginlist = {}
	for k, v in ipairs(gstate.pluginlist) do
		table.insert(pluginlist, lib.get_state(v[1], v[2]))
	end
	
	local pluginDisplayContainer = {}
	
	local elem_width = {
		[1] = 0,
		[2] = 0,
		[3] = 0,
		[4] = 0,
		[5] = 0,
	}
	
	local function newpluginRowDisp(index)
		local plugin_internal_name = pluginlist[index].plugin_id or "plugin internal ID"
		local plugin_full_name = pluginlist[index].plugin_name or "plugin public name"
		local plugin_version = pluginlist[index].plugin_version or "plugin version"
		
		local plugin_load_status = pluginlist[index].load
		local plugin_failed = pluginlist[index].complete
		
		local load_states = {
			[1] = "\12744FF44 Loaded!",
			[2] = "\127FFDD00 Will load after reset",
			[3] = "\127FFDD00 Will not load next reset",
			[4] = "\127FF4444 Not Loaded!",
			[5] = "\127FF0000 Failed to load!",
		}
		
		local row_data = {
			[1] = plugin_full_name,
			[2] = plugin_internal_name,
			[3] = plugin_version,
			[4] = "",
			[5] = plugin_failed,
			currentstate = 1,
			newstate = 1,
		}
		
		if index > 1 then
			if plugin_load_status == "NO" then
				row_data[4] = load_states[4]
				row_data.newstate = 4
				row_data.currentstate = 4
			elseif plugin_failed == false then
				row_data[4] = load_states[5]
				row_data.newstate = 5
				row_data.currentstate = 5
			else
				row_data[4] = load_states[1]
				row_data.newstate = 1
				row_data.currentstate = 1
			end
		else
			row_data.currentstate = -1
			row_data.newstate = -1
		end
		
		local row_elements = {}
		row_elements = {
			[1] = iup.text {
				--full name
				value = "WWWWWWWWWWWWWWWWWWWWW", --row_data[1],
				readonly = "YES",
			},
			[2] = iup.label {
				--internal name
				title = row_data[2],
				alignment = "ACENTER",
			},
			[3] = iup.label {
				--version
				title = row_data[3],
				alignment = "ACENTER",
			},
			[4] = iup.label {
				--load state
				title = "  Will not load next reset", --row_data[4],
				alignment = "ACENTER",
			},
			[5] = iup.button {
				--state change button
				title = "  Don't Load  ",
				action = function(self)
					if row_data.newstate == 1 then
						self.title = "Load"
						row_data.newstate = 3
					elseif row_data.newstate == 4 then
						self.title = "Don't Load"
						row_data.newstate = 2
					elseif row_data.newstate == 3 and row_data.currentstate ~= 5 then
						self.title = "Don't Load"
						row_data.newstate = 1
					elseif row_data.newstate == 3 and row_data.currentstate == 5 then
						self.title = "Load"
						row_data.newstate = 5
					elseif row_data.newstate == 2 then
						self.title = "Load"
						row_data.newstate = 4
					elseif row_data.newstate == 5 then
						self.title = "Load"
						row_data.newstate = 3
					end
					
					row_elements[4].title = load_states[row_data.newstate]
					iup.Refresh(iup.GetDialog(self))
				end,
			},
		}
		if index == 1 then
			row_elements[5].active = "NO"
			row_elements[5].visible = "NO"
			row_elements[5].title = ""
		end
		
		for i=1, 5 do
			row_elements[i]:map()
			if tonumber(row_elements[i].size:match("(%d+)x")) > elem_width[i] then
				elem_width[i] = tonumber(row_elements[i].size:match("(%d+)x"))
			else
				row_elements[i].size = tostring(elem_width[i])
			end
			
			if i > 1 and i < 5 then
				row_elements[i].title = row_data[i]
			end
		end
		row_elements[1].value = row_data[1]
		
		if index == 1 then
			row_elements[4].title = "Current load state"
		elseif row_data.newstate == 1 then
			row_elements[5].title = "Don't Load"
		elseif row_data.newstate == 4 then
			row_elements[5].title = "Load"
		elseif row_data.newstate == 5 then
			row_elements[5].title = "Don't Load"
		end	
		
		local row_display = iup.frame {
			iup.hbox {
				gap = 4,
				row_elements[1],
				iup.label {
					title = "|",
				},
				row_elements[2],
				iup.label {
					title = "|",
				},
				row_elements[3],
				iup.label {
					title = "|",
				},
				row_elements[4],
				iup.label {
					title = "|",
				},
				row_elements[5],
			}
		}
		
		function row_display.apply()
			local result = "NO"
			if row_data.newstate < 3 or row_data.newstate == 5 then
				result = "YES"
			end
			gkini.WriteString("Neo-pluginstate", plugin_internal_name .. "." .. tostring(plugin_version), result)
		end
		
		function row_display.width_resize()
			local x_limit = math.floor(gkinterface.GetXResolution()/5)
			for i=1, 5 do
				--apply new element width to all entries
				row_elements[i]:map()
				if tonumber(row_elements[i].size:match("(%d+)x")) > elem_width[i] then
					elem_width[i] = tonumber(row_elements[i].size:match("(%d+)x"))
				else
					row_elements[i].size = tostring(elem_width[i])
				end
				
				--limit max width to 1/5th screen size
				if tonumber(row_elements[i].size:match("(%d+)x")) > x_limit then
					row_elements[i].size = tostring(x_limit)
					elem_width[i] = x_limit
				end
				
				--update row data
				if i > 1 and i < 5 then
					row_elements[i].title = row_data[i]
				end
			end
		end
		
		return row_display
	end
	
	local display_list_container_objs = {}
	local display_list_container = iup.vbox {}
	
	table.insert(pluginlist, 1, {})
	
	for i=1, #pluginlist do
		display_list_container_objs[i] = newpluginRowDisp(i)
		display_list_container_objs[i].width_resize()
		iup.Append(display_list_container, display_list_container_objs[i])
	end
	
	for i=1, #pluginlist do
		--doing it again to fix "ascending" sizes
		display_list_container_objs[i].width_resize()
	end
	
	local display_list_root = iup.vbox {
		create_scrollbox(display_list_container),
		iup.hbox {
			iup.fill { },
			iup.button {
				title = "Apply Changes",
				action = function()
					for k, v in ipairs(display_list_container_objs) do
						v.apply()
					end
					lib.reload()
				end,
			},
		},
	}
	
	
	
	--Do log-viewer panel
	
	local log_view = iup.multiline {
		value = "",
		readonly = "YES",
		expand = "YES",
	}
	
	local function update_log_view()
		local new_log = ""
		for _, v in ipairs(lib.get_gstate().log) do
			new_log = new_log .. v .. "\n"
		end
		log_view.value = new_log
	end
	update_log_view()
	
	local log_view_root = iup.vbox {
		log_view,
		iup.stationsubframe {
			iup.hbox {
				iup.fill { },
			},
		},
		iup.hbox {
			iup.fill { },
			iup.button {
				title = "Refresh Log",
				action = function()
					update_log_view()
				end,
			},
			iup.button {
				title = "Export",
				action = function()
					if GetPlayerName() ~= nil then
						update_log_view()
						SaveSystemNotes(log_view.value, 5000)
						lib.log_error("The log was saved to <vo>/settings/" .. GetPlayerName() .. "/system5000notes.txt")
						update_log_view()
					else
						lib.log_error("The log cannot be exported to a systemnotes file if you are not logged in!")
					end
				end,
			},
		},
	}
	
	--do settings editor panel
	local lookup_if = {}
	for k, v in ipairs(gstate.if_list) do
		lookup_if[v] = k
	end
	
	local lookup_mgr = {}
	for k, v in ipairs(gstate.mgr_list) do
		lookup_mgr[v] = k
	end
	
	
	
	local next_if = gstate.ifmgr
	local if_list_select = iup.list {
		value = 1,
		dropdown = "YES",
		action = function(self, text, index, click_value)
			if click_value == 1 then
				next_if = text
				if text == "no_entry" then
					next_if = ""
				end
			end
		end,
	}
	for k, v in ipairs(gstate.if_list) do
		if_list_select[k] = v
	end
	if #gstate.if_list < 2 then
		if_list_select.active = "NO"
	end
	if lookup_if[gstate.ifmgr] then
		if_list_select.value = lookup_if[gstate.ifmgr]
	end
	
	local next_mgr = gstate.manager
	local mgr_list_select = iup.list {
		value = 1,
		dropdown = "YES",
		action = function(self, text, index, click_value)
			if click_value == 1 then
				next_mgr = text
				if text == "no_entry" then
					next_mgr = ""
				end
			end
		end,
	}
	for k, v in ipairs(gstate.mgr_list) do
		mgr_list_select[k] = v
	end
	if lookup_mgr[gstate.manager] then
		mgr_list_select.value = lookup_mgr[gstate.manager]
	end
	
	local neo_default_state = iup.list {
		value = 2,
		dropdown = "YES",
		[1] = "YES",
		[2] = "NO",
	}
	
	if default_state == "YES" then
		neo_default_state.value = 1
	end
	
	local nmgr_toggle_open_notif = iup.list {
		value = 2,
		dropdown = "YES",
		[1] = "YES",
		[2] = "NO",
	}
	
	local nmgr_toggle_open_start = iup.list {
		value = 2,
		dropdown = "YES",
		[1] = "YES",
		[2] = "NO",
	}
	
	if auto_open == "YES" then
		nmgr_toggle_open_start.value = 1
	end
	
	if open_on_notif == "YES" then
		nmgr_toggle_open_notif.value = 1
	end
	
	
	
	local setting_edit_main_panel = iup.stationsublist {
		{},
		control = "YES", 
		expand = "YES",
	}
	
	local function new_list_seperator()
		return iup.stationsubframe {
			iup.hbox {
				iup.fill { },
			},
		}
	end
	
	local setting_row_title_general = iup.hbox {
		iup.label {
			title = "Neoloader general settings:",
			font = Font.H3,
		},
	}
	
	local setting_row_controller = iup.hbox {
		iup.label {
			title = "Neoloader Management Controller: ",
		},
		iup.fill { },
		mgr_list_select,
	}
	
	local setting_row_ifmgr = iup.hbox {
		iup.label {
			title = "Custom Interface Manager: ",
		},
		iup.fill { },
		if_list_select,
	}
	
	local setting_row_newstate = iup.hbox {
		iup.label {
			title = "Default load state for new plugins",
		},
		iup.fill { },
		neo_default_state,
	}
	
	local setting_row_title_neomgr = iup.hbox {
		iup.label {
			title = "neomgr settings: ",
			font = Font.H3,
		},
	}
	
	local setting_row_open_diag = iup.hbox {
		iup.label {
			title = "Open neomgr when the game starts",
		},
		iup.fill { },
		nmgr_toggle_open_start,
	}
	
	local setting_row_open_notif = iup.hbox {
		iup.label {
			title = "Show notifications",
		},
		iup.fill { },
		nmgr_toggle_open_notif,
	}
	
	local setting_apply = iup.vbox {
		iup.fill {
			size = gkinterface.GetYResolution() * (1/4)
		},
		iup.hbox {
			iup.fill { },
			iup.button {
				title = "Apply Changes",
				action = function()
					gkini.WriteString("Neoloader", "if", next_if)
					gkini.WriteString("Neoloader", "mgr", next_mgr)
					
					local def_val = neo_default_state.value == "1" and "YES" or "NO"
					local open_val = nmgr_toggle_open_start.value == "1" and "YES" or "NO"
					local notif_val = nmgr_toggle_open_notif.value == "1" and "YES" or "NO"
					gkini.WriteString("Neoloader", "rDefaultLoadState", def_val)
					gkini.WriteString("neomgr", "OpenOnGameLaunch", open_val)
					gkini.WriteString("neomgr", "HandleNotifications", notif_val)
					
					ReloadInterface()
				end,
			},
		},
	}
	
	local setting_uninstaller_msg = iup.multiline {
		readonly = "YES",
		expand = "HORIZONTAL",
		size = HUDSize(0.7, 0.2),
		value = "If you are having issues with Neoloader, try uninstalling it. This button will remove as much neoloader-based data as possible from your config.ini and try to prevent Neoloader from launching again. You might also want to do this if you are upgrading to a new version of Neoloader.",
	}
	
	local setting_uninstaller = iup.hbox {
		iup.frame {
			iup.vbox {
				setting_uninstaller_msg,
				iup.hbox {
					iup.fill { },
					iup.button {
						title = "UNINSTALL",
						fgcolor = "255 80 80",
						action = function()
							lib.uninstall(key)
						end,
					},
				},
			},
		},
	}
	
	local setting_element_container = {
		setting_row_title_general,
		setting_row_controller,
		setting_row_ifmgr,
		setting_row_newstate,
		new_list_seperator(),
		
		setting_row_title_neomgr,
		setting_row_open_diag,
		setting_row_open_notif,
		new_list_seperator(),
		
		setting_apply,
		new_list_seperator(),
		
		setting_uninstaller,
	}
	
	local update_setting_width
	
	do
		local setting_element_modified_list = {}
		local maxsize = gkinterface.GetXResolution() * (1) --adjust?
		local objmax
		local colorflag = true
		for index, element in ipairs(setting_element_container) do
			local object = create_subdlg(element)
			if colorflag == true then
				colorflag = false
				object.bgcolor = "127 127 127"
			else
				colorflag = true
				object.bgcolor = "135 135 135"
			end
			object:map()
			
			local size = tonumber(string.match(object.size, "%d+"))
			if (not objmax) or size > objmax then
				objmax = size
			end
			
			setting_element_modified_list[index] = object
			iup.Append(setting_edit_main_panel, object)
		end
		
		setting_edit_main_panel[1] = 1
		
		if objmax > maxsize then
			objmax = maxsize
		end
		
		function update_setting_width(new_width)
			for index, diag in ipairs(setting_element_modified_list) do
				local nums = {}
				for value in string.gmatch(diag.size, "%d+") do
					table.insert(nums, value)
				end
				--local xwid = nums[1] discard
				local yhit = nums[2]
				diag.size = tostring(new_width) .. "x" .. tostring(yhit)
			end
			iup.Refresh(setting_edit_main_panel)
		end
	end
	
	local setting_edit_root = iup.vbox {
		setting_edit_main_panel,
	}
	
	--do window creation panel
	
	local tabs_container = iup.zbox {
		value = display_list_root,
		[1] = display_list_root,
		[2] = log_view_root,
		[3] = setting_edit_root,
	}
	
	local diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		iup.vbox {
			margin = margin_setting,
			iup.fill {
				size = "%2",
			},
			iup.hbox {
				iup.label {
					title = "Neoloader basic plugin manager",
					font = Font.H3,
				},
				iup.fill { },
				iup.button {
					title = "Close",
					action = function(self)
						iup.GetDialog(self):hide()
						if not PlayerInStation() and IsConnected() and HUD and HUD.dlg then
							HideAllDialogs()
							ShowDialog(HUD.dlg)
						end
					end,
				},
			},
			iup.hbox {
				iup.button {
					title = "Plugin List",
					action = function()
						tabs_container.value = display_list_root
					end,
				},
				iup.button {
					title = "Logging",
					action = function()
						tabs_container.value = log_view_root
					end,
				},
				iup.button {
					title = "Neoloader Settings",
					action = function()
						tabs_container.value = setting_edit_root
					end,
				},
			},
			iup.hbox {
				tabs_container,
			},
			iup.hbox {
				iup.fill { },
				iup.label {
					title = "This plugin manager is bundled with Neoloader, and only meant to provide minimal functionality.",
				},
			},
			iup.fill {
				size = "%2",
			},
		},
	}
	
	diag:map()
	
	local scrolling_disp_width = tonumber(string.match(setting_edit_main_panel.size, "%d+"))
	update_setting_width(scrolling_disp_width - Font.H1)
	
	neo_diag = diag
	
	neo_diag:show()
end

local option_frame = iup.vbox {
	iup.button {
		title = "Neoloader Manager",
		action = function()
			public.open()
		end,
	},
}

if lib.is_ready("MultiUI", 1) then
	--[[
		MultiUI can be given items with a tag defining where they should go; this allows custom interfaces to take these panels and place them where neccesary, while allowing parentless panels to be accessed via MultiUI's own UI.
		
		of course, that doesn't exist yet, so this is just a stub.
	]]--
else
	if lib.get_gstate().manager == "neomgr" then
		if OptionsDialog then
			if gkini.ReadString("Vendetta", "usenewui", "1") == "1" then
				iup.Append(OptionsDialog, iup.frame {option_frame} )
			elseif gkini.ReadString("Vendetta", "usenewui", "0") == "0" then
				if OptionsDialog[1] and OptionsDialog[1][1] and OptionsDialog[1][1][1] then
					iup.Append(OptionsDialog[1][1][1], iup.frame {option_frame} )
				end
			end
		else
			console_print("OptionsDialog not ready")
		end
	else
		console_print("current manager: " .. (lib.get_gstate().manager or ""))
	end
end

function public.add_option(iup_reference)
	local cur_mgr = lib.get_gstate().manager
	if cur_mgr == "neomgr" then
		iup.Append(option_frame, iup_reference)
		--iup.Refresh(option_frame)
	else
		if lib.is_ready(cur_mgr) then
			lib.execute(cur_mgr, "0", add_option, iup_reference)
		end
	end
end

public.mgr = true

lib.set_class("neomgr", "1", public)
lib.lock_class("neomgr", "1", lib.generate_key())