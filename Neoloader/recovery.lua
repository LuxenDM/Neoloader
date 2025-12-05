--[[
[metadata]
description=This is Neoloader's recovery environment.
version=3.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-26
]]--

local file_args = {...}

local local_path        = file_args[1]
local auth_key          = file_args[2]

local rs = {}

local cp = console_print --aliased for user, in case they need it later

rs.ready = true  -- set false if the recovery UI itself catastrophically fails

rs.state = {
	phase = "bootstrap",    -- "bootstrap", "fs_ok", "neo_ok", "lib_ok", "lme_ok", "vo_ok"
	pathlock = false,
	statelock = false,
	exec_mode = file_args[4] or "independent",
	alignment_offset = file_args[3] or 0,

	capabilities = {
		has_fs  = false,     -- initial file set
		has_neo = false,     -- neo table exists
		has_lib = false,     -- LME API exists
		has_lme = false,     -- LIBRARY_MANAGEMENT_ENGINE_COMPLETE
		has_vo  = false,     -- PLUGINS_LOADED
	},
}

rs.errors = {}          -- newest first
local neo    = nil         -- filled by neo_check_success
rs.auth_key = auth_key  -- if we ever need to do LME calls inside recovery

local register_resolution --declared later

-- convenience
local function now_ms()
	local gtime_ms = (gkmisc.GetGameTime() + rs.state.alignment_offset) % 1000
	return gtime_ms
end

local function make_error(message, opts)
    opts = opts or {}
    return {
        raw_message = tostring(message),     -- "KEY|fallback" or plain text
        level       = opts.level or 4,
        critical    = not not opts.critical,
        tag         = opts.tag or "generic",
        context     = opts.context or "",
        added_data  = opts.added_data,
        timestamp   = os.date("%Y-%m-%d %H:%M:%S"),
        ms          = now_ms(),
    }
end



-- called by init.lua after basic file presence check
rs.file_check_success = function(intable)
	rs.state.capabilities.has_fs = true
	rs.state.phase = "fs_ok"
	for k, v in pairs(intable or {}) do
		rs.state[k] = v
	end
end

-- called by init.lua after neo table is created
rs.neo_check_success = function(parent_neo)
	rs.state.capabilities.has_neo = true
	rs.state.phase = "neo_ok"
	neo = parent_neo
end

-- called by init.lua after lib table is populated by API
rs.lib_check_success = function(intable)
	rs.state.capabilities.has_lib = true
	rs.state.phase = "lib_ok"
	for k, v in pairs(intable or {}) do
		rs.state[k] = v
	end
end

--called when init.lua is about to reach final lines of file
rs.lme_check_success = function()
	rs.state.capabilities.has_lme = true
	rs.state.phase = "lme_ok"
end

--called when PLUGINS_LOADED event occurs, Vendetta Online has loaded successfully
rs.vo_check_success = function()
	rs.state.capabilities.has_vo = true
	rs.state.phase = "vo_ok"
end


-- locale lookups with "KEY|fallback" support
local lcache       = {}
local last_locale  = nil
local lang_path    = nil

local read_locale  = gkini.ReadString
local read_string2 = gkini.ReadString2

local function refresh_locale()
	local locale_flag = read_locale("Vendetta", "locale", "en")

	if locale_flag ~= last_locale then
		last_locale = locale_flag
		lcache = {}
		-- assuming lang path pattern: plugins/Neoloader/lang/en/recovery.ini
		lang_path = local_path .. "/lang/" .. locale_flag .. "/recovery.ini"
	end
end

local function split_key_and_fallback(key_or_text)
	-- look for the first '|' as separator
	local sep = key_or_text:find("|", 1, true)
	if not sep then
		-- old behavior: key == fallback
		return key_or_text, key_or_text
	end

	local key      = key_or_text:sub(1, sep - 1)
	local fallback = key_or_text:sub(sep + 1)
	if key == "" then
		-- degenerate case, treat like no key
		return key_or_text, key_or_text
	end
	return key, fallback
end

rs.lget = function(key_or_text)
	refresh_locale()

	-- parse "ERR_KEY|fallback" or plain text
	local key, fallback = split_key_and_fallback(key_or_text)

	-- cache key should be locale + logical key
	local cache_id = last_locale .. "|" .. key
	local cached   = lcache[cache_id]
	if cached ~= nil then
		return cached
	end

	-- ReadString2 will:
	--  1) check lang_path [recovery] key
	--  2) return `fallback` if no match
	local raw = read_string2("recovery", key, fallback, lang_path)

	-- Allow "\n" in INI to mean newline in-game
	-- (fallback from Lua can contain real newlines already)
	raw = raw:gsub("\\n", "\n")

	lcache[cache_id] = raw
	return raw
