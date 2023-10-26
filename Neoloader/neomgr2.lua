--bundled manager for Neoloader, version 2

--verify API compatibility
local api_check = lib.get_gstate()
for k, v in ipairs {
	api_check.major == 3,
	api_check.minor >= 7,
} do
	assert(v, "This version of neomgr is not compatible with the version of Neoloader installed! Please use the version bundled with your latest installation of Neoloader!")
end



--babel support

local babel, shelf_id, update_class
local bstr = function(id, def)
	return def
end

local babel_support = function()
	babel = lib.get_class("babel", "0")
	
	shelf_id = babel.register("plugins/Neoloader/lang/", {'en', 'es', 'fr', 'pt'})
	
	bstr = function(id, def)
		return babel.fetch(shelf_id, id, def)
	end
	
	update_class()
end

--lib.require({{name="babel", version="0"}}, babel_support)


local gkrs = gkini.ReadString

local auth_key
local config = {
	auto_open = gkrs("neomgr", "auto_open", "NO"),
	echo_notif = gkrs("neomgr", "echo_notif", "YES"),
	--[[
		depreciated en/disabling "on-top" visual notifications
		
		making a notification system that didn't interfere with the user's current activity cannot work , as any notification would have to be rendered "on top" and block clicks until removed. If there is a way to get non-blocking topmost dialogs, this can be reimplemented. For now, notifications can only be viewed in a specific area, and/or implemented into other plugins directly.
	]]--
	
	sort_type = gkrs("neomgr", "sort_type", "state"),
	sort_dir = gkrs("neomgr", "sort_dir", "UP"),
	--[[
		UP Ascending, DOWN Descending (default)
		
		state: sort by current load status
		alpha: sort alphabetically
		load: sort by load order
	]]--
	
	
}

local neo = {}

function update_class()
	local class = {
		CCD1 = true,
		smart_config = {
			title = "Neoloader Minimal Management Utility",
			cb = function() end,
			nocfg1 = {
				type = "text",
				align = "right",
				display = "neomgr is a minimal utility bundled with Neoloader",
			},
			nocfg2 = {
				type = "text",
				align = "right",
				display = "Configure it through its own interface",
			},
			nocfg3 = {
				type = "text",
				align = "right",
				display = "Live configuration is not supported",
			},
			"nocfg1",
			"nocfg2",
			"nocfg3",
		},
		description = "neomgr is the bundled management interace for Neoloader. It provides a minimal interface for configuring Neoloader and managing plugins.",
		commands = {
			"/neo: open neoloader's manager",
			"/neosetup: setup neoloader if uninstalled",
			"/neomgr: enable neomgr if all managers are disabled",
		},
		manifest = {
			"plugins/Neoloader/neomgr.lua",
			"plugins/Neoloader/neomgr.ini",
		},
	}
	
	for k, v in pairs(class) do
		neo[k] = v
	end
	
	lib.set_class("neomgr", "2.0.0", neo)
end


function neo.mgr_key(new_key)
	if not auth_key then
		auth_key = new_key
	end
end







local notif_scrollframe = iup.stationsublist {
	{},
	control = "YES",
	bgcolor = "0 0 0 0 *",
	border = "NO",
	expand = "YES",
}
local notif_frame = iup.vbox {}
local notif_list = {}
local notif_constructor = {}

local notif_listener = {}
local new_notif_listener = function(callback_func)
	if type(callback_func) ~= "function" then
		return false
	end
	
	table.insert(notif_listener, callback_func)
end

local new_notif_generator = function(notif_to_handle, echo_func, data_func)
	notif_to_handle = tostring(notif_to_handle)
	
	if type(echo_func) ~= "function" then
		echo_func = function(data)
			return "[" .. (data.title or notif_to_handle).. "] " .. (data.subtitle or "No chat handler for notification")
		end
	end
	
	if type(data_func) ~= "function" then
		data_func = function(data)
			return iup.pdarootframe {
				iup.hbox {
					alignment = "ACENTER",
					iup.vbox {
						iup.label {
							title = "",
							image = data.img or "plugins/Neoloader/notif_placeholder.png",
							size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
						},
					},
					iup.vbox {
						iup.label {
							title = data.title or notif_to_handle,
							font = Font.H6,
						},
						iup.label {
							title = data.subtitle or "Notification",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_1 or " ",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_2 or " ",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_3 or " ",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_4 or " ",
							font = Font.Tiny,
						},
					},
				},
			}
		end
	end
	
	if not notif_constructor[notif_to_handle] then
		notif_constructor[notif_to_handle] = {
			echo = echo_func,
			data = data_func,
		}
	end
