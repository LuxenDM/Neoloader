NEO_EXISTS = true --use lib/lib[0] instead if you are testing for a generic library management implementation

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
local neo = {
	version = {
		[1] = 5,
		[2] = 1,
		[3] = "Private Beta Release",
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
	patch = 2, --lib.reload added
	
	pathlock = false,
	statelock = false,
	
	allowDelayedLoad = gkreadstr("Neoloader", "rAllowDelayedLoad", "NO"),
	allowBadAPIVersion = gkreadstr("Neoloader", "rAllowBadAPIVersion", "YES"),
	initLoopTimeout = gkreadint("Neoloader", "rInitLoopTimeout", 0),
	echoLogging = gkreadstr("Neoloader", "rEchoLogging", "YES"),
	defaultLoadState = gkreadstr("Neoloader", "rDefaultLoadState", "NO"),
	doErrPopup = gkreadstr("Neoloader", "rDoErrPopup", "YES"),
	
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

function lib.log_error(...)
	if neo.echoLogging == "YES" then
		console_print(...)
	end
	table.insert(neo.log, ...)
end

RegisterEvent(function() neo.pathlock = true end, "LIBRARY_MANAGEMENT_ENGINE_COMPLETE")
--when the default loader is working, dofile() has the 'current working directory' appended in front of any path given. This is reset when all plugins are fully loaded.

RegisterEvent(function() neo.pathlock = false neo.statelock = true end, "PLUGINS_LOADED")
--when all plugins are loaded, it becomes impossible to create global variables because the sandbox metatable's "new index" is removed; to create globals the plugin must use declare("name", value) (but pluginders should do that anyways if their plugin has any execution post-load)





function lib.err_handle(test, log_msg)
	if log_msg == nil and type(test) == 'string' then
		console_print("debug: err_handle test is a string and log_msg is nil")
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

function lib.resolve_file(file, path, path2)
	if err_han( type(file) ~= "string" , "lib.resolve_file expected a string as argument 1, got " .. type(file) ) then
		return false, "file not a string"
	end
	if err_han( type(path) ~= "string" and path ~= nil , "lib.resolve_file expected nil or a string for argument 2, got " .. type(path) ) then
		return false, "path not a string or nil"
	end
	if path == nil then
		--assume that we were given file = path/to/file.lua; we extract the path ourselves. thank stack overflow for the answer here.
		local last_slash_index = string.find(file, "/[^/]*$")
		
		if not last_slash_index then
			path = ""
		else
			path = string.sub(file, 1, last_slash_index)
			file = string.sub(file, last_slash_index + 1)
		end
		
		--path, file = string.match(file, "(.*)([^/]*)$")
		--lib.log_error("result: path = " .. path .. "\n	file = " .. file)
	end
	path2 = tostring(path2 or "")
	
	
	
	local file_loaded, path_to_file
	for i, filepath in ipairs {
		path .. file, 				--preset paths aren't being used
		file, 						--preset paths are being used; the default plugin loader must be executing
		"../../" .. path .. file, 	--preset paths are used but we're accessing a file somewhere else (hope this works?)
		path2 .. file, 				--try the plugin's registration path
		"../../" .. path2 .. file, 	--try the plugin's registration path with preset backtracking?
	} do
		lib.log_error("Attempting to resolve " .. filepath)
		local status, err = loadfile(filepath)
		if status then	--success!
			file_loaded = status
			path_to_file = filepath
			break
		else			--error!
			if not string.find(err, "No such file or directory") then
				lib.log_error("unable to resolve file: " .. tostring(err or "error"))
				return false, err or "error"
			end
			lib.log_error("result: " .. err)
		end
	end
	
	
	
	if file_loaded then
		return true, file_loaded()
		--if devplugine then dofile(path_to_file) instead
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
			return converted_dep_tables
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
			if v.name ~= "null" then
				if not lib.is_ready(v.name or "null", v.version or "0") then
					status = false
					break
				end
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
				latest = data.plugin_version,
			}
		elseif neo.plugin_registry[id].latest < data.plugin_version then
			--this is a new version of an already-registered plugin
			neo.plugin_registry[id].latest = data.plugin_version
		else
			--this is an older version of an already-registered plugin
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
	if lib.is_exist(id, iniTable.plugin_version) then
		--don't use the error handler here; duplicate registration can be attempted and shouldn't trigger errors for the user
		--	multiple plugins may use the same sharable library
		--duplicate plugin entry in config.ini; we need to remove this plugin
		--and mark the original with a triggered error
		lib.log_error("(INIT) plugin registration failed: duplicate plugin!")
		return false, "Duplicate of plugin exists"
	else
		table.insert(neo.plugin_container, {})
		neo.number_plugins_registered = neo.number_plugins_registered + 1
		
		local data = copy_table(iniTable)
		data.dependencies_met = false
		data.complete = false
		data.load = false
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
				latest = data.plugin_version,
			}
		elseif neo.plugin_registry[id].latest or "0" < data.plugin_version or "0" then
			--this is a new version of an already-registered plugin
			neo.plugin_registry[id].latest = data.plugin_version
		else
			--this is an older version of an already-registered plugin
		end
		
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
	lib.log_error("attempting activation of " .. tostring(id) .. "." .. tostring(version))
	if err_han( type(id) ~= "string", "lib.activate_plugin expected a string for its first argument, got " .. type(id) ) then
		return false, "plugin ID not a string"
	end
	version = tostring(version or 0)
	if version == "0" then
		version = lib.get_latest(id)
	end
	local plugin_id = id .. "." .. version
	--this is called to start a plugin that is already registered. it SHOULD NOT be used without the user's knowledge.
	--libraries should be set as loaded/disabled by the user themselves and resolved ONLY by the user using a plugin manager or during Init
	if verify_key == mgr_key then
		if lib.is_exist(id, version) then
			if lib.resolve_dep_table(neo.plugin_registry[plugin_id].plugin_dependencies) then
				if lib.get_state(id, version).load == "YES" then
					if neo.plugin_registry[plugin_id].plugin_path ~= "" then
						local status, err = lib.resolve_file(neo.plugin_registry[plugin_id].plugin_path, nil, neo.plugin_registry[plugin_id].plugin_folder)
						if status then
							neo.plugin_registry[plugin_id].complete = true
							lib.log_error("Activated plugin " .. plugin_id .. " with Neoloader!")
							if (neo.statelock == false) or (neo.allowDelayedLoad == "YES") then
								lib.check_queue()
							end
						else
							lib.log_error("Failed to activate " .. plugin_id)
							lib.notify("PLUGIN_FAILURE", id, version)
							return false, "failed to activate, " .. err or "?"
						end
					else
						neo.plugin_registry[plugin_id].complete = true
						lib.log_error("Plugin " .. plugin_id .. " has no file to activate (compatibility plugin?)")
						if (neo.statelock == false) or (neo.allowDelayedLoad == "YES") then
							lib.check_queue()
						end
					end
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
end

