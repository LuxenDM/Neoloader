NEO_EXISTS = true --use lib/lib[0] instead if you are testing for a generic library management implementation

local plog
if gksys.IsExist("plugins/preload.lua") then
	plog = dofile("plugins/preload.lua")
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

--clean up and improve the timestat system
local gk_get_microsecond = gkmisc.GetGameTime

local timestat_neo_start = gk_get_microsecond()
local timestat_step = gk_get_microsecond()
local function timestat_advance()
	local next_step = gk_get_microsecond()
	local retval = next_step - timestat_step
	timestat_step = next_step
	return retval
end

print("\n\n\nVendetta Online is now starting.")
print("Neoloader is Initializing...")

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
neo = {
	version = {
		[1] = 5,
		[2] = 3,
		[3] = 1,
		[4] = "Beta",
	},
	notifications = {},
	log = {},
	error_flag = false, 
	plugin_registry = {}, --holds registered plugin details [id .. version]; [id].latest will provide version sstring of latest version for redirect
	plugin_container = {}, --holds a library's "reserved" data/functions.
	
	list_if = { --list of possible IFs
		[1] = "no_entry",
	},
	list_mgr = { --list of possible managers
		[1] = "no_entry",
	},
	
	init = gkini.ReadInt("Neoloader", "Init", 0),
	API = 3,
	minor = 7, --lib.find_file() and lib.set_load()
	patch = 0,
	
	pathlock = false,
	statelock = false,
	
	allowDelayedLoad = gkreadstr("Neoloader", "rAllowDelayedLoad", "NO"),
	allowBadAPIVersion = gkreadstr("Neoloader", "rAllowBadAPIVersion", "YES"),
	initLoopTimeout = gkreadint("Neoloader", "rInitLoopTimeout", 0),
	echoLogging = gkreadstr("Neoloader", "rEchoLogging", "YES"),
	defaultLoadState = gkreadstr("Neoloader", "rDefaultLoadState", "NO"),
	doErrPopup = gkreadstr("Neoloader", "rDoErrPopup", "NO"),
	protectResolveFile = gkreadstr("Neoloader", "rProtectResolveFile", "YES"),
	listPresorted = gkini.ReadString("Neoloader", "rPresortedList", "NO"),
	clearCommands = gkreadstr("Neoloader", "rClearCommands", "NO"),
	dbgFormatting = gkreadstr("Neoloader", "rDbgFormatting", "YES"),
	dbgIgnoreLevel = gkreadint("Neoloader", "iDbgIgnoreLevel", 2),
	
	number_plugins_registered = 0,
	
	current_if = gkreadstr("Neoloader", "if", ""),
	current_mgr = gkreadstr("Neoloader", "mgr", ""),
}

local mgr_key = 0
--[[
	This mgr_key is the random value used to prevent any plugin from calling functions we want to verify ONLY the user can initiate, such as forcing an uninstall or changing a plugin's state.
]]--











lib = {} --public functions container
lib[0] = "LME"
lib[1] = "Neoloader"

local waiting_for_dependencies = {} --storage for functions with unfulfilled dependencies tested by lib.require
local converted_dep_tables = {} --storage for build results of compiled ini files

function lib.log_error(msg, alert, id, version)
	alert = tonumber(alert or 2) or 2
	if alert < neo.dbgIgnoreLevel then
		return
	end
	val = tostring(msg) or ""
	id = tostring(id) or "null"
	version = tostring(version)
	if version == "0" then
		version = lib.get_latest(id)
	end
	if neo.dbgFormatting == "YES" then
		local status = "ALERT"
		for i, v in ipairs {
			[1] = "DEBUG",
			[2] = "INFO",
			[3] = "WARNING",
			[4] = "ERROR",
		} do
			status = i == alert and v or status
		end
		
		val = "[" .. os.date() .. "." .. tostring(gk_get_microsecond()) .. "] [" .. status .. "] " .. val
	end
	if neo.echoLogging == "YES" then
		console_print(val)
	end
	if lib.is_exist(id, version) then
		table.insert(neo.plugin_registry[id .. "." .. version].errors, val)
	end
	if plog then
		plog(val)
	end
	table.insert(neo.log, val)
end

RegisterEvent(function() neo.pathlock = true end, "LIBRARY_MANAGEMENT_ENGINE_COMPLETE")
--when the default loader is working, dofile() has the 'current working directory' appended in front of any path given. This is reset when all plugins are fully loaded.

RegisterEvent(function() neo.pathlock = false neo.statelock = true end, "PLUGINS_LOADED")
--when all plugins are loaded, it becomes impossible to create global variables because the sandbox metatable's "new index" is removed; to create globals the plugin must use declare("name", value) (but pluginders should do that anyways if their plugin has any execution post-load)