end

local notif_creator = function(status, data)
	if not notif_constructor[status] then
		data = {
			title = "UNHANDLED_NOTIFICATION",
			subtitle = "Unknown notification type " .. status,
		}
		status = "UNHANDLED_NOTIFICATION"
	end
	if type(data) ~= "table" then
		data = {}
	end
	
	lib.log_error(status, 2)
	
	local obj = notif_constructor[status].data(data)
	table.insert(notif_list, {
		timestamp = os.time(),
		reference = obj,
	})
	iup.Append(notif_frame, obj)
	iup.Refresh(iup.GetDialog(notif_frame))
	iup.Refresh(notif_scrollframe)
	iup.Refresh(iup.GetDialog(notif_scrollframe))
	
	for i, v in ipairs(notif_listener) do
		local status, err = pcall(v, notif_constructor[status].data(data))
		if not status then
			lib.log_error("[neomgr] notification handler error - failed to call a notification listener, error returned: " .. tostring(err))
		end
	end
	
	if config.echo_notif == "YES" then
		print(notif_constructor[status].echo(data))
	end
end

local notif_clearall = function()
	for i=#notif_list, 1, -1 do
		notif_list[i].reference:detach()
		iup.Destroy(notif_list[i].reference)
		table.remove(notif_list, i)
	end
	
	iup.Refresh(notif_frame)
end

new_notif_generator("UNHANDLED_NOTIFICATION", nil, nil)
new_notif_generator("SUCCESS",
	function(data) --notification chat print
		return "NPLME has loaded successfully!"
	end,
	function(data) --notification iup generator
		return iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = "plugins/Neoloader/notif_placeholder.png",
						size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
					},
				},
				iup.vbox {
					iup.label {
						title = "Neoloader loaded successfully!",
						Font.H4,
					},
				},
			}
		}
	end
)
new_notif_generator("NEW_REGISTRY",
	function(data) --notification chat print
		return "A new plugin has been registered: " .. tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "?")
	end,
	function(data) --notification iup generator
		return iup.iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = "plugins/Neoloader/notif_placeholder.png",
						size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
					},
				},
				iup.vbox {
					iup.label {
						title = "A new plugin has been registered!",
						font = Font.H4,
					},
					iup.label {
						title = tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "?"),
						font = Font.H6,
					},
				},
			}
		}
	end
)
new_notif_generator("PLUGIN_FAILURE",
	function(data) --notification chat print
		return "Neoloader encountered an error while loading a plugin: " .. tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "???")
	end,
	function(data) --notification iup generator
		return iup.iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = "plugins/Neoloader/notif_placeholder.png",
						size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
					},
				},
				iup.vbox {
					iup.label {
						title = "Neoloader couldn't load a plugin!",
						font = Font.H4,
					},
					iup.label {
						title = tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "???"),
						font = Font.H6,
					},
					iup.label {
						title = tostring(data.error_string or "<failed to fetch error string>"),
						font = Font.H6,
					},
				},
			}
		}
	end
)
iup.Append(notif_scrollframe, iup.dialog {
	border = "NO",
	menubox = "NO",
	resize = "NO",
	expand = "YES",
	bgcolor = "0 0 0 0 *",
	notif_frame,
})
notif_scrollframe[1] = 1


local notif_diag = iup.dialog {
	topmost = "YES",
	fullscreen = "YES",
	bgcolor = "0 0 0 100 *",
	iup.frame { --HUDFrame Left?
		iup.vbox {
			iup.hbox {
				iup.fill { },
				iup.label {
					title = "Recent Notifications",
					font = Font.H5,
				},
				iup.fill { },
				iup.stationbutton {
					title = "Clear All",
					action = function(self)
						notif_clearall()
						HideDialog(iup.GetDialog(self))
					end,
				},
				iup.stationbutton {
					title = "Close",
					action = function(self)
						HideDialog(iup.GetDialog(self))
					end,
				},
			},
			notif_scrollframe,
		},
	}
}
notif_diag:map()

neo.notif = notif_creator
neo.handle_new_notif_type = new_notif_generator
neo.open_notifications = function()
	ShowDialog(notif_diag)
end
neo.get_thumb_image = function() return {
	image = "plugins/Neoloader/notif_placeholder.png",
	size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
} end

declare("testnotif", notif_diag)







cp = console_print

cp("mgr2 test")

