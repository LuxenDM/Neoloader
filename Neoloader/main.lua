--[[
[metadata]
description=Default loader entrypoint for Neoloader
version=2.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-7-1
]]--

local lme_flag = false

if type(lib) == "table" and lib[0] == "LME" then
	lme_flag = true
end

local lang_code = gkini.ReadString("Vendetta", "locale", "en")

local launch_mode_cfg = gkini.ReadString("Neoloader", "launch_mode", "cooperative-first-run")
local local_path = "plugins/!Neoloader/"
if not gksys.IsExist(local_path .. "init.lua") then
	local_path = gkini.ReadString("Neoloader", "home_path_override", "plugins/Neoloader/")
end
if not gksys.IsExist(local_path .. "init.lua") then
	--attempt to get path by sniffing error()

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
	
	if not gksys.IsExist(local_path .. "init.lua") then
		--We have NO idea where this file is executing from, and that is a PROBLEM! launch the default interface and inform the user that Neoloader is being run in a very unusual manner. We cannot launch the recovery interface if we cannot guarantee its location
		
		print("Catastrophic error: unable to determine Neoloader directory!")
		print("Please verify you have downloaded the latest version of Neoloader, and attempt reinstallation. Alternatively, if you know the exact path to Neoloader's files")
		
		--use timer to delay trigger, show dialog to get directory and then trigger reload
		
		return
	end
end

--[[ launch_mode_cfg
	cooperative-first-run	- first time, will use cooperative mode.
	cooperative				- running in cooperative mode.
	independent				- running in independent mode.
	removed					- User uninstalled Neoloader
]]--

local stop_error = gkini.ReadString("Neoloader", "STOP", "")

local lget = function(header, key, def)
	local lang_path = local_path .. "lang/" .. lang_code .. "/setup.ini"
	
	return gkini.ReadString2(header, key, def, lang_path) or def
end

local button_scalar = function()
	local val = ""
	if gkinterface.IsTouchModeEnabled() then
		val = tostring(Font.Default * 2)
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