function lib.err_handle(test, log_msg)
	if log_msg == nil and type(test) == 'string' then
		--debug: err_handle test is a string and log_msg is nil
		log_msg = test
		test = true
	end
	if type(test) == "boolean" then
		if test == false then
			return false --returns inverse; test is the error condition, so returns true if there IS an error.
		else
			local err = debug.traceback("Neoloader captured an error: " .. tostring(log_msg))
			lib.log_error(err)
			lib.notify("CAPTURED_ERROR", err)
			if neo.doErrPopup == "YES" and neo.statelock == true then
				error(err)
			end
			return true
		end
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
	
	--lib.log_error("Attempting to find " .. file)
	
	local last_slash_index = string.find(file, "/[^/]*$")
		
	if last_slash_index then
		--the first argument was a path/to/file and not just a file; break apart and handle
		--lib.log_error("			first arg was a path/to/file")
		local path = string.sub(file, 1, last_slash_index)
		file = string.sub(file, last_slash_index + 1)
		
		table.insert(path_checks, {
			path .. file,
			"../" .. path .. file,
			"../../" .. path .. file,
		})
		--lib.log_error("			fixed to finding " .. file .. " with path provided: " .. path)
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
	
	--lib.log_error("trying these: ")
	
	local first_valid_path = false
	local valid_path_table = {}
	
	for index, path in ipairs(path_checks) do
		--lib.log_error("			" .. path[1])
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
		lib.log_error("unable to resolve file provided (" .. tostring(file) .. "); file not found")
		return false, "unable to find file"
	end
	
	local file_loaded
	lib.log_error("Attempting to resolve " .. tostring(pathtable[1][1]))
	for k, path_table in ipairs(pathtable) do
		for i=1, 3 do
			local status, err = loadfile(pathtable[k][i])
			if status then --success!
				file_loaded = status
				break
			else
				if not string.find(err, "No such file or directory") then
					lib.log_error("Unable to resolve file: " .. tostring(err or "error?"))
					return false, "error resolving file"
				end
			end
		end
		if file_loaded then
			break
		end
	end
	
	if file_loaded then
		if neo.protectResolveFile == "YES" then
			return pcall(file_loaded)
		else
			return true, file_loaded()
		end
	else
		return false, "unable to resolve file: file does not appear to exist or cannot be accessed using known methods"
	end
end

function lib.build_ini(iniFilePointer)
	if err_han( type(iniFilePointer) ~= "string" , "lib.build_ini expected a string (file path) as argument 1, got " .. type(iniFilePointer) ) then
		return false, "ini file path not a string"
	end
	local ifp = iniFilePointer --less typing
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
			lib.log_error("INI Builder failed: API Mismatch!")
			return false, "API mismatch"
		end
		
		if converted_dep_tables[id .. pluginversion] then
			--this plugin has already been registered
			--pass along existing table and exit
			return converted_dep_tables[id .. pluginversion]
		end
		
		local author = getstr("modreg", "author", "", ifp)
		local website = getstr("modreg", "website", "", ifp)
		local pluginpath = getstr("modreg", "path", "", ifp)
		local pluginfolderpath = string.sub(iniFilePointer, 1, string.find(iniFilePointer, "/[^/]*$"))
		
		local dependents = {}
		if getint("dependency", "num_dependents", 0, ifp) > 0 then
			for i=1, getint("dependency", "num_dependents", 0, ifp) do
				table.insert(dependents, {
					name = getstr("dependency", "depid" .. tostring(i), "null", ifp),
					version = getstr("dependency", "depvs" .. tostring(i), "0", ifp),
				})
			end
		end
		
		converted_dep_tables[id .. pluginversion] = {
			plugin_id = id,
			plugin_type = plugintype,
			plugin_name = name,
			plugin_version = pluginversion,
			plugin_author = author,
			plugin_link = website,
			plugin_path = pluginpath,
			plugin_folder = pluginfolderpath,
			plugin_dependencies = dependents,
			plugin_regpath = iniFilePointer,
		}
		return converted_dep_tables[id .. pluginversion]
	end
end