function lib.get_latest(id)
	id = tostring(id or "null")
	if lib.is_exist(id) then
		return neo.plugin_registry[id].latest
	end
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
			
			plugin_id = name,
			plugin_version = version,
			plugin_type = ref.plugin_type,
			plugin_name = ref.plugin_name,
			plugin_author = ref.plugin_author,
			plugin_link = ref.plugin_link,
			plugin_folder = ref.plugin_folder,
			plugin_ini_file = ref.plugin_regpath,
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
	
	if type(ftable) ~= "table" then
		console_print("We were given an ftable of type " .. type(ftable) .. " :" .. tostring(ftable))
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
		if neo.plugin_registry[name .. "." .. version].lock == key then
			neo.plugin_registry[name .. "." .. version].lock = nil
		end
	end
end

function lib.notify(status)
	if lib.is_ready(neo.current_mgr) then
		lib.execute(neo.current_mgr, lib.get_latest(neo.current_mgr), "notif", status)
	end
end

function lib.get_API()
	return neo.API
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
		local _, expected = lib.resolve_file("plugins/Neoloader/zcom.lua")
		local commands = GetRegisteredUserCommands()
		for i=1, #commands do
			if not expected[commands[i]] then
				RegisterUserCommand(commands[i], function() print("Error") end) --cannot unregister, only register empty functions instead
				--reminder to self: IsDeclared() is also a valid function
			end
		end
		
		--delay till after START/PLUGINS_LOADED events
		ReloadInterface()
	end
end















do
	--try to clear bad behavior from fake-registering commands after a reload
	local _, expected = lib.resolve_file("plugins/Neoloader/zcom.lua")
	local commands = GetRegisteredUserCommands()
	for i=1, #commands do
		if not expected[commands[i]] then
			RegisterUserCommand(commands[i], function() print("Error: no such command") end)
		end
	end
end

lib.log_error("[timestat] library environment setup: " .. tostring(timestat_advance()))

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
	lib.resolve_file("plugins/Neoloader/setup.lua")
	dofile("vo/if.lua")
	
