--bundled manager for Neoloader, version 2



cp = function() end --console_print




--verify API compatibility
local api_check = lib.get_gstate()
for k, v in ipairs {
	api_check.major == 3,
	api_check.minor >= 10,
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
	
	shelf_id = babel.register("plugins/Neoloader/lang/neomgr/", {'en', 'es', 'fr', 'pt'})
	
	bstr = function(id, def)
		return babel.fetch(shelf_id, id, def)
	end
	
	update_class()
end


local gkrs = gkini.ReadString

local auth_key
local config = {
	auto_open = gkrs("neomgr", "auto_open", "NO"),
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
	
	enable_dependents = gkrs("neomgr", "enable_dependents", "YES"),
		--if a mod requires other disabled mods when its turned on, they'll also be enabled
		
	show_debuginfo = gkrs("neomgr", "show_debuginfo", "NO"),
}

local neo = {}

function update_class()
	local class = {
		CCD1 = true,
		smart_config = {
			title = bstr(1, "Neoloader Lightweight Management Utility"),
			cb = function(cfg, val)
				if cfg == "update_check" then
					Game.OpenWebBrowser("https://www.nexusmods.com/vendettaonline/mods/3")
				end
				if config[cfg] then
					config[cfg] = val
					gkini.WriteString("neomgr", cfg, val)
				end
			end,
			auto_open = {
				type = "toggle",
				display = bstr(2, "Open neomgr when the game starts"),
				[1] = config.auto_open,
			},
			qa_buttons = {
				type = "toggle",
				display = bstr(3, "Add quick-access buttons to the Options menu"),
				[1] = config.qa_buttons,
			},
			enable_dependents = {
				type = "toggle",
				display = bstr(4, "Auto-enable mods required by a mod you select to load"),
				[1] = config.enable_dependents,
			},
			show_debuginfo = {
				type = "toggle",
				display = bstr(64, "Show debugging info"),
				[1] = config.show_debuginfo,
			},
			update_check = {
				type = "action",
				display = "",
				align = "right",
				[1] = bstr(87, "Check for updates"),
			},
			"auto_open",
			"enable_dependents",
			"show_debuginfo",
			"qa_buttons",
			"update_check",
		},
		description = bstr(5, "neomgr is the bundled management interace for Neoloader. It provides a lightweight interface for configuring Neoloader and managing plugins."),
		commands = {
			"/neo: open neoloader's manager",
			"/neosetup: setup neoloader if uninstalled",
			"/neomgr: enable neomgr if all managers are disabled",
		},
		manifest = {
			"plugins/Neoloader/neomgr2.lua",
			"plugins/Neoloader/neomgr2.ini",
			
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

function neo.auth_key_receiver(new_key)
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




local ghost_check = false

local diag_constructor = function()
	
	if not auth_key then
		config.show_debuginfo = "NO"
	end
	
	if ghost_check then
		lib.log_error("[CRITICAL ERROR] neomgr detected itself as a ghost! Launching recovery environment; ghosts can't be killed from the sandbox.")
		--[[
			For some reason, if the user disables neomgr and reloads, a ghost of it will remain and can be accessed with bound commands. The garbage collector is failing to clean up ANYTHING when this occurs. Why is this happening? Not a clue!
		]]--
		gkini.WriteString("Neoloader", "STOP", "recovery")
		auth_key = nil
		lib.reload()
		return
	end
	
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
			cp("adding an item!")
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
			
			if sorttype and sort_methods[sorttype] then
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
			local apply_timer = Timer()
			local handle_func = function(a, b)
				ctable.cb(a, b)
			end
			
			local slider = iup.canvas {
				size = "200x" .. button_scalar(),
				border = "NO",
				xmin = tonumber(data.min) or 1,
				xmax = tonumber(data.max) or 100,
				posx = tonumber(data.default) or 50,
				dx = (tonumber(data.max) - tonumber(data.min))/10,
				expand = "NO",
				scrollbar = "HORIZONTAL",
				scroll_cb = function(self)
					apply_timer:SetTimeout(1, function() ctable.cb(ref, self.posx) end)
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
						ctable.cb(ref, self.value)
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
									title = bstr(7, "Close"),
									action = function(self)
										HideDialog(iup.GetDialog(self))
									end,
								},
							},
							iup.label {
								title = tostring(ctable.title or bstr(6, "CCD1 Untitled SCM")),
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
	
	local apply_flag = false
	local apply_actions = {}
	
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
		
		
		--
		
		--
		
		local apply_changes = iup.stationbutton {
			title = bstr(8, "Apply all pending changes") .. " >>>",
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
						if (config.enable_dependents == "YES") and (v[3] == "YES") then
							cp("dep resolving is enabled!")
							local deps = lib.get_state(v[1], v[2]).plugin_dependencies
							for k2, v2 in ipairs(deps) do
								lib.set_load(auth_key, v2.name, v2.version, "YES")
							end
							cp("dependencies resolved")
						end
					end
					ghost_check = true
					lib.reload()
				end
				if auth_key then
					apply_func(auth_key)
				else
					lib.request_auth(bstr(1, "Neoloader Lightweight Manager [neomgr]"), apply_func)
				end
			end,
		}
		
		local load_toggle = iup.stationtoggle {
			title = bstr(68, "Enabled"),
			value = "OFF",
			action = function(self)
				
				if apply_actions[cur_sel_str()] then
					--Cancel load state toggle
					local index = apply_actions[cur_sel_str()]
						--index to be cleared
					table.remove(apply_actions, index)
						--remove application details
					apply_actions[cur_sel_str()] = nil
						--remove pointer index in table
					local data = pluginlist[pluginlist[cur_sel_str()]]
					
					if data.current_state == -1 then
						self.title = data.load == "YES" and bstr(11, "Will load") or bstr(12, "Will Not load")
					end
					
					iup.Refresh(self)
				else
					--queue load state toggle
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
					
					iup.Refresh(self)
				end
				
				apply_flag = #apply_actions > 0
				apply_changes.visible = apply_flag and "YES" or "NO"
			end,	
		}
		
		local name_view = iup.label {
			title = bstr(13, "Plugin Name"),
			font = Font.H3,
		}
		
		local version_view = iup.label {
			title = "v" .. bstr(14, "Version"),
		}
		
		local desc_readout = iup.multiline {
			readonly = "YES",
			value = "",
			size = config.show_debuginfo == "YES" and "x%15" or "x%10",
			expand = "HORIZONTAL",
		}
		
		local CCD1_access = iup.stationbutton {
			title = bstr(15, "Manage"),
			visible = "YES",
			action = function(self)
				if self.visible == "NO" then
					return
				end
				create_CCD1_view(cur_selection[1], cur_selection[2])
			end,
		}
		
		local general_open = iup.stationbutton {
			title = bstr(16, "Open"),
			visible = "YES",
			action = function(self)
				if self.visible == "NO" then
					return
				end
				lib.execute(cur_selection[1], cur_selection[2], "open")
			end,
		}
		
		local general_config = iup.stationbutton {
			title = bstr(17, "Configure"),
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
				[-1] = bstr(12, "Will Not Load"), --newly registered
				[0] = bstr(9, "Disabled"),
				[1] = bstr(18, "Cannot load"),--missing dep
				[2] = bstr(18, "Cannot load"),--failed/error
				[3] = bstr(10, "Loaded"),
			}
			
			if lib.lme_get_config("defaultLoadState") == "YES" then
				load_status[-1] = bstr(11, "Will load")
			end
			
			load_toggle.value = data.load == "YES" and "ON" or "OFF"
			load_toggle.state = data.next_state or data.current_state or -1
				--what was this again?
			
			if apply_actions[cur_sel_str()] then
				--there is a pending action for this plugin, so inverse
				load_toggle.value = data.load == "YES" and "OFF" or "NO"
			end
			
			if (load_status[-1] == bstr(11, "Will load")) and (data.current_state == -1) then
				--this is a "NEW" plugin and auto-enable is set
				load_toggle.value = "ON"
				if apply_actions[cur_sel_str()] then
					--but there's an action, so disable
					load_toggle.value = "OFF"
				end
			end
			
			name_view.title = data.plugin_name
			version_view.title = "v" .. data.plugin_version
			desc_readout.value = ""
			CCD1_access.visible = "NO"
			general_open.visible = "NO"
			general_config.visible = "NO"
			
			if data.current_state > 2 then
				local class = lib.get_class(data.plugin_id, data.plugin_version)
				
				CCD1_access.visible = class.CCD1 and "YES" or "NO"
				general_open.visible = type(class.open) == "function" and "YES" or "NO"
				general_config.visible = type(class.config) == "function" and "YES" or "NO"
				desc_readout.value = (type(class.description) == "string" and class.description .. "\n") or ""
				desc_readout.caret = 0
			end
			
			local log_display = desc_readout.value
			--status messaging
			if data.current_state == 3 then
				--loaded
				log_display = log_display .. bstr(70, "This plugin has loaded successfully")
				if data.compat_flag == "YES" then
					log_display = log_display .. "\n" .. bstr(79, "This is a 'compatibility' plugin; Neoloader has limited control and insight in the management of this plugin.")
				end
			elseif data.current_state == 2 then
				--cannot load, failure/error
				log_display = log_display ..  bstr(71, "This plugin failed to load") .. "; " .. bstr(83, "error details can be found below")
			elseif data.current_state == 1 then
				--cannot load, missing dependency
				log_display = log_display .. bstr(72, "This plugin depends on a plugin that either failed to load or is not found")
			elseif data.current_state == 0 then
				--disabled
				log_display = log_display .. bstr(77, "This plugin is disabled; enable it with the toggle in the top-left")
			elseif data.current_state == -1 then
				--new
				log_display = log_display .. bstr(78, "This plugin was just registered! If enabled, it will launch when the game is reloaded.")
			end
			
			--extended info
			local log_table = lib.get_state(data.plugin_id, data.plugin_version).errors
			if (#log_table > 0) and (config.show_debuginfo == "YES" or data.current_state == 2) then
				log_display = log_display .. "\n\n" .. bstr(86, "Plugin log") .. ":\n	" .. table.concat(log_table, "\n\127FFFFFF	", 1, #log_table) .. "\127FFFFFF"
			end
			
			local dep_table = lib.get_state(data.plugin_id, data.plugin_version).plugin_dependencies
			
			if (#dep_table > 0) and (config.show_debuginfo == "YES" or data.current_state < 3) then
				log_display = log_display .. "\n\n" .. bstr(81, "This plugin depends on")
				
				for k, v in ipairs(dep_table) do
					if v.ver_max ~= "~" then
						log_display = log_display .. "\n	" .. (v.name or "???") .. " " .. ((v.version == "0" and bstr(73, "any version")) or "v" .. (v.version or "???")) .. " " .. bstr(82, "through") .. " " .. ((v.ver_max == "0" and bstr(73, "any version")) or "v" .. (v.ver_max or "???"))
					else
						log_display = log_display .. "\n	" .. (v.name or "???") .. " " .. ((v.version == "0" and bstr(73, "any version")) or "v" .. (v.version or "???"))
					end
					log_display = log_display .. " >> "
					if lib.is_exist(v.name, v.version) then
						if lib.get_state(v.name, v.version).load == "YES" then
							if lib.get_state(v.name, v.version).complete then
								log_display = log_display .. bstr(70, "This plugin is enabled and loaded")
							else
								if lib.get_state(v.name, v.version).plugin_is_new then
									log_display = log_display .. bstr(80, "This plugin is new and hasn't loaded yet") .. "!"
								else
									log_display = log_display .. bstr(74, "This plugin is enabled but never finished loading; check for errors") .. "!"
								end
							end
						else
							log_display = log_display .. bstr(75, "This plugin is present but not enabled")
						end
					else
						if lib.is_exist(v.name) then
							local ver_table = lib.get_state(v.name, "0").versions
							log_display = log_display .. bstr(84, "This specific version is not enabled")
							if type(ver_table) == "table" then
								local ver_display = ""
								for ver_index, ver_item in ipairs(ver_table) do
									ver_display = ver_display .. (ver_index > 1 and ", v" or " v")
									ver_display = ver_display .. ver_item .. (lib.is_ready(v.name, ver_item) and " (enabled)" or " (disabled)")
								end
								log_display = log_display .. "\n		" .. bstr(85, "The versions available are") .. ver_display
							end
						else
							log_display = log_display .. bstr(76, "This plugin has not been detected by Neoloader")
						end
					end
				end
			end
			
			if data.current_state > 2 and config.show_debuginfo == "YES" then
				local class = lib.get_class(data.plugin_id, data.plugin_version)
				local class_report = "\n\nPublic data:"
				for k, v in pairs(class) do
					class_report = class_report .. "\n	" .. tostring(k) .. " >> " .. type(v) .. ": " .. tostring(v)
				end
				log_display = log_display .. class_report
			end
			
			if config.show_debuginfo == "YES" then
				log_display = log_display .. "\n\nINI:\n	" .. data.plugin_ini_file
			end
			
			
			
			desc_readout.value = log_display
			desc_readout.caret = 0
			
			iup.Refresh(iup.GetParent(name_view))
			
		end
		
		local mod_view = iup.stationsubframe {
			iup.vbox {
				iup.hbox {
					load_toggle,
					iup.fill { },
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
			[-1] = bstr(63, "NEW"),
			['-1'] = "255 0 255",
			[0] = bstr(19, "NOT ENABLED"),
			['0'] = "255 200 100",
			[1] = bstr(21, "ERROR DURING LOADING"), --load failure
			['1'] = "255 0 0",
			[2] = bstr(20, "ERROR DURING LOADING"), --missing dep
			['2'] = "255 0 0",
			[3] = bstr(22, "LOADED"),
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
			
			if item.plugin_is_new then
				cur_state = -1
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
							fgcolor = "150 150 150",
							font = Font.H6,
							visible = config.show_debuginfo,
						},
						iup.label {
							title = item.plugin_id .. " v" .. item.plugin_version,
							fgcolor = "150 150 150",
							expand = "HORIZONTAL",
							alignment = "ACENTER",
							font = Font.H6,
						},
						iup.label {
							title = "#" .. tostring(item.load_position),
							font = Font.H6,
							visible = "NO",
						},
					},
					iup.hbox {
						iup.label {
							title = "Click to see more information",
							font = Font.H6,
							visible = (cur_state > 0 and cur_state < 3) and "YES" or "NO",
						},
						iup.label {
							title = bstr(23, "Authored by") .. " " .. item.plugin_author,
							fgcolor = "150 150 150",
							expand = "HORIZONTAL",
							alignment = "ACENTER",
							font = Font.H6,
						},
						iup.label {
							--balancing center point of author label
							title = "Click to see more information",
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
			bstr(24, "Name"),
			bstr(25, "Load position"),
			bstr(26, "Current Status"),
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
			bstr(27, "Ascending"),
			bstr(28, "Decending"),
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
						title = bstr(29, "Sort by") .. " ",
					},
					sort_select,
					sort_dir_select,
					iup.fill { },
					apply_changes,
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
			expand = "YES",
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
			title = bstr(30, "Refresh log"),
			action = function()
				log_copy = lib.get_gstate().log
				local entry_amount = #log_copy
				page_select.xmin = 1
				page_select.xmax = entry_amount > 1 and entry_amount or 2
				page_select.posx = 1
				num_logentries.title = tostring(entry_amount)
			end,
		}
		
		local root_logview_panel = iup.stationsubframe {
			iup.vbox {
				alignment = "ACENTER",
				iup.fill {
					size = "%4",
				},
				readout,
				page_select,
				iup.fill {
					size = "%4",
				},
				iup.hbox {
					iup.label {
						title = bstr(31, "Number of entries") .. ": ",
					},
					num_logentries,
				},
				update_logsize,
				iup.fill {
					size = "%4",
				},
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
				display = bstr(32, "Load plugins expecting a different LME API version than") .. " " .. lib.get_API(),
				default = "YES",
			},
			echoLogging = {
				display = bstr(33, "Print LME logs to game console"),
				default = "YES",
			},
			defaultLoadState = {
				display = bstr(34, "Auto-load newly registered plugins"),
				default = "NO",
			},
			protectResolveFile = {
				display = bstr(36, "Attempt to catch errors when loading plugins"),
				default = "YES",
			},
			dbgFormatting = {
				display = bstr(37, "Format log messages"),
				default = "YES",
			},
			dbgIgnoreLevel = {
				type = "scale",
				display = bstr(38, "Ignore logging messages below the selected priority"),
				default = "2",
			},
			--order of options
			"allowDelayedLoad",
			"allowBadAPIVersion",
			"echoLogging",
			"protectResolveFile",
			"clearCommands",
			"defaultLoadState",
			"doErrPopup",
			"dbgFormatting",
			"dbgIgnoreLevel",
			"ignoreOverrideState",
		}
		
		if config.show_debuginfo == "YES" then
			valid_config.doErrPopup = {
				display = bstr(35, "Popup standard errors for safely caught LME errors"),
				default = "NO",
			}
			valid_config.ignoreOverrideState = {
				display = bstr(-1, "Load Neoloader when default loader is disabled"),
				default = "NO",
			}
			valid_config.allowDelayedLoad = {
				display = bstr(-1, "Allow plugins to be activated after PLUGINS_LOADED event"),
				default = "NO",
			}
			valid_config.clearCommands = {
				display = bstr(-1, "Force-delete ghosted commands on game load"),
				default = "NO",
			}
		end
		
		local ctl = control_list_creator()
		ctl.expand = "VERTICAL"
		ctl.size = "%60x"
		
		local create_setting_editor = function(setting_to_edit)
			--obtain current option with lib.get_lme_config(setting_to_edit)
			cp("Creating setting modifier from " .. tostring(setting_to_edit))
			local config_being_adjusted = setting_to_edit
			local rules = valid_config[setting_to_edit]
			if not rules then
				return iup.vbox {} --invalid or hidden item
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
					fgcolor = (tonumber(cur_select)) == tonumber(rules.default) and "255 255 255" or "255 215 0",
					action = function(self, t, i, c)
						local new_setting = tostring(i - 1)
						lib.lme_configure(setting_to_edit, tonumber(new_setting), auth_key)
						self.fgcolor = new_setting == rules.default and "255 255 255" or "255 215 0"
						cur_select = new_setting
					end,
					bstr(39, "Ignore Nothing"),
					bstr(40, "Ignore Inconsequential"),
					bstr(41, "Ignore Debug"),
					bstr(42, "Ignore Standard"),
					bstr(43, "Ignore Warnings"),
					value = tonumber(cur_select) + 1,
				}
				iup.Append(cfg_panel, cfg_scale)
			else
				cp("Rules.type was an unhandled " .. tostring(rules.type))
				local cfg_item = iup.vbox {
					iup.label {
						title = "There was an error!?",
						fgcolor = "255 0 0",
					}
				}
				iup.Append(cfg_panel, cfg_item)
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
		unins_msg.value = bstr(44, "If you are having issues with Neoloader, try uninstalling it. This button will remove as much neoloader-based data as possible from your config.ini, and will prevent it from automatically loading until you are able to remove the plugin's files from your game. You might also want to do this if you are upgrading to a new version of Neoloader. If you want to install Neoloader again, use the button that will appear in your Options menu to trigger the setup process.")
		
		local gs = lib.get_gstate()
		
		local if_select = iup.stationsublist {
			dropdown = "YES",
			size = "200x" .. button_scalar(),
			action = function(self, t, i, cv)
				if cv == 1 then
					self.fgcolor = (t ~= gs.current_if) and "255 215 0" or "255 255 255"
					lib.lme_configure("current_if", t, auth_key)
				end
			end,
		}
		for k, v in ipairs(lib.get_gstate().if_list) do
			if v == "no_entry" then
				v = "vo-if"
			end
			if_select[k] = v
			if v == gs.current_if then
				if_select.value = k
			end
		end
		
		
		
		local mgr_select = iup.stationsublist {
			dropdown = "YES",
			size = "200x" .. button_scalar(),
			action = function(self, t, i, cv)
				if cv == 1 then
					self.fgcolor = (t ~= gs.current_mgr) and "255 215 0" or "255 255 255"
					self.fgcolor = (t == "no_entry") and "255 0 0" or self.fgcolor
					lib.lme_configure("current_mgr", t, auth_key)
				end
			end,
		}
		for k, v in ipairs(lib.get_gstate().mgr_list) do
			mgr_select[k] = v
			if v == gs.current_mgr then
				mgr_select.value = k
			end
		end
		
		
		
		local notif_select = iup.stationsublist {
			dropdown = "YES",
			size = "200x" .. button_scalar(),
			action = function(self, t, i, cv)
				if cv == 1 then
					self.fgcolor = (t ~= gs.current_notif) and "255 215 0" or "255 255 255"
					lib.lme_configure("current_notif", t, auth_key)
				end
			end,
		}
		for k, v in ipairs(lib.get_gstate().notif_list) do
			notif_select[k] = v
			if v == gs.current_notif then
				notif_select.value = k
			end
		end
		
		
		
		
		
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
						title = bstr(45, "WARNING! This is not your currently selected LME interface! Options requiring authentication may not apply!"),
					},
					iup.stationbutton {
						title = bstr(46, "Get authentication for this session"),
						action = function(self)
							local obtain_key = function(auth)
								iup.GetParent(self).visible = "NO"
								auth_key = auth
							end
							lib.request_auth(bstr(1, "Neoloader Lightweight Manager [neomgr]"), obtain_key)
						end,
					},
				},
				iup.label {
					title = bstr(47, "LME Configuration Settings"),
				},
				iup.hbox {
					iup.stationsubframe {
						iup.vbox {
							alignment = "ALEFT",
							iup.hbox {
								iup.fill { },
							},
							iup.hbox {
								iup.label {
									title = bstr(48, "Select an interface to load") .. ": ",
								},
								iup.fill { },
								if_select,
							},
							iup.hbox {
								iup.label {
									title = bstr(49, "Select your LME manager") .. ": ",
								},
								iup.fill { },
								mgr_select,
							},
							iup.hbox {
								iup.label {
									title = bstr(50, "Select your notification handler") .. ": ",
								},
								iup.fill { },
								notif_select,
							},
							iup.fill { },
						},
					},
					ctl,
				},
				iup.fill { },
				iup.hbox {
					alignment = "ACENTER",
					iup.fill { },
					iup.label {
						title = bstr(51, "Check for Neoloader updates on") .. "   ",
					},
					iup.stationbutton {
						title = "NexusMods",
						size = "x" .. button_scalar(),
						action = function()
							Game.OpenWebBrowser("https://www.nexusmods.com/vendettaonline/mods/3")
						end,
					},
					iup.stationbutton {
						title = "VOUPR",
						size = "x" .. button_scalar(),
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
							iup.stationbutton {
								title = bstr(62, "Load LME recovery system"),
								action = function()
									gkini.WriteString("Neoloader", "STOP", "recovery")
									lib.reload()
								end,
							},
							iup.fill { },
							iup.stationbutton {
								title = bstr(52, "Uninstall Neoloader"),
								size = "x" .. button_scalar(),
								fgcolor = "255 0 0",
								action = function()
									lib.uninstall()
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
		local ctl_ref = tostring(notif_ctl)
		
		local notif_class = lib.get_class(lib.get_gstate().current_notif, "0")
		
		if (type(notif_class) ~= "table") or (not notif_class.notif_handler) then
			local invalid = iup.stationsubframe {
				iup.vbox {
					alignment = "ACENTER",
					iup.hbox {
						iup.fill { },
					},
					iup.label {
						title = bstr(53, "Unable to get notification system"),
					},
					iup.label {
						title = bstr(54, "Please ensure a notification handler is enabled on the plugins display page."),
					},
				},
			}
			
			--stub functions since no notifs are handled
			invalid.ctl_update = function() end
			invalid.unreg = function() end
			
			return invalid
		end
		
		local notif_panel = iup.stationsubframe {
			iup.vbox {
				alignment = "ACENTER",
				iup.label {
					title = bstr(55, "Recent Notifications"),
					font = Font.H5,
				},
				iup.hbox {
					iup.fill { },
					iup.stationbutton {
						title = bstr(56, "Clear All"),
						size = "x" .. button_scalar(),
						action = function(self)
							notif_ctl:clear_items()
							notif_ctl:update()
							notif_class.clear_all()
						end,
					},
				},
				notif_ctl,
			},
		}
		
		notif_panel.ctl_update = function()
			notif_ctl:clear_items()
			local history = notif_class.get_history()
			for k, v in ipairs(history) do
				local notif_obj = notif_class.make_visual(v.notif, v.data)
				notif_ctl:add_item(notif_obj)
			end
			notif_ctl:update()
		end
		notif_panel.unreg = function()
			notif_class.unregister_listener("neomgr")
		end
		
		local listener_func = function(status, data)
			cp("neomgr listener called with " .. status .. " >> " .. spickle(data))
			cp("ctl exists: " .. tostring(notif_ctl))
			cp("ctl ref should be " .. tostring(ctl_ref))
			if tostring(notif_ctl) ~= tostring(ctl_ref) then
				lib.log_error("CTL Reference mismatch!", 4, "neomgr", "0")
				print("An error has occured! Please send your errors.log file to Luxen De'Mark for investigation!")
			end
			
			notif_ctl:clear_items()
			local history = notif_class.get_history()
			for k, v in ipairs(history) do
				local notif_obj = notif_class.make_visual(v.notif, v.data)
				notif_ctl:add_item(notif_obj)
			end
			notif_ctl:update()
		end
		
		notif_class.register_listener("neomgr", listener_func)
		
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
	local tabs_reset_color
	local tabs_container = {
		iup.stationbutton {
			title = bstr(57, "Manage installed mods"),
			bgcolor = "255 255 255",
			expand = "HORIZONTAL",
			size = "x" .. button_scalar(),
			action = function(self)
				tabs_reset_color()
				panel_view.value = modlist_panel
				self.bgcolor = "255 255 255"
			end,
		},
		iup.stationbutton {
			title = bstr(55, "View notifications"),
			bgcolor = "150 150 150",
			expand = "HORIZONTAL",
			size = "x" .. button_scalar(),
			action = function(self)
				tabs_reset_color()
				notif_panel:ctl_update()
				panel_view.value = notif_panel
				self.bgcolor = "255 255 255"
			end,
		},
		iup.stationbutton {
			title = bstr(58, "View log"),
			bgcolor = "150 150 150",
			expand = "HORIZONTAL",
			size = "x" .. button_scalar(),
			action = function(self)
				tabs_reset_color()
				panel_view.value = logview_panel
				self.bgcolor = "255 255 255"
			end,
		},
		iup.stationbutton {
			title = bstr(47, "Configure Neoloader"),
			bgcolor = "150 150 150",
			expand = "HORIZONTAL",
			size = "x" .. button_scalar(),
			action = function(self)
				tabs_reset_color()
				panel_view.value = config_panel
				self.bgcolor = "255 255 255"
			end,
		},
	}
	tabs_reset_color = function()
		for i, v in ipairs(tabs_container) do
			v.bgcolor = "150 150 150"
		end
	end
	
	local tabs_view = iup.hbox {}
	for i, v in ipairs(tabs_container) do
		tabs_view:append(v)
	end
	
	local close_button = iup.stationbutton {
		title = bstr(7, "Close"),
		size = "x" .. button_scalar(),
		action = function(self)
			local close_action = function()
				notif_panel.unreg()
				HideDialog(iup.GetDialog(self))
				iup.Destroy(iup.GetDialog(self))
			end
			
			if apply_flag and #apply_actions > 0 then
				--there are pending applications
				local apply_alert = iup.dialog {
					fullscreen = "YES",
					topmost = "YES",
					bgcolor = "0 0 0 150 *",
					iup.vbox {
						iup.fill { },
						iup.hbox {
							iup.fill { },
							iup.stationnameframe {
								iup.vbox {
									alignment = "ACENTER",
									iup.label {
										title = bstr(65, "Cancel pending changes") .. "?",
										font = Font.H2
									},
									iup.fill {
										size = Font.Default,
									},
									iup.hbox {
										iup.stationbutton {
											title = bstr(66, "YES"),
											action = function(alert_self)
												HideDialog(iup.GetDialog(alert_self))
												close_action()
											end,
										},
										iup.stationbutton {
											title = bstr(67, "NO"),
											action = function(alert_self)
												HideDialog(iup.GetDialog(alert_self))
											end,
										},
									},
								},
							},
							iup.fill { },
						},
						iup.fill { },
					},
				}
				
				apply_alert:map()
				ShowDialog(apply_alert)
			else
				close_action()
			end
		end,
	}
	
	local root_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		defaultesc = close_button,
		iup.vbox {
			iup.hbox {
				iup.fill { },
				iup.label {
					title = bstr(1, "Neoloader Lightweight Management Interface"),
				},
				iup.fill { },
			},
			iup.hbox {
				iup.label {
					title = "LME " .. bstr(59, "Provider") .. ": " .. lib[1] .. " " .. bstr(14, "version") .. " " .. lib.get_gstate().version.strver,
				},
				iup.fill {},
				iup.stationbutton {
					title = bstr(60, "Reload"),
					size = "x" .. button_scalar(),
					action = function(self)
						HideDialog(iup.GetDialog(self))
						iup.Destroy(iup.GetDialog(self))
						lib.reload()
					end,
				},
				iup.fill {
					size = "%1",
				},
				close_button,
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
	
	local angular_check = gkini.ReadString("Vendetta", "usenewui", "?")
	
	if config.qa_buttons == "YES" then
		if ((angular_check == "1") or (angular_check == "?")) and Platform == "Windows" then
			local odbutton = OptionsDialog[1][1][15]
			
			local x_pos = tonumber(odbutton.cx)
			local y_pos = tonumber(odbutton.cy)
			local sizes = {}
			for value in string.gmatch(odbutton.size, "%d+") do
				table.insert(sizes, tonumber(value))
			end
			y_pos = y_pos - (sizes[2] * 1.5)
			
			local neobutton = iup.button {
				title = bstr(61, "Open Mod Manager"),
				size = odbutton.size,
				cx = x_pos,
				cy = y_pos,
				image = odbutton.image,
				action = neo.open,
			}
			
			iup.Append(OptionsDialog[1][1], neobutton)
		else
			local neobutton = iup.stationbutton {
				title = bstr(61, "Open Mod Manager"),
				expand = "HORIZONTAL",
				action = neo.open,
			}
			
			iup.Append(OptionsDialog[1][1][1], neobutton)
		end
	end
end

RegisterEvent(open_button_creator, "PLUGINS_LOADED")

neo.mgr = true
update_class()

lib.require({{name="babel", version="0"}}, babel_support)