function lib.resolve_dep_table(intable)
	--returns true or false if the table of dependencies have been met
	if err_han( type(intable) ~= "table", "lib.resolve_dep_table expected a table for argument 1, got " .. type(intable) ) then
		return false, "input not a table"
	end
	local status = true
	for k, v in ipairs(intable) do
		if err_han( type(v) ~= "table", "lib.resolve_dep_table was given an improperly formatted table; table values should be tables!" ) then
			return false, "bad table format"
		else
			v.name = tostring(v.name or "null")
			v.version = tostring(v.version or "0")
			if v.version == "0" then
				v.version = lib.get_latest(v.name)
			end
			for i, v2 in ipairs {
				--lib.is_exist(v.name, v.version),
				lib.is_ready(v.name, v.version),
				neo.plugin_registry[v.name .. "." .. v.version] and neo.plugin_registry[v.name .. "." .. v.version].dependent_freeze < 1,
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
		--duplicate plugin entry in config.ini; we need to remove this plugin from the config
		--and mark the original with a triggered error
		return false, 304
	else
		table.insert(neo.plugin_container, {})
		neo.number_plugins_registered = neo.number_plugins_registered + 1
		
		local data = copy_table(iniTable)
		data.dependencies_met = false
		data.complete = false --true when all checks complete and plugin is run
		data.dependent_freeze = 0
		data.load = gkreadstr("Neo-pluginstate", data.plugin_id .. "." .. data.plugin_version, neo.defaultLoadState)
		data.index = #neo.plugin_container
		data.load_position = neo.number_plugins_registered
		data.errors = {}
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
		
		lib.log_error("Added " .. id .. " v" .. data.plugin_version .. " to Neoloader's plugin registry!")
		neo.plugin_registry[id .. "." .. data.plugin_version] = data
		return id, data.plugin_version
	end
end	

function lib.register(iniFilePointer)
	if err_han( type(iniFilePointer) ~= "string", "lib.register expected a string (file path) for argument 1, got " .. type(iniFilePointer) ) then
		return false, "file pointer not a string"
	end
	--used to add new plugins/libraries to Neoloader
	local id = gkini.ReadString2("modreg", "id", "null", iniFilePointer)
	if err_han( id == "null", "lib.register could not open the plugin at " .. iniFilePointer) then
		return false, "invalid file pointer"
	end
	local iniTable, errid = lib.build_ini(iniFilePointer)
	if err_han( iniTable == false, "lib.register could not build the INI file at " .. iniFilePointer .. "; error recieved was " .. tostring(errid) ) then
		return false, errid
	end
	neo.listPresorted = "NO"
	gkini.WriteString("Neoloader", "rPresortedList", "NO")
	lib.log_error("Attempting to register data for " .. id .. " v" .. iniTable.plugin_version)
	if lib.is_exist(id, iniTable.plugin_version) then
		--don't use the error handler here; duplicate registration can be attempted and shouldn't trigger errors for the user
		--	multiple plugins may use the same sharable library
		--duplicate plugin entry in config.ini; we need to remove this plugin
		--and mark the original with a triggered error
		lib.log_error("			plugin registration failed: duplicate plugin!")
		return false, "Duplicate of plugin exists"
	else
		table.insert(neo.plugin_container, {})
		neo.number_plugins_registered = neo.number_plugins_registered + 1
		
		local data = copy_table(iniTable)
		data.dependencies_met = false
		data.complete = false
		data.dependent_freeze = 0
		data.load = false
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
		lib.notify("NEW_REGISTRY", id, data.plugin_version or "0")
		--write the registration to config.ini
		gkini.WriteString("Neo-pluginstate", (data.plugin_id .. "." .. (data.plugin_version or "0")), "NO")
		gkini.WriteString("Neo-registry", "reg" .. tostring(neo.number_plugins_registered), iniFilePointer)
		
		neo.plugin_registry[id .. "." .. (data.plugin_version or "0")] = data
		return true
	end
end

function lib.require(intable, callback)
	if err_han( type(intable) ~= "table", "lib.require expected a table for argument 1, got " .. type(intable) )  then
		return false, "dependency list not a table"
	end
	if err_han( type(callback) ~= "function", "lib.require expected a function for argument 2, got " .. type(callback) ) then
		return false, "callback not a function"
	end
	if lib.resolve_dep_table(intable) then
		callback()
	else
		table.insert(waiting_for_dependencies, {intable, callback})
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
	if err_han( type(name) ~= "string", "lib.is_exist expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if type(neo.plugin_registry[name]) ~= "table" then
		return false, "doesn't exist as ID only"
	else
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
end

function lib.is_ready(id, version)
	if err_han( type(id) ~= "string", "lib.is_ready expected a string for its first argument, got " .. type(id) ) then
		return false, "plugin ID not a string"
	end
	if lib.is_exist(id) then
		version = tostring(version or 0)
		if version == "0" then
			version = lib.get_latest(id)
		end
		
		if lib.is_exist(id, version) then
			if neo.plugin_registry[id .. "." .. version].complete == true then
				return true
			else
				return false
			end
		end
	end
end

function lib.activate_plugin(id, version, verify_key)
	local time_start = gk_get_microsecond()
	lib.log_error("attempting activation of " .. tostring(id) .. "." .. tostring(version))
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
	if verify_key == mgr_key then
		if lib.is_exist(id, version) then
			local modreg = neo.plugin_registry[plugin_id]
			if lib.resolve_dep_table(modreg.plugin_dependencies) or modreg.flag == "FORCE" then
				if valid_load_states[lib.get_state(id, version).load] then
					if modreg.plugin_path ~= "" then
						local status, err = lib.resolve_file(modreg.plugin_path, nil, modreg.plugin_folder)
						if status then
							modreg.complete = true
							lib.log_error("Activated plugin " .. plugin_id .. " with Neoloader!")
							if (neo.statelock == false) or (neo.allowDelayedLoad == "YES") then
								if neo.plugin_registry[plugin_id].dependent_freeze < 1 then
									lib.check_queue()
								end
							end
						else
							lib.log_error("\127FF0000Failed to activate " .. plugin_id .. "\127FFFFFF")
							lib.log_error("		error message: " .. tostring(err))
							lib.notify("PLUGIN_FAILURE", id, version)
							return false, "failed to activate, " .. err or "?"
						end
					else
						modreg.complete = true
						lib.log_error("Plugin " .. plugin_id .. " has no file to activate (compatibility plugin?)")
						if (neo.statelock == false) or (neo.allowDelayedLoad == "YES") then
							--can't be frozen if there's no activated code
							lib.check_queue()
						end
					end
					if modreg.flag == "AUTH" then
						lib.execute(id, version, "mgr_key", mgr_key)
					end
					
					neo.plugin_registry[plugin_id] = modreg
					
				else
					lib.log_error("Attempted to activate " .. plugin_id .. " but it's load state is 'NO'!")
					return false, "load state is NO"
				end
			else
				lib.log_error("Attempted to activate " .. plugin_id .. " but its dependencies aren't fulfilled!")
				return false, "unmatched dependencies"
			end
		else
			lib.log_error("Attempted to activate " .. plugin_id .. " but it doesn't exist!")
			--don't return false, no plugin ID to report to init
		end
	else
		lib.log_error("Attempted to activate a plugin, but key is incorrect!")
		--don't return false, no plugin ID to report to init
	end
	
	lib.log_error("[timestat] activation took: " .. tostring(gk_get_microsecond() - time_start), 1)
end

function lib.get_latest(id)
	id = tostring(id or "null")
	if lib.is_exist(id) then
		local version = tostring(neo.plugin_registry[id].latest)
		if version == "0" then
			version = neo.plugin_registry[id][#neo.plugin_registry[id]]
		end
		return version
	end
	return "?"
end


function lib.get_state(name, version)
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
		}
	end
	
	return rettable
end

function lib.get_gstate()
	local data = {}
	data.version = neo.version
	data.pathlock = neo.pathlock
	data.statelock = neo.statelock
	data.manager = neo.current_mgr
	data.ifmgr = neo.current_if
	data.major = neo.API
	data.minor = neo.minor
	data.patch = neo.patch
	if not lib.is_exist(neo.current_if) then
		data.ifmgr = "vo-if"
	end
	data.notifications = neo.notifications
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
	
	data.mgr_list = neo.list_mgr
	data.if_list = neo.list_if
	
	data.newstate = neo.defaultLoadState
	data.format_log = neo.dbgFormatting
	data.log_level = neo.dbgIgnoreLevel
	
	return data
end

function lib.execute(name, version, func, ...)
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
				lib.log_error("Attempted to call " .. name .. " v" .. version .. " class function " .. func .. " but it doesn't exist")
			end
		else
			lib.log_error("Attempted to call " .. name .. " v" .. version .. " but it isn't loaded")
		end
	else
		lib.log_error("Attempted to call " .. name .. " v" .. version .. " but it doesn't exist")
	end
	return retval
end

function lib.get_class(name, version)
	if err_han( type(name) ~= "string", "lib.get_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	
	if lib.is_exist(name, version) then
		if lib.get_state(name, version).complete == true then
			local index = neo.plugin_registry[name .. "." .. version].index
			return copy_table(neo.plugin_container[index])
		end
	end
end

function lib.set_class(name, version, ftable)
	if err_han( type(name) ~= "string", "lib.set_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	lib.log_error("Setting class for " .. name .. " v" .. version, 1)
	if type(ftable) ~= "table" then
		ftable = {ftable or 0} --is the or_0 neccesary here?
	end
	if lib.is_exist(name, version) then
		if (neo.plugin_registry[name .. "." .. version].lock == nil) and (neo.plugin_registry[name .. "." .. version].load == "YES") then
			local index = neo.plugin_registry[name .. "." .. version].index
			neo.plugin_container[index] = ftable
			if ftable.IF == true then
				table.insert(neo.list_if, name)
			end
			if ftable.mgr == true then
				table.insert(neo.list_mgr, name)
			end
		end
	end
end

function lib.lock_class(name, version, custom_key)
	if err_han( type(name) ~= "string", "lib.lock_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	if lib.is_exist(name, version) then
		if neo.plugin_registry[name .. "." .. version].lock == nil then
			neo.plugin_registry[name .. "." .. version].lock = custom_key or lib.generate_key()
		else
			lib.log_error(name .. " v" .. version .. " is already locked!")
		end
	end
end

function lib.unlock_class(name, version, key)
	if err_han( type(name) ~= "string", "lib.unlock_class expected a string for its first argument, got " .. type(name) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(name)
	end
	if lib.is_exist(name, version) then
		if neo.plugin_registry[name .. "." .. version].lock == key or mgr_key == key then
			local old_key = neo.plugin_registry[name .. "." .. version].lock
			neo.plugin_registry[name .. "." .. version].lock = nil
			return old_key
		end
	end
end

function lib.notify(status, ...)
	args = ...
	if type(args) ~= "table" then
		args = {args}
	end
	
	if lib.is_ready(neo.current_mgr) then
		lib.execute(neo.current_mgr, lib.get_latest(neo.current_mgr), "notif", status, ...)
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

function lib.uninstall(verify_key)
	if verify_key == mgr_key then
		lib.log_error("Attempting to uninstall Neoloader!")
		declare("NEO_UNINSTALL", true)
		declare("NEO_UNINS_KEY", mgr_key)
		lib.resolve_file("plugins/Neoloader/setup.lua")
	else
		lib.log_error("A mod attempted uninstallation of Neoloader, but the verification key did not match!")
	end
end

function lib.generate_key()
	return SHA1(tostring(gk_get_microsecond() + math.random()))
end

function lib.plugin_read_str(name, version, header, key)
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
	if err_han( type(plugin_id) ~= "string", "lib.get_path expected a string for its first argument, got " .. type(plugin_id) ) then
		return false, "plugin ID not a string"
	end
	--[[
	if libraries rely on multiple files but are also meant to be distributed with every plugin that requires them, this function will retrieve the stored "path" registered to the working library, stripping it of the plugin's index.lua
	]]--
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
	if neo.statelock then
		ProcessEvent("PRE_RELOAD_INTERFACE")
		
		--unregister commands
		if neo.clearCommands == "YES" then
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
end

function lib.request_auth(name, callback)
	if err_han( type(callback) ~= "function", "lib.request_auth requires a callback function to recieve the auth key!") then
		return false
	end
	
	name = tostring(name or "<untitled>")
	
	local grant = iup.button {
		title = "Give Access",
		action = function(self)
			callback(mgr_key)
			iup.GetDialog(self):destroy()
			if not PlayerInStation() and IsConnected()  and HUD and HUD.dlg then
				HideAllDialogs()
				ShowDialog(HUD.dlg)
			end
		end,
	}
	
	local deny = iup.button {
		title = "Deny Access",
		action = function(self)
			iup.GetDialog(self):destroy()
			if not PlayerInStation() and IsConnected()  and HUD and HUD.dlg then
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
							title = name .. " is requesting management permission over Neoloader!",
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
	auth = tostring(auth)
	id = tostring(id)
	version = tostring(version)
	
	if auth == mgr_key then
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
		end
	end
end

function lib.set_waiting(id, ver, state, key)
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
	elseif lib.is_exist(id, ver) then
		mod = id .. "." .. ver
		if state > 0 then
			lib.log_error(mod .. " is now waiting", 1)
			neo.plugin_registry[mod].dependent_freeze = 1
			neo.plugin_registry[mod].freeze_key = key
		elseif neo.plugin_registry[mod].dependent_freeze == 1 and key == neo.plugin_registry[mod].freeze_key then
			lib.log_error(mod .. " has reactivated", 1)
			neo.plugin_registry[mod].dependent_freeze = 0
			lib.check_queue()
		end
	end
end
















lib.log_error("[timestat] library function setup: " .. tostring(timestat_advance()))

do
	--check that all files exist
	for i, filepath in ipairs {
		"config_override.ini",
		"env.lua",
		"init.lua",
		"init.lua.version",
		"main.lua",
		"setup.lua",
		"zcom.lua",
	} do
		if not gksys.IsExist("plugins/Neoloader/" .. filepath) then
			lib.log_error("Core file missing from Neoloader: " .. filepath)
			neo.error_flag = true
		end
	end
	
	for i, filepath in ipairs {
		"neomgr.ini",
		"neomgr.lua",
	} do
		if not gksys.IsExist("plugins/Neoloader/" .. filepath) then
			lib.log_error("Optional file missing from Neoloader: " .. filepath)
		end
	end
end

if neo.clearCommands == "YES" then
	--try to clear bad behavior from fake-registering commands after a reload
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

lib.log_error("[timestat] library extra environment setup: " .. tostring(timestat_advance()))







--init process
--you need to recheck your notes for changes both above and below this

--[[
What we do here:
	1) Check and set up config.ini if this is the first time Neoloader is running. No plugins will be loaded (everything SHOULD be load=NO), so break and exit.
	2) Loop through config.ini's [Neo-registry] to obtain every ini file pointer. loop until "null" is reached.
	3) Resolve every file pointer and build the neccesary table. Missing files are ignored (not removed! That could add a "null" in between existing elements; create a seperate tool that will rebuild and clean the registry later!!!!)
	4) check every plugin state [name.version], default to NO. if YES or FORCE, add to the processing table.
	
	5) Begin processing the library table to sort into load order.
		5a) The plugin registered as the active interface manager is loaded immediately if it exists; otherwise, launch the default interface NOW
		5b) Libraries with no dependencies are added to the sorted queue immediately
		5c) Libraries are sorted based on their dependency tree (brute force sorting)
		5d) plugins are queued after libraries, but otherwise have the same rules
	6) Process the queue and load the plugins
	
	We need to make sure we are properly adding items to plugin_registry even if they don't get loaded. Use the silent registration (and verify that is doing what we want!!!)
	
	TODO: Add more logging to this stuff!
]]--