end



local function format_error_for_display(err)
    -- this handles "KEY|fallback" or plain text
    local base = rs.lget(err.raw_message) or err.raw_message

    local msg = base
    if err.added_data and err.added_data ~= "" then
        msg = msg .. err.added_data
    end

    return string.format("[%s.%03d] %s", err.timestamp, err.ms, msg)
end


rs.push_error = function(message, opts)
	opts = opts or {}

	local err = make_error(message, opts)
	
	if opts.resolution then
		if type(opts.resolution) == "table" then
			-- e.g. { key="RECOV_FIX_FS", title=..., ... }
			local def = opts.resolution
			-- ensure it has a key
			if def.key then
				register_resolution(def)       -- your internal resolution registry helper
				err.resolution_key = def.key
			end
		elseif type(opts.resolution) == "string" then
			err.resolution_key = opts.resolution
		end
	end
	
	table.insert(rs.errors, 1, err)

	-- expose last error in raw form for compatibility
	rs.error = err.raw_message

	-- optional: push to LME log / console, unless explicitly disabled
	if not opts.no_log then
		-- strip translation key for logging
		local key, fallback = split_key_and_fallback(err.raw_message)
		local log_msg = fallback or err.raw_message

		if type(lib) == "table" and type(lib.log_error) == "function" then
			-- use LME logging surface if available
			lib.log_error(log_msg, err.level or 4)
		else
			-- early boot / catastrophic case: fall back to console
			console_print(log_msg)
		end
	end

	-- critical errors enter recovery popup immediately
	if err.critical and rs.ready then
		rs.open("popup")
	end
end


--[[ example
	recovery_system.push_error(
		"RECOV_MISSING_CORE_FILES|Neoloader ran into a critical error and cannot start!\nRequired files for Neoloader's operation were not found.\nFiles missing:",
		{
			critical   = true,
			level      = 4,
			tag        = "fs",
			added_data = "\n\t" .. table.concat(missing, ",\n\t"),
		}
	)
]]--

----------------------------------------------------------------------------------------------
-- Resolution definitions
----------------------------------------------------------------------------------------------

local resolutions = {}

register_resolution = function(def)
	-- def.key must be unique
	resolutions[def.key] = def
end

-- core examples:

register_resolution {
	key         = "reload",
	title       = "Reload game",
	description = "Reload the game interface and plugins. Sometimes a bug could be coincidental and fixed just by reloading the game. This is also the option to select if you modify your game files to fix the bug yourself.",
	kind        = "terminal",   -- must be handled after popup returns in popup mode
	priority 	= 10, --early, but after any 'recommended' actions

	visible_if = function(state)
		return true --state.capabilities.has_fs
	end,

	run = function(state)
		ReloadInterface()
	end,
}

register_resolution {
	key         = "show_console",
	title       = "Show console",
	description = "Open the game console for debugging output.",
	kind        = "immediate", --used directly, doesn't hide dialog
	priority 	= 999,

	visible_if = function(state)
		return true
	end,

	run = function(state)
		gkinterface.GKProcessCommand("consoletoggle")
	end,
}

register_resolution {
	key         = "vo_if",
	title       = "Launch default interface",
	description = "Attempt to launch the default Vendetta interface.",
	kind        = "terminal",
	priority 	= 1000,

	visible_if = function(state)
		-- only makes sense in independent exec, before statelock
		return (state.exec_mode == "independent") and (not state.statelock)
	end,

	run = function(state)
		if (state.exec_mode == "independent") and (not state.statelock) then
			dofile("vo/if.lua")
		end
		if not IsConnected() then
			ProcessEvent("START")
		else
			if PlayerInStation() then
				ProcessEvent("SHOW_STATION")
			else
				ProcessEvent("HUD_SHOW")
			end
		end
	end,
}

register_resolution {
	key         = "quit",
	title       = "Close Vendetta Online",
	description = "Exit the game completely. Recommended if you have used multiple reloads and bugs appear nonsensical.", --clear game memory, reload can leave 'ghost data' behind
	kind        = "terminal",
	priority 	= 10000,

	visible_if = function(state)
		return true
	end,

	run = function(state)
		-- VO's quit call; adapt as appropriate
		--gkinterface.GKProcessCommand("quit")
		Game.Quit()
	end,
}

