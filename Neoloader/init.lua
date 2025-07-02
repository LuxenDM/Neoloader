--[[
[metadata]
description=This is the core of Neoloader.
]]--

console_print("\n\n\nVendetta Online has loaded\nNeoloader is Initializing...")

local timestat_start = gkmisc.GetGameTime()
local memstat_start = math.ceil(collectgarbage("count"))

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
		
		gkini.WriteString("Neoloader", "STOP", "home_dir_failure")
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

if gksys.IsExist(local_path .. "/recovery.lua") then
	dofile(local_path .. "/recovery.lua")
end

if (gkini.ReadString("Neoloader", "override_disabled_state", "NO") == "NO") and (gkini.ReadInt("Vendetta", "plugins", 1) == 0) then
	console_print("Plugins are disabled, and Neoloader is not configured to override this setting! The default interface will load, and Neoloader will exit!")
	dofile("vo/if.lua")
	return
end

local config = {
	current_if = gkini.ReadString("Neoloader", "current_if", "vo/if.lua"),
}

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
	
	config = config,
	registry = {},
	container = {},
	log = log,
	
	lib = lib,
	
	process_stats = {
		timestat_start = timestat_start,
		memstat_start = memstat_start,
	},
	
	error = function()
		--consistant internal showstopping error handler
	end,
	
	load_module = function(file_path)
		local valid_file_path = local_path .. "/" .. file_path
		if not gksys.IsExist(valid_file_path) then
			error("Neoloader failed to find a required module: " .. file_path)
		end
		lib.log_error("loading module " .. file_path, 1)
		
		local file_f, err = loadfile(valid_file_path)
		
		if not file_f then
			error("Neoloader failed to load a required module: " .. file_path .. ";\nError defined is " .. tostring(err))
		else
			file_f(neo)
		end
	end,
	
	load_optional = function(file_path)
		--pcall load_module and ignore error if file isn't available
	end,
}

