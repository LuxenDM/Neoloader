console_print("\n\n\nVendetta Online has loaded\nNeoloader is Initializing...")

NEO_EXISTS = true --use lib/lib[0] instead if you are testing for a generic library management implementation

--depreciated preload.lua in favor of recovery.lua
if gksys.IsExist("plugins/Neoloader/recovery.lua") then
	dofile("plugins/Neoloader/recovery.lua")
end

if type(print) ~= "function" then
	print = console_print
end

local copy_table --is this neccesary for a self-recursive function?
copy_table = function(input)
	if type(input) ~= "table" then
		return {input}
	end
	local newtable = {}
	for k, v in pairs(input) do
		if type(v) == "table" then
			newtable[k] = copy_table(v)
		else
			newtable[k] = v
		end
	end
	return newtable
end

local locale = gkini.ReadString("Vendetta", "locale", "en")
local tprint = function(key, value)
	return gkini.ReadString2(locale, key, value, "plugins/Neoloader/lang/neo.ini")
end

local gk_get_microsecond = gkmisc.GetGameTime

local timestat_neo_start = gk_get_microsecond()
local timestat_step = gk_get_microsecond()
local function timestat_advance()
	local next_step = gk_get_microsecond()
	local retval = next_step - timestat_step
	timestat_step = next_step
	return retval
end

local override_switch = gkini.ReadString2("Override", "doOverride", "NO", "plugins/Neoloader/config-override.ini")


local gkreadstr = function(header, key, def_value)
	local retval
	if override_switch == "YES" then
		retval = gkini.ReadString2(header, key, def_value, "plugins/Neoloader/config-override.ini")
	else
		retval = gkini.ReadString(header, key, def_value)
	end
	return retval
end
local gkreadint = function(header, key, def_value)
	local retval
	if override_switch == "YES" then
		retval = gkini.ReadInt2(header, key, def_value, "plugins/Neoloader/config-override.ini")
	else
		retval = gkini.ReadInt(header, key, def_value)
	end
	return retval
end



--This will be local when released
local neo = {
	version = {
		strver = "6.2.0",
		[1] = 6,
		[2] = 2,
		[3] = 0,
		[4] = "",
	},
	log = {},
	error_flag = false, 
	plugin_registry = {}, --holds registered plugin details [id .. version]; [id].latest will provide version sstring of latest version for redirect
	plugin_container = {}, --holds a library's "class" data/functions.
	
	list_if = { --list of possible IFs
		[1] = "no_entry",
	},
	list_mgr = { --list of possible managers
		[1] = "no_entry",
	},
	list_notif = { --list of possible notification handlers
		[1] = "no_entry",
	},
	
	init = gkini.ReadInt("Neoloader", "Init", 0),
	API = 3,
	minor = 11, --lib.catch_block() & lib.update_state()
	patch = 0,
	lmever = "3.11.0",
	
	pathlock = false,
	statelock = false,
	
	allowDelayedLoad = gkreadstr("Neoloader", "rAllowDelayedLoad", "NO"),
	allowBadAPIVersion = gkreadstr("Neoloader", "rAllowBadAPIVersion", "YES"),
	echoLogging = gkreadstr("Neoloader", "rEchoLogging", "YES"),
	defaultLoadState = gkreadstr("Neoloader", "rDefaultLoadState", "YES"),
	doErrPopup = gkreadstr("Neoloader", "rDoErrPopup", "NO"),
	protectResolveFile = gkreadstr("Neoloader", "rProtectResolveFile", "YES"),
	listPresorted = gkini.ReadString("Neoloader", "rPresortedList", "NO"),
	clearCommands = gkreadstr("Neoloader", "rClearCommands", "NO"),
	dbgFormatting = gkreadstr("Neoloader", "rDbgFormatting", "YES"),
	dbgIgnoreLevel = gkreadint("Neoloader", "iDbgIgnoreLevel", 2),
	ignoreOverrideState = gkreadint("Neoloader", "rOverrideDisabledState", "NO"),
	
	number_plugins_registered = 0, --registry index
	number_plugins_exist = 0, --actually present counter
	
	current_if = gkreadstr("Neoloader", "if", ""),
	current_mgr = gkreadstr("Neoloader", "mgr", ""),
	current_notif = gkreadstr("Neoloader", "current_notif", ""),

	update_check = gkini.ReadInt("Neoloader", "iUpdateCheck", 0),
}

if neo.ignoreOverrideState == "NO" and gkini.ReadInt("Vendetta", "plugins", 1) == 0 then
	console_print("Plugins are disabled, and Neoloader is not configured to override this setting! The default interface will load, and Neoloader will exit!")
	dofile("vo/if.lua")
	return
end		

local configd = {
	--config defines
	ignoreOverrideState = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rOverrideDisabledState",
	},
	allowDelayedLoad = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rAllowDelayedLoad",
	},
	allowBadAPIVersion = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rAllowBadAPIVersion",
	},
	echoLogging = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rEchoLogging",
	},
	defaultLoadState = {
		need_auth = "YES",
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
			["FORCE"] = true,
			["AUTH"] = true,
		},
		default = "NO",
		key = "rDefaultLoadState",
	},
	doErrPopup = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rDoErrPopup",
	},
	protectResolveFile = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rProtectResolveFile",
	},
	listPresorted = {
		need_auth = "YES",
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rPresortedList",
	},
	clearCommands = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rClearCommands",
	},
	dbgFormatting = {
		type = "string",
		valid = {
			["YES"] = true,
			["NO"] = true,
		},
		default = "NO",
		key = "rDbgFormatting",
	},
	dbgIgnoreLevel = {
		type = "number",
		valid = {
			[0] = true,
			[1] = true,
			[2] = true,
			[3] = true,
			[4] = true,
		},
		default = 2,
		key = "iDbgIgnoreLevel",
	},
	current_if = {
		need_auth = "YES",
		type = "string",
		valid = "ALL",
		default = "",
		key = "if",
	},
	current_mgr = {
		need_auth = "YES",
		type = "string",
		valid = "ALL",
		default = "",
		key = "mgr",
	},
	current_notif = {
		need_auth = "YES",
		type = "string",
		valid = "ALL",
		default = "",
		key = "current_notif",
	},
}

local mgr_key = 0
--[[
	This mgr_key is the random value used to prevent any plugin from calling functions we want to verify ONLY the user can initiate, such as forcing an uninstall or changing a plugin's state.
]]--

local load_position_tracker = {}
--[[
	Tracks where a declaration file is found in the config registry. THis is checked to determine the plugin's load position
]]--











lib = {} --public functions container
lib[0] = "LME"
lib[1] = "Neoloader" --LME provider

local waiting_for_dependencies = {} --storage for functions with unfulfilled dependencies tested by lib.require
local converted_dep_tables = {} --storage for build results of compiled ini files

function lib.log_error(msg, alert, id, version)
	alert = tonumber(alert or 2) or 2
	if alert < neo.dbgIgnoreLevel then return end

	local val = tostring(msg)
	local use_plugin = id ~= nil or version ~= nil

	if use_plugin then
		id, version = lib.pass_ini_identifier(id, version)
		id = tostring(id or "null")
		version = tostring(version)
		if version == "0" and id ~= "null" then
			version = lib.get_latest(id)
		end
	end

	if neo.dbgFormatting == "YES" then
		local level_labels = {
			[1] = "DEBUG",
			[2] = "INFO",
			[3] = "WARNING",
			[4] = "ERROR",
		}
		local status = level_labels[alert] or "ALERT"
		val = string.format("[%s.%04d] [%s] %s\127FFFFFF",
			os.date(),
			gk_get_microsecond() % 10000,
			status,
			val
		)
	end

	if neo.echoLogging == "YES" then
		console_print(filter_colorcodes(val))
	end

	if use_plugin and lib.is_exist(id, version) then
		table.insert(neo.plugin_registry[id .. "." .. version].errors, val)
	end

	table.insert(neo.log, val)
