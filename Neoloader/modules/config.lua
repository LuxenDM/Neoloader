--[[
[metadata]
description=This is the configuration manager for Neoloader
version=1.0.14
owner=Neoloader|7.0.0
type=lua
created=2025-10-20
]]--

--[[
these configuration options have been deprecated:

• allow_delayed_load: Now always yes: preparing for VFS-based plugin support, which may be downloaded post-game load. NLMPE v7+ should explicitly make loading these seamless without reload.
• list_presorted: New loading system automagically handles load order regardless of input order, no need to support or handle hardcoded load orders.
• echo_logging: logging will always occur now. No need to induce confusion for logs not being added to the game console by user-facing switch.
• protect_resolve_file: will always be pcalled during load and execution
• format_logged_messages: Always YES to reduce log variance

These configuration options are new or continue to be supported:

• launch_mode: independent launches as self, cooperative launches under default loader
• override_disabled_plugin_state: YES to load Neoloader even if plugins are disabled by the game client. Default to NO.
• allow_bad_api_version: YES to load plugins that don't match the LME API version of Neoloader. *might* cause bugs. This can also be a per-plugin switch, by using load state of "YES -API"
• default_load_state: YES or NO, are plugins allowed to load when they are first registered. defaults to YES (previously no), make sure to import existing config on user choice
• do_err_popup: Defaults to NO, show error popups when caught. These are normally routed to the log, but can be shown anyways for modders. Can use option INTERRUPT to use interrupting popup behavior.
• clear_commands_on_reload: legacy behavior, not recommended but still available
• hide_log_message_level: default 1, hides debug messages. can increase to hide more. only affects visibility in-game, all messages passed to console.

current_if: current interface manager (ID, version always assumed latest)
current_mgr: current LME manager (ID, version always assumed latest)
current_notif: current LME notification handler (ID, version always assumed latest)
]]--

local neo = ...
local config = neo.config
neo.api.config = {}

local api = neo.api.config

api.validity_override = false --if true, allow invalid options to be written; used by recovery system and uninstaller