--[[
	reminder to self: if has_lib is false but has_neo is true, then the error is likely within the API generation! This means there is an error with NEOLOADER! 
]]--



register_resolution {
	key         = "LME_disable_plugins_pre", --before lib table exists
	title       = "Disable all registered LME plugins",
	description = "Disable all plugins so the LME will not load them next session.", --clear game memory, reload can leave 'ghost data' behind
	kind        = "terminal",
	priority 	= 400,

	visible_if = function(state)
		return (not state.capabilities.has_neo)
	end,

	run = function(state)
		--copied directly from v6.3.0 recovery, can be made more efficient probably?
		local counter = 0
		while true do
			counter = counter + 1
			local ini_file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
			if ini_file ~= "" then
				local id = gkini.ReadString2("modreg", "id", "null", ini_file)
				local version = gkini.ReadString2("modreg", "version", "null", ini_file)
				if id ~= "null" then
					cp("disabling LME plugin " .. id .. " v" .. version)
					gkini.WriteString("Neo-pluginstate", id .. "." .. version, "NO")
				end
				
				counter = counter + 1
			else
				break
			end
		end
	end,
}

register_resolution {
	key         = "LME_disable_plugins_post",
	title       = "Disable all registered LME plugins",
	description = "Disable all plugins so the LME will not load them next session.", --clear game memory, reload can leave 'ghost data' behind
	kind        = "terminal",
	priority 	= 400,

	visible_if = function(state)
		return (state.capabilities.has_lib)
	end,

	run = function(state)
		--copied directly from v6.3.0 recovery, can be made more efficient probably?
		local counter = 0
		while true do
			counter = counter + 1
			local ini_file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
			if ini_file ~= "" then
				local id = gkini.ReadString2("modreg", "id", "null", ini_file)
				local version = gkini.ReadString2("modreg", "version", "null", ini_file)
				if id ~= "null" then
					cp("disabling LME plugin " .. id .. " v" .. version)
					gkini.WriteString("Neo-pluginstate", id .. "." .. version, "NO")
				end
				
				counter = counter + 1
			else
				break
			end
		end
	end,
}

register_resolution {
	key 		= "safe_LME_settings_pre",
	title		= "Apply safe LME settings",
	description = "Sets safe LME settings this session (before LME has loaded)",
	kind		= "terminal",
	priority	= 300,
	
	visible_if = function(state)
		return (not state.capabilities.has_neo)
	end,
	
	run = function()
		--set LME settings by writing config directly
		gkini.WriteString("Neoloader", "override_disabled_plugin_state", "NO")
		gkini.WriteString("Neoloader", "allow_bad_api_version", "NO")
		gkini.WriteString("Neoloader", "default_load_state", "NO")
		gkini.WriteString("Neoloader", "do_err_popup", "NO")
		gkini.WriteString("Neoloader", "clear_commands_on_reload", "NO")
		gkini.WriteString("Neoloader", "hide_log_message_level", "0")
		gkini.WriteString("Neoloader", "current_if", "vo-if")
		gkini.WriteString("Neoloader", "current_mgr", "neomgr")
		--ensure enabled state
		gkini.WriteString("Neoloader", "current_notif", "neonotif")
		gkini.WriteString("Neoloader", "launch_mode", "independent")
		--set if launch value
	end,
}

register_resolution {
	key 		= "safe_LME_settings_post",
	title		= "Apply safe LME settings",
	description = "Turns off potentially problematic configuration settings in your LME provider. Some plugins may be disabled as a result.",
	kind		= "terminal",
	priority	= 300,
	
	visible_if = function(state)
		return (state.capabilities.has_lib)
	end,
	
	run = function()
		--set LME settings by writing to config manager
		--lib.lme_configure(op, val, auth_key)
		local au = auth_key --shortcut
		lib.lme_configure("override_disabled_plugin_state", "NO", au)
		lib.lme_configure("allow_bad_api_version", "NO", au)
		lib.lme_configure("default_load_state", "NO", au)
		lib.lme_configure("do_err_popup", "NO", au)
		lib.lme_configure("clear_commands_on_reload", "NO", au)
		lib.lme_configure("hide_log_message_level", "0", au)
		lib.lme_configure("current_if", "vo-if", au)
		lib.lme_configure("current_mgr", "neomgr", au)
		do
			if not lib.is_exist("neomgr") then
				lib.register(local_path .. "modules/neomgr/neomgr.lua")
			end
			lib.set_load(au, "neomgr", "0", "YES")
		end
		lib.lme_configure("current_notif", "neonotif", au)
		do
			if not lib.is_exist("neonotif") then
				lib.register(local_path .. "modules/neonotif/neonotif.lua")
			end
			lib.set_load(au, "neonotif", "0", "YES")
		end
		lib.lme_configure("launch_mode", "independent", au)
		
		--set if launch value
		gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
		
		lib.reload()
	end,
}



