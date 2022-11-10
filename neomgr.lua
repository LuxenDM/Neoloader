--[[
This is the bundled management UI for the Neoloader engine. It uses Neoloader's API to show the status of Neo-compatible mods, and allows the user to allow/prevent mods from loading.

This is only meant to provide minimal functionality, and should be replaced with a more featured manager by the user, but is not entirely neccesary for the functionality of Neoloader.
]]--

local key = 0
local lastNotif = ""
local ready = false
local public = {}
local diag_timer = Timer()
local margin_setting = tonumber(lib.mod_read_str("neomgr", "0", "data", "margin"))

--[[
As a manager, neomgr needs to have a standardized API in its "class". these functions are stored in public{}, and if neomgr is the active manager, Neoloader will activate these functions. We can also provide other functions for other mods to use here, but since this is a minimally featured management system for Neoloader, we won't do this.

functions needed:
	open:
		Opens the neomgr display
	mgr_key:
		Neoloader is sending neomgr the "key" used to activate mods or run the uninstaller.
	notif:
		A notification that requires user attention was triggered
		
		Possible notifications:
			A new mod was registered (lib.register after ADVANCED_PLUGIN_LOADER_COMPLETE)
			A mod failed to load during init (Activation failure)
			No root-level mods are available (No mods can be activated)
			Startup successful (Everything's A-OK) (self-hides after 5 seconds)
			<other>
				other plugins could use the notif but provide a status that neomgr isn't expecting; a generic message will be opened instead.
	???
]]--

function public.mgr_key(new_key)
	key = new_key
end












--notification handler

local function createNotification(status)
	
	local valid_status = {
		--[[
		EXAMPLE = {
			[1] = "Message to display",
			[2] = bool "Is a timeout expected?"
				true: window self-hides after 5 seconds
		}
		]]--
		NEW_REGISTRY = {
			[1] = "A new mod has been registered; open the Neoloader manager to configure your mods!",
			[2] = true,
		},
		MOD_FAILURE = {
			[1] = "Neoloader failed to load a mod! Open the Neoloader manager to configure your mods.",
			[2] = false,
		},
		ROOT_FAILURE = {
			[1] = "No dependent-less mods were set to be loaded, so Neoloader had no mods to load. Open the Neoloader manager to configure your mods.",
			[2] = true,
		},
		SUCCESS = {
			[1] = "Neoloader finished successfully! To configure your mods, open the Neoloader manager.",
			[2] = true,
		},
	}
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
					title = "To manage your mods, use the button in the options menu or use the /neo command",
				},
				iup.button {
					title = "Hide Notification",
					action = function(self)
						iup.Destroy(iup.GetDialog(self))
					end,
				},
			},
		},
	}
	
	diag:map()
	diag:showxy(0, 0)
	
	do --why did I "do" this?
		diag_timer:SetTimeout(10000, function() iup.Destroy(diag) end)
	end
end

RegisterEvent(function() 
	ready = true
	if lastNotif ~= "" then
		if lib.mod_read_str("neomgr", "1", "data", "HandleNotifications") == "YES" then
			createNotification(lastNotif)
		end
	end
	if lib.mod_read_str("neomgr", "1", "data", "OpenOnGameLaunch") == "YES" then
		public.open()
	end
end, "PLUGINS_LOADED")

