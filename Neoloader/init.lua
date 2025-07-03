--[[
[metadata]
description=This is the core of Neoloader.
]]--

console_print("\n\n\nVendetta Online has loaded\nNeoloader is Initializing...")
--note to self: can we do a custom loading screen via popup, or does the 'deprecated' popup system prevent the game from loading?

local timestat_start = gkmisc.GetGameTime()
local memstat_start = math.ceil(collectgarbage("count"))
local recovery_system = {}

local version = {
	strver = "7.0.0",
	[1] = 7,
	[2] = 0,
	[3] = 0,
	[4] = "",
}

local local_path = "plugins/Neoloader"
if not gksys.IsExist(local_path .. "/init.lua") then
	local_path = gkini.ReadString("Neoloader", "home_path_override", "plugins/Neoloader/Neoloader")
end
if not gksys.IsExist(local_path .. "/init.lua") then
	--attempt to get path by sniffing error()

	local ok, err = pcall(function()
		error("Path lookup")
	end)

	if not ok and type(err) == "string" then
		-- Try to extract the filename prefix
		local path = err:match("([^:]+):%d+: Path lookup")
		if path then
			-- Strip filename if needed
			local_path = path:match("^(.-)/[^/]-$")
		end
	end
	
	if not gksys.IsExist(local_path .. "/init.lua") then
		--We have NO idea where this file is executing from, and that is a PROBLEM! launch the default interface and inform the user that Neoloader is being run in a very unusual manner. We cannot launch the recovery interface if we cannot guarantee its location
		
		--gkini.WriteString("Neoloader", "STOP", "home_dir_failure")
		dofile("vo/if.lua")
		ProcessEvent("START")
		console_print("\n\n###Neoloader has encountered a critical error!###")
		console_print("	error: Neoloader was unable to determine its home directory")
		--gkini.WriteString("Vendetta", "plugins", "0") --prevent even normal plugins from loading in this state
		error("Neoloader critical error, unable to determine home directory!")
		
		--todo: dialog to help user locate correct directory and apply as an override to this outcome
	end
end

console_print("Neoloader has identified its home directory as " .. local_path)
console_print("Verifying required files...")

do
	local missing = {}
	for index, file in ipairs {
		--init.lua, --already verified as above
		--root directory files
		"/recovery.lua",
		"/main.lua",
		
		--modules directory files (subdirectories are handled within one of these files 
		"/modules/alert.lua",
		"/modules/api.lua",
		"/modules/auth.lua",
		"/modules/class container.lua",
		"/modules/config.lua",
		"/modules/dependency handler.lua",
		"/modules/env.lua",
		"/modules/ifgen.lua",
		"/modules/ini cache.lua",
		"/modules/loader process.lua",
		"/modules/locale.lua"
		"/modules/log.lua",
		"/modules/registry.lua",
		"/modules/stats.lua",
		"/modules/tree.lua",
		"/modules/update patcher.lua",
	} do
		if not gksys.IsExist(local_path .. file) then
			table.insert(missing, local_path .. file)
			console_print("File missing: " .. local_path .. file)
		end
	end
	
	if missing[1] ~= "/recovery.lua" then
		recovery_system = dofile(local_path .. "/recovery.lua")
	end
	
	if #missing > 0 then
		recovery_system.error = "Neoloader ran into a critical error and cannot start! \n Required files for Neoloader's operation were not found. \n files missing:\n	" .. table.concat(missing, ",\n	")
		error("Neoloader critical error")
	end
end

recovery_system.file_check_success()



if (gkini.ReadString("Neoloader", "override_disabled_state", "NO") == "NO") and (gkini.ReadInt("Vendetta", "plugins", 1) == 0) then
	console_print("Plugins are disabled, and Neoloader is not configured to override this setting! The default interface will load, and Neoloader will exit!")
	dofile("vo/if.lua")
	return
end

local config = {}
local log = {}

print = function(msg)
	table.insert(log, msg)
	console_print(msg)
end

declare("lib", {}) --LME API public table
lib[0] = "LME"
lib[1] = "Neoloader"
lib.log_error = function(msg, lvl) --temporary
	local status = "ALERT"
	for i, v in ipairs {
		"DEBUG",
		"INFO",
		"WARNING",
		"ERROR",
	} do
		status = (i == lvl and v) or status
	end
	
	local timestamp = os.date() .. tostring(gkmisc.GetGameTime() % 10000)
	print("[" .. timestamp .. "] [" .. status .. "] " .. tostring(msg))
end

local neo
neo = { --neoloader private table
	version = version,
	path = local_path,
	
	lme_ver = "3.12.0",
	
	config = config,
	registry = {},
	container = {},
	log = log,
	
	lib = lib,
	
	process_stats = {
		timestat_start = timestat_start,
		memstat_start = memstat_start,
	},
	
	load_module = function(file_path, optional)
		local valid_file_path = local_path .. "/modules/" .. file_path
		if not gksys.IsExist(valid_file_path) then
			if not optional then
				recovery_system.error = "Neoloader failed to find a required module: " .. file_path
				recovery_system.critical = true
				recovery_system.push_error()
			end
			lib.log_error("Neoloader failed to find an optional module: " .. file_path)
			return false
		end
		lib.log_error("loading module " .. file_path, 1)
		
		local file_f, err = loadfile(valid_file_path)
		
		if not file_f then
			if not optional then
				error("Neoloader failed to load a required module: " .. file_path .. ";\nError defined is " .. tostring(err))
			end
			lib.log_error("Neoloader failed to load an optional module: " .. file_path .. ";\nError defined is " .. tostring(err))
		else
			file_f(neo)
		end
	end,
}

local load_module = neo.load_module

lib.log_error("Loading initial core modules")
--initial modules for core operation
load_module("locale.lua")
load_module("log.lua")
load_module("config.lua")
load_module("tree.lua")
load_module("stats.lua")

neo.stats.checkpoint("Preparing environment for operation")
--prepare Neoloader environment
load_module("update patcher.lua")
load_module("registry.lua")
load_module("class container.lua")
load_module("auth.lua")
load_module("alert.lua")
load_module("ifgen.lua")
load_module("uninstaller.lua")

neo.stats.checkpoint("Generating LME API v" .. neo.lme_ver)
load_module("api.lua")

neo.stats.checkpoint("Preparing mod loading system")
load_module("env.lua")
load_module("dependency handler.lua")
load_module("ini cache.lua")
load_module("loader process.lua")

if not lib.is_exist("neomgr", "0") then
	lib.register(local_path .. "/modules/neomgr/neomgr.lua")
end

if not lib.is_exist("neonotif", "0") then
	lib.register(local_path .. "/modules/neonotif/neonotif.lua")
end

--check for current manager, make sure it loaded okay. if not, try neomgr (force-launch if needed). if failure, notify user with option to launch recovery

--register the 'neo' command with the active manager if it is available

--log unfilled dependencies for objects still in the dependency queue

--reset handler -> its own code (bind to reload and quit events)

neo.stats.checkpoint("Neoloader has finished initial execution! The standard plugin loader will now take over.\n\n")
ProcessEvent("LIBRARY_MANAGEMENT_ENGINE_COMPLETE")