local config_definitions = {
	override_disabled_plugin_state = { --if plugins are disabled, Neoloader self-quits. this overrides that behavior, allowing Neoloader and any LME mods to run
		valid = { --list of valid inputs (nil for 'any input'
			YES = true,
			NO = true,
		},
		default = "NO", --when set to default, what to write.
		preferred = "NO", --recommended options may be less 'safe' than default
		legacy = { --previous IDs for this configuration, provided for legacy support
			"override_disabled_plugin_state",
			"rOverrideDisabledState",
			"ignoreOverrideState",
		},
	},
	allow_bad_api_version = { --If a mod is designed for a future or previous version of the LME, it will be skipped. This overrides that behavior
		valid = {
			YES = true,
			NO = true,
		},
		default = "NO",
		recommended = "NO",
		legacy = {
			"allow_bad_api_version",
			"rAllowBadAPIVersion",
			"allowBadAPIVersion",
		},
	},
	default_load_state = { --mods typically run when installed on game load. this can change that behavior, in case mods are being made available over the network with a VFS, when the user wants to download but not run mods (to inspect, for instance)
		need_auth = true, --require authorization key to change
		valid = {
			YES = true,
			NO = true,
			FORCE = true,
			AUTH = true,
		},
		default = "YES",
		recommended = "YES",
		legacy = {
			"default_load_state",
			"rDefaultLoadState",
			"defaultLoadState",
		},
	},
	do_err_popup = { --when errors occur in LME plugins, Neoloader will attempt to catch and hide these errors. This is useful during game launch, where errors normally CTD the game. If developing plugins, making these visible may want wanted. Can only affect errors Neoloader would catch, cannot affect runtime errors in plugins directly.
		valid = {
			YES = true, --shows errors using standard method
			NO = true, --logs and hides errors that are caught
			INTERRUPT = true, --shows error handler with a popup dialog that stops game execution while visible
		},
		default = "NO",
		recommended = "NO",
		legacy = {
			"do_err_popup",
			"rDoErrPopup",
			"doErrPopup",
		},
	},
	clear_commands_on_reload = { --legacy option to clear game commands. A bug in command release caused ghost plugin execution. This has been fixed since, but the option remains available.
		valid = {
			YES = true,
			NO = true, --recommended unless you know what you're doing
		},
		default = "NO",
		recommended = "NO",
		legacy = {
			"clear_commands_on_reload",
			"rClearCommands",
			"clearCommands",
		},
	},
	hide_log_message_level = { --hides in-game log visibility for alert levels below the set amount. mod devs should use '0'. Doesn't affect errors.log output.
		valid = {
			['0'] = true,
			['1'] = true,
			['2'] = true,
			['3'] = true,
			['4'] = true,
		},
		default = "0", --"2",
		recommended = "0",
		legacy = {
			"hide_log_message_level",
			"iDbgIgnoreLevel",
			"dbgIgnoreLevel",
		},
	},
	--[[
	external_plugin_list = { --if it exists, appends all plugins in list to registry during pre-load locate. Used for external mod management utilities. Not yet implemented.
		need_auth = "YES",
		valid = nil,
		default = "",
		legacy = {},
	},
	]]--
	current_if = { --tells Neoloader what interface to launch and authenticate. the interface is always launched first. If empty or interface isn't present or errors, launches default interface directly.
		need_auth = "YES",
		valid = nil,
		default = "Vendetta Online Standard Interface",
		legacy = {},
	},
	current_mgr = { --tells Neoloader what LME control interface to authenticate. failback to neomgr. failback again, to just using recovery interface
		need_auth = "YES",
		valid = nil,
		default = "neomgr",
		legacy = {},
	},
	current_notif = { --tells Neoloader where to send LME system notifications to. if empty, LME notifications cannot be viewed (but still exist)
		need_auth = "YES",
		valid = nil,
		default = "neonotif",
		legacy = {},
	},
	launch_mode = { --Tells Neoloader when to run. When set to independent, will override interface behavior and run as its own launcher. When cooperative, will launch underneath the standard plugin loader.
		valid = {
			independent = true,
			cooperative = true,
			removed = false, --force-set when uninstalled
		},
		default = "cooperative",
		recommended = "independent",
		legacy = {
			"launch_mode",
		},
	},
	stat_graphing = { --If enabled, Neoloader will checkpoint periodically to mark time, memory, and network usage
		valid = {
			YES = true,
			NO = true,
		},
		default = "NO",
		recommended = "YES",
		legacy = {
			"stat_graphing",
		},
	},
	
	--These are deprecated, and provided only for compatibility reasons
	allowDelayedLoad = { --always enabled now
		valid = {
			deprecated = true,
		},
		default = "deprecated",
		legacy = {
			"allowDelayedLoad",
		},
	},
	echoLogging = { --always enabled now
		valid = {
			deprecated = true,
		},
		default = "deprecated",
		legacy = {
			"echoLogging",
		},
	},
	protectResolveFile = { --always enabled now
		valid = {
			deprecated = true,
		},
		default = "deprecated",
		legacy = {
			"protectResolveFile",
		},
	},
	dbgFormatting = { --always enabled now
		valid = {
			deprecated = true,
		},
		default = "deprecated",
		legacy = {
			"dbgFormatting",
		},
	},
}

local legacy_alias = {} --reverse-mapped legacy keys to modern key equivilants

for canonical, def in pairs(config_definitions) do
	if def.legacy then
		for i = 1, #def.legacy do
			local legacy_key = def.legacy[i]
			-- only map if not already mapped; avoids surprises
			if legacy_alias[legacy_key] == nil then
				legacy_alias[legacy_key] = canonical
			end
		end
	end
end


api.is_valid = function(setting, new_value)
	local definition = config_definitions[setting]
	if not definition then
		return false, "invalid setting key"
	end
	
	if (neo.api.validity_override) or (not definition.valid) then
		return true, "all values valid"
	end
	
	local is_valid = definition.valid[new_value]
	
	if (not is_valid) then
		return false, "invalid value"
	else
		return true, "valid value"
	end
end

api.set_config = function(auth, setting, new_value)
	-- remap legacy key to canonical
	local canonical = setting
	if not config_definitions[canonical] and legacy_alias[setting] then
		canonical = legacy_alias[setting]

		console_print(
		  "[Neoloader] config: legacy key '" .. tostring(setting) ..
		  "' used in set_config, mapping to '" .. canonical .. "'"
		)
	end

	if (not config_definitions[canonical]) then
		return false, "invalid setting key"
	end

	local valid_status, valid_message = api.is_valid(canonical, new_value)
	if not valid_status then
		return false, valid_message
	end

	if config_definitions[canonical].need_auth == "YES" then
		if not neo.api.check_auth(auth) then
			return false, "bad auth"
		end
	end

	config[canonical] = new_value
	gkini.WriteString("Neoloader", canonical, new_value)
	return true, "ok"
end


api.get_config = function(setting)
	-- exact modern key
	if config[setting] ~= nil then
		return config[setting]
	end

	-- legacy alias?
	local canonical = legacy_alias[setting]
	if canonical then
		lib.log_error (
			"[Neoloader] config: legacy key '" .. tostring(setting) ..
			"' used, mapping to '" .. canonical .. "'",
			1
		)
		
		return config[canonical]
	end

	return nil
end


api.get_all_keys = function()
	local cfg_list = {}
	for key, _ in pairs(config_definitions) do
		table.insert(cfg_list, key)
	end
	return cfg_list
end

local setup_config_once_flag = false
api.setup_config = function()
	if setup_config_once_flag then
		return
	end
	setup_config_once_flag = true

	for setting, def in pairs(config_definitions) do
		local new_value = ""
		-- try legacy keys in order
		if def.legacy and #def.legacy > 0 then
			for i=1, #def.legacy do
				new_value = gkini.ReadString("Neoloader", def.legacy[i], "")
				if new_value ~= "" then break end
			end
		end
		-- fallback to current key if legacy not found
		if new_value == "" then
			new_value = gkini.ReadString("Neoloader", setting, "")
		end
		if new_value == "" then
			new_value = def.default
		end
		config[setting] = new_value
		gkini.WriteString("Neoloader", setting, new_value)
	end
end

api.setup_config()

api.set_defaults = function()
	--todo, used for recovery interface
end

local config_reset_handler = function()
	for k, v in pairs(config) do
		gkini.WriteString("Neoloader", k, v)
	end
	
	gkinterface.GKSaveCfg()
end

RegisterEvent(config_reset_handler, "UNLOAD_INTERFACE")
RegisterEvent(config_reset_handler, "QUIT")