end


RegisterEvent(function() neo.pathlock = true end, "LIBRARY_MANAGEMENT_ENGINE_COMPLETE")
--when the default loader is working, dofile() has the 'current working directory' appended in front of any path given. This is reset when all plugins are fully loaded.

RegisterEvent(function() neo.pathlock = false neo.statelock = true end, "PLUGINS_LOADED")
--when all plugins are loaded, it becomes impossible to create global variables because the sandbox metatable's "new index" is removed; to create globals the plugin must use declare("name", value) (but modders should do that anyways if their plugin has any execution post-load)





function lib.err_handle(test, log_msg)
	if log_msg == nil and type(test) == 'string' then
		--debug: err_handle test is a string and log_msg is nil
		log_msg = test
		test = true
	end
	if type(test) ~= "boolean" then
		test = test ~= nil --if we aren't provided a bool, then any value is "true"
	end
	
	if test == false then
		return false --returns inverse; test is the error condition, so returns true if there IS an error.
	else
		local err = debug.traceback("Neoloader captured an error: " .. tostring(log_msg))
		lib.log_error(err, 4)
		lib.notify("CAPTURED_ERROR", err)
		if neo.doErrPopup == "YES" and neo.statelock == true then
			error(err)
		end
		return true
	end
end
local err_han = lib.err_handle --fast shortcut

function lib.find_file(file, ...)
	if err_han( type(file) ~= "string" , "lib.find_file expected a string as argument 1, got " .. type(file) ) then
		return false, "file not a string"
	end
	
	local path_checks = {}
	local pathlist = {...}
	
	--this is to maintain compatibility with previous resolve_file(file, nil, path) usage
	if pathlist[2] and not pathlist[1] then
		table.remove(pathlist, 1)
	end
	
	lib.log_error("Attempting to find " .. file, 1)
	
	local last_slash_index = string.find(file, "/[^/]*$")
		
	if last_slash_index then
		--the first argument was a path/to/file and not just a file; break apart and handle
		local path = string.sub(file, 1, last_slash_index)
		file = string.sub(file, last_slash_index + 1)
		
		table.insert(path_checks, {
			path .. file,
			"../" .. path .. file,
			"../../" .. path .. file,
		})
	end
	
	for index, path in ipairs(pathlist) do
		table.insert(path_checks, {
			path .. file,
			"../" .. path .. file,
			"../../" .. path .. file,
		})
	end
	
	table.insert(path_checks, {
		file,
		"../" .. file,
		"../../" .. file,
	})
	
	local first_valid_path = false
	local valid_path_table = {}
	
	for index, path in ipairs(path_checks) do
		lib.log_error("		" .. path[1], 1)
		if gksys.IsExist(path[1]) then
			first_valid_path = first_valid_path or path[1]
			table.insert(valid_path_table, path)
		end
	end
	
	return first_valid_path, valid_path_table
end
	
	

function lib.resolve_file(file, ...)
	if err_han( type(file) ~= "string" , "lib.resolve_file expected a string as argument 1, got " .. type(file) ) then
		return false, "file not a string"
	end
	
	local path, pathtable = lib.find_file(file, ...)
	
	if not path then
		lib.log_error("unable to resolve file provided (" .. tostring(file) .. "); file not found", 2)
		return false, "unable to find file"
	end
	
	local file_loaded
	lib.log_error("Attempting to resolve " .. tostring(pathtable[1][1]), 1)
	for k, path_table in ipairs(pathtable) do
		for i=1, 3 do
			local status, err = loadfile(pathtable[k][i])
			if status then --success!
				file_loaded = status
				break
			else
				if not string.find(err, "No such file or directory") then
					lib.log_error("Unable to resolve file: " .. tostring(err or "error?"), 2)
					return false, err
				end
			end
		end
		if file_loaded then
			break
		end
	end
	
	if file_loaded then
		if neo.protectResolveFile == "YES" then
			local status, err = pcall(file_loaded)
			
			if not status then
				lib.log_error("unable to resolve file: pcall caught an error during execution!", 3)
				lib.log_error("	" .. tostring(err), 3)
				lib.log_error(debug.traceback("	trace up to lib.resolve_file(): "), 1)
				lib.log_error("		If you are a plugin developer, try turning off execution protection!", 1)
			end
			
			return status, err
		else
			return true, file_loaded()
		end
	else
		lib.log_error("unable to resolve file: file does not appear to exist or cannot be accessed using known methods", 1)
		return false, "error resolving file"
	end
end

function lib.build_ini(iniFilePointer)
	if err_han( type(iniFilePointer) ~= "string" , "lib.build_ini expected a string (file path) as argument 1, got " .. type(iniFilePointer) ) then
		return false, "ini file path not a string"
	end
	local ifp = iniFilePointer --less typing
	lib.log_error("	Building INI " .. ifp, 1)
	local getstr = gkini.ReadString2
	local getint = gkini.ReadInt2
	
	if err_han( gksys.IsExist(ifp) == false, "lib.build_ini failed; file does not exist at " .. ifp ) then
		return false, "no file"
	end
	
	local id = getstr("modreg", "id", "null", ifp)
	if err_han( id == "null" , "lib.build_ini couldn't find a valid INI file with the path " .. iniFilePointer ) then
		--this pointer isn't valid
		--or, plugins cannot use "null" as an id
		--we can't actually tell the difference without additional logic
		return false, "invalid pointer"
	else
		local plugintype = getstr("modreg", "type", "plugin", ifp)
		local name = getstr("modreg", "name", "UNTITLED: " .. ifp, ifp)
		local pluginversion = getstr("modreg", "version", "0", ifp)
		local pluginapi = getint("modreg", "api", 0, ifp)
		if err_han( pluginapi ~= neo.API and neo.allowBadAPIVersion == "NO" , "lib.build_ini failed; API mismatched. expected " .. tostring(neo.API) .. ", got " .. tostring(pluginapi) ) then
			lib.log_error("INI Builder failed: API Mismatch!", 1)
			return false, "API mismatch"
		end
		
		if converted_dep_tables[iniFilePointer] then
			--this plugin has already been registered
			--pass along existing table and exit
			return converted_dep_tables[iniFilePointer]
		end
		
		local author = getstr("modreg", "author", "", ifp)
		local website = getstr("modreg", "website", "", ifp)
		local pluginpath = getstr("modreg", "path", "", ifp)
		local pluginfolderpath = string.sub(iniFilePointer, 1, string.find(iniFilePointer, "/[^/]*$"))
		
		local plugin_dependencies = {}
		local counter = 0
		while true do
			counter = counter + 1
			local next_dep = {
				name = getstr("dependency", "depid" .. tostring(counter), "null", ifp),
				version = getstr("dependency", "depvs" .. tostring(counter), "0", ifp),
				ver_max = getstr("dependency", "depmx" .. tostring(counter), "~", ifp),
			}
			if next_dep.name == "null" then
				break
			else
				table.insert(plugin_dependencies, next_dep)
			end
		end
		
		converted_dep_tables[iniFilePointer] = {
			compat = pluginpath == "" and "YES" or "NO",
			plugin_id = id,
			plugin_type = plugintype,
			plugin_name = name,
			plugin_version = pluginversion,
			plugin_author = author,
			plugin_link = website,
			plugin_path = pluginpath,
			plugin_folder = pluginfolderpath,
			plugin_dependencies = plugin_dependencies,
			plugin_regpath = iniFilePointer,
		}
		return converted_dep_tables[iniFilePointer]
	end
end