local diag_constructor = function()
	
	local function create_subdlg(ctrl)
		
		local dlg = iup.dialog{
			border="NO",
			menubox="NO",
			resize="NO",
			expand = "YES",
			shrink = "YES",
			bgcolor="0 0 0 0 *",
			ctrl,
		}
		
		return dlg
	end
	
	local control_list_creator = function()
		
		cp("executing control list creator")
		
		local lockstate = false
		local actual_items = {}
		local contents = {}
		local sort_methods = {}
		
		local ctl = iup.stationsublist {
			{},
			control = "YES",
			expand = "YES",
		}
		
		ctl.unlock = function(self)
			ctl[1] = nil
			lockstate = false
		end
		
		ctl.lock = function(self)
			ctl[1] = 1
			lockstate = true
		end
		
		ctl.add_item = function(self, obj)
			table.insert(contents, obj)
		end
		
		ctl.clear_items = function(self)
			contents = {}
		end
		
		ctl.add_sorter = function(self, sorttype, sortfunc)
			sort_methods[sorttype] = sortfunc
		end
		
		ctl.update = function(self, sorttype)
			if lockstate then
				self:unlock()
			end
			
			cp("CTL update function")
			cp("sort type provided is " .. tostring(sorttype))
			
			if sort_methods[sorttype] then
				cp("sorting as " .. sorttype .. " in direction " .. config.sort_dir)
				table.sort(contents, sort_methods[sorttype])
			end
			
			cp("	detaching old items")
			
			for k, v in ipairs(actual_items) do
				v:detach()
				iup.GetNextChild(v):detach()
			end
			actual_items = {}
			
			cp("	resizing new items")
			
			--prepare items
			local x_size = string.match(ctl.size, "%d+") or "100"
			for k, v in ipairs(contents) do
				--cp("	mapping index " .. tostring(k))
				local obj = create_subdlg(v)
				actual_items[k] = obj
				obj:map()
				
				local sizes = {}
				for value in string.gmatch(obj.size, "%d+") do
					value = tonumber(value)
					table.insert(sizes, value)
				end
				--cp("	applying size")
				--cp("	CTL size is " .. ctl.size or "???")
				--cp("	x_size is " .. tostring(x_size) .. " of type " .. type(x_size))
				obj.size = tostring(tonumber(x_size) - Font.Default) .. "x" .. tostring(sizes[2])
				--cp("	size now " .. obj.size)
			end
			
			cp("Appending new items")
			
			for k, v in ipairs(actual_items) do
				iup.Append(self, v)
			end
			
			cp("Locking items")
			
			self:lock()
			
			cp("Refreshing")
			
			iup.Refresh(self)
		end
		
		cp("CTL functions created")
		
		iup.Append(ctl, create_subdlg(iup.hbox {}))
		--ctl:lock()
		
		cp("CTL appended and locked")
		
		return ctl
	end
	
	local create_CCD1_view = function(id, version)
		--rudimentary CCD1 support
	end
	
	local create_plugin_display = function()
		
		local pluginlist = {}
		for k, v in ipairs(lib.get_gstate().pluginlist) do
			--v[1]: mod ID, v[2]: mod Version
			table.insert(pluginlist, lib.get_state(v[1], v[2]))
			pluginlist[v[1] .. v[2]] = #pluginlist
		end
		local cur_selection = {pluginlist[1].plugin_id, pluginlist[1].plugin_version}
		local cur_sel_str = function()
			return cur_selection[1] .. cur_selection[2]
		end
		
		local apply_actions = {}
		local apply_flag = false
		
		--[[
			status toggle	plugin name		id vVersion
			[				description					]
			CCD1 Manage		open			.config
		]]--
		
		local apply_changes = iup.stationbutton {
			title = "Apply pending changes >>>",
			visible = "NO",
			action = function()
				local apply_func = function(auth)
					for k, v in pairs(apply_actions) do
						lib.set_load(auth, k[1], k[2], v)
					end
					lib.reload()
				end
				if auth_key then
					apply_func(auth_key)
				else
					lib.request_auth("Neoloader Lightweight Manager [neomgr]", apply_func)
				end
			end,
		}
		
		local load_toggle = iup.stationbutton {
			title = "Not loaded",
			action = function(self)
				apply_flag = true
				if apply_actions[cur_sel_str()] then
					apply_actions[cur_sel_str()] = nil
				else
					local index = pluginlist[cur_sel_str()]
					local load_to_apply = pluginlist[index].load == "NO" and "YES" or "NO"
					apply_actions[cur_sel_str()] = load_state_to_apply
					apply_changes.visible = "YES"
				end
			end,
		}
		
		local name_view = iup.label {
			title = "Plugin Name",
			font = Font.H3,
		}
		
		local version_view = iup.label {
			title = "vVersion",
		}
		
		local desc_readout = iup.multiline {
			readonly = "YES",
			value = "",
			size = "x%10",
			expand = "HORIZONTAL",
		}
		
		local CCD1_access = iup.stationbutton {
			title = "Manage",
			visible = "YES",
			action = function(self)
				if self.visible == "NO" then
					return
				end
				create_CCD1_view(cur_selection[1], cur_selection[2])
			end,
		}
		
		local general_open = iup.stationbutton {
			title = "Open",
			visible = "YES",
			action = function(self)
				if self.visible == "NO" then
					return
				end
				lib.execute(cur_selection[1], cur_selection[2], "open")
			end,
		}
		
		local general_config = iup.stationbutton {
			title = "Configure",
			visible = "YES",
			action = function(self)
				if self.visible == "NO" then
					return
				end
				lib.execute(cur_selection[1], cur_selection[2], "config")
			end,
		}
		
		local mod_disp_update = function()
			--make sure to run AFTER plugins have been populated!
			local index = pluginlist[cur_sel_str()]
			local data = pluginlist[index]
			
			local load_status = {
				[-1] = "?", --prevent adjustment, dunno what's going on
				[0] = "Not loaded",
				[1] = "Cannot load",--missing dep
				[2] = "Cannot load",--failed/error
				[3] = "Loaded",
			}
			
			load_toggle.title = load_status[data.current_state] or "???"
			load_toggle.state = data.next_state or data.current_state or -1
			
			name_view.title = data.plugin_name
			version_view.title = data.plugin_version
			desc_readout.value = ""
			CCD1_access.visible = "NO"
			general_open.visible = "NO"
			general_config.visible = "NO"
			
			if data.current_state > 2 then
				local class = lib.get_class(data.plugin_id, data.plugin_version)
				
				CCD1_access.visible = class.CCD1 and "YES" or "NO"
				general_open.visible = type(class.open) == "function" and "YES" or "NO"
				general_config.visible = type(class.config) == "function" and "YES" or "NO"
				desc_readout.value = type(class.description) == "string" and class.description or ""
				desc_readout.caret = 0
			end
			
			iup.Refresh(iup.GetParent(name_view))
			
		end
		
		local mod_view = iup.stationsubframe {
			iup.vbox {
				iup.hbox {
					iup.fill { },
					apply_changes,
				},
				iup.hbox {
					load_toggle,
					iup.fill {},
					name_view,
					iup.fill {},
					version_view,
				},
				desc_readout,
				iup.hbox {
					CCD1_access,
					iup.fill {},
					general_open,
					iup.fill {},
					general_config,
				},
			},
		}
		
		local ctl = control_list_creator()
		
		local states = {
			[0] = "NOT LOADED",
			['0'] = "255 200 100",
			[1] = "MISSING DEPENDENCY",
			['2'] = "255 0 0",
			[2] = "FAILED",
			['3'] = "255 0 0",
			[3] = "LOADED",
			['3'] = "100 255 100",
		}
		
		local create_item_row = function(index)
			local item = pluginlist[index]
			
			local cur_state = 0
			
			if item.load ~= "NO" then
				if item.complete then
					cur_state = 3
				else
					if not lib.resolve_dep_table(item.plugin_dependencies or {{}}) then
						cur_state = 1
					else
						cur_state = 2
					end
				end
			end
			
			item.current_state = cur_state
			
			local item_disp = iup.stationsubframe {
				shrink = "YES",
				expand = "HORIZONTAL",
				iup.vbox {
					alignment = "ACENTER",
					iup.hbox {
						iup.label {
							title = states[cur_state] or "???",
							fgcolor = states[tostring(cur_state)],
						},
						iup.fill { },
						iup.label {
							title = item.plugin_name,
						},
						iup.fill { },
						iup.label { --to help keep fill{}s balanced
							title = states[cur_state] or "???",
							visible = "NO",
						},
					},
					iup.hbox {
						iup.label {
							title = "#" .. tostring(item.load_position),
							font = Font.H6,
						},
						iup.fill { },
						iup.label {
							title = item.plugin_id .. " v" .. item.plugin_version,
							fgcolor = "150 150 150",
							font = Font.H6,
						},
						iup.fill {
							size = "%2",
						},
						iup.label {
							title = "Authored by " .. item.plugin_author,
							fgcolor = "150 150 150",
							font = Font.H6,
						},
						iup.fill { },
						iup.label {
							title = "#" .. tostring(item.load_position),
							font = Font.H6,
							visible = "NO",
						},
					},
				},
			}
			
			local cvobj = iup.vbox {
				iup.stationbutton {
					title = "",
					expand = "YES",
					bgcolor = "0 0 0 0 *",
					action = function(self)
						cp("User clicked on " .. item.plugin_id .. " v" .. item.plugin_version)
						cur_selection = {item.plugin_id, item.plugin_version}
						mod_disp_update()
					end,
				},
			}
			
			local label_obj = iup.zbox {
				all = "YES",
				data = item,
				item_disp,
				cvobj,
			}
			
			return label_obj
		end
		
		for i=1, #pluginlist do
			ctl:add_item(create_item_row(i))
		end
		
		local sort_name = function(a, b)
			local name1 = tostring(a.data.plugin_name)
			local name2 = tostring(b.data.plugin_name)
			local nsiz1 = string.len(name1)
			local nsiz2 = string.len(name2)
			
			if nsiz1 < nsiz2 then
				name1 = name1 .. string.rep("_", nsiz2 - nsiz1)
			elseif nsiz1 > nsiz2 then
				name2 = name2 .. string.rep("_", nsiz1 - nsiz2)
			end
			
			if name1 == name2 then
				if config.sort_dir == "UP" then
					return a.data.plugin_version < b.data.plugin_version
				else
					return a.data.plugin_version > b.data.plugin_version
				end
			else
				if config.sort_dir == "UP" then
					return name1 < name2
				else
					return name1 > name2
				end
			end
		end
		
		local sort_status = function(a, b)
			if a.data.current_state == b.data.current_state then
				return sort_name(a, b)
			end
			
			if config.sort_dir == "UP" then
				return a.data.current_state > b.data.current_state
			else
				return a.data.current_state < b.data.current_state
			end
		end
		
		local sort_loadpos = function(a, b)
			if config.sort_dir == "UP" then
				return a.data.load_position < b.data.load_position
			else
				return a.data.load_position > b.data.load_position
			end
		end
		
		ctl:add_sorter("alpha", sort_name)
		ctl:add_sorter("state", sort_status)
		ctl:add_sorter("load", sort_loadpos)
		
		local sort_select = iup.stationsublist {
			dropdown = "YES",
			action = function(self, t, i, c)
				if c == 1 then
					for k, v in ipairs {
						"alpha",
						"load",
						"state",
					} do
						if i == k then
							ctl:update(v)
							config.sort_type = v
							gkini.WriteString("neomgr", "sort_type", v)
							break
						end
					end
				end
			end,
			"Name",
			"Load position",
			"Current Status",
		}
		if config.sort_type == "alpha" then
			sort_select.value = 1
		elseif config.sort_type == "load" then
			sort_select.value = 2
		elseif config.sort_type == "state" then
			sort_select.value = 3
		end
		
		local sort_dir_select = iup.stationsublist {
			dropdown = "YES",
			action = function(self, t, i, c)
				if c == 1 then
					if i < 2 then
						config.sort_dir = "UP"
					else
						config.sort_dir = "DOWN"
					end
					gkini.WriteString("neomgr", "sort_dir", config.sort_dir)
					ctl:update(config.sort_type)
				end
			end,
			value = config.sort_dir == "UP" and 1 or 2,
			"Ascending",
			"Decending",
		}
		
		local root_modlist_panel = iup.stationsubframe {
			iup.vbox {
				mod_view,
				iup.stationsubframe {
					iup.hbox {
						iup.fill {},
					},
				},
				iup.hbox {
					iup.label {
						title = "Sort by ",
					},
					sort_select,
					sort_dir_select,
				},
				ctl,
			},
		}
		
		root_modlist_panel.ctl_update = function(sort_type)
			ctl:update(sort_type)
			mod_disp_update()
		end
		
		return root_modlist_panel
	end
	
	local create_log_view = function()
		--paged, not single multiline!
	end
	
	local create_settings = function()
		
	end
	
	
	local modlist_panel = create_plugin_display()
	local root_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.vbox {
			iup.hbox {
				iup.fill {},
				iup.stationbutton {
					title = "Close",
					action = function(self)
						HideDialog(iup.GetDialog(self))
					end,
				},
			},
			modlist_panel,
		}
	}
	cp("Mapping Dialog")
	root_diag:map()
	cp("updating")
	modlist_panel.ctl_update(config.sort_type)
	cp("Showing")
	ShowDialog(root_diag)
end

neo.open = diag_constructor


RegisterUserCommand("neotest", neo.open)

update_class()