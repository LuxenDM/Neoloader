--[[
[metadata]
description=This is the core of Neoloader.
owner=Neoloader|7.0.0
type=lua
created=2025-7-1
]]--


--this can only trigger in independent mode; if using cooperative (or first-run) mode and plugins are disabled, Neoloader will never run.
if (gkini.ReadString("Neoloader", "override_disabled_state", "NO") == "NO") and (gkini.ReadInt("Vendetta", "plugins", 1) == 0) then
	console_print("Plugins are disabled, and Neoloader is not configured to override this setting! The default interface will load, and Neoloader will exit!")
	dofile("vo/if.lua")
	return
end

console_print("\n\n\nVendetta Online has loaded\nNeoloader is Initializing...")

local alignment_offset = 0
local pathlock = false
local statelock = false

do --Align engine ms remainder to wall-clock second boundary
    local gktime = gkmisc.GetGameTime
    local now_s  = os.time()
    local start_ms = gktime()
    -- spin until os.time() increments; OK during load in your sandbox
    while os.time() == now_s do end
    local tick_ms = gktime()
    -- Estimate how far into the second we were at the tick transition
    -- We want (gktime() + offset) % 1000 to line up with the wall clock's ms at boundary ≈ 000
    alignment_offset = (1000 - ((tick_ms - start_ms) % 1000)) % 1000
    console_print("Aligned ms time value with discovered offset of " .. tostring(alignment_offset) .. "ms")
end

local timestat_start = gkmisc.GetGameTime() + alignment_offset
console_print("\tCheckpoint time value starting at " .. tostring(timestat_start) .. "ms")
local memstat_start = math.ceil(collectgarbage("count"))
console_print("\tCheckpoint memory value starting at " .. tostring(memstat_start) .. " kbytes")
--verify bytes here

local recovery_system = {}
local auth_key = SHA1(tostring(gkmisc.GetGameTime() + math.random()))

local version = {
	strver = "7.0.0 -PBR3",
	[1] = 7,
	[2] = 0,
	[3] = 0,
	[4] = "PBR3",
}
local lme_ver = {
	strver = "3.12.1",
	[1] = 3,
	[2] = 12,
	[3] = 1,
	[4] = "",
}

local local_path = "plugins/Neoloader/"
if not gksys.IsExist(local_path .. "init.lua") then
	local_path = gkini.ReadString("Neoloader", "home_path_override", "plugins/!Neoloader/")
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
end

local reclget = function(key, def) --recovery-mode lget
	local locale = gkini.ReadString("Vendetta", "locale", "en")
	return gkini.ReadString2("recovery", key, def, local_path .. "lang/" .. locale .. "/core.ini")
end