function lib.resolve_dep_table(intable)
	--returns true or false if the table of dependencies have been met
	if err_han( type(intable) ~= "table", "lib.resolve_dep_table expected a table for argument 1, got " .. type(intable) ) then
		return false, "input not a table"
	end
	local status = true
	--use a copy here to prevent back-adjustments
	for k, v in ipairs(copy_table(intable)) do
		if err_han( type(v) ~= "table", "lib.resolve_dep_table was given an improperly formatted table; table values should be tables!" ) then
			return false, "bad table format"
		else
			v.name = tostring(v.name or v.id or "null")
			v.version = tostring(v.version or "0")
			v.ver_max = tostring(v.ver_max or "~")
			if not lib.is_exist(v.name) then
				--this mod doesn't exist at all in the registry
				return false
			end
			if v.version == "0" then
				v.version = lib.get_latest(v.name)
			end
			if v.ver_max == "0" then
				v.ver_max = lib.get_latest(v.name)
			end
			if v.ver_max ~= "~" then
				v.version = lib.get_latest(v.name, v.version, v.ver_max)
			end
			
			for i, v2 in ipairs {
				--lib.is_exist(v.name, v.version),
				lib.is_ready(v.name, v.version),
				neo.plugin_registry[v.name .. "." .. v.version] and neo.plugin_registry[v.name .. "." .. v.version].dependent_freeze < 1,
				v.version ~= "?",
			} do
				if v2 == false then
					status = false
					break
				end
			end
			
			if not status then
				--break again for container loop
				break
			end
		end
	end
	return status
end

