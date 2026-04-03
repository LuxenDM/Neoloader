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

local ui_post_update = {}
local refresh_ui_state = function()
	for _, ihandle in pairs(ui_post_update) do
		if ihandle.do_update then
			ihandle:do_update()
		end
	end
end

rs.errors = {}          -- newest first
local neo    = nil         -- filled by neo_check_success
rs.auth_key = auth_key  -- if we ever need to do LME calls inside recovery

local register_resolution --declared later

-- convenience
local now_ms = function()
	local gtime_ms = (gkmisc.GetGameTime() + rs.state.alignment_offset) % 1000
	return gtime_ms
end

local make_error = function(message, opts)
    opts = opts or {}
    return {
        raw_message = tostring(message),     -- "KEY|fallback" or plain text
        level       = opts.level or 4,
        critical    = opts.critical,
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
	if refresh_ui_state then
		refresh_ui_state()
	end
end

-- called by init.lua after neo table is created
rs.neo_check_success = function(parent_neo)
	rs.state.capabilities.has_neo = true
	rs.state.phase = "neo_ok"
	neo = parent_neo
	if refresh_ui_state then
		refresh_ui_state()
	end
end

-- called by init.lua after lib table is populated by API
rs.lib_check_success = function(intable)
	rs.state.capabilities.has_lib = true
	rs.state.phase = "lib_ok"
	for k, v in pairs(intable or {}) do
		rs.state[k] = v
	end
	if refresh_ui_state then
		refresh_ui_state()
	end
end

local call_close_diag
--called when init.lua is about to reach final lines of file
rs.lme_check_success = function()
	rs.state.capabilities.has_lme = true
	rs.state.phase = "lme_ok"
	
	if call_close_diag then
		call_close_diag()
	end
	if refresh_ui_state then
		refresh_ui_state()
	end
end

--called when PLUGINS_LOADED event occurs, Vendetta Online has loaded successfully
rs.vo_check_success = function()
	rs.state.capabilities.has_vo = true
	rs.state.phase = "vo_ok"
	if refresh_ui_state then
		refresh_ui_state()
	end
end

local recovery_can_close = function()
	local c = rs.state.capabilities
	return c.has_fs and c.has_neo and c.has_lib and c.has_lme and c.has_vo
end

local recovery_can_open_lme = function()
	local c = rs.state.capabilities
	return c.has_lme and c.has_lib
end


-- locale lookups with "KEY|fallback" support
local lcache       = {}
local last_locale  = nil
local lang_path    = nil

local read_locale  = gkini.ReadString
local read_string2 = gkini.ReadString2

local refresh_locale = function()
	local locale_flag = read_locale("Vendetta", "locale", "en")

	if locale_flag ~= last_locale then
		last_locale = locale_flag
		lcache = {}
		-- assuming lang path pattern: plugins/Neoloader/lang/en/recovery.ini
		lang_path = local_path .. "/lang/" .. locale_flag .. "/recovery.ini"
	end
end

local split_key_and_fallback = function(key_or_text)
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



local format_error_for_display = function(err)
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
			lib.lme_configure("current_notif", "", au)
			lib.lme_configure("stat_graphing", "", au)
			lib.lme_configure("launch_mode", "removed", au)
			
			local plist = lib.get_gstate().pluginlist
			for _, idvpairs in ipairs(plist) do
					lib.log_error("de-registering LME plugin " .. idvpairs[1] .. " v" .. idvpairs[2])
				lib.set_load(au, idvpairs[1], idvpairs[2], "REM")
			end
			
			local counter = 0
			while true do
				counter = counter + 1
				
				local reg_entry = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
				if reg_entry == "" then
					break
				end
				
				gkini.WriteString("Neo-registry", "reg" .. tostring(counter), "")
			end
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
			gkini.WriteString("Neoloader", "current_notif", "")
			gkini.WriteString("Neoloader", "stat_graphing", "")
			gkini.WriteString("Neoloader", "launch_mode", "removed")
			
			local counter = 0
			while true do
				counter = counter + 1
				local reg_entry = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
				if reg_entry == "" then
					break
				end
				
				local id = gkini.ReadString2("modreg", "id", "null", ini_file)
				local version = gkini.ReadString2("modreg", "version", "null", ini_file)
				
				if id ~= "null" then
					lib.log_error("de-registering LME plugin " .. id .. " v" .. version)
					gkini.WriteString("Neo-pluginstate", id .. "." .. version, "REM")
				end
				
				gkini.WriteString("Neo-registry", "reg" .. tostring(counter), "")
			end
		end
		
		gkini.WriteString("Vendetta", "if", "")
		
		gkinterface.GKSaveCfg()
		
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
			gkini.WriteString("Vendetta", setting, "")
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
-- based on Helium v1.1.3

Font = Font or {
	Default = (gkinterface.GetYResolution()/1080) * 24,
}
local height_scale = (gkinterface.IsTouchModeEnabled() and (Font.Default * 2)) or Font.Default

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

local diag				--forward-declared dialog root
local mt_update			--forward-declared, call to update log display in header
local rs_update			--forward-declared, call to update resolution list
rs.current_mode			= "panel"
rs.current_resolution	= nil

local oplist = function(intable)
	local default
	default = {
		header = "Neoloader",
		key = "INVALID",
		hide_key = false,
		value = 1, --current setting
		default = 1, --recommended setting
		[1] = "INVALID", --setting value
		action = function(new_value)
			gkini.WriteString(default.header, default.key, new_value)
		end,
	}

	for i, v in pairs(intable) do
		default[i] = v
	end

	local option_list = iup.list {
		dropdown = "YES",
		action = function(self, t, i, cv)
			if cv ~= 1 then
				return
			end
			default.action((t == lget("BINARY_YES|YES") and "YES") or (t == lget("BINARY_NO|NO") and "NO") or t)
		end,
		value = default.value,
		set_to_default = function(self)
			self.value = default.default
		end,
		set_to_current = function(self)
			self.value = default.value
		end,
	}
	for i, v in ipairs(default) do
		option_list[i] = lget(v)
	end

	local op_frame = iup.hbox {
		iup.label {
			title = (not default.hide_key and lget(default.key) or ""),
		},
		iup.fill { },
		option_list,
	}

	return op_frame
end

local build_plugin_card = function(default)
	local title = default.title or "Unknown plugin"
	local status = default.status or nil
	local option_control = default.option_control

	return iup.frame {
		segmented = "0 0 1 1",
		image = "",
		bgcolor = default.bgcolor or "0 0 0 0 *",
		shrink = "YES",
		expand = "HORIZONTAL",
		iup.vbox {
			margin = tostring(Font.Default / 2) .. "x" .. tostring(Font.Default / 2),
			gap = tostring(math.max(4, Font.Default / 4)),
			
			iup.label {
				title = title,
				expand = "HORIZONTAL",
				wordwrap = "YES",
			},
			
			status and iup.label {
				title = status,
				expand = "HORIZONTAL",
				wordwrap = "YES",
				fgcolor = "200 200 200",
			} or nil,
			
			option_control,
		},
	}
end

local build_home_tab = function(switch_page)
	local home_title = iup.label {
		title = lget("RECOVERY_HOME_TITLE|Neoloader Recovery"),
		expand = "HORIZONTAL",
		wordwrap = "YES",
	}

	local home_body = iup.label {
		title = lget("RECOVERY_HOME_BODY|This is the recovery interface. Unless you manually opened this menu, Neoloader may have run into a catastrophic error while trying to load. Use the pages on the left to inspect logs, change what plugins are loaded, or run recovery actions to try and fix detected problems."),
		expand = "HORIZONTAL",
		wordwrap = "YES",
	}

	local home_warn = iup.label {
		title = lget("RECOVERY_HOME_WARN|Only change what is needed. Some changes may apply immediately, while others may require the next load to fully take effect."),
		expand = "HORIZONTAL",
		wordwrap = "YES",
	}
	
	local open_lme_button = iup.button {
		title = lget("RECOVERY_HOME_OPEN_LME|Open LME manager"),
			size = "%30x",
		visible = recovery_can_open_lme() and "YES" or "NO",
		active = recovery_can_open_lme() and "YES" or "NO",
		action = function()
			if type(lib) == "table" and type(lib.open_config) == "function" then
				lib.open_config()
			end
		end,
		do_update = function(self)
			self.visible = recovery_can_open_lme() and "YES" or "NO"
			self.active = recovery_can_open_lme() and "YES" or "NO"
		end,
	}
	
	local close_recovery_button = iup.button {
		title = lget("RECOVERY_HOME_CLOSE|Close recovery"),
			size = "%30x",
		visible = recovery_can_close() and "YES" or "NO",
		active = recovery_can_close() and "YES" or "NO",
		action = function(self)
			iup.GetDialog(self):hide()
		end,
		do_update = function(self)
			self.visible = recovery_can_close() and "YES" or "NO"
			self.active = recovery_can_close() and "YES" or "NO"
		end,
	}
	
	local suggest_action = function()
		local c = rs.state.capabilities

		if not c.has_fs then
			return lget("RECOVERY_SUGGEST_FS_FAILURE|Filesystem check failed. Your LME provider was not installed correctly.")
		elseif not c.has_neo then
			return lget("RECOVERY_SUGGEST_NEO_FAILURE|Neoloader failed early. Check logs for more details. Your LME provider may not have been installed correctly, or needs an update.")
		elseif not c.has_lib then
			return lget("RECOVERY_SUGGEST_LIB_FAILURE|Core API not available. Check logs for more details. Your LME provider may not have been installed correctly, or needs an update.")
		elseif not c.has_lme then
			return lget("RECOVERY_SUGGEST_LME_FAILURE|The LME provider did not finish loading. Try safe LME settings.")
		elseif not c.has_vo then
			return lget("RECOVERY_SUGGEST_VO_FAILURE|The game interface does not appear to have opened. Try to manually launch the game's default interface from the resolutions tab.")
		else
			return lget("RECOVERY_SUGGEST_ALL_SUCCESS|No critical failures detected in your LME provider. If you did not open this interface, a non-LME plugin may have failed or a non-critical issue occured.")
		end
	end
	
	local recommended_action = iup.label {
		title = " ",
		expand = "HORIZONTAL",
		wordwrap = "YES",
		do_update = function(self)
			self.title = suggest_action()
		end,
	}
	
	table.insert(ui_post_update, open_lme_button)
	table.insert(ui_post_update, close_recovery_button)
	table.insert(ui_post_update, recommended_action)

	local shortcut_box = iup.vbox {
		gap = tostring(math.max(6, Font.Default / 3)),

		iup.button {
			title = lget("RECOVERY_HOME_OPEN_PLUGINS|Open plugin controls"),
			size = "%30x",
			action = function()
				switch_page("plugins")
			end,
		},
		iup.button {
			title = lget("RECOVERY_HOME_OPEN_RESOLUTIONS|Open recovery tools"),
			size = "%30x",
			action = function()
				switch_page("resolutions")
			end,
		},
		iup.button {
			title = lget("RECOVERY_HOME_OPEN_LOGS|View logs"),
			size = "%30x",
			action = function()
				switch_page("logs")
			end,
		},

		iup.button {
			title = lget("RECOVERY_HOME_ACCESS_CONSOLE|Open game console"),
			size = "%30x",
			action = function()
				gkinterface.GKProcessCommand("ConsoleToggle")
			end,
		},

		open_lme_button,

		close_recovery_button,
	}

	local content_box = iup.vbox {
		margin = tostring(Font.Default) .. "x" .. tostring(Font.Default),
		gap = tostring(math.max(8, Font.Default / 2)),

		home_title,
		home_body,
		home_warn,
		
		iup.fill { size = "%2", },
		recommended_action,
		iup.fill { size = "%1", },
		shortcut_box,
		iup.fill { size = "%2", },
	}

	local scroll_content = iup.frame {
		bgcolor = "0 0 0 0 *",
		segmented = "0 0 1 1",
		image = "",
		content_box,
	}

	local scroll_pane = create_list_control { scroll_content }

	local root_view = iup.frame {

		post_map_update = function()
			scroll_pane:map_cb()
		end,

		display_trigger = function()
			local pane_w = tonumber(scroll_pane.w) or 0
			if pane_w <= 0 then
				return
			end

			local frame_w = math.max(1, pane_w - Font.Default)
			local inner_w = math.max(1, frame_w - (Font.Default * 2))
			
			local safe_inner = tostring(inner_w) .. "x"
			
			scroll_content.size = tostring(frame_w) .. "x"
			content_box.size = safe_inner

			home_title.size = safe_inner
			home_body.size  = safe_inner
			home_warn.size  = safe_inner
			
			recommended_action.size = safe_inner

			iup.Refresh(scroll_pane)
		end,

		iup.vbox {
			scroll_pane,
		},
	}

	return root_view
end

local build_logs_tab = function()
	local log_pages = {}
	local log_page_index = 1
	local LOG_PAGE_MAX = 8000 -- adjust below actual multiline hard limit
	
	local mtline = iup.multiline {
		readonly = "YES",
		expand = "YES",
		value = "",
	}
	
	local split_log_pages = function(full_text, max_chars)
		local pages = {}
		local current = ""
		
		local function push_current()
			if current ~= "" then
				table.insert(pages, current)
				current = ""
			end
		end
		
		for line in (tostring(full_text or "") .. "\n"):gmatch("(.-)\n") do
			local candidate
			if current == "" then
				candidate = line
			else
				candidate = current .. "\n" .. line
			end
			
			if #candidate > max_chars then
				push_current()
				
				if #line > max_chars then
					local start_i = 1
					while start_i <= #line do
						table.insert(pages, line:sub(start_i, start_i + max_chars - 1))
						start_i = start_i + max_chars
					end
				else
					current = line
				end
			else
				current = candidate
			end
		end
		
		push_current()
		
		if #pages == 0 then
			pages[1] = ""
		end
		
		return pages
	end
	
	local page_label = iup.label {
		title = lget("RECOVERY_LOGS_PAGE|Page") .. " 1 / 1",
	}

	local prev_button = iup.button {
		title = "< " .. lget("RECOVERY_LOGS_PREV|Prev"),
	}

	local next_button = iup.button {
		title = lget("RECOVERY_LOGS_NEXT|Next") .. " >",
	}
	
	local update_log_page_view = function()
		local total = #log_pages
		if total < 1 then total = 1 end
		
		if log_page_index < 1 then log_page_index = 1 end
		if log_page_index > total then log_page_index = total end
		
		mtline.value = log_pages[log_page_index] or ""
		mtline.caret = 1
		page_label.title = lget("RECOVERY_LOGS_PAGE|Page") .. " " .. tostring(log_page_index) .. " / " .. tostring(total)
		
		prev_button.active = (log_page_index > 1) and "YES" or "NO"
		next_button.active = (log_page_index < total) and "YES" or "NO"
		
		iup.Refresh(page_label)
		iup.Refresh(prev_button)
		iup.Refresh(next_button)
		iup.Refresh(mtline)
	end
	
	mt_update = function()
		local parts = {}

		if #rs.errors > 0 then
			table.insert(parts, lget("RECOV_PREAMBLE|Errors captured by recovery") .. ":\n\127FF8888")
			for _, err in ipairs(rs.errors) do
				table.insert(parts, format_error_for_display(err))
			end
		else
			table.insert(parts, lget("RECOVERY_LOGS_PREAMBLE_RLOG_EMPTY|Recovery log is empty."))
		end
		
		if rs.state.capabilities.has_neo and type(neo) == "table" and type(neo.log) == "table" and #neo.log > 0 then
			table.insert(parts, "\127FFFFFF")
			table.insert(parts, "----------------")
			table.insert(parts, lget("RECOVERY_LOGS_LME_LOG|Full Neoloader log") .. ":")
			table.insert(parts, "")
			table.insert(parts, table.concat(neo.log, "\n"))
		end
		
		local full_text = table.concat(parts, "\n")
		log_pages = split_log_pages(full_text, LOG_PAGE_MAX)
		
		if log_page_index > #log_pages then
			log_page_index = #log_pages
		end
		if log_page_index < 1 then
			log_page_index = 1
		end
		
		update_log_page_view()
	end
	
	prev_button.action = function()
		if log_page_index > 1 then
			log_page_index = log_page_index - 1
			update_log_page_view()
		end
	end

	next_button.action = function()
		if log_page_index < #log_pages then
			log_page_index = log_page_index + 1
			update_log_page_view()
		end
	end

	local root_view = iup.frame {
		post_map_update = function()
			mt_update()
		end,
		iup.vbox {
			margin = tostring(Font.Default) .. "x" .. tostring(Font.Default),
			gap = tostring(math.max(8, Font.Default / 2)),
			
			iup.label {
				title = lget("RECOVERY_LOGS_TITLE|Recovery logs"),
				expand = "HORIZONTAL",
				wordwrap = "YES",
			},
			
			iup.label {
				title = lget("RECOVERY_LOGS_DESCRIP|These logs may help identify which plugin or system failed during load."),
				expand = "HORIZONTAL",
				wordwrap = "YES",
			},
			
			mtline,
			
			iup.hbox {
				alignment = "ACENTER",
				prev_button,
				page_label,
				next_button,
			},
			
			iup.button {
				title = lget("RECOVERY_LOGS_REFRESH|Refresh logs"),
				action = function()
					mt_update()
				end,
			},
		},
	}

	root_view.refresh_logs = mt_update
	root_view.mtline = mtline
	return root_view
end

local build_resolution_tab = function()
	local list_contents = {}
	local entry_index = -1

	local entry_title = iup.label {
		title = lget("RECOVERY_RESOLVE_NONE|No recovery option selected."),
		expand = "HORIZONTAL",
		wordwrap = "YES",
	}

	local entry_descrip = iup.label {
		title = " ",
		--expand = "HORIZONTAL",
		wordwrap = "YES",
	}

	local entry_action = iup.button {
		title = lget("RECOVERY_WAITING_FOR_SELECTION|Waiting for selection..."),
		expand = "HORIZONTAL",
		active = "NO",
	}

	local resolution_selector = iup.list {
		dropdown = "NO",
		expand = "HORIZONTAL",
		size = "x" .. tostring(Font.Default * 8),
	}

	local rebuild_contents = function()
		local tmp = {}

		for i = #list_contents, 1, -1 do
			list_contents[i] = nil
		end

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

		for i = 1, #tmp do
			list_contents[i] = tmp[i]
		end
	end

	local set_selected_resolution = function(i)
		local def = list_contents[i]
		entry_index = i

		if not def then
			entry_title.title = lget("RECOVERY_RESOLVE_NONE|No recovery option selected.")
			entry_descrip.title = lget("RECOV_SELECT_NEW_RESOLV|Select a recovery action above.")
			entry_action.title = ""
			entry_action.active = "NO"
			rs.current_resolution = nil
			return
		end

		rs.current_resolution = def
		entry_title.title = lget(def.key .. "_TITLE|" .. (def.title or def.name or ""))
		entry_descrip.title = lget(def.key .. "_DESCRIP|" .. (def.description or def.descrip or ""))
		entry_action.title = lget("RECOV_RUN|Run this action")
		entry_action.active = "YES"
		entry_action.action = function(self)
			if def.kind == "terminal" and rs.current_mode == "popup" then
				HideDialog(iup.GetDialog(self))
				return
			end

			local ok, err = pcall(def.run, rs.state)
			if not ok then
				rs.push_error("RECOV_RUN_FAIL|Resolution failed: " .. tostring(err), { level = 3 })
			end
			mt_update()
			rs_update()
		end
	end

	local refresh_resolutions = function()
		for i = #list_contents, 1, -1 do
			resolution_selector[i] = nil
		end

		rebuild_contents()

		for i, def in ipairs(list_contents) do
			resolution_selector[i] = lget(def.title or def.name or ("Option " .. tostring(i)))
		end

		entry_index = -1
		rs.current_resolution = nil

		entry_title.title = lget("RECOVERY_RESOLVE_NONE|No recovery option selected.")
		entry_descrip.title = lget("RECOV_SELECT_NEW_RESOLV|Select a recovery action above. They are listed in order of severity; it is recommended to attempt them in order if you are unsure how to fix the bug yourself.")
		entry_action.title = ""
		entry_action.active = "NO"

		if #list_contents > 0 then
			resolution_selector.value = "1"
		else
			resolution_selector.value = nil
		end
	end

	local scroll_content = iup.frame {
		segmented = "0 0 1 1",
		image = "",
		bgcolor = "0 0 0 0 *",
		iup.vbox {
			margin = tostring(Font.Default) .. "x" .. tostring(Font.Default),
			gap = tostring(math.max(8, Font.Default / 2)),
			
			resolution_selector,
			entry_action,
			iup.fill {
				size = "%2",
			},
			entry_title,
			entry_descrip,
		},
	}

	local scroll_pane = create_list_control { scroll_content }

	resolution_selector.action = function(self, text, i, state)
		if state == 1 then
			set_selected_resolution(i)
		end
	end
	
	local root_view = iup.frame {
		post_map_update = function()
			scroll_pane:map_cb()
		end,
		display_trigger = function()
			local safe_width = tostring(scroll_pane.w - (Font.Default * 3)) .. "x"
			
			scroll_content.size = safe_width
			resolution_selector.size = safe_width .. tostring(Font.Default * 8)
			entry_action.size = safe_width
			entry_title.size = safe_width
			entry_descrip.size = safe_width
			
			iup.Refresh(scroll_content)
		end,
		iup.vbox {
			scroll_pane,
		},
	}

	rs_update = refresh_resolutions
	root_view.set_selected_resolution = set_selected_resolution

	return root_view
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
			lget("BINARY_YES|YES"),
			lget("BINARY_NO|NO"),
		},
		oplist {
			key = "default_load_state",
			default = 1,
			value = gkini.ReadString("Neoloader", "default_load_state", "YES") == "YES" and 1 or 2,
			lget("BINARY_YES|YES"),
			lget("BINARY_NO|NO"),
		},
	}
	
	local opt_list_text = iup.label {
		title = lget("RECOVERY_CONFIG_MENU_PRE_DESCRIP|Set LME options and load states of registered plugins here. The LME has not yet loaded, so some options may only apply the next time the game runs, or will only partially apply this session."),
		expand = "HORIZONTAL",
		wordwrap = "YES",
	}
	
	local option_list_container = iup.vbox {
		margin = tostring(Font.Default) .. "x" .. tostring(Font.Default),
		gap = tostring(math.max(8, Font.Default / 2)),
		
		opt_list_text,
		
		iup.fill { size = "%1", },
	}
	
	for _, v in ipairs(config_options) do
		option_list_container:append(v)
	end
	
	local counter = 0
	local highlite_bg = false
	while true do
		counter = counter + 1
		highlite_bg = not highlite_bg
		
		local reg_file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
		if reg_file == "" then
			break
		end
		
		local id = gkini.ReadString2("modreg", "id", "null", reg_file)
		local ver = gkini.ReadString2("modreg", "version", "null", reg_file)
		local name = gkini.ReadString2("modreg", "name", "null", reg_file)
		local idver_key = id .. "." .. ver
		local current = gkini.ReadString("Neo-pluginstate", idver_key, "NO")
		
		local option_list = oplist {
			header = "Neo-pluginstate",
			key = idver_key,
			hide_key = true,
			default = 2,
			value = current == "YES" and 1 or 2,
			lget("BINARY_YES|YES"),
			lget("BINARY_NO|NO"),
		}
		
		local card = build_plugin_card {
			title = name .. " v" .. ver,
			status = lget("RECOVERY_PLUGIN_CARD_PRE|Registered plugin load state."),
			option_control = option_list,
			bgcolor = highlite_bg and "255 255 255 30 *" or "0 0 0 0 *",
		}
		
		option_list_container:append(card)
	end
	
	local scroll_content = iup.frame {
		segmented = "0 0 1 1",
		image = "",
		bgcolor = "0 0 0 0 *",
		option_list_container,
	}
	
	local scroll_pane = create_list_control { scroll_content }
	
	local root_view = iup.frame {
		post_map_update = function()
			scroll_pane:map_cb()
		end,
		display_trigger = function()
			local safe_width = tostring(scroll_pane.w - (Font.Default * 3)) .. "x"
			
			scroll_content.size = safe_width
			opt_list_text.size = safe_width
			
			iup.Refresh(scroll_content)
		end,
		iup.vbox {
			scroll_pane,
		},
	}
	
	return root_view