----------------------------------------------------------------------------------------------
-- interface
----------------------------------------------------------------------------------------------

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

local create_list_control = function(intable)
	--vscroll of static iup objects
	local imposter = iup.frame { --get size of parent
		expand = "YES",
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

	local content_frame = iup.frame {
		image = "",
		segmented = "0 0 1 1",
		bgcolor = "0 0 0 0 *",
		expand = "NO",
		cx = 0,
		cy = 0,
		content_container,
	}

	local slider
	slider = create_slider_control {
		scroll_event_cb = function()
			content_frame.cy = ((slider:get_pos() * (tonumber(content_container.h) - tonumber(slider.h))) / 100) * -1
			iup.Refresh(content_frame)
		end,
	}
	
	local cbox_area = iup.cbox { content_frame }
	
	local list_control_hbox = iup.hbox {
		cbox_area,
		slider,
	}
	
	local display_frame = iup.frame {
		list_control_hbox,
	}
	
	display_frame.map_cb = function(self)
		local w = imposter.w
		local h = imposter.h
		
		self.size = tostring(w) .. "x" .. tostring(h)
		slider.size = tostring(Font.Default) .. "x" .. tostring(h)
		content_frame.size = tostring(w - Font.Default) .. "x" .. tostring(h)
		
		match_widths(w)
		
		iup.Refresh(self)
		cbox_area.size = self.size
		
		iup.Refresh(self)
		
		iup.Refresh(self)
		
		slider.init_timer()
	end
	
	local root_frame = iup.zbox {
		all = "YES",
		display_frame,
		imposter,
	}
	
	root_frame.map_action = display_frame.map_cb
	
	return root_frame
end


local diag          -- forward-declared
local mt_update     -- updates error multiline
rs.current_mode     = "panel"
rs.current_resolution = nil

local function get_priority(def)
	return tonumber(def.priority) or 100
end

local function build_resolution_tab()
	local notice_preamble = "A catastrophic error occurred. Errors reported to the recovery system are listed below.\nMore details may be available in the game console.\n\n"
	
	if rs.state.has_vo then
		--has_vo is true if the game finished loading (hopefully successfully)
		--todo: have better wording for this
		notice_preamble = "Anything listed below is an error that was caught and logged to the recovery system.\nMore details may be available in the game console or in the LME log view in the Developer Tools tab.\n\n"
	end

	local mtline = iup.multiline {
		expand = "HORIZONTAL",
		readonly = "YES",
		size = "%70x%10",
		value = notice_preamble,
	}

	mt_update = function()
		local parts = {}
		for _, err in ipairs(rs.errors) do
			table.insert(parts, format_error_for_display(err))
		end
		mtline.value = notice_preamble .. table.concat(parts, "\n")
		mtline.caret = string.len(mtline.value)
	end

	local res_listbox = iup.vbox {
		--adjust this if has_vo is true
		-- "possible actions":?
		iup.label { title = "Try these options to recover:" },
	}

	-- 1) Gather visible resolutions into an array
	local sorted_resolutions = {}
	for key, def in pairs(resolutions) do
		-- use visible_if if present, otherwise always show
		if (not def.visible_if) or def.visible_if(rs.state) then
			table.insert(sorted_resolutions, { key = key, def = def })
		end
	end

	-- 2) Sort by priority, then by key as a stable-ish tie-breaker
	table.sort(sorted_resolutions, function(a, b)
		local pa = get_priority(a.def)
		local pb = get_priority(b.def)
		if pa == pb then
			-- fall back to key name for deterministic ordering
			return a.key < b.key
		end
		return pa < pb  -- lower number = earlier in list
	end)

	-- 3) Build UI in sorted order
	for _, entry in ipairs(sorted_resolutions) do
		local key = entry.key
		local def = entry.def

		local button = iup.button {
			title  = def.title,
			size   = "x" .. tostring(Font.Default),
			expand = "HORIZONTAL",
		}

		button.action = function(self)
			if def.kind == "immediate" then
				def.run(rs.state)
				return
			end

			if rs.current_mode == "popup" then
				rs.current_resolution = def
				iup.GetDialog(self):hide()
			else
				def.run(rs.state)
			end
		end

		local frame = iup.frame {
			iup.vbox {
				iup.hbox {
					iup.vbox {
						iup.label {
							title = "",
							size  = (not gkinterface.IsTouchModeEnabled()) and "32x32" or nil,
							image = local_path .. "assets/notif_placeholder.png",
						},
					},
					iup.vbox {
						button,
						iup.label {
							title    = def.description,
							wordwrap = "YES",
						},
					},
					iup.fill {},
				},
				iup.hbox { iup.fill {} },
			},
		}

		res_listbox:append(frame)
	end

	local res_listframe = iup.frame {
		image     = "",
		segmented = "0 0 1 1",
		bgcolor   = "0 0 0 0 *",
		res_listbox,
	}

	local res_listview = create_list_control { res_listframe }

	local tabwind = iup.vbox {
		mtline,
		iup.hbox {
			iup.fill {},
			iup.button {
				title  = "Refresh",
				action = mt_update,
			},
		},
		iup.fill { size = Font.Default },
		iup.frame {
			image     = "",
			segmented = "0 0 1 1",
			bgcolor   = "0 0 0 0 *",
			res_listview,
		},
		iup.fill { size = Font.Default },
	}

	local map_action = function()
		res_listview:map_action()
	end

	return tabwind, map_action
