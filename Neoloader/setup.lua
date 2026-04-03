--[[
[metadata]
description=First-run setup solution for Neoloader
version=2.0.0
owner=Neoloader|7.0.0
type=lua
created=2026-4-1
]]--

local local_path
local ok, err = pcall(function()
	error("Path lookup")
end)

if not ok and type(err) == "string" then
	-- Try to extract the filename prefix
	local path = err:match("([^:]+):%d+: Path lookup")
	if path then
		-- Strip filename if needed
		local_path = path:match("^(.-/)[^/]-$")
	end
end

console_print("%%1 local path is " .. local_path)

local gkrs = gkini.ReadString
local gkws = gkini.WriteString



local lget = function(header, key, def)
	local cur_lang_code = gkini.ReadString("Vendetta", "locale", "en")
	
	local lang_path = local_path .. "lang/" .. cur_lang_code .. "/setup.ini"
	
	return gkini.ReadString2(header, key, def, lang_path) or def
end

local button_scalar = function()
	local val = "" -- use natural size
	if gkinterface.IsTouchModeEnabled() then
		val = "x" .. tostring(Font.Default * 2) -- double of usual natural size
	end
	return val
end

local pre_setup_handler = function()
	--trigger before LME loads
	local counter = 1
	while true do
		if gkrs("Neo-registry", "reg" .. tostring(counter), "") ~= "" then
			counter = counter + 1
		else
			--No entry here
			break
		end
	end
	for i=counter, 1, -1 do
		gkws("Neo-registry", "reg" .. tostring(i), "")
	end
end