end

local build_post_LME_options = function()
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
				neo.api.config.set_config(auth_key, "launch_mode", new_value)
			end,
		},
		oplist {
			key = "allow_bad_api_version",
			default = 2,
			value = gkini.ReadString("Neoloader", "allow_bad_api_version", "NO") == "YES" and 1 or 2,
			lget("BINARY_YES|YES"),
			lget("BINARY_NO|NO"),
			action = function(new_value)
				neo.api.config.set_config(auth_key, "allow_bad_api_version", new_value)
			end,
		},
		oplist {
			key = "default_load_state",
			default = 1,
			value = gkini.ReadString("Neoloader", "default_load_state", "YES") == "YES" and 1 or 2,
			lget("BINARY_YES|YES"),
			lget("BINARY_NO|NO"),
			action = function(new_value)
				neo.api.config.set_config(auth_key, "default_load_state", new_value)
			end,
		},
	}
	
	local opt_list_text = iup.label {
		title = lget("RECOVERY_CONFIG_MENU_POST_DESCRIP|Set LME options and load states of registered plugins here. The LME has loaded, allowing the direct management of configuration."),
		expand = "HORIZONTAL",
		wordwrap = "YES",
	}
	
	local option_list_container = iup.vbox {
		margin = tostring(Font.Default) .. "x" .. tostring(Font.Default),
		gap = tostring(math.max(8, Font.Default / 2)),
		
		opt_list_text,
		
		iup.fill { size = "%1", },
	}
	
	for _, v in ipairs(config_options) do
		option_list_container:append(v)
	end
	
	local counter = 0
	local highlite_bg = false
	local plugin_list = lib.get_gstate().pluginlist --{{id, ver}, {id, ver}, ...}
	while true do
		counter = counter + 1
		highlite_bg = not highlite_bg
		
		local this_entry = plugin_list[counter]
		if not this_entry then
			break
		end
		local id = this_entry[1]
		local ver = this_entry[2]
		local mod_obj = lib.get_state(id, ver)
		local name = mod_obj.plugin_name
		local idver_key = id .. "." .. ver
		local current = mod_obj.load
		
		local option_list = oplist {
			hide_key = true,
			default = 2,
			value = current == "YES" and 1 or 2,
			lget("BINARY_YES|YES"),
			lget("BINARY_NO|NO"),
			action = function(new_value)
				lib.set_load(auth_key, id, ver, new_value)
			end,
		}
		
		local card = build_plugin_card {
			title = name .. " v" .. ver,
			status = lget("RECOVERY_PLUGIN_CARD_PRE|Registered plugin load state."),
			option_control = option_list,
			bgcolor = highlite_bg and "255 255 255 30 *" or "0 0 0 0 *",
		}
		
		option_list_container:append(card)
	end
	
	local scroll_content = iup.frame {
		segmented = "0 0 1 1",
		image = "",
		bgcolor = "0 0 0 0 *",
		option_list_container,
	}
	
	local scroll_pane = create_list_control { scroll_content }
	
	local root_view = iup.frame {
		post_map_update = function()
			scroll_pane:map_cb()
		end,
		display_trigger = function()
			local safe_width = tostring(scroll_pane.w - (Font.Default * 3)) .. "x"
			
			scroll_content.size = safe_width
			opt_list_text.size = safe_width
			
			iup.Refresh(scroll_content)
		end,
		iup.vbox {
			scroll_pane,
		},
	}
	
	return root_view