function public.notif(status)
	if ready == false then
		lastNotif = status
		console_print("Not ready to show notifications")
	else
		if lib.mod_read_str("neomgr", "1", "data", "HandleNotifications") == "YES" then
			createNotification(status)
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
	local gstate = lib.get_gstate()
	local modlist = {}
	for k, v in ipairs(gstate.modlist) do
		table.insert(modlist, lib.get_state(v[1], v[2]))
	end
	
	local modDisplayContainer = {}
	
	local elem_width = {
		[1] = 0,
		[2] = 0,
		[3] = 0,
		[4] = 0,
		[5] = 0,
	}
	
	local function newModRowDisp(index)
		local mod_internal_name = modlist[index].mod_id or "Mod internal ID"
		local mod_full_name = modlist[index].mod_name or "Mod public name"
		local mod_version = modlist[index].mod_version or "Mod version"
		
		local mod_load_status = modlist[index].load
		local mod_failed = modlist[index].complete
		
		local load_states = {
			[1] = "\12744FF44 Loaded!",
			[2] = "\127FFDD00 Will load after reset",
			[3] = "\127FFDD00 Will not load next reset",
			[4] = "\127FF4444 Not Loaded!",
			[5] = "\127FF0000 Failed to load!",
		}
		
		local row_data = {
			[1] = mod_full_name,
			[2] = mod_internal_name,
			[3] = mod_version,
			[4] = "",
			[5] = mod_failed,
			currentstate = 1,
			newstate = 1,
		}
		
		if index > 1 then
			if mod_load_status == "NO" then
				row_data[4] = load_states[4]
				row_data.newstate = 4
				row_data.currentstate = 4
			elseif mod_failed == false then
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
			gkini.WriteString("Neo-modstate", mod_internal_name .. "." .. tostring(mod_version), result)
		end
		
		function row_display.width_resize()
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
			local x_limit = math.floor(gkinterface.GetXResolution()/5)
			if tonumber(row_elements[1].size:match("(%d+)x")) > x_limit then
				row_elements[1].size = tostring(x_limit)
				elem_width[1] = x_limit
			end
		end
		
		return row_display
	end
	
	local display_list_container_objs = {}
	local display_list_container = iup.vbox {}
	
	table.insert(modlist, 1, {})
	
	for i=1, #modlist do
		display_list_container_objs[i] = newModRowDisp(i)
		display_list_container_objs[i].width_resize()
		iup.Append(display_list_container, display_list_container_objs[i])
	end
	
	for i=1, #modlist do
		--doing it again to fix "ascending" sizes
		display_list_container_objs[i].width_resize()
	end
	
	local display_list_root = iup.vbox {
		create_scrollbox(display_list_container),
		iup.hbox {
			iup.button {
				title = "Reload",
				action = function()
					ReloadInterface()
				end,
			},
			iup.fill { },
			iup.button {
				title = "Apply Changes",
				action = function()
					for k, v in ipairs(display_list_container_objs) do
						v.apply()
					end
					ReloadInterface()
				end,
			},
		},
	}
	
	
	
	--Do log-viewer panel
	
	local string_log = ""
	
	for _, v in ipairs(gstate.log) do
		string_log = string_log .. v .. "\n"
	end
	
	local log_view = iup.multiline {
		value = string_log,
		readonly = "YES",
		expand = "YES",
	}
	
	
	local log_view_root = iup.vbox {
		log_view,
		iup.button {
			title = "Export",
			action = function()
				if GetPlayerName() ~= nil then
					SaveSystemNotes(5000, gstate.log)
					lib.log_error("The log was saved to <vo>/settings/" .. GetPlayerName() .. "/system5000notes.txt")
				else
					lib.log_error("The log cannot be exported to a systemnotes file if you are not logged in!")
				end
			end,
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
	
	local setting_edit_root = iup.frame {
		iup.vbox {
			gap = 6,
			iup.hbox {
				iup.label {
					title = "Neoloader Management Interface: ",
				},
				iup.fill { },
				mgr_list_select,
			},
			iup.hbox {
				iup.label {
					title = "Custom Interface Manager: ",
				},
				iup.fill { },
				if_list_select,
			},
			iup.fill {
				size = "%8",
			},
			iup.hbox {
				iup.fill { },
				iup.button {
					title = "Apply Changes",
					action = function()
						gkini.WriteString("Neoloader", "if", next_if)
						gkini.WriteString("Neoloader", "mgr", next_mgr)
						ReloadInterface()
					end,
				},
			},
			iup.fill { },
			iup.frame {
				iup.vbox {
					iup.multiline {
						readonly = "YES",
						expand = "HORIZONTAL",
						size = HUDSize(0.7, 0.1),
						value = "If you are having issues with Neoloader, try uninstalling it. This button will remove as much neoloader-based data as possible from your config.ini and try to prevent Neoloader from launching again. You might also want to do this if you are upgrading to a new version of Neoloader.",
					},
					iup.hbox {
						iup.fill { },
						iup.button {
							title = "Uninstall",
							fgcolor = "255 80 80",
							action = function()
								lib.uninstall(key)
							end,
						},
					},
				},
			},
		},
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
					title = "Neoloader basic mod manager",
					font = Font.H3,
				},
				iup.fill { },
				iup.button {
					title = "Close",
					action = function(self)
						iup.Destroy(iup.GetDialog(self))
					end,
				},
			},
			iup.hbox {
				iup.button {
					title = "Modlist",
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
					title = "This mod manager is bundled with Neoloader, and only meant to provide minimal functionality.",
				},
			},
			iup.fill {
				size = "%2",
			},
		},
	}
	
	diag:map()
	diag:show()
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
			iup.Append(OptionsDialog, iup.frame {option_frame} )
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