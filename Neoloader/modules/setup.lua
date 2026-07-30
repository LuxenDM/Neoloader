--[[
[metadata]
description=First-run setup solution for Neoloader
owner=Neoloader|7.0.0
type=lua
created=2026-4-28
]]--

local neo = ...
local local_path = neo.path

local setup_ver = "2.1.0"

local gkrs = gkini.ReadString
local gkws = gkini.WriteString

local lexready = true
if not lib.is_ready("lexicon", "0") then
	lexready = false
end

local lex_ver = (lexready and lib.get_latest("lexicon", "1.0.0", "1.4.9")) or "0"
local lex = (lexready and lib.get_class("lexicon", lex_ver)) or {}

local lexicon_reference_id = (lexready and lex.register("neosetup", setup_ver, local_path .. "lang/en/setup.ini")) or "0"

local supported_lang = {"da", "de", "eo", "es", "fr", "id", "it", "nl", "pl", "pt", "tr"}

local lget = function(id, default)
	return default
end

if lexready then
	for _, lc in ipairs(supported_lang) do
		lex.register("neosetup", setup_ver, local_path .. "lang/" .. lc .. "/setup.ini")
	end
	
	lget = function(id, default)
		return lex.fetch(lexicon_reference_id, id, default)
	end
end

local button_scalar = function()
	local val = "" -- use natural size
	if gkinterface.IsTouchModeEnabled() then
		val = "x" .. tostring(Font.Default * 2) -- double of usual natural size
	end
	return val
end



--[[
Imported from Helium
]]--

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
		
		scroller.posy = 0
		scroller.init_timer()

		iup.Refresh(self)
	end

	return root_frame
end

local coverbutton = function(intable)
	local default = {
		action = function(self) end,
		[1] = iup.vbox { },
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	
	local cover = iup.button {
		title = "", 
		bgcolor = "0 0 0 0 *",
		expand = "YES",
		action = default.action,
	}
	
	return iup.zbox {
		all = "YES",
		expand = "NO",
		alignment = "ACENTER",
		default[1],
		cover,
	}
end

local slide_toggle = function(intable)
	assert(type(intable) == "table", "helium.slide_toggle expects a table")

	local default = {
		value = "NO",
		image_off = local_path .. "assets/slide_off.png",
		image_on  = local_path .. "assets/slide_on.png",
		size = tostring(Font.Default * 2) .. "x" .. tostring(Font.Default),
		action = function(self, value) end,
	}

	for k, v in pairs(intable) do
		default[k] = v
	end

	local img = iup.label {
		title = "",
		image = (default.value == "YES") and default.image_on or default.image_off,
		value = default.value,
		size = default.size,
		--bgcolor = "0 0 0  *",
	}
	
	local toggle_container = coverbutton {
		action = function(self)
			if img.value == "YES" then
				img.value = "NO"
				img.image = default.image_off
			else
				img.value = "YES"
				img.image = default.image_on
			end
			default.action(self, img.value)
		end,
		img,
	}

	return toggle_container
end

--[[
end of helium imported code
]]--

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
	
	local _bin_yes = lget("BINARY_YES", "YES")
	local _bin_no  = lget("BINARY_NO",  "NO")
	
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
		
		default.op_name = lget(default.op_key_for_lookup .. "_name", default.op_name)
		default.op_descrip = lget(default.op_key_for_lookup .. "_descrip", default.op_descrip)
		
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
						title = lget("NAV_NEXT", "Next"),
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
	
	local lex_select
	
	if lexready then
	
		local lex_screen_next_button = iup.stationbutton {
			size = button_scalar(),
			title = lget("NAV_NEXT", "Next"), --on locale change, switch to text for appropriate next. 
			action = setup_next,
		}
		
		lex_select = lex.interface.locale_selector {
			compact = false,
			show_config = false,
			show_labels = false,
			advanced = false,
			
			--on selection, invalidate interface and reset setup
			action = function(lang_entry)
				lex.set_primary_locale(lang_entry.code)
				invalidate_setup = true
				setup_next()
			end,
		}
		
		local cur_lang = lex.get_primary_locale()
		
		local lex_current = lex.get_language(cur_lang)
		
		local cur_flag = iup.label {
			title = "",
			image = lex_current.flag,
			size = tostring(Font.Default) .. "x" .. tostring(Font.Default),
		}
		
		make_base(iup.vbox {
			alignment = "ACENTER",
			iup.hbox {
				iup.label {
					title = lget("lang_current_notice", "Currently selected language") .. ": ",
					wordwrap = "YES",
					size = "%40x",
				},
				cur_flag,
			},
			lex_select,
			iup.hbox {
				iup.label {
					title = lget("lang_select_completion_prompt", "Once you have selected your language above, hit next to continue."),
					wordwrap = "YES",
					size = "%40x",
				},
				iup.fill { },
				lex_screen_next_button,
			},
		})
	end
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = "",
			image = local_path .. "assets/thumb.png",
			size = "256x256",
		},
		iup.label {
			title = lget("MAINGREET", "Neoloader is running for the first time or was recently updated. This setup will help configure how it behaves."),
			wordwrap = "YES",
			size = "%50x",
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				size = button_scalar(),
				title = lget("NAV_NEXT", "Next"),
				action = setup_next,
			},
		},
	})
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.fill { },
		iup.label {
			title = lget("SELECTCFGLEVEL", "How much setup would you like to go through?"),
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
			lget("usedef", "Just use default options"),
			lget("cfgstandard", "Show standard setup options"),
			lget("cfgadvanced", "Show additional options for plugin developers"),
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				size = button_scalar(),
				title = lget("NAV_NEXT", "Next"),
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
			lib.lme_configure("default_load_state", val, neo.auth_key)
		end,
	}
	
	local prev_if = gkini.ReadString("Vendetta", "if", "")
	local _option_indp = lget("launch_mode_option_indp", "independent")
	local _option_coop = lget("launch_mode_option_coop", "cooperative")
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
				lib.set_load(neo.auth_key, "voidif", "0", "YES")
				lib.lme_configure("current_if", "voidif", neo.auth_key)
			end
		end,
		_bin_no,
		_bin_yes,
		lget("register_voidif_addonly", "Register only"),
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
			title = lget("FINISH_SCREEN_MSG", "Options have been configured; thank you for using Neoloader!"),
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
			title = lget("FINISH_SCREEN_DISCORD_INV", "For assistance with Neoloader or plugins in general, visit the Vendetta Online Modding Community!"),
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
				title = lget("DISCORD_JOIN", "Click to join"),
				action = function()
					Game.OpenWebBrowser("https://discord.gg/hJbCnmZU4E")
				end,
			},
		},
		iup.fill { },
		iup.stationbutton {
			size = button_scalar(),
			title = lget("CLOSE_WINDOW", "Close"),
			action = function()
				setup_next()
				print(lget("FINISH_REMINDER_MSG", "You can run setup again with '/neosetup', or open the manager with '/neo'."))
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
								title = lget("SETUP_BANNER_TEXT", "Neoloader setup"),
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
	
	if lexready then
		lex_select:map_cb()
	end
	
	
	ShowDialog(diag)
end

RegisterUserCommand("neosetup", setup_handler)