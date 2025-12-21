--[[
[metadata]
description=This is Neoloader's recovery environment.
version=4.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-12-19
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

local lget = rs.lget



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
		Game.Quit()
	end,
}

--[[
	reminder to self: if has_lib is false but has_neo is true, then the error is likely within the API generation! This means there is an error with NEOLOADER! 
]]--

register_resolution {
	key         = "LME_open_config",
	title       = "Open LME management interface",
	description = "If your LME loaded successfully, you may be able to manage plugins and settings directly. Recovery will remain open in the background.",
	kind        = "immediate",
	priority    = 250,  -- after safe settings, before nuclear stuff

	visible_if = function(state)
		-- Only makes sense if the LME completed successfully and lib table exists
		return state.capabilities.has_lme and state.capabilities.has_lib
	end,
	
	run = function(state)
		lib.open_config()
	end,
}



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

register_resolution {
	key 		= "disable_all_plugins",
	title		= "Disable all plugins",
	description = "Turns off the game's ability to load plugins and closes the game. When the game is next launched, no plugins will be able to run. To allow plugins to run again, you'll need to re-enable them from your options menu.",
	kind		= "terminal",
	priority 	= 800,
	
	visible_if = function(state)
		return (true)
	end,
	
	run = function(state)
		gkini.WriteString("Vendetta", "plugins", "0") --prevent plugins from running
		gkini.WriteString("Vendetta", "if", "") --clear custom interface option
		
		if state.capabilities.has_lib then
			--lib available, use config manager
			lib.lme_configure("override_disabled_plugin_state", "NO", auth_key)
		else
			--no lib available, set config directly
			gkini.WriteString("Neoloader", "override_disabled_plugin_state", "NO")
		end
		
		Game.Quit()
	end,
}


register_resolution {
	key 		= "uninstall_lme",
	title		= "Uninstall Neoloader",
	description = "If your LME environment is misbehaving, this option will remove the settings and prevent Neoloader from executing until installed again. You should also use this option if you want to upgrade Neoloader and the standard uninstaller doesn't work.",
	kind		= "terminal",
	priority 	= 950,
	
	visible_if = function(state)
		return (true)
	end,
	
	run = function(state)
		
		if state.capabilities.has_lib then
			--lib available, use config manager
			neo.api.validity_override = true
			local au = auth_key --shortcut
			lib.lme_configure("override_disabled_plugin_state", "", au)
			lib.lme_configure("allow_bad_api_version", "", au)
			lib.lme_configure("default_load_state", "", au)
			lib.lme_configure("do_err_popup", "", au)
			lib.lme_configure("clear_commands_on_reload", "", au)
			lib.lme_configure("hide_log_message_level", "", au)
			lib.lme_configure("current_if", "", au)
			lib.lme_configure("current_mgr", "", au)
		else
			--no lib available, set config directly
			gkini.WriteString("Neoloader", "override_disabled_plugin_state", "")
			gkini.WriteString("Neoloader", "override_disabled_plugin_state", "")
			gkini.WriteString("Neoloader", "allow_bad_api_version", "")
			gkini.WriteString("Neoloader", "default_load_state", "")
			gkini.WriteString("Neoloader", "do_err_popup", "")
			gkini.WriteString("Neoloader", "clear_commands_on_reload", "")
			gkini.WriteString("Neoloader", "hide_log_message_level", "")
			gkini.WriteString("Neoloader", "current_if", "")
			gkini.WriteString("Neoloader", "current_mgr", "")
			--ensure enabled state
			gkini.WriteString("Neoloader", "current_notif", "")
			gkini.WriteString("Neoloader", "launch_mode", "")
		end
		
		Game.Quit()
	end,
}

register_resolution {
	key 		= "nuke_settings",
	title		= "Nuclear reset",
	description = "Removes as much LME data as possible from your config.ini, disables all plugins, and resets certain game options to known safe settings. If this doesn't fix your game, then you need help that an automated system cannot provide.",
	kind		= "terminal",
	priority 	= 1000,
	
	visible_if = function(state)
		return (true)
	end,
	
	run = function(state)
		gkini.WriteString("Vendetta", "plugins", "0") --prevent plugins from running
		
		if state.capabilities.has_lib then
			--lib available, use config manager
			neo.api.validity_override = true
			local au = auth_key --shortcut
			lib.lme_configure("override_disabled_plugin_state", "", au)
			lib.lme_configure("allow_bad_api_version", "", au)
			lib.lme_configure("default_load_state", "", au)
			lib.lme_configure("do_err_popup", "", au)
			lib.lme_configure("clear_commands_on_reload", "", au)
			lib.lme_configure("hide_log_message_level", "", au)
			lib.lme_configure("current_if", "", au)
			lib.lme_configure("current_mgr", "", au)
		else
			--no lib available, set config directly
			gkini.WriteString("Neoloader", "override_disabled_plugin_state", "")
			gkini.WriteString("Neoloader", "override_disabled_plugin_state", "")
			gkini.WriteString("Neoloader", "allow_bad_api_version", "")
			gkini.WriteString("Neoloader", "default_load_state", "")
			gkini.WriteString("Neoloader", "do_err_popup", "")
			gkini.WriteString("Neoloader", "clear_commands_on_reload", "")
			gkini.WriteString("Neoloader", "hide_log_message_level", "")
			gkini.WriteString("Neoloader", "current_if", "")
			gkini.WriteString("Neoloader", "current_mgr", "")
			--ensure enabled state
			gkini.WriteString("Neoloader", "current_notif", "")
			gkini.WriteString("Neoloader", "launch_mode", "")
		end
		
		for _, setting in ipairs {
			"if", "skin", "usenewui", "usefontscaling",
			"fontscale", "AudioDriver", "VideoDriver",
			"xres", "yres", "font", "enablevoicechat", "enabledeviceselection",
			"playbackmode", "playbackdevice", "capturemode", "capturedevice",
		} do
			gkini.WriteString("Vendetta", v, "")
		end
		
		local rem_counter = 0
		while true do
			rem_counter = rem_counter + 1
			local line_opt = gkini.ReadString("Neo-registry", "reg" .. tostring(rem_counter), "")
			if line_opt == "" then
				break
			end
			
			gkini.WriteString("Neo-registry", "reg" .. tostring(rem_counter), "")
		end
		
		gkini.WriteString("Neoloader", "STOP", "uninstalled|nuke_settings")
		
		Game.Quit()
	end,
}




----------------------------------------------------------------------------------------------
-- interface
----------------------------------------------------------------------------------------------

Font = {
	Default = (gkinterface.GetYResolution()/1080) * 24,
}
local height_scale = gkinterface.IsTouchModeEnabled() and (Font.Default * 2) or Font.Default

local diag				--forward-declared dialog root
local mt_update			--forward-declared, call to update log display in header
local rs_update			--forward-declared, call to update resolution list
rs.current_mode			= "panel"
rs.current_resolution	= nil

local build_log_display = function()
	--placed above tab system
	
	local notice_preamble = lget("RECOV_PREAMBLE|Errors captured by recovery:\n\n")
	
	local mtline = iup.multiline {
		expand = "HORIZONTAL",
		readonly = "YES",
		size = "%50x%10",
		value = "",
	}
	
	mt_update = function()
		local parts = {}
		for _, err in ipairs(rs.errors) do
			table.insert(parts, format_error_for_display(err))
		end
		mtline.value = notice_preamble .. table.concat(parts, "\n")
		mtline.caret = string.len(mtline.value)
	end
	
	local qr_code = iup.label {
		--qr code links to discord.
		title = "",
		image = local_path .. "assets/notif_placeholder.png",
		size = "256x256", --placeholder, press to expand or access later?
	}
	
	local report_builder = iup.button {
		title = "Create report",
		action = function()
			--[[
				send dedicated log to errors.log
					list of LME plugins and their states
					list of LME config values
					latest captured log messages
				take screenshot of log on screen via dump
				attempt TCPsocket connection to send log. possible to send image maybe?
			]]--
		end,
	}
	
	local close_btn = iup.button {
		title = "Close",
		action = function(self)
			HideDialog(iup.GetDialog(self))
		end,
	}
	
	local header_pane = iup.vbox {
		iup.fill {
			size = "8",
		},
		iup.hbox {
			iup.label {
				title = lget("RECOV_TITLE|Neoloader error recovery environment"),
			},
			iup.fill { },
			close_btn,
		},
		iup.fill {
			size = "8",
		},
		iup.hbox {
			iup.vbox {
				qr_code,
				report_builder,
			},
			mtline,
		},
	}
	
	return header_pane
end

local build_resolution_tab = function()
	
	local list_contents = {}
	local entry_index = -1
	
	local rebuild_contents = function()
		-- wipe prior
		for i = #list_contents, 1, -1 do
			list_contents[i] = nil
		end

		-- collect visible resolutions
		local tmp = {}
		for _, def in pairs(resolutions) do
			local ok = true
			if type(def.visible_if) == "function" then
				ok = def.visible_if(rs.state) == true
			end
			if ok then
				table.insert(tmp, def)
			end
		end

		table.sort(tmp, function(a, b)
			local pa = tonumber(a.priority or 0) or 0
			local pb = tonumber(b.priority or 0) or 0
			if pa ~= pb then
				return pa < pb
			end
			
			return tostring(a.title or a.key) < tostring(b.title or b.key)
		end)

		-- copy into list_contents (1..n)
		for i = 1, #tmp do
			list_contents[i] = tmp[i]
		end
	end
	
	local entry_descrip = iup.label {
		title = "",
		size = "%30x%30",
		expand = "YES",
		wordwrap = "YES",
	}
	
	local entry_action = iup.button {
		title = "",
		size = "x" .. tostring(height_scale),
		expand = "HORIZONTAL",
		action = function(self)
			local def = list_contents[entry_index]
			if not def then return end

			rs.current_resolution = def

			if def.kind == "immediate" then
				local ok, err = pcall(def.run, rs.state)
				if not ok then
					rs.push_error("RECOV_RUN_FAIL|Resolution failed: " .. tostring(err), { level = 3 })
				end
				mt_update()
				rs_update()
				return
			end

			-- terminal
			if rs.current_mode == "popup" then
				-- let rs.open() run it after popup returns
				HideDialog(iup.GetDialog(self))
				return
			end

			-- panel mode: run directly
			local ok, err = pcall(def.run, rs.state)
			if not ok then
				rs.push_error("RECOV_RUN_FAIL|Resolution failed: " .. tostring(err), { level = 3 })
			end
			mt_update()
			rs_update()
		end,
	}
	
	local resolution_selector = iup.list {
		--todo: generic iup.list has bgcolor rendering issues, figure out how to fix this later
		expand = "YES",
		action = function(self, t, i, cv)
			if cv == 1 then
				entry_index = i
				entry_descrip.title = list_contents[i].description
			end
			
			if cv ~= 1 then return end
			local def = list_contents[i]
			if not def then return end
			
			entry_index = i
			entry_descrip.title = lget(def.description or "")
			entry_action.title = lget("RECOV_RUN|Run this action")
			entry_action.active = "YES"
		end,
		font = height_scale,
		value = "1",
		update_list = function(self)
			for i=#list_contents, 1, -1 do
				self[i] = nil
				list_contents[i] = nil
			end
			
			rebuild_contents() --rebuilds list_contents with active resolutions
			
			for i, v in ipairs(list_contents) do
				entry_index = -1
				self[i] = v.title
				self.value = "1"
				entry_descrip.title = ""
			end
		end,
	}
	
	rs_update = function() resolution_selector:update_list() end
	
	local content_pane = iup.frame {
		iup.hbox {
			resolution_selector,
			iup.vbox {
				entry_descrip,
				entry_action,
			},
		},
	}
	
	return content_pane
end

local oplist = function(intable)
	local default
	default = {
		header = "Neoloader",
		key = "INVALID",
		value = 1, --current setting
		default = 1, --recommended setting
		[1] = "INVALID", --setting value
		action = function(new_value)
			gkini.WriteString(default.header, default.key, new_value)
		end,
	}

	for i, v in ipairs(intable) do
		default[i] = v
	end

	local option_list = iup.list {
		dropdown = "YES",
		action = function(self, t, i, cv)
			if cv ~= 1 then
				return
			end
			default.action(t)
		end,
		value = default.default,
		set_to_default = function(self)
			self.value = default.default
		end,
		set_to_current = function(self)
			self.value = default.value
		end,
	}
	for i, v in ipairs(default) do
		option_list[i] = v
	end

	local op_frame = iup.hbox {
		iup.label {
			title = default.key,
		},
		iup.fill { },
		option_list,
	}

	return op_frame
end

local build_pre_LME_options = function()
	local config_options = {
		oplist {
			key = "launch_mode",
			default = 1,
			value = gkini.ReadString("Neoloader", "launch_mode", "independent") == "independent" and 1 or 2,
			"independent",
			"cooperative",
			action = function(new_value)
				if new_value == "independent" then
					gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
				else
					gkini.WriteString("Vendetta", "if", "")
				end
				gkini.WriteString("Neoloader", "launch_mode", new_value)
			end,
		},
		oplist {
			key = "allow_bad_api_version",
			default = 2,
			value = gkini.ReadString("Neoloader", "allow_bad_api_version", "NO") == "YES" and 1 or 2,
			"YES",
			"NO",
		},
		oplist {
			key = "default_load_state",
			default = 1,
			value = gkini.ReadString("Neoloader", "default_load_state", "YES") == "YES" and 1 or 2,
			"YES",
			"NO",
		},
		iup.fill { size = "%2", },
	}

	local counter = 0
	while true do
		counter = counter + 1
		local reg_file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
		if reg_file == "" then
			break
		end

		local id = gkini.ReadString2("modreg", "id", "null")
		local ver = gkini.ReadString2("modreg", "version", "null")
		local name = gkini.ReadString2("modreg", "name", "null")
		local idver_key = id .. "." .. ver
		local current = gkini.ReadString("Neo-loadstate", idver_key, "NO")

		local option_list = oplist {
			header = "Neo-loadstate",
			key = idver_key,
			default = 2,
			value = current == "YES" and 1 or 2,
			"YES",
			"NO",
		}

		local op_frame = iup.hbox {
			iup.label {
				title = name .. " v" .. ver,
			},
			iup.fill { },
			option_list,
		}

		table.insert(config_options, op_frame)
	end

	--todo: create scrolling frame here
	
end

local create_diag = function()
	local header = build_log_display()
	
	local res_tab = build_resolution_tab()
	
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
			visible = rs.state.capabilities.has_lib and "YES" or "NO",
			active  = rs.state.capabilities.has_lib and "YES" or "NO",
			action = function()
				tabbox.value = lme_tab
			end,
		},
		iup.fill {},
		iup.button {
			title  = "Developer tools",
			visible = rs.state.capabilities.has_neo and "YES" or "NO",
			active  = rs.state.capabilities.has_neo and "YES" or "NO",
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
				header,
				iup.fill { size = Font.Default },
				tabrow,
				tabbox,
				iup.fill { size = Font.Default },
			},
			iup.fill { size = "%6" },
		},
	}

	diag_local:map()
	
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
	rs_update()

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
