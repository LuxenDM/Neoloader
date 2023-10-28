--bundled manager for Neoloader, version 2



cp = console_print




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
	
	qa_buttons = gkrs("neomgr", "qa_buttons", "YES"),
		--adds a quick-access button to the options dialog when YES
}

local neo = {}

function update_class()
	local class = {
		CCD1 = true,
		smart_config = {
			title = "Neoloader Lightweight Management Utility",
			cb = function(cfg, val)
				if config[cfg] then
					config[cfg] = val
					gkini.WriteString("neomgr", cfg, val)
				end
			end,
			auto_open = {
				type = "toggle",
				display = "Open neomgr when the game starts",
				[1] = config.auto_open,
			},
			echo_notif = {
				type = "toggle",
				display = "Print LME notifications in chat",
				[1] = config.echo_notif,
			},
			qa_buttons = {
				type = "toggle",
				display = "Add quick-access buttons to the Options menu",
				[1] = config.qa_buttons,
			},
			"auto_open",
			"echo_notif",
			"qa_buttons",
		},
		description = "neomgr is the bundled management interace for Neoloader. It provides a lightweight interface for configuring Neoloader and managing plugins.",
		commands = {
			"/neo: open neoloader's manager",
			"/neosetup: setup neoloader if uninstalled",
			"/neomgr: enable neomgr if all managers are disabled",
		},
		manifest = {
			"plugins/Neoloader/neomgr2.lua",
			"plugins/Neoloader/neomgr2.ini",
			
			"plugins/Neoloader/img/notif_placeholder.png",
			"plugins/Neoloader/img/thumb.png",
			
			"plugins/Neoloader/lang/en.ini",
			"plugins/Neoloader/lang/es.ini",
			"plugins/Neoloader/lang/fr.ini",
			"plugins/Neoloader/lang/pt.ini",
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

local button_scalar = function()
	local val = ""
	if gkinterface.IsTouchModeEnabled() then
		val = tostring(Font.Default * 2)
	end
	return val
end




--[[
	Todo: make the scrollframe generated on-call, not static
		this way the notification screen could be embedded in any dialog
		I could also move it away from this block section >.>
]]--
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
							image = data.img or "plugins/Neoloader/img/notif_placeholder.png",
							size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
						},
					},
					iup.vbox {
						iup.label {
							title = data.title or notif_to_handle,
							font = Font.H4,
						},
						iup.label {
							title = data.subtitle or "Notification",
							font = Font.H6,
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
					iup.fill { },
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
						image = "plugins/Neoloader/img/thumb.png",
						size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
					},
				},
				iup.vbox {
					iup.label {
						title = "Neoloader loaded successfully!",
						Font.H4,
					},
				},
				iup.fill { },
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
						image = "plugins/Neoloader/img/thumb.png",
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
				iup.fill { },
			},
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
						image = "plugins/Neoloader/img/thumb.png",
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
				iup.fill { },
			},
		}
	end
)