local failsafe_recovery = function(reason)
	local fsr_msg = reclget("RECOVERY_FAILSAFE", "Neoloader ran into a CRITICAL error and will not load! The failsafe system has been triggered; the default interface will now load. Error stated") .. ":\n\n" .. tostring(reason)
	console_print(fsr_msg)
	
	local fsr_diag = iup.dialog {
		fullscreen = "YES",
		topmost = "YES",
		bgcolor = "0 0 0 200 *",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.frame {
					image = "",
					bgcolor = "50 50 50",
					segmented = "0 0 1 1",
					size = "HALFxHALF",
					expand = "NO",
					iup.vbox {
						alignment = "ACENTER",
						iup.fill {size = "%2", },
						iup.multiline {
							size = "%40x%10",
							readonly = "YES",
							value = fsr_msg,
						},
						iup.fill {size = "%2", },
						iup.hbox {
							iup.button {
								title = reclget("RECOVERY_CONFIRM", "Okay"),
								action = function(self)
									iup.GetDialog(self):hide()
									--dofile((pathlock and "../../" or "") .. "vo/if.lua")
									--check fi we need to process event 'start' here or not?
								end,
							},
							---future options?
						},
						iup.fill {size = "%2", },
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	gkini.WriteString("Neoloader", "STOP", reason)
	gkini.WriteString("Vendetta", "if", "")
	--dofile("vo/if.lua")
	fsr_diag:popup(0, 0)
	
	if (not pathlock) and (not statelock) then
		--pathlock true : default loader is running, game already launched interface
		--statelock true: plugins already loaded, we or game must have already launched interface
		--both false: Neoloader is running as an interface, can directly launch VO-IF here
		dofile("vo/if.lua")
	end
	--reminder to self: make sure to return AFTER this function
end

	
if not gksys.IsExist(local_path .. "init.lua") then
	--We have NO idea where this file is executing from, and that is a PROBLEM! launch the default interface and inform the user that Neoloader is being run in a very unusual manner. We cannot launch the recovery interface if we cannot guarantee its location
	
	return failsafe_recovery(reclget("DIR_FIND_FAIL", "local_dir_find_failure: Was unable to determine the home directory using a variety of methods."))
end

console_print("Neoloader has identified its home directory as " .. local_path)

--pathlock defines if file paths are auto-prepended by the game loader
--if path is prepended, escape with ../../
pathlock = false --declared local above
local exec_mode = "independent"
do
	local status, result = pcall(dofile, "init.lua.version")
	if result == 1 then
		pathlock = true
		exec_mode = "cooperative"
		console_print("path lock is engaged; Neoloader appears to be running in 'cooperative mode' with the default loader (or another loading service). Neoloader will not launch the interface or load environmental placeholder values in this mode.")
	else
		local state_status, state_result = pcall(function() neo_this_tests_for_state_lock = false end)
		if not state_status then
			console_print("state lock is engaged, Neoloader must have run after the PLUGINS_LOADED event occured (maybe the user is trying to reinstall after removing Neoloader?)")
			statelock = true
		else
			console_print("path lock and state lock are not engaged; Neoloader appears to be running in 'independent mode'.") --recommended
		end
	end
end

--pathlock will be turned on while game loader is running
--this only fires if Neoloader is set to run independent of the game loader
--prevents plugins from activating to prevent path issues
RegisterEvent(function() 
	if not pathlock then
		pathlock = true
		lib.log_error("path lock is engaged", 1)
		ProcessEvent("NEO_PATHLOCK_ENGAGED")
	end
end, "LIBRARY_MANAGEMENT_ENGINE_COMPLETE")

--pathlock is cleared when the game loader finishes

local once_flag = false
local process_final_task_queue = function()
	-- called in coop mode by PLUGINS_LOADED event, OR
	-- called when late-triggered by setup
	if once_flag then
		return
	end
	once_flag = true
	
	pathlock = false
	statelock = true
	lib.log_error("path lock is cleared; state lock is engaged", 1)
	ProcessEvent("NEO_STATELOCK_ENGAGED")
	ProcessEvent("NEO_PATHLOCK_DISENGAGED")
	lib.check_queue()
	ProcessEvent("LME_PLUGINS_TRIGGER")
		--in coop mode, this starts queue processing
	recovery_system.vo_check_success()
	neo.stats.checkpoint("Default plugin loader has finished loading standard plugins!")
end

RegisterEvent(process_final_task_queue, "PLUGINS_LOADED")

console_print("Launching recovery system handler...")
do
	local rec_path = (pathlock and "../../" or "") .. local_path .. "recovery.lua"
	console_print("Looking in path " .. tostring(rec_path))
	if not gksys.IsExist(local_path .. "recovery.lua") then
		return failsafe_recovery(reclget("RECOVERY_NOT_FOUND", "Recovery system was not found. Expected to find it at should be at ") .. rec_path .. reclget("RECOVERY_NOT_FOUND_PCHECK", " pathlock was ") .. tostring(pathlock))
	end
	local file_f, err = loadfile(rec_path)
	if not file_f then
		return failsafe_recovery(reclget("RECOVERY_LOAD_ERROR", "Failed to load recovery system. Obtained the following error: ") .. tostring(err))
	end
	local status, err = pcall(file_f, local_path, auth_key, alignment_offset, exec_mode)
	if not status then
		return failsafe_recovery(reclget("RECOVERY_EXEC_ERROR", "Failed to start recovery system. Obtained the following error: ") .. tostring(err))
	end
	recovery_system = err
	console_print("\trecovery system online")
end

console_print("Verifying required files...")
do
	local missing = {}
	for index, file in ipairs {
		"init.lua",
		"init.lua.version",
		"recovery.lua",
		"main.lua",
		
		"modules/api.lua",
		"modules/config.lua",
		"modules/env.lua",
		"modules/loader process.lua",
		"modules/locale.lua",
		"modules/registry.lua",
		"modules/setup.lua",
		"modules/stats.lua",
		"modules/update patcher.lua",
		"modules/zcom.lua",
	} do
		if not gksys.IsExist(local_path .. file) then
			table.insert(missing, local_path .. file)
			console_print("File missing: " .. local_path .. file)
		end
	end
	
	if #missing > 0 then
		if recovery_system.ready then
			recovery_system.push_error(
				"RECOV_MISSING_CORE_FILES|Neoloader ran into a critical error and cannot start!\nRequired files for Neoloader's operation were not found.\nFiles missing:",
				{
					critical   = true,
					level      = 4,
					tag        = "fs",
					added_data = "\n\t" .. table.concat(missing, ",\n\t"),
				}
			)

		else
			--how did we get here without recovery?
			console_print("ERROR! missing_recovery_2: somehow, recovery check succeeded, but the recovery system wasn't ready when we began checking file system and found an error.")
			return failsafe_recovery(reclget("MISSING_RECOVERY_2", "recovery check passed but recovery system wasn't ready when a core file check failed!") .. " \n\t" .. table.concat(missing, ",\n\t"))
		end
	end
end

recovery_system.file_check_success {
	pathlock = pathlock,
	statelock = statelock,
	exec_mode = exec_mode,
}



local log = {
	"Neoloader is Initializing...",
	"Aligned ms time value with discovered offset of " .. tostring(alignment_offset) .. "ms",
	"Neoloader has identified its home directory as " .. local_path,
	"pathlock resolved as currently " .. tostring(pathlock),
	"statelock resolved as currently " .. tostring(statelock),
	"Launching recovery system handler...",
	"\trecovery system online",
	"Verifying required files...",
	"\tAll files verified! Neoloader will now begin creating the LME environment and loading modules...",
}

print = print or function(msg)
	table.insert(log, msg)
	console_print(msg)
end

--local neo --private in release version
declare("neo", {}) --global for testing only
declare("lib", {}) --LME API public table
lib[0] = "LME"
lib[1] = "Neoloader"
lib.log_error = function(msg, alert) --nearly API-level, just needs handling for id/version pairs
	alert = tonumber(alert or 2) or 2

	local level_labels = {
		[1] = "DEBUG",
		[2] = "INFO",
		[3] = "WARNING",
		[4] = "ERROR",
	}
	local status = level_labels[alert] or "ALERT"
	
	local gtime_ms = (gkmisc.GetGameTime() + alignment_offset) % 1000
	local val = string.format("[%s.%03d] [%s] %s\127FFFFFF",
        os.date("%Y-%m-%d %H:%M:%S"),
		gtime_ms,
		status,
		tostring(msg)
	)
	
	console_print(filter_colorcodes(val))
	table.insert(neo.log, val)
	
	if alert > 3 then
		recovery_system.push_error(filter_colorcodes(msg), {no_log = true})
	end
end

neo = { --neoloader private table
	testing = {},
	
	version = version,
	path = local_path,
	
	lme_ver = lme_ver,
	
	config = {},
	auth_key = auth_key,
	api = { --stores internal use functions
		check_auth = function(key)
			return key == neo.auth_key
		end,
		
		get_pathlock_value = function()
			return pathlock
		end,
		get_statelock_value = function()
			return statelock
		end,
		get_exec_mode = function()
			return exec_mode
		end,
		get_alignment_offset = function()
			return alignment_offset
		end,
		
		recovery_system = recovery_system,
		
		--config = nil,
		--registry = nil,
	},
	registry = {}, --stores registration data of all plugins
	runtime = {
		waitq = {}, --queue of plugins waiting to launch
	},
	log = log,
	
	lib = lib,
	
	stats = {
		timestat_start = timestat_start,
		memstat_start = memstat_start,
	},
	
	--[[ these don't get defined here
	current_mgr = "",
	current_if = "",
	current_notif = "",
	]]--
	
	load_module = function(file_path, optional)
		local valid_file_path = local_path .. "modules/" .. file_path
		if not gksys.IsExist(valid_file_path) then
			if not optional then
				recovery_system.push_error("RECOV_FS_MISSING_MODULE|Neoloader failed to find a required module", {
					critical = true,
					tag = "fs", 
					added_data = file_path .. " >> " .. valid_file_path,
				})
			else
				lib.log_error("Neoloader failed to find an optional module: " .. file_path)
			end
			return false
		end
		valid_file_path = (pathlock and "../../" or "") .. valid_file_path
		
		lib.log_error("loading module " .. file_path, 1)
		
		local file_f, err = loadfile(valid_file_path)
		
		if not file_f then
			if not optional then
				recovery_system.push_error("RECOV_FS_FAILED_MODULE|Neoloader failed to load a required module", {
					critical = true,
					tag = "fs",
					added_data = file_path .. " >> " .. tostring(err),
				})
			else
				lib.log_error("Neoloader failed to load an optional module: " .. file_path .. ";\nError defined is " .. tostring(err))
			end
		else
			file_f(neo)
		end
	end,
}

recovery_system.neo_check_success(neo)

local load_module = neo.load_module --shortcut

lib.log_error("Loading initial core modules")
--initial modules for core operation
load_module("update patcher.lua") --must load first

load_module("locale.lua")
load_module("config.lua")
--load_module("tree.lua") --later project
load_module("stats.lua")

neo.stats.checkpoint("Preparing environment for operation")
--prepare Neoloader environment
if (exec_mode == "independent") and (not statelock) then
	load_module("env.lua")
end
load_module("registry.lua")

neo.stats.checkpoint("Generating LME API v" .. neo.lme_ver.strver)
load_module("api.lua")

recovery_system.lib_check_success {
	pathlock = pathlock,
	statelock = statelock,
	exec_mode = exec_mode,
}

neo.stats.checkpoint("Preparing mod loading system")
load_module("zcom.lua") --handles command cleanup in rare legacy situations
load_module("loader process.lua")  --< triggers loading system; registered interface or VO-IF is handled first here (if independent exec_mode)

neo.stats.checkpoint("Checking status of bundled assets")

if not lib.is_exist(local_path .. "modules/lexicon/lexicon.lua") then
	lib.register(local_path .. "modules/lexicon/lexicon.lua")
end

if not lib.is_exist(local_path .. "modules/neomgr/neomgr.lua") then
	lib.register(local_path .. "modules/neomgr/neomgr.lua")
end

if not lib.is_exist(local_path .. "modules/neonotif/neonotif.lua") then
	lib.register(local_path .. "modules/neonotif/neonotif.lua")
end

if not lib.is_exist(local_path .. "modules/Vendetta Online Standard Interface/vosi.lua") then
	lib.register(local_path .. "modules/Vendetta Online Standard Interface/vosi.lua")
end


--check for current manager, make sure it loaded okay. if not, try neomgr (force-launch if needed). if failure, notify user with option to launch recovery

local recov_startup_mgr_check = function()
	neo.stats.checkpoint("Checking status of manager and cleaning up")
	
	if lib.is_ready(lib.lme_get_config("current_mgr")) == false then
		if lib.is_ready("neomgr") == true then
			lib.log_error("The last management interface for Neoloader was not found; the bundled manager was loaded instead.", 3)
			lib.lme_configure("current_mgr", "neomgr", neo.auth_key)
			--manually pass auth key
			lib.execute("neomgr", "0", "auth_key_receiver", neo.auth_key)
		elseif lib.is_exist("neomgr") then
			print(neo.api.lget("core", "recovery", "RECOV_STARTUP_MGR_CHECK_DISABLED"))
			recovery_system.push_error(
				"RECOV_STARTUP_MGR_CHECK_DISABLED|Neoloader failed to find an enabled plugin for LME management",
				{
					tag = "startup",
					resolution = {
						key = "enable_neomgr",
						title = "Try enabling neomgr",
						description = "'neomgr' is a front-end bundled with Neoloader, but appears to be disabled. Use this resolution to attempt enabling it.",
						kind = "terminal",
						priority = -1,
						
						visible_if = function()
							return true --only visible when added manually here
						end,
						
						run = function()
							local neomgr_ini = local_path .. "modules/neomgr/neomgr.lua"
							
							lib.set_load(neo.auth_key, neomgr_ini, nil, "YES")
							
							local id, ver = lib.pass_ini_identifier(neomgr_ini)
							neo.api.registry.update_record_fields(id, ver, {
								load = "YES",
							})
							
							lib.lme_configure("current_mgr", "neomgr", neo.auth_key)
							lib.activate_plugin(neomgr_ini, nil, neo.auth_key)
							
							RegisterUserCommand("neo", function()
								lib.open_config()
							end)
							lib.execute("neomgr", "0", "auth_key_receiver", neo.auth_key)
							
							lib.execute(neomgr_ini, nil, "open")
						end,
					},
				}
			)
		else
			print(neo.api.lget("core", "recovery", "RECOV_STARTUP_MGR_CHECK_FAILURE"))
			recovery_system.push_error(
				"RECOV_STARTUP_MGR_CHECK_FAILURE|Neoloader failed to find any plugin for LME management",
				{
					tag = "startup",
				}
			)
		end
	end

	if lib.is_ready(lib.lme_get_config("current_mgr")) == true then
		RegisterUserCommand("neo", function() lib.open_config() end)
		lib.log_error("Management interface found, 'neo' keyword has been bound to access.")
	else
		lib.log_error("Management interface was not found! " .. lib.lme_get_config("current_mgr") .. " wasn't listed as 'ready'!")
	end
	
	neo.api.lex_check()
	load_module("setup.lua")
	
	
	if gkini.ReadString("Neoloader", "first_run_setup", "NO") == "YES" then
		gkini.WriteString("Neoloader", "first_run_setup", "")
		gkinterface.GKProcessCommand("neosetup")
	end
end

if (neo.api.get_exec_mode() == "independent") then
	recov_startup_mgr_check()
else
	RegisterEvent(function()
		recov_startup_mgr_check()
	end, "LME_PLUGINS_LOADED")
end

if statelock then
	process_final_task_queue()
end

if neo.api.get_exec_mode() == "independent" then
	RegisterEvent(function()
		neo.stats.checkpoint("Default loader has finished execution and 'PLUGINS_LOADED' event has fired")
	end, "PLUGINS_LOADED")
end


recovery_system.lme_check_success()
lib.notify("SUCCESS")
neo.stats.checkpoint("Neoloader has finished initial execution! The standard plugin loader will now take over.")
lib.log_error("[breakpoint]\n\n\n", 0)
ProcessEvent("LIBRARY_MANAGEMENT_ENGINE_COMPLETE")