local delay_timer = Timer()
local setup_handler = function()
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
	delay_timer:Kill()
	
	local auth_key = "null"
	
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
		while true do
			setup_cur_panel = setup_cur_panel + 1
			if setup_cur_panel > #setup_panels then
				HideDialog(iup.GetDialog(setup_viewer))
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
			setup_viewer.value = setup_panels[setup_cur_panel]
		end
	end
	
	local make_opt = function(intable)
		local default = {
			op_cfg_key = "invalid",
			op_key_for_lookup = "invalid",
			op_name = "invalid option",
			op_descrip = "failure, no option available!",
			op_callback = function() end,
			op_default_index = 1,
			filter_value = 0,
			"YES",
			"NO",
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
						title = "Next",
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
		greet user
		request auth
			actually request auth
			auth callback triggers next, or provide cancel button
		use defaults, show standard options, show developer options
		[list options per individual screen]
		options have been applied, LME is configured
	]]--
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.label {
			title = lget("setup", "MAINGREET", "Neoloader is running for the first time, or has been updated recently. This menu will let you set configuration settings for how your LME will behave."),
			wordwrap = "YES",
			size = "%50",
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				title = "Next",
				action = setup_next,
			},
		},
	})
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.label {
			title = lget("setup", "DESCRIPAUTH", "Certain configuration settings require your direct authorization to change. When you select 'next', you must allow authorization to progress. This prevents your plugins from blindly affecting how Neoloader behaves."), --maybe change this text?
			wordwrap = "YES",
			size = "%50",
		},
		iup.fill { },
		iup.hbox {
			iup.fill { },
			iup.stationbutton {
				title = lget("setup", "usedef", "Just use default options"), --we don't need auth for this
				action = function()
					lib.lme_configure("launch_mode", "independent")
					gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
					gkinterface.GKSaveCfg()
					
					lib.reload()
				end,
			},
			iup.stationbutton {
				title = "next",
				action = function()
					lib.request_auth("Neoloader first-time setup", setup_next)
				end,
			},
		},
	})
	
	local cfg_level = 1
	
	make_base(iup.vbox {
		alignment = "ACENTER",
		iup.label {
			title = lget("setup", "SELECTCFGLEVEL", "Which options would you like to review during setup?"),
			wordwrap = "YES",
			size = "%50",
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
				title = "next",
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
		op_descrip = "Select if plugins can load as soon as they are registered. NO means they must be manually enabled.",
		op_callback = function(val)
			lib.lme_configure("default_load_state", val, auth_key)
		end,
	}
	
	local prev_if = gkini.ReadString("Vendetta", "if", "")
	make_opt {
		filter_value = 1,
		op_cfg_key = "launch_mode",
		op_key_for_lookup = "launch_mode",
		op_name = "Neoloader's operating mode",
		op_descrip = "Select if Neoloader should run independently of the standard plugin loader. Cooperative mode puts the Game's default loader in control, but older LME plugins may fail.",
		op_callback = function(val)
			lib.lme_configure("launch_mode", val)
			if val == "independent" then
				gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
			end
		end,
		"independent",
		"cooperative",
	}
	
	make_opt {
		filter_value = 2,
		op_key_for_lookup = "register_voidif",
		op_name = "Register VoidIF",
		op_descrip = "VoidIF is a blank interface. If you're running a very unique interface control system but ALSO want Neoloader to run in 'independent' mode through direct execution, select 'YES' to register and enable this utility.",
		op_callback = function(val)
			if val ~= "NO" then
				lib.register(local_path .. "modules/VoidIF/voidif.lua")
			end
			if val == "YES" then
				--undo IF overwrite; user has their own IF and will launch init themselves
				gkini.WriteString("Vendetta", "if", prev_if)
				lib.set_load(auth_key, "voidif", "0", "YES")
				lib.lme_configure("current_if", "voidif", auth_key)
			end
		end,
		"NO",
		"YES",
		"Register only",
	}
	
	make_opt {
		filter_value = 2,
		op_cfg_key = "override_disabled_state",
		op_key_for_lookup = "override_disabled_plugin_state",
		op_name = "Run Neoloader even when plugins are disabled",
		op_descrip = "When running in independent mode, Neoloader respects the game setting that disables the plugin loader and halts its execution. Set this to YES to disable this behavior and run Neoloader anyways.",
		op_callback = function(val)
			lib.lme_configure("override_disabled_plugin_state", val)
		end,
		"NO",
		"YES",
	}
	
	make_opt {
		filter_value = 2,
		op_cfg_key = "stat_graphing",
		op_key_for_lookup = "stat_graphing",
		op_name = "Enable periodic performance recording",
		op_descrip = "When enabled, a timer will periodically gather performance metrics of the game state. This feature currently stores and logs the metrics gathered. This data is never 'released' and is only visible in the log at this time, but may be accessible via a sub-module in the future.",
		op_callback = function(val)
			lib.lme_configure("stat_graphing", val)
		end,
		"NO",
		"YES",
	}
	
	make_base(iup.frame {
		bgcolor = "0 0 0 0 *",
		segmented = "0 0 1 1",
		iup.vbox {
			iup.label {
				title = lget("setup", "SCREENFINISH", "Options have been configured; thank you for using Neoloader!"),
				wordwrap = "YES",
				size = "%50",
			},
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationbutton {
					title = "Close",
					action = function()
						setup_next()
					end,
				},
			},
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
								title = "Neoloader setup",
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
	
	
	
	ShowDialog(diag)
end


--first-time config request
local config_request = function()
	--LME launches, then request is triggered. prevents dialogs being behind game dialogs
	
	delay_timer:SetTimeout(10, setup_handler)
	
	
	setup_handler()
	
end

if not lme_flag then
	if launch_mode_cfg == "removed" then
		print("Neoloader was uninstalled recently; execution has been aborted. To rerun setup, use the /neo command; otherwise, remove this plugin at your earliest convenience.")
		
		RegisterUserCommand("neo", function()
			console_print("Neoloader re-enabling after being 'removed'")
			gkini.WriteString("Neoloader", "launch_mode", "cooperative")
			dofile("init.lua")
			
			config_request()
		end)
		
		return
	elseif launch_mode_cfg == "cooperative-first-run" then
		console_print("First-time run of Neoloader")
		
		dofile("init.lua")
		
		config_request()
		
	elseif launch_mode_cfg == "independent" then
		--find out if we need to force Neoloader to run via interface reroute
		--todo: ask player how to reroute, don't assume
		if gkini.ReadString("Vendetta", "if", "") == "" then
			gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
		end
	else
		if not (launch_mode_cfg == "cooperative") then
			console_print("unknown operating mode, defaulting to cooperative")
		end
	
		console_print("Starting Neoloader in cooperative mode!")
		dofile("init.lua")
	end
end