end




local function create_diag()
	local res_tab, res_map_action = build_resolution_tab()

	local lme_tab = iup.vbox {
		iup.label { title = "LME configuration (to be implemented)" },
		iup.fill {},
	}

	local tabbox = iup.zbox {
		value  = res_tab,
		res_tab,
		lme_tab,
	}

	local tabrow = iup.hbox {
		iup.fill { },
		iup.button {
			title  = "Resolutions",
			action = function()
				tabbox.value = res_tab
			end,
		},
		iup.fill {},
		iup.button {
			title  = "LME configuration",
			visible = rs.state.has_lib and "YES" or "NO",
			active =  rs.state.has_lib and "YES" or "NO",
			action = function()
				tabbox.value = lme_tab
			end,
		},
		iup.fill {},
		iup.button {
			title  = "Developer tools",
			visible = rs.state.has_neo and "YES" or "NO",
			active =  rs.state.has_neo and "YES" or "NO",
			action = function()
				tabbox.value = lme_tab
			end,
		},
		iup.fill { },
	}

	local diag_local = iup.dialog {
		topmost   = "YES",
		fullscreen = "YES",
		bgcolor   = "0 0 0",
		iup.hbox {
			iup.fill { size = "%6" },
			iup.vbox {
				alignment = "ACENTER",
				iup.fill { size = Font.Default },
				iup.label { title = "Neoloader Recovery System" },
				iup.hbox {
					iup.fill { },
					iup.button {
						title = "Close",
						action = function(self)
							iup.GetDialog(self):hide()
						end,
						active = rs.current_mode == "panel" and "YES" or "NO",
						visible = rs.current_mode == "panel" and "YES" or "NO",
					},
				},
				iup.fill { size = Font.Default },
				tabrow,
				tabbox,
				iup.fill { size = Font.Default },
			},
			iup.fill { size = "%6" },
		},
	}

	diag_local:map()
	res_map_action()
	iup.Refresh(diag_local)

	return diag_local
end

local diag = create_diag()

rs.open = function(mode)
	mode = mode or "panel"
	rs.current_mode = mode
	rs.current_resolution = nil

	if not iup.IsValid(diag) then
		diag = create_diag()
	end

	mt_update()

	if mode == "popup" then
		-- interrupting mode: we want popup() semantics
		diag:hide()
		diag:popup(0, 0)  -- execution blocked until dialog is hidden

		-- once we get here, either user closed the popup or clicked a terminal action
		local chosen = rs.current_resolution
		if chosen and chosen.kind == "terminal" then
			chosen.run(rs.state)
		end
	else
		-- user-invoked: just show, do not try to run actions after show
		diag:show()
	end
end

RegisterUserCommand("recovery", rs.open)

return rs