if neo.init ~= neo.API then
	lib.log_error("Installing Neoloader for the first time!")
	gkini.WriteString("Neoloader", "installing", "now")
	NEO_UNINSTALL = false
	NEO_FIRST_INSTALL = mgr_key
	lib.resolve_file("plugins/Neoloader/setup.lua")
	dofile("vo/if.lua")
	
elseif gkini.ReadString("Neoloader", "installing", "done") == "now" then
	--there was an error during installation; abort and bug the user!
	lib.log_error("There was an error during the last installation! stub handler...", 4)
	--dumptable(neo)
	neo.error_flag = true
	dofile("vo/if.lua")
	RegisterUserCommand("neodelete", function() lib.uninstall(mgr_key) end)
	RegisterEvent(function() print("There was a catastrophic error while trying to setup Neoloader; please contact Luxen and provide your errors.log and config.ini") print("You can use /neodelete to try and remove Neoloader") end, "START")
	return
else
	lib.log_error("\nNeoloader: Init process has started!")
	
	lib.resolve_file("plugins/Neoloader/env.lua")
	--this contains variables that many of VO's public functions rely on.
	if gkini.ReadString("Neoloader", "installing", "finishing") == "finishing" then
		gkini.WriteString("Neoloader", "installing", "done")
		--notification for first-time installation
	end
	
	local registered_plugins = {} --list of registered ini files describing plugins; we cycle through everything in neo-registry in the config file. We check to make sure the file exists; if it does, we'll add it to this queue. Stage 1
	
	local validqueue = {} --The registered plugins are filtered into this if their state is valid. Stage 2
	
	local lopqueue = {} --load-order-processing queue; plugins and libs are added in order of their dependencies and subcategories. If we have a plugin registered as the active interface manager, that gets loaded immediately, and doesn't enter this queue. Stage 3
	
	local valid_states = {
		["YES"] = true, --allow a plugin to load
		["NO"] = false, --disallow a plugin to load
		["FORCE"] = true, --force a plugin to load regardless of its dependencies; this is for development use only, not intended for regular users to use!
		["AUTH"] = true, --This plugin should be given the management key when it loads
	}
	
	timestat_step = gk_get_microsecond()
	--[[Init Stage 1
		We want to loop through config.ini and find all registered plugins.
		These are added to the registered_plugins queue.
			Actual state checking and building the ini doesn't happen yet.
	]]--
	local counter = 0
	while true do
		--this loop repeats until an invalid file entry is recieved from Neo-registry in config.ini
		counter = counter + 1
		local file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
		if file == "" then
			--No file registered, this entry (and subsequent ones if config.ini isn't dirty) doesn't exist. Exit and move to next phase.
			counter = counter - 1
			break
		end
		
		local valid = gkini.ReadString2("modreg", "id", "null", file)
		if valid == "null" then
			--this file doesn't exist, or isn't meant to be a plugin package descriptor; we'll skip this entry.
			lib.log_error("The plugin at position " .. tostring(counter) .. " appears broken or missing, and will not load!", 1)
			lib.log_error("the file being accessed is " .. file, 1)
			--we need to increment the "number_plugins_registered" value here because otherwise new registrations will overwrite EXISTING entries in config.ini!!!
			neo.number_plugins_registered = neo.number_plugins_registered + 1
		else
			--this *appears* to be a Neoloader-compatible plugin, so lets add it to the queue
			table.insert(registered_plugins, file)
		end
	end
	
	lib.log_error("Neoloader found " .. tostring(counter) .. " plugins/libraries.")
	lib.log_error("[timestat] Init stage 1: " .. tostring(timestat_advance()), 1)
	--[[Init Stage 2
		Everything in the registered plugins queue should be valid, working plugins; now, we build and add these to Neoloader's registry and give them a container. execution doesn't happen yet, and plugins are added even if they won't be run; we need to track what exists, and that's what is handled here.
	]]--
	
	for k, v in ipairs(registered_plugins) do
		local id, version = silent_register(v)
		--yarr
		if id == false then
			--this plugin failed for some reason
			lib.log_error("failed to create registry entry for " .. v, 3)
		else
			--the plugin's INI built and was added; now we see if it needs to be loaded
			local loadstate = gkreadstr("Neo-pluginstate", id .. "." .. version, "NO")
			if valid_states[loadstate] == true then
				table.insert(validqueue, {id, version})
				if loadstate ~= "YES" then
					neo.plugin_registry[id .. "." .. version].flag = loadstate
				end
			end
		end
	end
	
	lib.log_error("Of those plugins, " .. tostring(#validqueue) .. " are set to be loaded\nNow breaking down dependency tree...")
	lib.log_error("[timestat] Init stage 2: " .. tostring(timestat_advance()), 1)
	--[[Init Stage 3
		We have filtered down to only plugins that SHOULD run; now we need to figure their load order based on dependencies.
		
		1) Anything registered as the IF manager is run immediately, assuming it exists and is set to be loaded.
			IF managers will ALWAYS run the latest version installed, as they should not provide multiple local versions.
			
			if the IF manager doesn't exist, we run the default interface here.
		
		2) Everything else is checked for dependencies
			no dependency: Added immediately to the plugin_table, which is the "ready for launch"
			dependency found: plugin is added to a table dependency_tree
				tree {
					[dependency_1] = {
						plugin_dependent_on_dep_1,
						...
					},
					...
				}
			plugins with multiple dependencies will be added to several keys here, and this is iterated over in stage 4.
			
		This seems like an expensive part of the init process (in how long it takes to complete, but that comes from launching the default interface.
		If you use MultiUI with barebones or another lightweight UI, this is *drastically* faster
	]]--
	
	local valid_copy = copy_table(validqueue) --i should check if this is neccesary in the future
	local lib_table = {}
	local plugin_table = {}
	local these_are_loaded = {
		[1] = {},
	}
	local dependency_tree = {}
	
	--if if-manager exists, then launch NOW; remove from to-load category
	lib.log_error("Your current interface is: " .. neo.current_if)
	if lib.is_exist(neo.current_if, lib.get_latest(neo.current_if)) and neo.plugin_registry[neo.current_if .. "." .. lib.get_latest(neo.current_if)].load == "YES" then
		lib.log_error("Attempting to quick-launch the current interface: " .. neo.current_if)
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
			lib.log_error("Successfully loaded the registered interface manager!")
			neo.plugin_registry[pluginID].complete = true
		end
		
		these_are_loaded[pluginID] = true
		table.insert(these_are_loaded[1], true)
	else
		--the if-manager set to load doesn't exist; we need to launch the default interface
		lib.log_error("Your interface does not exist or is not set to load; DefaultUI will be launched")
		dofile("vo/if.lua")
	end
	
	if neo.listPresorted == "YES" then
		lib.log_error("WARNING! Config.ini claims to be presorted by an external application; dependency load ordering has been skipped!", 3)
	end
	
	for k, v in ipairs(valid_copy) do
		local obj = neo.plugin_registry[v[1] .. "." .. v[2]]
		if (obj.plugin_dependencies == nil) or (#obj.plugin_dependencies == 0) then --no dependencies; this is a root object
			lib.log_error("No dependencies found for " .. obj.plugin_id .. " v" .. obj.plugin_version .. "; adding to instant processing queue")
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		elseif obj.flag == "FORCE" then
			lib.log_error("Skipping dependencies for " .. obj.plugin_id .. " v" .. obj.plugin_version .. "; development FORCE-load encountered")
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		elseif neo.listPresorted == "YES" then
			lib.log_error("Skipped dependency check for " .. obj.plugin_id .. " v" .. obj.plugin_version)
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		else --There is a dependency
			lib.log_error("Dependencies found for " .. obj.plugin_id .. " v" .. obj.plugin_version)
			for k2, v2 in ipairs(obj.plugin_dependencies) do
				lib.log_error("			requires " .. v2.name .. " v" .. v2.version)
			end
			lib.log_error("Adding " .. obj.plugin_id .. " to the delayed queue", 1)
			lib.require(obj.plugin_dependencies, function()
				local err_flag, err_detail = lib.activate_plugin(obj.plugin_id, obj.plugin_version, mgr_key)
				if err_flag == false then
					neo.error_flag = true
					table.insert(neo.plugin_registry[v[1] .. "." .. v[2]].errors, err_detail)
				end
			end)
		end
	end
	
	lib.log_error("[timestat] Init stage 3: " .. tostring(timestat_advance()), 1)
	
	--[[Init Stage 4
	We have broken the plugins down to show what their dependent on; we now reverse-built this into a linear list so all of them that CAN be loaded, are.
	
	todo: look into other methods of ordering; we use a brute-force check, which is likely not so efficient. shouldn't matter unless there are LOTS of plugins, but best practice is to pre-prepare!
	
	We already have "root" libraries and plugins loaded. Here, we loop through the table "dependency_tree" and see IF a plugin can be loaded, based on what's already in the plugin/library tables.
	]]--
	
	if #these_are_loaded[1] == 0 then
		--if there are no "root" plugins/libraries to load, then we won't bother checking other plugins for dependencies.
		lib.log_error("No 'root' level plugins or libraries are loaded; skipping further checks...", 4)
		neo.error_flag = true
		lib.notify("ROOT_FAILURE")
	else
		for k, v in ipairs(plugin_table) do
			local err_flag, err_detail = lib.activate_plugin(v[1], v[2], mgr_key)
			if err_flag == false then
				neo.error_flag = true
				table.insert(neo.plugin_registry[v[1] .. "." .. v[2]].errors, err_detail)
			end
		end
		
		lib.check_queue()
		
		lib.log_error("All plugins have been loaded!")
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
		lib.log_error("The last management interface for Neoloader was not found; the bundled manager was loaded instead.")
		neo.current_mgr = "neomgr"
	else
		lib.log_error("The last management interface for Neoloader was not found, and bundled manager is not available for use.")
		print("Neoloader failed to find an installed and enabled management interface; use /neomgr to force the bundled interface tool to load")
		RegisterUserCommand("neomgr", function()
			UnregisterUserCommand("neomgr")
			lib.set_load(mgr_key, "neomgr", "1", "YES")
			lib.reload()
		end)
	end
end
if lib.is_ready(neo.current_mgr) == true then
	local cur_version = lib.get_latest(neo.current_mgr)
	
	RegisterUserCommand("neo", function() lib.execute(neo.current_mgr, cur_version, "open") end)
	
	lib.execute(neo.current_mgr, cur_version, "mgr_key", mgr_key)
end

RegisterEvent(function()
	lib.log_error("[timestat] Standard plugin Loader completed in " .. tostring(gk_get_microsecond() - timestat_step))
end, "PLUGINS_LOADED")

RegisterEvent(function()
	--enforce known load states for plugins
	local plist = lib.get_gstate().pluginlist
	for k, v in ipairs(plist) do
		local new_state = neo.plugin_registry[v[1] .. "." .. v[2]].nextload
		if new_state then
			gkini.WriteString("Neo-pluginstate", v[1] .. "." .. v[2], new_state)
		else
			gkini.WriteString("Neo-pluginstate", v[1] .. "." .. v[2], lib.get_state(v[1], v[2]).load)
		end
	end
	
	gkinterface.GKSaveCfg()
	
end, "UNLOAD_INTERFACE")

lib.log_error("[timestat] Neoloader completed in " .. tostring(gk_get_microsecond() - timestat_neo_start))
timestat_step = gk_get_microsecond()
lib.log_error("Neoloader has finished initial execution! The standard plugin loader will now take over.\n\n")
ProcessEvent("LIBRARY_MANAGEMENT_ENGINE_COMPLETE")