neo.notif = notif_creator
neo.handle_new_notif_type = new_notif_generator
neo.get_thumb_image = function() return {
	image = "plugins/Neoloader/img/notif_placeholder.png",
	size = tostring((Font.Default / 24) * 48) .. "x" .. tostring((Font.Default / 24) * 48),
} end




















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
				if iup.IsValid(iup.GetNextChild(v)) then
					iup.GetNextChild(v):detach()
				end
				--v:destroy()
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
		
		cp("creating CCD1 view for " .. tostring(id) .. " v" .. tostring(version))
		
		local ctable = {} --content table
		ctable = lib.get_class(id, version)
		if not ctable.CCD1 then
			cp("ccd1 disabled")
			return
		end
		ctable = ctable.smart_config
		
		
		--[[
		element_builder(ref, data)
			ref: the element's reference ID
			data: the table used to build an element
		]]--
		
		local mk_prepend = function(data)
			return iup.hbox {
				iup.label {
					title = data.display or "?",
					expand = "HORIZONTAL",
				},
				iup.fill { },
			}
		end
		
		local mk_toggle = function(ref, data)
			return iup.hbox {
				mk_prepend(data),
				iup.stationtoggle {
					title = "",
					value = data[1] == "NO" and "OFF" or "ON",
					action = function(self)
						ctable.cb(ref, self.value == "ON" and "YES" or "NO")
					end,
				},
			}
		end
		
		local mk_dropdown = function(ref, data)
			local dropdown_obj = iup.stationsublist {
				dropdown = "YES",
				action = function(self, t, i, cv)
					if cv == 1 then
						ctable.cb(ref, t)
					end
				end,
			}
			
			for k, v in ipairs(data) do
				dropdown_obj[k] = tostring(v)
			end
			if #data < 1 then
				dropdown_obj[1] = "???"
			end
			dropdown_obj.value = data.default
			
			return iup.hbox {
				mk_prepend(data),
				dropdown_obj,
			}
		end
		
		local mk_slider = function(ref, data)
			local slider = iup.canvas {
				size = "200x" .. button_scalar(),
				border = "NO",
				xmin = tonumber(data.min) or 1,
				xmax = tonumber(data.max) or 100,
				posx = tonumber(data.default) or 50,
				dx = (tonumber(data.max) - tonumber(data.min))/10,
				expand = "NO",
				scroll_cb = function(self)
					ctable.cb(ref, self.posx)
				end,
			}
			
			return iup.hbox {
				mk_prepend(data),
				slider,
			}
		end
		
		local mk_edit = function(ref, data)
			return iup.hbox {
				mk_prepend(data),
				iup.text {
					expand = "NO",
					size = "200x",
					value = tostring(data.default),
					action = function(self)
						ctable.cb(ref, data)
					end,
				},
			}
		end
		
		local mk_header = function(ref, data)
			return iup.hbox {
				iup.label {
					title = tostring(data.display or "???"),
					font = Font.Big,
					alignment = "ACENTER",
					expand = "HORIZONTAL",
					wordwrap = "YES",
				},
			}
		end
		
		local mk_text = function(ref, data)
			local al = (data.align == "right" and "ARIGHT") or (data.align == "center" and "ACENTER") or ("ALEFT")
			return iup.hbox {
				iup.label {
					title = tostring(data.display or "???"),
					expand = "HORIZONTAL",
					alignment = al,
					wordwrap = "YES",
				},
			}
		end
		
		local mk_img = function(ref, data)
			if not gksys.IsExist(data[1]) then
				data[1] = IMAGE_DIR .. "hud_target.png"
			end
			
			return iup.hbox {
				iup.fill { },
				iup.label {
					title = "",
					image = data[1],
				},
				iup.fill { },
			}
		end
		
		local mk_spacer = function()
			return iup.hbox {
				iup.label {
					title = " ",
				},
			}
		end
		
		local mk_rule = function()
			return iup.stationsubframe {
				iup.hbox {
					iup.fill { },
				},
			}
		end
		
		local mk_action = function(ref, data)
			return iup.hbox {
				mk_prepend(data),
				iup.stationbutton {
					title = tostring(data[1] or "???"),
					action = function()
						ctable.cb(ref, "_action")
					end,
				},
			}
		end
		
		local mk_table = {
			header = mk_header,
			text = mk_text,
			image = mk_img,
			spacer = mk_spacer,
			rule = mk_rule,
			
			toggle = mk_toggle,
			dropdown = mk_dropdown,
			slider = mk_slider,
			input = mk_edit,
			action = mk_action,
		}
		
		
		
		
		local disp_frame = control_list_creator()
		disp_frame.size = "x%40"
		local disp_obj = {}
		
		local function mk_item(ihandle)
			--adds item to frame and obj table
			table.insert(disp_obj, ihandle)
			disp_frame:add_item(ihandle)
		end
			
		for k, v in ipairs(ctable) do
			cp("Entry is " .. tostring(ctable[v].type))
			if mk_table[ctable[v].type] then
				mk_item(mk_table[ctable[v].type](v, ctable[v]))
			end
		end
		
		local CCD1_manager = iup.dialog {
			topmost = "YES",
			fullscreen = "YES",
			bgcolor = "0 0 0 200 *",
			iup.vbox {
				iup.fill { },
				iup.hbox {
					iup.fill { },
					iup.stationbuttonframe {
						expand = "NO",
						iup.vbox {
							iup.hbox {
								iup.fill {
									size = "%50",
								},
								iup.stationbutton {
									title = "Close",
									action = function(self)
										HideDialog(iup.GetDialog(self))
									end,
								},
							},
							iup.label {
								title = tostring(ctable.title or "CCD1 Untitled SCM"),
							},
							iup.fill {
								size = "%2",
							},
							disp_frame,
							iup.fill {
								size = "%2",
							},
						},
					},
					iup.fill { },
				},
				iup.fill { },
			},
		}
		
		CCD1_manager:map()
		disp_frame:update()
		ShowDialog(CCD1_manager)
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
		
		--
		
		--
		
		local apply_changes = iup.stationbutton {
			title = "Apply pending changes >>>",
			visible = "NO",
			action = function(self)
				if #apply_actions < 1 then
					self.visible = "NO"
					return
				end
				
				
				local apply_func = function(auth)
					cp("Applying load states to " .. tostring(#apply_actions) .. " mods")
					for k, v in ipairs(apply_actions) do
						cp("Applying load state " .. tostring(v[3]) .. " to mod " .. tostring(v[1]) .. " v" .. tostring(v[2]))
						lib.set_load(auth, v[1], v[2], v[3])
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
					--[[
					apply_actions[cur_sel_str()] = index of apply_actions
					apply_actions[index] = {
						id,
						ver
						state
					}
					]]--
				if apply_actions[cur_sel_str()] then
					cp("removing " .. cur_sel_str())
					local index = apply_actions[cur_sel_str()]
						--index to clear
					table.remove(apply_actions, index)
						--remove application details
					apply_actions[cur_sel_str()] = nil
						--remove pointer index in table
					local data = pluginlist[pluginlist[cur_sel_str()]]
					
					self.title = data.load == "YES" and "Loaded" or "Not Loaded"
					iup.Refresh(self)
				else
					local index = pluginlist[cur_sel_str()]
						--index to grab
					local data = pluginlist[index]
						--data to use
					table.insert(apply_actions, {
						data.plugin_id,
						data.plugin_version,
						data.load == "NO" and "YES" or "NO",
					})
						--application detail
					
					apply_actions[cur_sel_str()] = #apply_actions
					cp("apply: " .. data.plugin_id .. " v" .. data.plugin_version .. " >> " .. (data.load == "NO" and "YES" or "NO"))
						--index pointer to data
					apply_changes.visible = "YES"
					
					self.title = data.load == "YES" and "Will not load" or "Will load"
					iup.Refresh(self)
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
				--what was this again?
			
			if apply_actions[cur_sel_str()] then
				load_toggle.title = data.load == "YES" and "Will not load" or "Will load"
			end
			
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
					load_toggle,
					iup.fill { },
					apply_changes,
				},
				iup.hbox {
					alignment = "ABOTTOM",
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
			size = "x" .. button_scalar(),
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
			size = "x" .. button_scalar(),
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
					alignment = "ACENTER",
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
		
		local log_copy = lib.get_gstate().log
		
		local readout = iup.multiline {
			readonly = "YES",
			value = "",
			size = "x%50",
			expand = "HORIZONTAL",
		}
		
		local num_logentries = iup.label {
			title = "<update>",
		}
		
		local page_select = iup.canvas {
			size = "%70x" .. button_scalar(),
			border = "NO",
			xmin = 1,
			xmax = 100,
			dx = 25,
			posx = 1,
			expand = "NO",
			scrollbar = "HORIZONTAL",
			scroll_cb = function(self, ...)
				readout.value = ""
				local end_point = (tonumber(self.posx) or 1) + 100
				if end_point > #log_copy then
					end_point = #log_copy
				end
				readout.value = table.concat(log_copy, "\n\127FFFFFF", (tonumber(self.posx) or 1), end_point)
				readout.caret = 1
			end,
		}
		
		local update_logsize = iup.stationbutton {
			title = "Refresh",
			action = function()
				log_copy = lib.get_gstate().log
				local entry_amount = #log_copy
				page_select.xmax = entry_amount
				page_select.posx = 1
				num_logentries.title = tostring(entry_amount)
			end,
		}
		
		local root_logview_panel = iup.stationsubframe {
			iup.vbox {
				alignment = "ACENTER",
				iup.fill { },
				readout,
				page_select,
				iup.fill {
					size = "%4",
				},
				iup.hbox {
					iup.label {
						title = "Number of entries" .. ": ",
					},
					num_logentries,
				},
				update_logsize,
				iup.fill { },
			},
		}
		
		update_logsize.action()
		page_select:scroll_cb()
		
		return root_logview_panel
	end
	
	local create_settings = function()
		
		local valid_config = {
			allowBadAPIVersion = {
				--if type is not defined, default toggle
				display = "Load plugins expecting a different LME version than " .. lib.get_API(),
				default = "NO",
			},
			echoLogging = {
				display = "Print LME logs to game console",
				default = "YES",
			},
			defaultLoadState = {
				display = "Auto-load newly registered plugins",
				default = "NO",
			},
			doErrPopup = {
				display = "Popup standard errors for safely caught LME errors",
				default = "NO",
			},
			protectResolveFile = {
				display = "Attempt to catch errors when loading plugins",
				default = "YES",
			},
			dbgFormatting = {
				display = "Format log messages",
				default = "YES",
			},
			dbgIgnoreLevel = {
				type = "scale",
				display = "Ignore logging messages below the selected priority",
				default = "2",
			},
			--order of options
			"allowBadAPIVersion",
			"echoLogging",
			"protectResolveFile",
			"defaultLoadState",
			"doErrPopup",
			"dbgFormatting",
			"dbgIgnoreLevel",
		}
		
		local ctl = control_list_creator()
		
		local create_setting_editor = function(setting_to_edit)
			--obtain current option with lib.get_lme_config(setting_to_edit)
			cp("Creating setting modifier from " .. tostring(setting_to_edit))
			local config_being_adjusted = setting_to_edit
			local rules = valid_config[setting_to_edit]
			if not rules then
				return iup.vbox {
					iup.label {
						title = "HUH?",
					},
				}
			end
			
			cp("rules: " .. spickle(rules))
			local cfg_panel = iup.vbox {
				alignment = "ARIGHT",
				iup.label {
					title = rules.display,
				},
				iup.hbox {
					iup.fill { },
				},
			}
			
			local cur_select = lib.lme_get_config(setting_to_edit)
			cp("existing option is set to " .. tostring(cur_select))
			if not rules.type then
				--toggle
				local cfg_button = iup.stationbutton {
					title = cur_select,
					size = "x" .. button_scalar(),
					fgcolor = cur_select == rules.default and "255 255 255" or "255 215 0",
					action = function(self)
						local new_setting = cur_select == "YES" and "NO" or "YES"
						
						cp("Player clicked to adjust " .. tostring(setting_to_edit) .. tostring(config_being_adjusted) .. " >> from " .. cur_select .. " to " .. new_setting)
						lib.lme_configure(setting_to_edit, new_setting, auth_key)
						self.title = new_setting
						self.fgcolor = new_setting == rules.default and "255 255 255" or "255 215 0"
						cur_select = new_setting
					end,
				}
				iup.Append(cfg_panel, cfg_button)
			elseif rules.type == "scale" then
				--dropdown
				local cfg_scale = iup.stationsublist {
					dropdown = "YES",
					size = "x" .. button_scalar(),
					fgcolor = cur_select == rules.default and "255 255 255" or "255 215 0",
					action = function(self, t, i, c)
						local new_setting = tostring(i - 1)
						lib.lme_configure(setting_to_edit, new_setting, auth_key)
						self.fgcolor = new_setting == rules.default and "255 255 255" or "255 215 0"
						cur_select = new_setting
					end,
					"Ignore Nothing",
					"Ignore Inconsequential",
					"Ignore Debug",
					"Ignore Standard",
					"Ignore Warnings",
					value = tonumber(cur_select) + 1,
				}
				iup.Append(cfg_panel, cfg_scale)
			end
			
			return iup.stationsubframe {cfg_panel}
		end
		
		for order, item in ipairs(valid_config) do
			cp(tostring(order) .. " >> " .. tostring(item))
			ctl:add_item(create_setting_editor(item))
		end
		
		local unins_msg = iup.multiline {
			readonly = "YES",
			value = "",
			expand = "HORIZONTAL",
			size = "x%10",
		}
		unins_msg.value = "If you are having issues with Neoloader, try uninstalling it. This button will remove as much neoloader-based data as possible from your config.ini and try to prevent Neoloader from launching again. You might also want to do this if you are upgrading to a new version of Neoloader."
		
		local setting_panel = iup.stationsubframe {
			ctl_update = function() ctl:update() end,
			iup.vbox {
				iup.vbox {
					alignment = "ACENTER",
					visible = (auth_key) and "NO" or "YES",
					iup.hbox {
						iup.fill { },
					},
					iup.label {
						wordwrap = "YES",
						title = "WARNING! This is not your currently selected LME interface! Options requiring authentication may not apply!",
					},
					iup.stationbutton {
						title = "Get authentication for this session",
						action = function(self)
							local obtain_key = function(auth)
								iup.GetParent(self).visible = "NO"
								auth_key = auth
							end
							lib.request_auth("Neoloader Lightweight Manager [neomgr]", obtain_key)
						end,
					},
				},
				iup.label {
					title = "LME Configuration Settings",
				},
				iup.hbox {
					iup.fill {},
					ctl,
					iup.fill {},
				},
				iup.fill {
					size = "%4",
				},
				iup.vbox {
					iup.hbox {
						iup.label {
							title = "Select an interface to load: ",
						},
						--item
					},
					iup.hbox {
						iup.label {
							title = "Select your LME interface: ",
						},
						--item
					},
				},
				iup.fill { },
				iup.hbox {
					iup.label {
						title = "Check for updates on ",
					},
					iup.stationbutton {
						title = "NexusMods",
						action = function()
							Game.OpenWebBrowser("https://www.nexusmods.com/vendettaonline/mods/3")
						end,
					},
					iup.stationbutton {
						title = "VOUPR",
						action = function()
							Game.OpenWebBrowser("https://voupr.spenced.com/plugin.php?name=neoloader")
						end,
					},
					iup.fill { },
				},
				iup.stationsubframe {
					bgcolor = "200 0 0",
					iup.vbox {
						unins_msg,
						iup.hbox {
							iup.fill { },
							iup.stationbutton {
								title = "Uninstall Neoloader",
								size = "x" .. button_scalar(),
								fgcolor = "255 0 0",
								action = function()
									lib.request_auth(
										"Neoloader Uninstaller",
										function()
											lib.uninstall(auth_key)
										end
									)
								end,
							},
						},
					},
				},
			},
		}
		
		return setting_panel
	end
	
	local create_notif_view = function()
		local notif_ctl = control_list_creator()
		
		new_notif_listener(function()
			notif_ctl:clear_items()
			for k, v in ipairs(notif_list) do
				notif_ctl:add_item(v.reference)
			end
			notif_ctl:update()
		end)
		
		local notif_panel = iup.stationsubframe {
			iup.vbox {
				alignment = "ACENTER",
				iup.label {
					title = "Recent Notifications",
					font = Font.H5,
				},
				iup.hbox {
					iup.fill { },
					iup.stationbutton {
						title = "Clear All",
						size = "x" .. button_scalar(),
						action = function(self)
							notif_clearall()
							notif_ctl:clear_items()
							notif_ctl:update()
						end,
					},
				},
				notif_ctl,
			},
		}
		
		notif_panel.ctl_update = function()
			notif_ctl:clear_items()
			for k, v in ipairs(notif_list) do
				notif_ctl:add_item(v.reference)
			end
			notif_ctl:update()
		end
		
		return notif_panel
	end
	
	
	local modlist_panel = create_plugin_display()
	local logview_panel = create_log_view()
	local config_panel = create_settings()
	local notif_panel = create_notif_view()
	
	local panel_view = iup.zbox {
		modlist_panel,
		notif_panel,
		logview_panel,
		config_panel,
		value = modlist_panel,
	}
	local tabs_view = iup.hbox {
		iup.stationbutton {
			title = "Manage installed mods",
			expand = "HORIZONTAL",
			action = function()
				panel_view.value = modlist_panel
			end,
		},
		iup.stationbutton {
			title = "View notifications",
			expand = "HORIZONTAL",
			action = function()
				notif_panel:ctl_update()
				panel_view.value = notif_panel
			end,
		},
		iup.stationbutton {
			title = "View log",
			expand = "HORIZONTAL",
			action = function()
				panel_view.value = logview_panel
			end,
		},
		iup.stationbutton {
			title = "Configure Neoloader",
			expand = "HORIZONTAL",
			action = function()
				panel_view.value = config_panel
			end,
		},
	}
	
	local root_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.vbox {
			iup.hbox {
				iup.fill { },
				iup.label {
					title = "Neoloader Lightweight Management Interface",
				},
				iup.fill { },
			},
			iup.hbox {
				iup.label {
					title = "LME Provider: " .. lib[1] .. " version " .. lib.get_gstate().version.strver,
				},
				iup.fill {},
				iup.stationbutton {
					title = "Reload",
					size = "x" .. button_scalar(),
					action = function(self)
						lib.reload()
					end,
				},
				iup.fill {
					size = "%1",
				},
				iup.stationbutton {
					title = "Close",
					size = "x" .. button_scalar(),
					action = function(self)
						HideDialog(iup.GetDialog(self))
					end,
				},
			},
			tabs_view,
			panel_view,
		}
	}
	
	cp("Mapping Dialog")
	root_diag:map()
	cp("updating")
	modlist_panel.ctl_update(config.sort_type)
	config_panel.ctl_update()
	cp("Showing")
	ShowDialog(root_diag)
end

neo.open = diag_constructor




























local open_button_creator = function()
	--this adds the neoloader button to options
	if config.auto_open == "YES" then
		neo.open()
	end
	
	local angular_check = gkini.ReadString("Vendetta", "usenewui", "n")
	
	if config.qa_buttons == "YES" then
		if angular_check == "1" and Platform == "Windows" then
			local odbutton = OptionsDialog[1][1][15]
			
			local x_pos = tonumber(odbutton.cx)
			local y_pos = tonumber(odbutton.cy)
			local sizes = {}
			for value in string.gmatch(odbutton.size, "%d+") do
				table.insert(sizes, tonumber(value))
			end
			y_pos = y_pos - (sizes[2] * 1.5)
			
			local neobutton = iup.button {
				title = "Open Mod Manager",
				size = odbutton.size,
				cx = x_pos,
				cy = y_pos,
				image = odbutton.image,
				action = neo.open,
			}
			
			iup.Append(OptionsDialog[1][1], neobutton)
		else
			local neobutton = stationbutton {
				title = "Open Mod Manager",
				expand = "HORIZONTAL",
				action = neo.open,
			}
			
			iup.Append(OptionsDialog[1][1][1], neobutton)
		end
	end
end

RegisterEvent(open_button_creator, "PLUGINS_LOADED")

RegisterUserCommand("neotest", neo.open)
neo.mgr = true
update_class()