local function silent_register(iniFilePointer)
	if err_han( type(iniFilePointer) ~= "string", "silent registry failed! File pointer wasn't a string!") then
		return false, "silent register: file pointer not a string"
	end
	--used to add plugins/libraries to Neoloader during the loading process. doesn't register to config, as that's where they are being read from.
	local id = gkini.ReadString2("modreg", "id", "null", iniFilePointer)
	if err_han( id == "null", "Silent registry failed! The plugin provided doesn't exist or is broken; path was " .. iniFilePointer) then
		return false, 100
	end
	local iniTable, errid = lib.build_ini(iniFilePointer)
	if err_han( iniTable == false, "Silent Registry failed! An error was returned during ini building!") then
		return false, errid
	end
	if err_han( lib.is_exist(id, iniTable.plugin_version) ~= false, "Silent Registry failed! The plugin being registered already exists!" ) then
		--duplicate plugin entry in config.ini; we need to remove this plugin from the config and mark the original with a triggered error
		lib.log_error("registration error: already exists", 3, id, iniTable.plugin_version)
		return false, 304
	else
		table.insert(neo.plugin_container, {})
		neo.number_plugins_registered = neo.number_plugins_registered + 1
		neo.number_plugins_exist = neo.number_plugins_exist + 1
		
		local data = copy_table(iniTable)
		data.dependencies_met = false
		data.complete = false --true when all checks complete and plugin is run
		data.dependent_freeze = 0
		data.load = gkreadstr("Neo-pluginstate", data.plugin_id .. "." .. data.plugin_version, neo.defaultLoadState)
		data.index = #neo.plugin_container
		data.load_position = load_position_tracker[data.plugin_regpath]
		data.errors = {}
		data.complete = false
		if lib.resolve_dep_table(data.plugin_dependencies) then
			data.dependencies_met = true
			--reminder: we do not run plugins on registry; they must be user-activated or during the loading process only.
		end
		
		if not neo.plugin_registry[id] then
			--this is the first version of an already-registered plugin
			neo.plugin_registry[id] = {
				latest = "0",
			}
		end
		
		table.insert(neo.plugin_registry[id], data.plugin_version)
		table.sort(neo.plugin_registry[id])
		
		if data.load == "YES" then
			--version is already in system; check versions and mark the newer one.
			local balance = lib.compare_sem_ver(neo.plugin_registry[id].latest, data.plugin_version)
			if balance < 0 then
				--this is a new version of an already-registered plugin
				neo.plugin_registry[id].latest = data.plugin_version
			else
				--this is either the same version (which shouldn't be possible) or is older than the already registered one
			end
		end
		
		lib.log_error("Added " .. id .. " v" .. data.plugin_version .. " to Neoloader's plugin registry!", 1)
		neo.plugin_registry[id .. "." .. data.plugin_version] = data
		return id, data.plugin_version
	end
end	

function lib.register(iniFilePointer)
	if err_han( type(iniFilePointer) ~= "string", "lib.register expected a string (file path) for argument 1, got " .. type(iniFilePointer) ) then
		return false, "file pointer not a string"
	end
	local id = gkini.ReadString2("modreg", "id", "null", iniFilePointer)
	if err_han( id == "null", "lib.register could not open the plugin at " .. iniFilePointer) then
		return false, "invalid file pointer"
	end
	local iniTable, errid = lib.build_ini(iniFilePointer)
	if err_han( iniTable == false, "lib.register could not build the INI file at " .. iniFilePointer .. "; error recieved was " .. tostring(errid) ) then
		return false, errid
	end
	neo.listPresorted = "NO"
	lib.log_error("Attempting to register data for " .. id .. " v" .. iniTable.plugin_version, 1)
	if lib.is_exist(id, iniTable.plugin_version) then
		--don't use the error handler here; duplicate registration can be attempted and shouldn't trigger errors for the user
		--	multiple plugins may use the same sharable library
		--duplicate plugin entry in config.ini; we need to remove this plugin and mark the original with a triggered error
		lib.log_error("	plugin registration skipped: plugin is already registered", 1, id, iniTable.plugin_version)
		return false, "Duplicate of plugin exists"
	else
		table.insert(neo.plugin_container, {})
		neo.number_plugins_registered = neo.number_plugins_registered + 1
		
		local data = copy_table(iniTable)
		data.new_entry = true
		data.dependencies_met = false
		data.complete = false
		data.dependent_freeze = 0
		data.load = gkreadstr("Neo-pluginstate", data.plugin_id .. "." .. data.plugin_version, neo.defaultLoadState)
		data.index = #neo.plugin_container
		data.load_position = neo.number_plugins_registered
		data.errors = {}
		if lib.resolve_dep_table(data.plugin_dependencies) then
			data.dependencies_met = true
			--reminder: we do not run plugins on registry; they must be user-activated or during the loading process only.
		end
		
		--don't mark plugin version as latest, it won't be "activated"
		if not neo.plugin_registry[id] then
			neo.plugin_registry[id] = {
				latest = "0",
			}
		end
		table.insert(neo.plugin_registry[id], data.plugin_version)
		
		lib.log_error("Added NEW " .. id .. " v" .. (data.plugin_version or "0") .. " to Neoloader's plugin registry and to config.ini at position " .. tostring(neo.number_plugins_registered))
		lib.notify("NEW_REGISTRY", {plugin_id = id, version = data.plugin_version or "0"})
		--write the registration to config.ini
		gkini.WriteString("Neo-pluginstate", (data.plugin_id .. "." .. (data.plugin_version or "0")), "NO")
		gkini.WriteString("Neo-registry", "reg" .. tostring(neo.number_plugins_registered), iniFilePointer)
		
		neo.plugin_registry[id .. "." .. (data.plugin_version or "0")] = data
		
		--TODO: Attempt late activation if enabled in settings
		return true
	end
end

function lib.require(intable, callback, id, ver)
	if err_han( type(intable) ~= "table", "lib.require expected a table for argument 1, got " .. type(intable) )  then
		return false, "dependency list not a table"
	end
	if err_han( type(callback) ~= "function", "lib.require expected a function for argument 2, got " .. type(callback) ) then
		return false, "callback not a function"
	end
	if lib.resolve_dep_table(intable) then
		callback()
	else
		table.insert(waiting_for_dependencies, {intable, callback, owner_id = id, owner_version = ver})
	end
end

function lib.check_queue()
	for k, v in ipairs(waiting_for_dependencies) do
		if lib.resolve_dep_table(v[1]) then
			lib.log_error("		A dependency was resolved for a mod in the processing queue!", 1)
			local temp = v[2]
			table.remove(waiting_for_dependencies, k)
			temp()
		end
	end
end

function lib.is_exist(name, version)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.is_exist expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if type(neo.plugin_registry[name]) ~= "table" then
		return false, "doesn't exist as ID only"
	end
	
	if version == "0" then
		version = neo.plugin_registry[name].latest --can't use lib.get_latest: lib.get_latest uses this function, causes an infinite loop
		if version == "0" then
			--no active versions, get latest inactive version registered
			version = neo.plugin_registry[name][#neo.plugin_registry[name]]
		end
	end
	
	if type(neo.plugin_registry[name .. "." .. version]) ~= "table" then
		return false, "specific version doesn't exist"
	else
		return true
	end
end

function lib.is_ready(id, version)
	id, version = lib.pass_ini_identifier(id, version)
	if err_han( type(id) ~= "string", "lib.is_ready expected a string for its first argument, got " .. type(id) ) then
		return false, "plugin ID not a string"
	end
	local status = false
	if not lib.is_exist(id) then
		return false, "plugin doesn't exist"
	end
	
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(id)
	end
	
	if not lib.is_exist(id, version) then
		return false, "plugin doesn't exist"
	end
	
	if neo.plugin_registry[id .. "." .. version].complete == true then
		status = true
	end
	
	return status
end

function lib.activate_plugin(id, version, verify_key)
	id, version = lib.pass_ini_identifier(id, version)
	local time_start = gk_get_microsecond()
	lib.log_error("attempting activation of " .. tostring(id) .. "." .. tostring(version), 1)
	if err_han( type(id) ~= "string", "lib.activate_plugin expected a string for its first argument, got " .. type(id) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(id)
	end
	
	local valid_load_states = {
		["YES"]		= true,
		["FORCE"]	= true,
		["AUTH"]	= true,
	}
	
	local plugin_id = id .. "." .. version
	--this is called to start a plugin that is already registered. it SHOULD NOT be used without the user's knowledge.
	--libraries should be set as loaded/disabled by the user themselves and resolved ONLY by the user using a plugin manager or during Init
	if verify_key ~= mgr_key then
		lib.log_error("Attempted to activate a plugin, but key is incorrect!", 1)
		--don't return false, no plugin ID to report to init
		return
	end

	if not lib.is_exist(id, version) then
		lib.log_error("Attempted to activate " .. plugin_id .. " but it doesn't exist!", 1)
		--don't return false, no plugin ID to report to init
		return
	end

	local modreg = neo.plugin_registry[plugin_id]
	
	if not valid_load_states[lib.get_state(id, version).load] then
		lib.log_error("Attempted to activate " .. plugin_id .. " but it's load state is 'NO'!", 1, id, version)
		return false, "load state is NO"
	end
	
	if modreg.compat == "YES" then
		modreg.complete = true
		lib.log_error(plugin_id .. " is a compatibility plugin; empty container created successfully! The default loader will launch it soon.", 1, id, version)
		neo.plugin_registry[plugin_id] = modreg
		ProcessEvent("COMPAT_PLUGIN_ACTIVATED")
		return
	end
	
	if not (lib.resolve_dep_table(modreg.plugin_dependencies) or modreg.flag == "FORCE") then
		lib.log_error("Attempted to activate " .. plugin_id .. " but its dependencies aren't fulfilled!", 2)
		lib.notify("PLUGIN_FAILURE", {plugin_id = id, version = version, error_string = "Unfilled Dependencies!"})
		return false, "unmatched dependencies"
	end

	
	
	local status, err = lib.resolve_file(modreg.plugin_path, nil, modreg.plugin_folder)
	if not status then
		lib.log_error("\127FF0000Failed to activate " .. plugin_id .. "\127FFFFFF", 3, id, version)
		lib.log_error("		error message: " .. tostring(err), 3, id, version)
		lib.notify("PLUGIN_FAILURE", {plugin_id = id, version = version, error_string = tostring(err)})
		return false, "failed to activate, " .. err or "?"
	end

	modreg.complete = true
	lib.log_error("Activated plugin " .. plugin_id .. " with Neoloader successfully!", 2, id, version)
	lib.log_error("[timestat] activation took: " .. tostring(gk_get_microsecond() - time_start), 1, id, version)
	if (neo.statelock == false) or (neo.allowDelayedLoad == "YES") then
		if neo.plugin_registry[plugin_id].dependent_freeze < 1 then
			lib.check_queue()
		end
	end
	
	if modreg.flag == "AUTH" or id == neo.current_mgr then
		lib.execute(id, version, "auth_key_receiver", mgr_key)
	end
	
	neo.plugin_registry[plugin_id] = modreg
	
	ProcessEvent("LME_PLUGIN_ACTIVATED")
end

function lib.get_latest(id, min, max)
	id = tostring(id or "null")
	if not lib.is_exist(id) then
		return "?"
	end
	
	local ver_table = neo.plugin_registry[id]
	local version = tostring(ver_table.latest)
	if version == "0" then
		version = ver_table[#ver_table]
	end
	
	if max and lib.compare_sem_ver(max, version) < 0 then
		version = "?"
		for index=#ver_table, 1, -1 do
			local ver_available = ver_table[index]
			
			if lib.is_ready(id, ver_available) and lib.compare_sem_ver(max, ver_available) >= 0 and lib.compare_sem_ver(min, ver_available) <= 0 then
				version = ver_available
				break
			end
		end
	end
	
	return version
end


function lib.get_state(name, version)
	name, version = lib.pass_ini_identifier(name, version)
	--returns most neoloader info about a plugin
	
	if err_han( type(name) ~= "string", "lib.get_state expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	local rettable = {}
	if lib.is_exist(name, version) then
		if version == "0" then
			version = lib.get_latest(name)
		end
		
		local ref = neo.plugin_registry[name .. "." .. version]
		rettable = {
			load = ref.load or "NO",
			complete = ref.complete or false,
			dependencies_met = ref.dependencies_met or false,
			load_position = ref.load_position or 0,
			errors = ref.errors or {},
			latest = lib.get_latest(name) or "-1",
			versions = copy_table(neo.plugin_registry[name] or {"???"}),
			
			plugin_id = name,
			plugin_version = version,
			plugin_type = ref.plugin_type,
			plugin_name = ref.plugin_name,
			plugin_author = ref.plugin_author,
			plugin_link = ref.plugin_link,
			plugin_folder = ref.plugin_folder,
			plugin_ini_file = ref.plugin_regpath,
			
			plugin_frozen = ref.dependent_freeze > 0 and "YES" or "NO",
			
			plugin_dependencies = ref.plugin_dependencies,
			
			plugin_is_new = ref.new_entry,
			compat_flag = ref.compat
		}
	end
	
	return rettable
end

function lib.get_gstate()
	local data = {}
	data.version = neo.version
	data.lmever = neo.lmever
	data.major = neo.API
	data.minor = neo.minor
	data.patch = neo.patch
	
	data.pathlock = neo.pathlock
	data.statelock = neo.statelock
	
	data.mgr_list = neo.list_mgr
	data.if_list = neo.list_if
	data.notif_list = neo.list_notif
	
	--depreciate these
		data.manager = neo.current_mgr
		data.ifmgr = neo.current_if
	--end
	
	data.current_mgr = neo.current_mgr
	data.current_if = neo.current_if
	data.current_notif = neo.current_notif
	
	if not lib.is_exist(neo.current_if) then
		data.ifmgr = "vo-if"
	end
	
	data.log = neo.log
	
	data.pluginlist = {}
	for k, v in pairs(neo.plugin_registry) do
		if v.plugin_id ~= nil then
			table.insert(data.pluginlist, {
				[1] = v.plugin_id,
				[2] = v.plugin_version,
			})
		end
	end
	
	--depreciated; too many settings, so they should be obtained through lib.lme_get_config(). These will remain here, but no more will be added.
	data.newstate = neo.defaultLoadState
	data.format_log = neo.dbgFormatting
	data.log_level = neo.dbgIgnoreLevel
	
	return data
end

function lib.execute(name, version, func, ...)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.execute expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	if err_han( func == nil, "lib.execute expected a value for its third argument, got nil") then
		return false, "function key is nil"
	end
	local retval
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name) or "0"
	end
	if lib.is_exist(name, version) then
		if lib.get_state(name, version).complete == true then
			local index = neo.plugin_registry[name .. "." .. version].index
			local action = neo.plugin_container[index][func]
			if type(action) == "function" then
				retval = action(...)
			elseif action then
				retval = action
			else
				lib.log_error("Attempted to call " .. name .. " v" .. version .. " class function " .. func .. " but it doesn't exist", 1)
			end
		else
			lib.log_error("Attempted to call " .. name .. " v" .. version .. " but it isn't loaded", 1)
		end
	else
		lib.log_error("Attempted to call " .. name .. " v" .. version .. " but it doesn't exist", 1)
	end
	return retval
end

function lib.get_class(name, version)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.get_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	
	if not lib.is_exist(name, version) then
		return false, "Mod doesn't exist"
	end
	
	if lib.get_state(name, version).complete ~= true then
		return false, "Mod isn't complete"
	end
	
	local index = neo.plugin_registry[name .. "." .. version].index
	
	return copy_table(neo.plugin_container[index])
end

function lib.set_class(name, version, ftable)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.set_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	lib.log_error("Setting class for " .. name .. " v" .. version, 1)
	if type(ftable) ~= "table" then
		ftable = {ftable}
	end
	
	if not lib.is_exist(name, version) then
		return false, "mod doesn't exist"
	end
	
	if (neo.plugin_registry[name .. "." .. version].lock == nil) and (neo.plugin_registry[name .. "." .. version].load == "YES") then
		local index = neo.plugin_registry[name .. "." .. version].index
		neo.plugin_container[index] = ftable
		if ftable.IF == true and not neo.list_if[name] then
			neo.list_if[name] = true
			table.insert(neo.list_if, name)
		end
		if ftable.mgr == true and not neo.list_mgr[name] then
			neo.list_mgr[name] = true
			table.insert(neo.list_mgr, name)
		end
		if ftable.notif_handler == true and not neo.list_notif[name] then
			neo.list_notif[name] = true
			table.insert(neo.list_notif, name)
		end
	end
end

function lib.lock_class(name, version, custom_key)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.lock_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	if not lib.is_exist(name, version) then
		return false, "mod doesn't exist"
	end
	
	if neo.plugin_registry[name .. "." .. version].lock == nil then
		neo.plugin_registry[name .. "." .. version].lock = custom_key or lib.generate_key()
	else
		lib.log_error(name .. " v" .. version .. " is already locked!", 1, name, version)
	end
end

function lib.unlock_class(name, version, key)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.unlock_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	if not lib.is_exist(name, version) then
		return false, "mod doesn't exist"
	end
	
	if neo.plugin_registry[name .. "." .. version].lock == key or mgr_key == key then
		local old_key = neo.plugin_registry[name .. "." .. version].lock
		neo.plugin_registry[name .. "." .. version].lock = nil
		return old_key
	end
end

function lib.notify(status, ...)
	args = ...
	if type(args) ~= "table" then
		args = {args}
	end
	
	if lib.is_ready(neo.current_notif) then
		lib.execute(neo.current_notif, "0", "notif", status, ...)
	else
		lib.require({{id = neo.current_notif, version = "0"}}, function()
			lib.notify(status, args)
		end)
	end
end

function lib.get_API()
	return neo.API
end

function lib.get_minor()
	return neo.minor
end

function lib.get_patch()
	return neo.patch
end

function lib.uninstall()
	lib.log_error("Attempting to uninstall Neoloader!", 3)
	lib.resolve_file("plugins/Neoloader/unins.lua")
end

function lib.generate_key()
	return SHA1(tostring(gk_get_microsecond() + math.random()))
end

function lib.plugin_read_str(name, version, header, key)
	name, version = lib.pass_ini_identifier(name, version)
	if err_han( type(name) ~= "string", "lib.plugin_read_str expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	if lib.is_exist(name, version) then
		local path = neo.plugin_registry[name .. "." .. version].plugin_regpath
		return gkini.ReadString2(tostring(header or "modreg"), tostring(key or "name"), "", path)
	end
end

function lib.get_path(plugin_id, version)
	plugin_id, ver = lib.pass_ini_identifier(plugin_id, ver)
	if err_han( type(plugin_id) ~= "string", "lib.get_path expected a string for its first argument, got " .. type(plugin_id) ) then
		return false, "plugin ID not a string"
	end
	--if libraries rely on multiple files but are also meant to be distributed with every plugin that requires them, this function will retrieve the stored "path" registered to the working library
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(plugin_id)
	end
	
	if lib.is_exist(plugin_id, version) then
		return neo.plugin_registry[plugin_id .. "." .. version].plugin_folder
	end
end

function lib.open_config()
	lib.execute(neo.current_mgr, lib.get_latest(neo.current_mgr), "open")
end

function lib.open_if_config()
	lib.execute(neo.current_if, lib.get_latest(neo.current_if), "open")
end

function lib.reload()
	if not neo.statelock then
		return
	end
	
	ProcessEvent("PRE_RELOAD_INTERFACE")
	
	--unregister commands
	if neo.clearCommands == "YES" then
		lib.log_error("Command clearing is enabled and will now execute", 3)
		local _, expected = lib.resolve_file("plugins/Neoloader/zcom.lua")
		local commands = GetRegisteredUserCommands()
		for i=1, #commands do
			if not expected[commands[i]] then
				RegisterUserCommand(commands[i], function() print("Error") end)
			end
		end
	end
	
	--delay till after START/PLUGINS_LOADED events
	ReloadInterface()
end

function lib.request_auth(name, callback)
	if err_han( type(callback) ~= "function", "lib.request_auth requires a callback function to recieve the auth key!") then
		return false
	end
	
	name = tostring(name or "<untitled>")
	
	local grant = iup.button {
		title = tprint("grant_auth", "Give Access"),
		action = function(self)
			callback(mgr_key)
			iup.GetDialog(self):destroy()
			if not PlayerInStation() and IsConnected() and HUD and HUD.dlg then
				HideAllDialogs()
				ShowDialog(HUD.dlg)
			end
		end,
	}
	
	local deny = iup.button {
		title = tprint("deny_auth", "Deny Access"),
		action = function(self)
			iup.GetDialog(self):destroy()
			if not PlayerInStation() and IsConnected() and HUD and HUD.dlg then
				HideAllDialogs()
				ShowDialog(HUD.dlg)
			end
		end,
	}
	
	local auth_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0 200 *",
		default_esc = deny,
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.frame {
					iup.vbox {
						alignment = "ACENTER",
						iup.fill {
							size = "%2",
						},
						iup.label {
							title = name .. " " .. tprint("request_auth", "is requesting management permission over Neoloader!"),
						},
						iup.fill {
							size = "%2",
						},
						iup.hbox {
							grant,
							iup.fill {
								size = "%4",
							},
							deny,
						},
						iup.fill {
							size = "%2",
						},
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	auth_diag:map()
	auth_diag:show()
	
end

function lib.get_whole_ver(semverstr)
	if err_han(type(semverstr) ~= "string", "lib.get_whole_ver() expects a string input!") then
		return false
	end

    local ver_str, meta_str = semverstr:match("^([^%+%-]+)(.*)$")
	if not ver_str then
		ver_str = ""
	end
    local ver_table = {}
    for num in ver_str:gmatch("%d+") do
        table.insert(ver_table, tonumber(num))
    end

    if #ver_table < 1 then
        ver_table = {0}
    end

    local ret_table = {ver_table, meta_str}
    return ret_table
end

function lib.compare_sem_ver(obj1, obj2)
    local ot1 = lib.get_whole_ver(obj1)
    local ot2 = lib.get_whole_ver(obj2)

    if not ot1 or not ot2 then
        return false
    end

    local ver1, meta1 = ot1[1], ot1[2]
    local ver2, meta2 = ot2[1], ot2[2]

    for i = 1, math.max(#ver1, #ver2) do
        local n1 = ver1[i] or 0
		local n2 = ver2[i] or 0
		if n1 ~= n2 then
            return n1 < n2 and -1 or 1
        end
    end

    if meta1 == "" and meta2 == "" then
        return 0
    elseif meta1 == "" then
        return -1
    elseif meta2 == "" then
        return 1
    else
        return meta1 < meta2 and -1 or 1
    end
end

function lib.set_load(auth, id, version, state)
	id, version = lib.pass_ini_identifier(id, version)
	auth = tostring(auth)
	id = tostring(id)
	version = tostring(version)
	
	if auth ~= mgr_key then
		return
	end
	
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(id)
	end
	
	local valid_states = {
		YES = true,
		NO = true,
		FORCE = true,
		AUTH = true,
	}
	if not valid_states[state] then
		state = "NO"
	end
	if lib.is_exist(id, version) then
		gkini.WriteString("Neo-pluginstate", id .. "." .. version, state)
		neo.plugin_registry[id .. "." .. version].nextload = state
		lib.log_error("Set load state for " .. id .. " v" .. version .. " to " .. state, 1, id, version)
	end
end

function lib.set_waiting(id, ver, state, key)
	id, ver = lib.pass_ini_identifier(id, ver)
	local valid_state = {
		["YES"] = 1,
		["NO"] = 0,
		[true] = 1,
		[false] = 0,
		["ON"] = 1,
		["OFF"] = 0,
		[1] = 1,
		[0] = 0,
	}
	state = valid_state[state] or 0
	id = tostring(id or "null")
	ver = tostring(ver or "0")
	if ver == "0" then
		ver = lib.get_latest(id)
	end
	if not key then
		return false, "waiting state key must be provided"
	elseif not lib.is_exist(id, ver) then
		return false, "mod to set waiting needs to exist"
	end
	
	mod = id .. "." .. ver
	if state > 0 then
		lib.log_error(mod .. " is now waiting", 1, id, ver)
		neo.plugin_registry[mod].dependent_freeze = 1
		neo.plugin_registry[mod].freeze_key = key
	elseif neo.plugin_registry[mod].dependent_freeze == 1 and key == neo.plugin_registry[mod].freeze_key then
		lib.log_error(mod .. " has reactivated", 1, id, ver)
		neo.plugin_registry[mod].dependent_freeze = 0
		lib.check_queue()
	end
end

function lib.lme_configure(cfg_option, new_val, auth)
	cfg_option = tostring(cfg_option)
	local define = configd[cfg_option]
	if not define then
		return false, "option does not exist"
	else
		if (type(define.valid) == "table" and define.valid[new_val] or define.valid == "ALL") and (define.need_auth == "YES" and auth == mgr_key or not define.need_auth) then
			lib.log_error("Configuration change: " .. cfg_option .. " >> " .. tostring(new_val), 1)
			neo[cfg_option] = new_val
			if define.type == "number" then
				gkini.WriteInt("Neoloader", define.key, tonumber(new_val) or 0)
			else
				gkini.WriteString("Neoloader", define.key, tostring(new_val))
			end
		end
	end
end

function lib.lme_get_config(cfg_option)
	if not cfg_option then
		--no options provided, return all valid options in table
		local cfg_available = {}
		for k, v in pairs(configd) do
			table.insert(cfg_available, k)
		end
		return cfg_available
	end
	
	cfg_option = tostring(cfg_option)
	local define = configd[cfg_option]
	if not define then
		return false, "option does not exist"
	else
		return neo[cfg_option]
	end
end

function lib.pass_ini_identifier(id, ver)
	--tests if id exists; if true, pass id/ver back to caller.
	--if not, check if its an INI file and pass id/ver from prebuild
	--	we don't build other INIs, only use ones from registry
	--else, let caller deal with it.
	if type(neo.plugin_registry[id]) == "table" then
		return id, ver
	elseif type(id) == "string" then
		local build = converted_dep_tables[id]
		
		if not build then
			return id, ver
		end
		
		return build.plugin_id, build.plugin_version
	else
		return id, ver
	end
end

function lib.update_state(id, ver, state_data)
	id, ver = lib.pass_ini_identifier(id, ver)
	ver = tostring(ver or 0)
	if ver == "0" then
		ver = lib.get_latest(id)
	end
	if not lib.is_exist(id, ver) then
		return false
	end
	
	if err_han(type(state_data) ~= "table", "lib.update_state() expects a table input!") then
		return false, "invalid input"
	end
	
	local ref = neo.plugin_registry[id .. "." .. ver]
	
	lib.log_error("State update for " .. id .. " v" .. ver, 1)
	for k, v in pairs {
		complete = "complete",
		name = "plugin_name",
		link = "plugin_link",
		plugin_name = "plugin_name",
		plugin_link = "plugin_link",
	} do
		if k == "complete" and state_data[k] ~= nil and ref[v] == false then
			lib.log_error("	state 'complete' >> Cannot be changed from false!", 1)
		elseif state_data[k] ~= nil then
			if type(state_data[k]) == type(ref[v]) then
				lib.log_error("	state '" .. tostring(k) .. "' >> " .. tostring(state_data[k]), 1)
				ref[v] = state_data[k]
				if k == "complete" then
					lib.log_error("\127FF0000" .. "Plugin encountered an error and triggered its own failure state.", 3, id, ver)
					lib.log_error("	stated error: " .. tostring(state_data.err_details or "no passed message"), 3, id, ver)
					lib.notify("PLUGIN_FAILURE", {
						plugin_id = id,
						version = ver,
						error_string = tostring(state_data.err_details or "self triggered error with no passed error message")
					})
				end
			else
				lib.log_error("	state '" .. tostring(k) .. "' failed to change to >> " .. tostring(state_data[k]) .. " type of " .. type(state_data[k]), 1)
				lib.log_error("	state was " .. tostring(ref[v]), 1)
			end
		end
	end

	
	neo.plugin_registry[id .. "." .. ver] = ref
end

function lib.block_trap(id, ver, func)
	id, ver = lib.pass_ini_identifier(id, ver)
	ver = tostring(ver or 0)
	if ver == "0" then
		ver = lib.get_latest(id)
	end
	if not lib.is_exist(id, ver) then
		return false
	end
	
	if err_han(type(func) ~= "function", "lib.block_trap() expects a function to trap, got " .. type(func)) then
		return false, "invalid input"
	end
	
	local status, err = pcall(func)
	if not status then
		lib.log_error("\127FF0000" .. "block_trap caught an error belonging to " .. id .. " v" .. ver, 4, id, ver)
		lib.log_error("	" .. tostring(err), 4, id, ver)
		lib.log_error(debug.traceback("	trace up to lib.block_trap(): "), 3, id, ver)
		
		lib.update_state(id, ver, {complete = false, err_details = err})
	end
end










local STOP_code = gkini.ReadString("Neoloader", "STOP", "")
if STOP_code ~= "" then
	gkini.WriteString("Neoloader", "STOP", "")
	gkinterface.GKSaveCfg()
	if STOP_code == "recovery" then
		error("The LME was instructed to load the recovery environment for the user. This error halts all continued execution.")
	else
		error("The LME recieved a STOP code of " .. STOP_code)
	end
end



lib.log_error("[timestat] library function setup: " .. tostring(timestat_advance()), 1)

do
	--check that all files exist
	for i, filepath in ipairs {
		"env.lua",
		"init.lua",
		"init.lua.version",
		"main.lua",
		"recovery.lua",
		"setup.lua",
		"unins.lua",
		"zcom.lua",
	} do
		if not gksys.IsExist("plugins/Neoloader/" .. filepath) then
			lib.log_error("Core file missing from Neoloader: " .. filepath, 4)
			neo.error_flag = true
		end
	end
	
	for i, filepath in ipairs {
		"config_override.ini",
		"neomgr2.lua",
		"neo_notif.lua",
	} do
		if not gksys.IsExist("plugins/Neoloader/" .. filepath) then
			lib.log_error("Optional file missing from Neoloader: " .. filepath, 2)
		end
	end
end

if neo.clearCommands == "YES" then
	--try to clear bad behavior from fake-registering commands after a reload
	lib.log_error("Command clearing is enabled and will now execute", 3)
	local _, expected = lib.resolve_file("plugins/Neoloader/zcom.lua")
	local commands = GetRegisteredUserCommands()
	for i=1, #commands do
		if not expected[commands[i]] then
			RegisterUserCommand(commands[i], function() print("Error: no such command") end)
		end
	end
end

mgr_key = lib.generate_key()


RegisterUserCommand("neodelete", function() lib.uninstall(mgr_key) end)
RegisterUserCommand("reload", lib.reload)

lib.log_error("[timestat] library extra environment setup: " .. tostring(timestat_advance()), 1)







--install check
if neo.init ~= neo.API then
	lib.log_error("Neoloader was updated! API was " .. tostring(neo.init), 3)
	lib.log_error("If Neoloader becomes unstable, use the recovery environment to uninstall, then reinstall!")
end

--update check
if neo.update_check < 1 then
	if neo.update_check == 0 then --Update pre-existing config from Neoloader 6.1.x -> 6.2.0
		lib.log_error("Neoloader was updated from v6.1.x or earlier - applying configuration fixes for v6.2.0", 3)
		
		local registry_fixes = {
			["plugins/Neoloader/neomgr.ini"] = "plugins/Neoloader/neomgr2.lua",
			["plugins/Neoloader/neo_notif.ini"] = "plugins/Neoloader/neo_notif.lua",
		}

		local counter = 0
		while true do
			counter = counter + 1
			local reg = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
			if reg == "" then
				break
			end

			if registry_fixes[reg] then
				gkini.WriteString("Neo-registry", "reg" .. tostring(counter), registry_fixes[reg])
				lib.log_error("patched registration entry for " .. reg .. " >> " .. registry_fixes[reg], 1)
			end
		end

		neo.update_check = 1
		gkini.WriteInt("Neoloader", "iUpdateCheck", 1)
	end
end

RegisterUserCommand("neo", function()
	print("\127FFFFFF" .. tprint("neoerrinit_1", "Neoloader failed to initialize a management interface and failed to handle the error too. You can use") .. " \127FFFF00/recovery\127FFFFFF " .. tprint("neoerrinit_2", "to open the LME recovery environment"))
end)


do --init process
	
	
	--setup use to occur here
	
	
	lib.log_error("Neoloader: Init process has started!\n\n", 2)
	
	lib.resolve_file("plugins/Neoloader/env.lua")
	--this contains variables that many of VO's public functions rely on.
	
	local registered_plugins = {} --list of registered ini files describing plugins
	
	local validqueue = {} --The registered plugins are filtered into this if their state is valid. Stage 2
	
	local valid_states = {
		["YES"] = true, --allow a plugin to load
		["NO"] = false, --disallow a plugin to load
		["FORCE"] = true, --force a plugin to load regardless of its dependencies; this is for development use only, not intended for regular users to use!
		["AUTH"] = true, --This plugin should be given the management key when it loads
	}
	
	timestat_step = gk_get_microsecond()
	--Init Stage 1: Loop through config.ini and find all registered plugins
	local counter = 0
	lib.log_error("Now searching config.ini for registered plugins...", 2)
	while true do
		--this loop repeats until an invalid file entry is recieved from Neo-registry in config.ini
		counter = counter + 1
		local file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
		if file == "" then
			--No file registered, this entry (and subsequent ones if config.ini isn't dirty) doesn't exist. Exit and move to next phase.
			counter = counter - 1
			break
		end
		table.insert(load_position_tracker, file)
		load_position_tracker[file] = #load_position_tracker
		
		
		local valid = gkini.ReadString2("modreg", "id", "null", file)
		if valid == "null" then
			--this file doesn't exist, or isn't meant to be a plugin package descriptor; we'll skip this entry.
			lib.log_error("	The plugin at position " .. tostring(counter) .. " appears broken or missing, and will not load!", 1)
			lib.log_error("	the file being accessed is " .. file, 1)
			--we need to increment the "number_plugins_registered" value here because otherwise new registrations will overwrite EXISTING entries in config.ini!!!
			neo.number_plugins_registered = neo.number_plugins_registered + 1
		else
			--this *appears* to be a Neoloader-compatible plugin, so lets add it to the queue
			table.insert(registered_plugins, file)
		end
	end
	
	lib.log_error("Neoloader found " .. tostring(counter) .. " plugins/libraries.", 2)
	lib.log_error("[timestat] Init stage 1: " .. tostring(timestat_advance()), 1)
	--Init Stage 2: build INI files and register information
	
	for k, v in ipairs(registered_plugins) do
		local id, version = silent_register(v)
		if id == false then
			--this plugin failed for some reason
			lib.log_error("	failed to create registry entry for " .. v, 3)
		else
			--the plugin's INI built and was added; now we see if it needs to be loaded
			local loadstate = gkreadstr("Neo-pluginstate", id .. "." .. version, "NEW")
			if loadstate == "NEW" then
				lib.log_error("	" .. id .. " v" .. version .. " is new; using default load state " .. neo.defaultLoadState, 1, id, version)
				loadstate = neo.defaultLoadState
				lib.set_load(mgr_key, id, version, neo.defaultLoadState)
			else
				lib.log_error("	load state for " .. id .. " v" .. version .. ": " .. loadstate, 1)
			end
			if valid_states[loadstate] == true then
				table.insert(validqueue, {id, version})
				if loadstate ~= "YES" then
					neo.plugin_registry[id .. "." .. version].flag = loadstate
				end
			end
		end
	end
	
	lib.log_error("Of those plugins, " .. tostring(#validqueue) .. " are set to be loaded\nNow breaking down dependency tree...", 2)
	lib.log_error("[timestat] Init stage 2: " .. tostring(timestat_advance()), 1)
	--[[Init Stage 3
		We have filtered down to only plugins that SHOULD run; now we need to figure their load order based on dependencies.
		
		1) Anything registered as the IF manager is run immediately, assuming it exists and is set to be loaded.
			IF managers will ALWAYS run the latest version installed, as they should not provide multiple local versions.
			
			if the IF manager doesn't exist, we run the default interface here.
		
		2) Everything else is checked for dependencies
			no dependency: Added immediately to the plugin_table, which is the "ready for launch"
			dependency found: plugin uses lib.require() handling
	]]--
	
	local valid_copy = copy_table(validqueue) --i should check if this is neccesary in the future
	local plugin_table = {}
	local these_are_loaded = {
		[1] = {},
	}
	local dependency_tree = {}
	
	--if if-manager exists, then launch NOW; remove from to-load category
	lib.log_error("Your current interface is: " .. neo.current_if, 2)
	if lib.is_exist(neo.current_if, lib.get_latest(neo.current_if)) and neo.plugin_registry[neo.current_if .. "." .. lib.get_latest(neo.current_if)].load == "YES" then
		lib.log_error("Attempting to launch the current interface: " .. neo.current_if, 2)
		local index = 0
		for k, v in ipairs(valid_copy) do
			--k: index of table
			--v: {name, version}
			if v[1] == neo.current_if then
				index = k
				break
			end
		end
		local obj = table.remove(valid_copy, index)
		--[[
		we need to manually active the plugin here; neo.plugin_registry[name.(latest)].plugin_path
		First, make sure its set to load; if not, failsafe to defaultUI
		also, we need to catch errors; if an error occurs, register a popup to the START event and failsafe
		]]--
		local pluginID = obj[1] .. "." .. obj[2]
		local status, err = lib.resolve_file(neo.plugin_registry[pluginID].plugin_path)
		if status == false then
			lib.log_error("Failed to launch the registered interface manager; failsafing to the DefaultUI", 3)
			dofile("vo/if.lua")
		else
			lib.log_error("Successfully loaded the registered interface manager!", 2)
			neo.plugin_registry[pluginID].complete = true
		end
		
		these_are_loaded[pluginID] = true
		table.insert(these_are_loaded[1], true)
	else
		--the if-manager set to load doesn't exist; we need to launch the default interface
		if neo.current_if == "vo-if" then
			lib.log_error("Now loading the default interface for Vendetta Online...", 2)
			dofile("vo/if.lua")
		else
			lib.log_error("Your interface does not exist or is not set to load; DefaultUI will be launched", 2)
			dofile("vo/if.lua")
		end
	end
	
	if neo.listPresorted == "YES" then
		lib.log_error("Config.ini claims to be presorted by an external application; dependency load ordering has been skipped!", 3)
	end
	
	for k, v in ipairs(valid_copy) do
		local obj = neo.plugin_registry[v[1] .. "." .. v[2]]
		if obj.compat == "YES" then
			lib.log_error(obj.plugin_id .. " v" .. obj.plugin_version .. " is a compatibility plugin!", 2)
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		elseif obj.flag == "FORCE" then
			lib.log_error("Skipping dependencies for " .. obj.plugin_id .. " v" .. obj.plugin_version .. "; development FORCE-load encountered", 3)
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		elseif neo.listPresorted == "YES" then
			lib.log_error("Skipped dependency check for " .. obj.plugin_id .. " v" .. obj.plugin_version, 3)
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		elseif (obj.plugin_dependencies == nil) or (#obj.plugin_dependencies == 0) then --no dependencies; this is a root object
			lib.log_error("No dependencies found for " .. obj.plugin_id .. " v" .. obj.plugin_version .. "; adding to load queue", 2)
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		else --There is a dependency
			lib.log_error("Dependencies found for " .. obj.plugin_id .. " v" .. obj.plugin_version, 2)
			for k2, v2 in ipairs(obj.plugin_dependencies) do
				if v2.ver_max == "~" then
					lib.log_error("		requires " .. v2.name .. " v" .. v2.version, 2)
				else
					lib.log_error("		requires " .. v2.name .. " from v" .. v2.version .. " to v" .. v2.ver_max, 2)
				end
			end
			lib.log_error("Adding " .. obj.plugin_id .. " to the delayed queue", 1)
			lib.require(obj.plugin_dependencies, function()
				local err_flag, err_detail = lib.activate_plugin(obj.plugin_id, obj.plugin_version, mgr_key)
				if err_flag == false then
					neo.error_flag = true
					table.insert(neo.plugin_registry[v[1] .. "." .. v[2]].errors, err_detail)
				end
			end, obj.plugin_id, obj.plugin_version)
		end
	end
	
	lib.log_error("[timestat] Init stage 3: " .. tostring(timestat_advance()), 1)
	
	--Init Stage 4
	
	if #these_are_loaded[1] == 0 then
		--if there are no "root" plugins/libraries to load, then we won't bother checking other plugins for dependencies.
		lib.log_error("No 'root' level plugins or libraries are loaded; skipping further checks...", 4)
		neo.error_flag = true
	else
		for k, v in ipairs(plugin_table) do
			local err_flag, err_detail = lib.activate_plugin(v[1], v[2], mgr_key)
			if err_flag == false then
				neo.error_flag = true
				table.insert(neo.plugin_registry[v[1] .. "." .. v[2]].errors, err_detail)
			end
		end
		
		lib.check_queue()
		
		lib.log_error("All plugins have been processed!", 2)
		ProcessEvent("LME_PLUGINS_LOADED")
		
		lib.log_error("[timestat] Init stage 4: " .. tostring(timestat_advance()), 1)
		if neo.error_flag == false then
			lib.notify("SUCCESS")
		end
	end
end

if lib.is_ready(neo.current_mgr) == false then
	--if the manager isn't found, try the bundled version
	if lib.is_ready("neomgr") == true then
		lib.log_error("The last management interface for Neoloader was not found; the bundled manager was loaded instead.", 3)
		lib.lme_configure("current_mgr", "neomgr", mgr_key)
	elseif lib.is_exist("neomgr") then
		lib.log_error("The last management interface for Neoloader was not found, and bundled manager is currently disabled!", 4)
		print(tprint("neoerr_rec1", "Neoloader failed to find an installed and enabled management interface; use /neo to force the bundled interface tool to load"))
		RegisterUserCommand("neo", function()
			lib.set_load(mgr_key, "neomgr", "0", "YES")
			lib.lme_configure("current_mgr", "neomgr", mgr_key)
			lib.reload()
		end)
	else
		lib.log_error("The last management interface for Neoloader was not found, and -nothing- was not found!", 4)
		print(tprint("neoerr_recsolve", "Neoloader failed to find a management interface; use /neo to open the recovery environment"))
		RegisterUserCommand("neo", function()
			gkini.WriteString("Neoloader", "STOP", "recovery")
			lib.reload()
		end)
	end
end

if lib.is_ready(neo.current_mgr) == true then
	local cur_version = lib.get_latest(neo.current_mgr)
	
	RegisterUserCommand("neo", function() lib.execute(neo.current_mgr, cur_version, "open") end)
	
	--lib.execute(neo.current_mgr, cur_version, "auth_key_receiver", mgr_key) --depreciated; auth_key_receiver now called during lib.activate
end

RegisterEvent(function()
	lib.check_queue()
	for k, v in ipairs(waiting_for_dependencies) do
		local id = v.owner_id
		local ver = v.owner_version
		if id and ver and lib.is_exist(id, ver) then
			lib.log_error("A dependency for " .. id .. " v" .. ver .. " was never resolved!", 3, id, ver)
		end
	end
	lib.log_error("[timestat] Standard plugin Loader completed in " .. tostring(gk_get_microsecond() - timestat_step), 2)
end, "PLUGINS_LOADED")

local function reset_handler()
	--used to verify options are properly saved, preventing authorization bypass when possible
	
	--enforce known load states for mods
	local plist = lib.get_gstate().pluginlist
	for k, v in ipairs(plist) do
		local new_state = neo.plugin_registry[v[1] .. "." .. v[2]].nextload
		if new_state then
			gkini.WriteString("Neo-pluginstate", v[1] .. "." .. v[2], new_state)
		else
			gkini.WriteString("Neo-pluginstate", v[1] .. "." .. v[2], lib.get_state(v[1], v[2]).load)
		end
	end
	
	--enforce known config options for neoloader
	for k, v in pairs(configd) do
		if v.type == "number" then
			gkini.WriteInt("Neoloader", v.key, neo[k])
		else
			gkini.WriteString("Neoloader", v.key, neo[k])
		end
	end
	
	--save the config file
	gkinterface.GKSaveCfg()
end

RegisterEvent(reset_handler, "UNLOAD_INTERFACE")
RegisterEvent(reset_handler, "QUIT")

lib.log_error("[timestat] Neoloader completed in " .. tostring(gk_get_microsecond() - timestat_neo_start), 2)
timestat_step = gk_get_microsecond()
lib.log_error("Neoloader has finished initial execution! The standard plugin loader will now take over.\n\n", 2)
ProcessEvent("LIBRARY_MANAGEMENT_ENGINE_COMPLETE")