local clearframe = function(intable)
	assert(type(intable) == "table", "Helium.clearframe expects a table for its argument, got a " .. type(intable))
	
	local default = {
		bgcolor = "0 0 0 0 *",
		segmented = "0 0 1 1",
		iup.vbox { },
		expand = "NO",
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	assert((iup.IsValid(default[1])), "Helium.clearframe input table did not have a valid IUP element at [1]; got " .. type(intable[1]))
	
	return iup.frame(default)
end

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
		defaults[k] = v
	end

	local scroll = iup.canvas(defaults)
	scroll.get_pos = function(self)
		return self.posy
	end

	local scroll_update
	scroll_update = function()
		if not iup.IsValid(scroll) then
			scroll_timer:Kill()
			return
		end
		
		if scroll_flag then
			defaults.scroll_event_cb(scroll)
			scroll_flag = false
		end
		scroll_timer:SetTimeout(1, scroll_update)
	end

	scroll.init_timer = scroll_update

	return scroll
end

local create_autobox = function(intable)
	local default = {
		expand = "YES",
		[1] = iup.vbox {},
		cx = 0,
		cy = 0,
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	
	local cbox_children = {}
	--add from default
	for k, v in ipairs(default) do
		cbox_children[k] = clearframe {
			cx = v.cx or default.cx,
			cy = v.cy or default.cy,
			v,
		}
	end
	--clear from default
	for k, v in ipairs(cbox_children) do
		default[k] = nil
	end
	
	local imposter = clearframe {
		--used to get size of parent
		expand = "YES",
		iup.vbox {
			iup.hbox {
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	local cbox_area = iup.cbox (cbox_children)
	
	default[1] = iup.zbox {
		cbox_area,
		default.expand ~= "NO" and imposter or nil,
	}
		
	
	local root_frame = clearframe(default)
	root_frame.map_cb = function(self)
		local root = imposter
		local w = tostring(root.w)
		local h = tostring(root.h)
		cbox_area.size = w .. "x" .. h
		for k, v in ipairs(cbox_children) do
			v.size = w .. "x" .. h
		end
		iup.Refresh(self)
	end
	
	root_frame.cbox = cbox_area
	root_frame.cbox_children = cbox_children
	root_frame.imposter = imposter
	
	return root_frame
end

local create_list_control = function(intable)
	local default = {
		expand = "YES",
		scrollbar = "YES",
		[1] = iup.vbox {},
	}

	for k, v in pairs(intable) do
		default[k] = v
	end

	local iup_element = default[1]
	default[1] = nil

	-- use autobox with one child: the scrollable element
	local ab = create_autobox {
		iup_element,
	}

	local scroller
	scroller = create_slider_control {
		scroll_event_cb = function()
			local content = ab.cbox_children[1]
			content.cy = ((scroller:get_pos() * (tonumber(content.h) - tonumber(scroller.h))) / 100) * -1
			iup.Refresh(content)
		end,
	}

	default[1] = iup.hbox {
		ab,
		scroller,
	}

	local root_frame = clearframe(default)

	root_frame.map_cb = function(self)
		if self.expand == "NO" then return end

		local w = ab.imposter.w
		local h = ab.imposter.h

		self.size = tostring(w) .. "x" .. tostring(h)
		scroller.size = tostring(Font.Default) .. "x" .. tostring(h)

		local content = ab.cbox_children[1]

		-- handle scrollbar logic
		local content_h = content.h
		local inner_w = w - Font.Default

		if default.scrollbar == "NO" or content_h < h then
			-- disable scrollbar if content fits
			--scroller:detach()
			ab.cbox.size = w .. "x" .. h
			content.size = w .. "x" .. h
		else
			ab.cbox.size = inner_w .. "x" .. h
			content.size = inner_w .. "x" .. content_h
		end
		
		scroller.init_timer()

		iup.Refresh(self)
	end

	return root_frame
end





local setup_handler


local delay_timer = Timer()
setup_handler = function()
	--trigger after LME loads
	
	--[[
		if user closes interface, just use defaults
		
		config to select:
			standard:
				default load state
				select operating mode 'cooperative'/'independent'
				
			developer:
				register VoidIF
				override disabled state
				enable stat graphing
	]]--
	
	local auth_key = "null"
	
	local invalidate_setup = false --true when needed to relaunch (locale changed)
	
	local setup_panels = {}
	local setup_panel_view_filter = 1 --skips values above this
	local setup_viewer = iup.zbox {
		alignment = "ACENTER",
		iup.vbox {
			iup.label {
				title = "You shouldn't see this",
			},
		},
	}
	local setup_cur_panel = 1
	local setup_next = function()
		if invalidate_setup then
			HideDialog(iup.GetDialog(setup_viewer))
			delay_timer:SetTimeout(10, setup_handler)
			return
		end
		while true do
			setup_cur_panel = setup_cur_panel + 1
			if setup_cur_panel > #setup_panels then
				HideDialog(iup.GetDialog(setup_viewer))
				lib.reload()
				return
			end
			local next_panel = setup_panels[setup_cur_panel]
			setup_viewer.value = next_panel
			if (tonumber(next_panel.filter_value) or 0) < setup_panel_view_filter then
				break
			end
		end
	end
	
	local set_first_panel_flag = false
	local make_base = function(ihandle)
		local panel = iup.frame {
			bgcolor = "0 0 0 0 *",
			segmented = "0 0 1 1",
			filter_value = ihandle.filter_value or 0,
			ihandle,
		}
		
		table.insert(setup_panels, panel)
		setup_viewer:append(panel)
		
		if not set_first_panel_flag then
			set_first_panel_flag = true
			setup_viewer.value = setup_panels[1]
		else
			setup_viewer.value = setup_panels[setup_cur_panel] -- what was this for again?
		end
	end
	
	local _bin_yes = lget("generic", "BINARY_YES", "YES")
	local _bin_no  = lget("generic", "BINARY_NO",  "NO")
	
	local make_opt = function(intable)
		local default = {
			op_cfg_key = "invalid",
			op_key_for_lookup = "invalid",
			op_name = "invalid option",
			op_descrip = "failure, no option available!",
			op_callback = function() end,
			op_default_index = 1,
			filter_value = 0,
			_bin_yes,
			_bin_no,
		}
		
		for k, v in pairs(intable) do
			default[k] = v
		end
		
		default.op_name = lget("setup", default.op_key_for_lookup .. "_name", default.op_name)
		default.op_descrip = lget("setup", default.op_key_for_lookup .. "_descrip", default.op_descrip)
		
		local cur_select = default.op_default_index
		
		local lselect = iup.list {
			dropdown = "YES",
			action = function(self, t, i, cv)
				if cv == 1 then
					cur_select = i
				end
			end,
		}
		
		for i, v in ipairs(default) do
			lselect[i] = tostring(v)
		end
		
		make_base(iup.frame {
			bgcolor = "0 0 0 0 *",
			segmented = "0 0 1 1",
			filter_value = default.filter_value,
			iup.vbox {
				alignment = "ACENTER",
				iup.fill { },
				iup.label {
					title = default.op_name,
				},
				iup.fill { },
				iup.label {
					title = default.op_descrip,
					wordwrap = "YES",
					size = "%50",
				},
				iup.fill { },
				iup.hbox {
					iup.fill { },
					lselect,
				},
				iup.fill { },
				iup.fill { },
				iup.hbox {
					iup.fill { },
					iup.stationbutton {
						title = lget("generic", "NAV_NEXT", "Next"),
						size = button_scalar(),
						action = function(self)
							default.op_callback(default[cur_select])
							setup_next()
						end,
					},
				},
			},
		})
	end
	
	--[[
		select locale
		splash screen, greet user
		request auth
			actually request auth
			auth callback triggers next, or provide cancel button
		user selects "use defaults, show standard options, show developer options"
		[list options per individual screen]
		options have been applied, LME is configured
	]]--
	
	local locale_select_action = function(self, code)
		gkini.WriteString("Vendetta", "locale", code or "en")
		invalidate_setup = true
		setup_next(self)
	end
	
	local locale_select = create_list_control {
		iup.vbox {
			iup.frame {
				iup.hbox {
					alignment = "ACENTER",
					iup.button {
						title = "",
						_locale = "en",
						image = local_path .. "assets/flag_en.png",
						size = "256x171",
						action = function(self)
							locale_select_action(self, "en")
						end,
					},
					iup.fill { },
					iup.stationbutton {
						action = function(self)
							locale_select_action(self, "en")
						end,
						title = "English",
						size = "x50",
						font = "40",
					},
				},
			},
			iup.frame {
				iup.hbox {
					alignment = "ACENTER",
					iup.button {
						title = "",
						_locale = "es",
						image = local_path .. "assets/flag_es.png",
						size = "256x171",
						action = function(self)
							locale_select_action(self, "es")
						end,
					},
					iup.fill { },
					iup.stationbutton {
						action = function(self)
							locale_select_action(self, "es")
						end,
						title = "Espanol",
						size = "x50",
						font = "40",
					},
				},
			},
			iup.frame {
				iup.hbox {
					alignment = "ACENTER",
					iup.button {
						title = "",
						_locale = "fr",
						image = local_path .. "assets/flag_fr.png",
						size = "256x171",
						action = function(self)
							locale_select_action(self, "fr")
						end,
					},
					iup.fill { },
					iup.stationbutton {
						action = function(self)
							locale_select_action(self, "fr")
						end,
						title = "Francais",
						size = "x50",
						font = "40",
					},
				},
			},
			iup.frame {
				iup.hbox {
					alignment = "ACENTER",
					iup.button {
						title = "",
						_locale = "pt",
						image = local_path .. "assets/flag_pt.png",
						size = "256x171",
						action = function(self)
							locale_select_action(self, "pt")
						end,
					},
					iup.fill { },
					iup.stationbutton {
						action = function(self)
							locale_select_action(self, "pt")
						end,
						title = "Portugues",
						size = "x50",
						font = "40",
					},
				},
			},
		},
	}
	
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = lget("setup", "LOCALE_SELECT", "Select your language."),
		},
		iup.fill { },
		--if user selects to change the locale here, setup will need to be re-run
		iup.frame {
			expand = "NO",
			size = "%50x%40",
			image = "",
			segmented = "0 0 1 1",
			bgcolor = "0 0 0 0 *",
			locale_select,
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				size = button_scalar(),
				title = lget("generic", "NAV_NEXT", "Next"),
				action = setup_next,
			},
		},
	})
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = "",
			image = local_path .. "assets/thumb.png",
			size = "256x256",
		},
		iup.label {
			title = lget("setup", "MAINGREET", "Neoloader is running for the first time or was recently updated. This setup will help configure how it behaves."),
			wordwrap = "YES",
			size = "%50x",
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				size = button_scalar(),
				title = lget("generic", "NAV_NEXT", "Next"),
				action = setup_next,
			},
		},
	})
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = lget("setup", "DESCRIPAUTH", "Some settings require your approval before they can be changed. This prevents plugins from modifying important behavior without your permission."), 
			wordwrap = "YES",
			size = "%50x",
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				size = button_scalar(),
				title = lget("setup", "usedef", "Just use default options"), --we don't need auth for this
				action = function()
					lib.lme_configure("launch_mode", "independent")
					gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
					gkinterface.GKSaveCfg()
					
					lib.reload()
				end,
			},
			iup.stationbutton {
				size = button_scalar(),
				title = lget("generic", "NAV_NEXT", "Next"),
				action = function()
					lib.request_auth("Neoloader first-time setup", setup_next)
				end,
			},
		},
	})
	
	local cfg_level = 1
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = lget("setup", "SELECTCFGLEVEL", "How much setup would you like to go through?"),
			wordwrap = "YES",
			size = "%50x",
		},
		iup.fill { },
		iup.list {
			dropdown = "YES",
			action = function(self, t, i, cv)
				if cv == 1 then
					setup_panel_view_filter = i
				end
			end,
			value = 1,
			lget("setup", "usedef", "Just use default options"),
			lget("setup", "cfgstandard", "Show standard setup options"),
			lget("setup", "cfgadvanced", "Show additional options for plugin developers"),
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				size = button_scalar(),
				title = lget("generic", "NAV_NEXT", "Next"),
				action = function(self)
					setup_next()
				end,
			},
		},
	})
	
	make_opt {
		filter_value = 1,
		op_cfg_key = "default_load_state",
		op_key_for_lookup = "default_load_state",
		op_name = "Default load state",
		op_descrip = "Allow plugins to load automatically when registered. NO means they must be manually enabled.",
		op_callback = function(val)
			val = val == _bin_yes and "YES" or "NO"
			lib.lme_configure("default_load_state", val, auth_key)
		end,
	}
	
	local prev_if = gkini.ReadString("Vendetta", "if", "")
	local _option_indp = lget("setup", "launch_mode_option_indp", "independent")
	local _option_coop = lget("setup", "launch_mode_option_coop", "cooperative")
	make_opt {
		filter_value = 1,
		op_cfg_key = "launch_mode",
		op_key_for_lookup = "launch_mode",
		op_name = "Neoloader's operating mode",
		op_descrip = "Choose how Neoloader starts. Independent mode runs Neoloader directly. Cooperative mode uses the game’s normal plugin loader, but some older LME plugins may not work.",
		op_callback = function(val)
			local val = val == _option_indp and "independent" or "cooperative"
			lib.lme_configure("launch_mode", val)
			if val == "independent" then
				gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
			end
		end,
		_option_indp,
		_option_coop,
	}
	
	make_opt {
		filter_value = 2,
		op_key_for_lookup = "register_voidif",
		op_name = "Register VoidIF",
		op_descrip = "VoidIF is only for unusual advanced interface setups. Leave this off unless you already know you need it.",
		op_callback = function(val)
			if val ~= _bin_no then
				lib.register(local_path .. "modules/VoidIF/voidif.lua")
			end
			if val == _bin_yes then
				--undo IF overwrite; user has their own IF and will launch init themselves
				gkini.WriteString("Vendetta", "if", prev_if)
				lib.set_load(auth_key, "voidif", "0", "YES")
				lib.lme_configure("current_if", "voidif", auth_key)
			end
		end,
		_bin_no,
		_bin_yes,
		lget("setup", "register_voidif_addonly", "Register only"),
	}
	
	make_opt {
		filter_value = 2,
		op_cfg_key = "override_disabled_state",
		op_key_for_lookup = "override_disabled_plugin_state",
		op_name = "Run Neoloader even when plugins are disabled",
		op_descrip = "When running in independent mode, Neoloader respects the game setting that disables the plugin loader and halts its execution. Set this to YES to disable this behavior and run Neoloader anyways.",
		op_callback = function(val)
			val = val == _bin_yes and "YES" or "NO"
			lib.lme_configure("override_disabled_plugin_state", val)
		end,
		_bin_no,
		_bin_yes,
	}
	
	make_opt {
		filter_value = 2,
		op_cfg_key = "stat_graphing",
		op_key_for_lookup = "stat_graphing",
		op_name = "Enable periodic performance recording",
		op_descrip = "Periodically records performance information and writes it to the log for debugging.",
		op_callback = function(val)
			val = val == _bin_yes and "YES" or "NO"
			lib.lme_configure("stat_graphing", val)
		end,
		_bin_no,
		_bin_yes,
	}
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = lget("setup", "FINISH_SCREEN_MSG", "Options have been configured; thank you for using Neoloader!"),
			wordwrap = "YES",
			size = "%50x",
		},
		iup.label {
			title = "",
			image = local_path .. "assets/thumb.png",
			size = "256x256",
		},
		iup.fill { },
		iup.label {
			title = lget("setup", "FINISH_SCREEN_DISCORD_INV", "For assistance with Neoloader or plugins in general, visit the Vendetta Online Modding Community!"),
			wordwrap = "YES",
			size = "%50x",
		},
		iup.hbox {
			iup.label {
				title = "",
				image = local_path .. "assets/social_discord.png",
				size = tostring(Font.Default) .. "x" .. tostring(Font.Default)
			},
			iup.stationbutton {
				title = lget("setup", "DISCORD_JOIN", "Click to join"),
				action = function()
					Game.OpenWebBrowser("https://discord.gg/hJbCnmZU4E")
				end,
			},
		},
		iup.fill { },
		iup.stationbutton {
			size = button_scalar(),
			title = lget("generic", "CLOSE_WINDOW", "Close"),
			action = function()
				setup_next()
				print(lget("setup", "FINISH_REMINDER_MSG", "You can run setup again with '/neosetup', or open the manager with '/neo'."))
			end,
		},
	})
	
	local diag = iup.dialog {
		topmost = "YES",
		bgcolor = "0 0 0 200 *",
		fullscreen = "YES",
		alignment = "ACENTER",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationsubframe {
					size = "%70x%50",
					expand = "NO",
					alignment = "ACENTER",
					iup.vbox {
						alignment = "ACENTER",
						iup.hbox {
							iup.label {
								title = lget("setup", "SETUP_BANNER_TEXT", "Neoloader setup"),
							},
						},
						setup_viewer,
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	diag:map()
	
	locale_select:map_cb()
	
	
	
	ShowDialog(diag)
end



delay_timer:SetTimeout(1000, setup_handler)

RegisterUserCommand("neosetup", setup_handler)