end

local create_diag = function()
	local home_tab
	local logs_tab
	local res_tab
	local lme_tab
	local dev_tab
	
	local page_box
	local nav_status
	
	local post_LME_once_flag = false
	
	local switch_page = function(page_name)
		if page_name == "home" then
			page_box.value = home_tab
		elseif page_name == "resolutions" then
			page_box.value = res_tab
		elseif page_name == "plugins" then
			if (rs.state.capabilities.has_lib) and (not post_LME_once_flag) then
				post_LME_once_flag = true
				lme_tab:detach()
				lme_tab = build_post_LME_options()
				page_box:append(lme_tab)
				
				local diag_ref = iup.GetDialog(lme_tab)
				if diag_ref then
					iup.Refresh(diag_ref)
					diag_ref:map()
					iup.Refresh(diag_ref)
				end
				if lme_tab.post_map_update then
					lme_tab:post_map_update()
				end
			end
			page_box.value = lme_tab
		elseif page_name == "logs" then
			if logs_tab.refresh_logs then
				logs_tab:refresh_logs()
			end
			page_box.value = logs_tab
		elseif page_name == "dev" then
			page_box.value = dev_tab
		end
		
		if page_box.value.display_trigger then
			page_box.value.display_trigger()
		end
	end
	
	home_tab = build_home_tab(switch_page)
	logs_tab = build_logs_tab()
	res_tab = build_resolution_tab()
	lme_tab = build_pre_LME_options()
	
	dev_tab = iup.frame {
		segmented = "0 0 1 1",
		image = "",
		bgcolor = "0 0 0 0 *",
		iup.vbox {
			margin = tostring(Font.Default) .. "x" .. tostring(Font.Default),
			iup.label {
				title = lget("RECOVERY_DEV_PLACEHOLDER|Developer tools are not yet implemented."),
				expand = "HORIZONTAL",
				wordwrap = "YES",
			},
		},
	}
	
	page_box = iup.zbox {
		value = home_tab,
		home_tab,
		res_tab,
		lme_tab,
		logs_tab,
		dev_tab,
	}
	
	local dev_tab_button = iup.button {
		title = lget("RECOVERY_NAV_DEV|Developer tools"),
				expand = "HORIZONTAL",
		visible = rs.state.capabilities.has_neo and "YES" or "NO",
		active = rs.state.capabilities.has_neo and "YES" or "NO",
		action = function()
			switch_page("dev")
		end,
		do_update = function(self)
			self.visible = recovery_can_open_lme() and "YES" or "NO"
			self.active = recovery_can_open_lme() and "YES" or "NO"
		end,
	}
	
	table.insert(ui_post_update, dev_tab_button)
	
	local nav_column = iup.frame {
		size = "%7x",
		shrink = "YES",
		iup.vbox {
			margin = tostring(Font.Default / 2) .. "x" .. tostring(Font.Default / 2),
			gap = tostring(math.max(6, Font.Default / 3)),
			
			iup.label {
				title = lget("RECOVERY_NAV_TITLE|Recovery"),
				expand = "HORIZONTAL",
				wordwrap = "YES",
			},
			
			iup.button {
				title = lget("RECOVERY_NAV_HOME|Home"),
				expand = "HORIZONTAL",
				action = function()
					switch_page("home")
				end,
			},
			iup.button {
				title = lget("RECOVERY_NAV_RESOLVE|Resolutions"),
				expand = "HORIZONTAL",
				action = function()
					switch_page("resolutions")
				end,
			},
			iup.button {
				title = lget("RECOVERY_NAV_PLUGINS|Plugins"),
				expand = "HORIZONTAL",
				action = function()
					switch_page("plugins")
				end,
			},
			iup.button {
				title = lget("RECOVERY_NAV_LOGS|Logs"),
				expand = "HORIZONTAL",
				action = function()
					switch_page("logs")
				end,
			},
			dev_tab_button,
			
			iup.fill { },
		},
	}
	
	local diag_local = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.hbox {
			margin = tostring(Font.Default / 2) .. "x" .. tostring(Font.Default / 2),
			gap = tostring(math.max(6, Font.Default / 3)),
			
			nav_column,
			
			iup.vbox {
				page_box,
			},
		},
	}
	
	diag_local:map()
	if lme_tab.post_map_update then
		lme_tab:post_map_update()
		page_box.value.display_trigger()
	end
	
	return diag_local
end

local diag = create_diag()
declare("diagtest", diag)
RegisterUserCommand("dodiag", function()
	diagtest = diag
end)

rs.open = function(mode)
	mode = mode or "panel"
	rs.current_mode = mode
	rs.current_resolution = nil

	if not iup.IsValid(diag) then
		diag = create_diag()
	end

	mt_update()
	rs_update()
	
	if refresh_ui_state then
		refresh_ui_state()
	end

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
		-- or invoked as safety background catch
		diag:show()
	end
end

rs.open()

call_close_diag = function()
	if (diag.visible == "YES") and (#rs.errors < 1) then
		diag:hide()
	end
end

RegisterUserCommand("recovery", function()
	rs.push_error("RECOV_USER_ACCESS_NOTIF|Recovery opened by user", {})
	rs.open()
end)

return rs