elseif gkini.ReadString("Neoloader", "installing", "done") == "now" then
	--there was an error during installation; abort and bug the user!
	lib.log_error("There was an error during the last installation! stub handler...")
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
		["FORCE"] = true, --force a plugin to load regardless of its dependencies; this is for development use only, not intended for regular users to use! not yet implemented...
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
			lib.log_error("The plugin at position " .. tostring(counter) .. " appears broken or missing, and will not load!")
			lib.log_error("the file being accessed is " .. file)
			--we need to increment the "number_plugins_registered" value here because otherwise new registrations will overwrite EXISTING entries in config.ini!!!
			neo.number_plugins_registered = neo.number_plugins_registered + 1
		else
			--this *appears* to be a Neoloader-compatible plugin, so lets add it to the queue
			table.insert(registered_plugins, file)
		end
	end
	
	lib.log_error("Neoloader found " .. tostring(counter) .. " plugins/libraries.")
	lib.log_error("[timestat] Init stage 1: " .. tostring(timestat_advance()))
	--[[Init Stage 2
		Everything in the registered plugins queue should be valid, working plugins; now, we build and add these to Neoloader's registry and give them a container. execution doesn't happen yet, and plugins are added even if they won't be run; we need to track what exists, and that's what is handled here.
	]]--
	
	for k, v in ipairs(registered_plugins) do
		local id, version = silent_register(v)
		if id == false then
			--this plugin failed for some reason
			lib.log_error("failed to create registry entry for " .. v)
		else
			--the plugin built and was added; now we see if it needs to be loaded
			local loadstate = gkreadstr("Neo-pluginstate", id .. "." .. version, "NO")
			if valid_states[loadstate] == true then
				table.insert(validqueue, {id, version})
			end
		end
	end
	
	lib.log_error("Of those plugins, " .. tostring(#validqueue) .. " are set to be loaded\nNow breaking down dependency tree...")
	lib.log_error("[timestat] Init stage 2: " .. tostring(timestat_advance()))
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
	
	local valid_copy = copy_table(validqueue)
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
			lib.log_error("Failed to launch the registered interface manager; failsafing to the DefaultUI")
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
	
	for k, v in ipairs(valid_copy) do
		local obj = neo.plugin_registry[v[1] .. "." .. v[2]]
		if (obj.plugin_dependencies == nil) or (#obj.plugin_dependencies == 0) then --no dependencies; this is a root object
			lib.log_error("No dependencies found for " .. obj.plugin_id .. " v" .. obj.plugin_version .. "; adding to processing queue")
				table.insert(plugin_table, v)
				these_are_loaded[v[1] .. "." .. v[2]] = true
				table.insert(these_are_loaded[1], true)
		else --There is a dependency
			lib.log_error("Dependencies found for " .. obj.plugin_id .. " v" .. obj.plugin_version .. "; breaking into dependency tree...")
			for k2, v2 in ipairs(obj.plugin_dependencies) do
				
				if v2.version == "" then --handle soft dependencies (not-version-specific); discouraged but doable
				--future idea: allow version ranges?
					v2.version = lib.get_latest(v2.name)
				end
				
				--split apart v2[name.version] dependencies and link (=this plugin's name.version) in dependency_tree
				
				--first, create the entry container; this is the plugin that is being depended on
				
				dependency_tree[v2.name .. "." .. v2.version] = dependency_tree[v2.name .. "." .. v2.version] or {}
				
				--now, create the entry to the plugin that is dependent
				
				table.insert(dependency_tree[v2.name .. "." .. v2.version], {v[1], v[2] or 0})
			end
		end
	end
	
	lib.log_error("[timestat] Init stage 3: " .. tostring(timestat_advance()))
	
	--[[Init Stage 4
	We have broken the plugins down to show what their dependent on; we now reverse-built this into a linear list so all of them that CAN be loaded, are.
	
	todo: look into other methods of ordering; we use a brute-force check, which is likely not so efficient. shouldn't matter unless there are LOTS of plugins, but best practice is to pre-prepare!
	
	We already have "root" libraries and plugins loaded. Here, we loop through the table "dependency_tree" and see IF a plugin can be loaded, based on what's already in the plugin/library tables.
	]]--
	
	if #these_are_loaded[1] == 0 then
		--if there are no "root" plugins/libraries to load, then we won't bother checking other plugins for dependencies.
		lib.log_error("No 'root' level plugins or libraries are loaded; skipping further checks...")
		neo.error_flag = true
		lib.notify("ROOT_FAILURE")
	else
		lib.log_error("Sorting plugins based on the dependency tree...")
		local function addexec(id, ver)
			if (ver == nil) then
				ver = "0"
			end
			local pluginID = id .. "." .. tostring(ver)
			these_are_loaded[pluginID] = true
			table.insert(plugin_table, {id, ver})
			lib.log_error("Added " .. id .. " v" .. ver .. " to the execution queue")
		end
		
		local function checkreqs(name, version)
			local id = name .. "." .. tostring(version or 0)
			local deps = neo.plugin_registry[id].plugin_dependencies
			local status = true
			for k, v in ipairs(deps) do
				local tempver = v.version
				if tempver == nil or tempver == 0 or tempver == "0" then
					tempver = lib.get_latest(v.name)
				end
				if v.name ~= "null" then
					if these_are_loaded[(v.name or "null") .. "." .. (tempver or "0")] ~= true then
						status = false
						break
					end
				end
			end
			return status
		end
		
		local function loadpass()
			local new_change = false
			
			for k, v in pairs(dependency_tree) do
				--k: pluginID of the thing dependend on
				--v: table of dependents
				for k2, v2 in ipairs(dependency_tree[k]) do
					--k2: index of dependent object
					--v2: {id, version} of dependent object
					local pluginID = v2[1] .. "." .. v2[2]
					if these_are_loaded[pluginID] ~= true then
						if checkreqs(v2[1], v2[2]) == true then
							addexec(v2[1], v2[2])
							new_change = true
							table.remove(dependency_tree[k], k2)
						end
					else
						--this is a duplicate entry of an item that was already loaded; this is caused by objects having multiple dependencies that were already fulfilled
						table.remove(dependency_tree[k], k2)
					end
				end
				if #dependency_tree[k] == 0 then
					--this plugin group has been emptied of all items dependent on it; we can remove it now to prevent future unneccesary iteration
					dependency_tree[k] = nil
				end
			end
			return new_change
		end
		
		local startTime = os.time()
		
		while loadpass() do
			if neo.initLoopTimeout > 0 then
				if os.time() - startTime > neo.initLoopTimeout then
					--timed out
					break
				end
			end
		end
		loadpass() --one more time for good measure
		
		
		
		--unless there's no root-level plugins to load, this will have the highest "time" taken. Look into making stage 4's code more efficient
		lib.log_error("[timestat] Init stage 4: " .. tostring(timestat_advance()))
		
		--[[Init Stage 5:
			if everything is doing what its supposed to do, then all plugins should load appropriately as we iterate over both library and plugin tables!
		]]--
		
		
		
		
		local plugin_start
		
		for k, v in ipairs(plugin_table) do
			plugin_start = gk_get_microsecond()
			local err_flag, err_detail = lib.activate_plugin(v[1], v[2], mgr_key)
			if err_flag == false then
				neo.error_flag = true
				table.insert(neo.plugin_registry[v[1] .. "." .. v[2]].errors, err_detail)
			end
			lib.log_error("[timestat] plugin activated in: " .. tostring(gk_get_microsecond() - plugin_start))
		end
		
		lib.log_error("All plugins have been loaded!")
		ProcessEvent("LME_PLUGINS_LOADED")
		
		lib.log_error("[timestat] Init stage 5: " .. tostring(timestat_advance()))
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
	end
end
if lib.is_ready(neo.current_mgr) == true then
	local cur_version = lib.get_latest(neo.current_mgr)
	
	RegisterUserCommand("neo", function() lib.execute(neo.current_mgr, cur_version, "open") end)
	
	mgr_key = lib.generate_key()
	lib.execute(neo.current_mgr, cur_version, "mgr_key", mgr_key)
end

RegisterEvent(function()
	RegisterUserCommand("neodelete", function() lib.uninstall(mgr_key) end)
	RegisterUserCommand("reload", lib.reload)
	lib.log_error("[timestat] Standard plugin Loader completed in " .. tostring(gk_get_microsecond() - timestat_step))
end, "PLUGINS_LOADED")

lib.log_error("[timestat] Neoloader completed in " .. tostring(gk_get_microsecond() - timestat_neo_start))
timestat_step = gk_get_microsecond()
lib.log_error("Neoloader has finished initial execution! The standard plugin loader will now take over.\n\n")
ProcessEvent("LIBRARY_MANAGEMENT_ENGINE_COMPLETE")