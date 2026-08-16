--[[
[metadata]
description=the Registry is the list of plugins Neoloader is aware of.
version=1.0.15
owner=Neoloader|7.0.0
type=lua
created=2025-10-26
]]--

neo = ...
local registry = neo.registry
local class_container = {}
--neo.testing.class_container = class_container
neo.api.registry = {}
local api = neo.api.registry

local list_versions = {} --looks up what versions are available and their load states
local plugin_lookups = {} --quickly get registry index of registered plugins
local version_order = {} --list of versions of each plugin sorted lowest to highest ver-num

--[[
registry[1] = {
	--INI data
	compat = "NO",-- set to YES if plugin uses default game loader
	plugin_id = "neoloader",
	plugin_name = "Neoloader",
	plugin_type = "LME",
	plugin_version = neo.lme_ver,
	plugin_author = "Luxen De'Mark",
	plugin_link = "https://www.nexusmods.com/vendettaonline/mods/3",
	plugin_path = neo.path .. "init.lua",
	plugin_folder = neo.path,
	plugin_dependencies = {}, --list of {id/ver/vermax} dependency list
	plugin_regpath = neo.path .. "registration.ini",
	
	complete = false --true if plugin has loaded successfully
	launched = false --true if we attempted to load this plugin
	new_entry = true --this plugin was just registered
	dependencies_met = false --only able to run if true
	
	dependents_frozen = false --if true, ignores this plugin during dependency resolution; plugins relying on this one will not be launched until this is true (lets you delay activation post-completion, if you want that for some reason)
	
	load = "Plugin load state in config"
	index = registry[this index reverse lookup]
	load_position = 
		1.x:	position in config.ini
		y.x:	position in external list y
	errors = {} list of log_error() tied to this mod
	
	container = {}
	container_locked = false
	container_key = ""
}

list_versions = {
	[plugin_id] = {
		latest_inactive = "7.0.0", --latest version (including inactive)
		latest_active = "7.0.0", --latest active version
		"7.0.0" = "YES", --COMPLETE state
		"4.3.3" = "NO",
	}
}

plugin_lookups = {
	[id.version] = plugin_index
}

version_order = { --oldest to newest
	[plugin_id] = {
		[1] = "6.3.0",
		[2] = "7.0.0",
		[3] = "8.5.0",
	}
}

Not all of this is still accurate, but its fairly close

]]--

local _update_indexes --declared below

local ini_pointer_cache = {}  -- [ifp] = { id=<id>, ver=<version> }

-- Fast check: does this ID exist in the registry (any version)?
api.has_id = function(id)
	if type(id) ~= "string" then return false end
	return version_order[id] ~= nil and #version_order[id] > 0
end


api.break_version = function(semverstr)
	--take a semantic-like version string and break it into a table
	--directly from lib.get_whole_ver (no need to change it)
	--"x.y.z -yarr" returns {x, y, z,}, "yarr"
	
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

api.compare_ver = function(obj1, obj2)
	--[[
		compares two semantic-like version strings.
		-1: obj1 is older version than obj2
		0 : both objects are entirely equal
		+1: obj1 is newer version than obj2
		
		semantic meta elements come 'after' non-meta matching versions
		"1.2.3 -alpha" is an newer version than "1.2.3"
		!!!
			this is actually a bug I never caught! It will be changed if we ever up the API version, in order to match what semantic versioning should work like
	]]--
	local ot1 = api.break_version(obj1)
    local ot2 = api.break_version(obj2)

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

api.find_plugin = function(id, version)
	if not list_versions[id] then
		return false, "id_match_fail"
	end
	
	if not list_versions[id][version] then
		return false, "ver_match_fail"
	end
	
	local index = plugin_lookups[id .. "." .. version]
	local data = registry[index]
	
	return true, index, data
end

api.substitute_zero = function(id, zval)
	local ver_table = list_versions[id]
	if not ver_table then
		return false, "id_match_fail"
	end

	if zval ~= "0" then
		return zval
	end

	local v = ver_table.latest_active
	if (not v) or (v == "0") then
		return false, "no_active_versions_known"
	end

	return v
end


api.get_latest_ver = function(id, ver_min, ver_max)
	local order_list = version_order[id]
	local ver_list = list_versions[id]
	if not order_list then
		return false, "id_match_fail"
	end
	
	if ver_max == "~" then
		--lib.log_error("get_latest_ver called with ver_max='~' for " .. tostring(id) .. "; '~' means exact-only and must be handled outside get_latest_ver.", 3)
		return false, "exact_version_required"
	end
	
	if not ver_min then
		-- Broad query: newest known version, active preferred.
		local latest = ver_list.latest_active

		if (not latest) or latest == "0" then
			latest = ver_list.latest_inactive
		end

		if not latest or latest == "0" then
			return false, "no_versions_known"
		end

		return true, latest
	end

	-- Range resolution may inspect inactive versions too.
	local ver_limit = ver_list.latest_active

	if (not ver_limit) or ver_limit == "0" then
		ver_limit = ver_list.latest_inactive
	end
	
	if tostring(ver_min) == "0" then
		local resolved, err = api.substitute_zero(id, ver_min)

		if not resolved then
			return false, err
		end

		ver_min = resolved
	end
	
	if api.compare_ver(ver_min, ver_limit) > 0 then
		return false, "min_too_high"
	end
	
	if ver_max == nil then
		ver_max = ver_limit
	else
		ver_max = api.substitute_zero(id, ver_max)
		if not ver_max then
			return false, "no_valid_ver_max"
		end
	end
	
	if api.compare_ver(ver_max, ver_limit) > 0 then
		--clamp ver_max to limit
		ver_max = ver_limit
	end
		--[[
			remember, if ver_max is "~" then it doesn't exist
			"1.2", "~": the version requires is ONLY "1.2"
			get_latest_version can assume "0" for ver_max, "~" handling is done elsewhere
		]]--
	
	--we need to determine the valid range of elements in the order list and return the last valid one
	
	local min_index = -1
	local max_index = -1
	
	for index, ver_test in ipairs(order_list) do
		if api.compare_ver(ver_min, ver_test) <= 0 then
			min_index = index
			break
		end
	end
	
	for index, ver_test in ipairs(order_list) do
		if api.compare_ver(ver_max, ver_test) >= 0 then
			max_index = index
		else
			break
		end
	end
	
	if max_index < 0 then
		return false, "no_valid_ver_max_too_low"
	end
	
	if (min_index < 0) or (max_index < min_index) then
		return false, "no_valid_ver_min_too_high"
	end
	
	return true, order_list[max_index]
end

api.build_ini = function(ini_pointer)
	if not gksys.IsExist(ini_pointer) then
		return false, "file not found"
	end
	
	local rv = function(vtr, htr) --read value, value to read, header to read
		local data = gkini.ReadString2(htr or "modreg", vtr, "", ini_pointer)
		if data == "" then
			data = nil
		end
		return data
	end
	
	if not rv("id") then
		return false, "INI data not found"
	end
	
	local ini_data = {
		plugin_id = rv("id"),
		plugin_version = rv("version"),
		plugin_name = rv("name"),
		plugin_type = rv("type"),
		plugin_author = rv("author"),
		plugin_link = rv("link"),
		plugin_path = rv("path"),
		plugin_regpath = ini_pointer,
		API_required = rv("API") or rv("api") or "3",
	}
	
	ini_data.compat = ini_data.plugin_path and "NO" or "YES"
	
	local plugin_dependencies = {}
	local counter = 0
	while true do
		counter = counter + 1
		local next_dep = {
			name = rv("depid" .. tostring(counter), "dependency"),
			version = rv("depvs" .. tostring(counter), "dependency") or "0",
			ver_max = rv("depmx" .. tostring(counter), "dependency") or "~",
		}
		if not next_dep.name then
			break
		else
			table.insert(plugin_dependencies, next_dep)
		end
	end
	if #plugin_dependencies > 0 then
		ini_data.plugin_dependencies = plugin_dependencies
	end
	
	ini_pointer_cache[ini_pointer] = ini_data
	
	return ini_data
end

-- Resolve an INI file path (that has been parsed before) and returns its registry entry
api.from_ini_pointer = function(ifp)
	local rec = ini_pointer_cache[ifp]
	if not rec then return false, "not_cached" end
	return true, rec
end


api.add_new_plugin = function(intable)
	if type(intable) ~= "table" then
		return false, "input table not a table, got " .. type(intable)
	end
	
	local default = {
		compat = "NO",
		plugin_id = "null",
		plugin_name = nil,
		plugin_type = "plugin",
		plugin_version = nil,
		plugin_author = "Unknown Author",
		plugin_link = nil,
		plugin_path = nil,
		plugin_folder = nil,
		plugin_dependencies = {},
		plugin_regpath = nil,

		complete = false,
		launched = false,
		new_entry = true,
		dependencies_met = false,

		dependents_frozen = false,

		load = neo.api.config.get_config("default_load_state"),
		index = nil, --index in registry
		load_position = nil, --index in config.ini
		errors = {},
		
		container_index = #class_container + 1,
		container_locked = false,
		container_key = "",
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	local data = default

	-- minimal validation
	
	if data.plugin_id == "null" or not data.plugin_version then
		return false, "missing or invalid id or version"
	end

	-- derive folder if absent
	if not data.plugin_folder and data.plugin_regpath then
		data.plugin_folder = data.plugin_regpath:gsub("([^/]+)$", "")
	end

	-- guard duplicates
	local k = data.plugin_id.."."..data.plugin_version
	if plugin_lookups[k] then
		return false, "duplicate version already registered"
	end

	-- append to registry and stamp index
	table.insert(class_container, {})
	table.insert(registry, data)
	data.index = #registry
	plugin_lookups[k] = data.index

	-- update all side indexes for registration moment
	_update_indexes(data, "register")

	return true, data
end



api.set_container = function(id, ver, class)
	local status, index, data = api.find_plugin(id, ver)
	if not status then
		return false, index
	end
	
	if data.container_locked then
		return false, "locked"
	end
	
	class_container[data.container_index] = class 
	
	return true
end

api.get_container = function(id, ver)
	local status, index, data = api.find_plugin(id, ver)
	if not status then
		return false, index
	end
	
	return class_container[data.container_index]
end

--state: true to lock, false to unlock
api.toggle_lock = function(id, ver, state, key)
	local status, index, data = api.find_plugin(id, ver)
	if not status then
		return false, index
	end
	
	if (state) and (not data.container_locked) then
		data.container_key = key or tostring(gkmisc.GetGameTime() + math.random())
		data.container_locked = true
	elseif (not state) and ((data.container_key == key) or (neo.api.check_auth(key))) then
		data.container_locked = false
		return data.container_key
	end
end



-- shared bookkeeping for inserts/updates
-- mode = "register" | "activate"
_update_indexes = function(record, mode)
	local id, ver = record.plugin_id, record.plugin_version
	
	-- ensure per-ID tables
	list_versions[id] = list_versions[id] or { latest_active = nil, latest_inactive = nil }
	version_order[id]   = version_order[id]   or {}
	plugin_lookups[id.."."..ver] = record.index

	-- update version_order[id] (dedupe + sort)
	local vo = version_order[id]
	local seen = false
	for i=1, #vo do if vo[i] == ver then seen = true break end end
	if not seen then table.insert(vo, ver) end
	table.sort(vo, function(a, b) return api.compare_ver(a, b) < 0 end)

	-- cache the current load state for quick reporting
	list_versions[id][ver] = record.load

	-- refresh latest_inactive immediately on registration (or any insert)
	-- (= newest by api.compare_ver regardless of load)
	local newest = vo[#vo]
	list_versions[id].latest_inactive = newest

	-- Recompute the newest enabled version that is launching or complete.
	if mode == "activate" then
		local latest_ok = nil

		for i = #vo, 1, -1 do
			local v = vo[i]
			local state = list_versions[id][v]
			local candidate_index = plugin_lookups[id .. "." .. v]
			local candidate = candidate_index and registry[candidate_index]

			if state ~= "NO"
			and candidate
			and (
				candidate.launched == true
				or candidate.complete == true
			) then
				latest_ok = v
				break
			end
		end

		list_versions[id].latest_active = latest_ok
	end
end

-- tiny helper to mark completion (activation success path can call this)
api.mark_complete = function(id, ver, stats)
	local key = id.."."..ver
	local idx = plugin_lookups[key]
	if not idx then return false, "not found" end
	local rec = registry[idx]
	rec.complete = true
	if stats then rec.stats = stats end
	
	rec.launched = true --in case somehow didn't get triggered

	-- activation-time index refresh (may bump latest_active)
	_update_indexes(rec, "activate")
	return true, rec
end

api.mark_failure = function(id, ver)
	local key = id.."."..ver
	local idx = plugin_lookups[key]
	if not idx then return false, "not found" end
	
	local rec = registry[idx]
	rec.launched = false
	rec.complete = false
	_update_indexes(rec, "activate")
	return true, rec
end

api.mark_launching = function(id, ver)
	local key = id.."."..ver
	local idx = plugin_lookups[key]
	if not idx then return false, "not found" end
	
	local rec = registry[idx]
	rec.launched = true
	_update_indexes(rec, "activate")
	return true, rec
end

--[[
Updates selected fields in an existing registry record.
Intended for internal lib functions (e.g. block_trap) that need to
mark a plugin incomplete or attach diagnostics without exposing
the raw registry table.

Arguments:
  id     : string  – plugin ID
  ver    : string  – version string
  patch  : table   – key/value pairs to merge into the record

Returns:
  true, record     – on success
  false, err       – if plugin not found or patch invalid
]]--
api.update_record_fields = function(id, ver, patch)
	if type(id) ~= "string" or type(ver) ~= "string" then
		return false, "invalid id or version"
	end
	if type(patch) ~= "table" then
		return false, "patch must be a table"
	end

	local ok, idx, rec = api.find_plugin(id, ver)
	if not ok or not rec then
		return false, "plugin not found"
	end

	-- shallow merge of patch into the record
	for k, v in pairs(patch) do
		rec[k] = v
	end

	-- write-back to registry slot (guaranteed valid)
	registry[idx] = rec

	-- update any cached metadata that depends on these keys
	if patch.complete ~= nil or patch.load ~= nil then
		_update_indexes(rec, "activate")
	end

	return true, rec
end

-- inside registry.lua
api.ensure_registry_entry = function(data)
    local path = tostring(data.plugin_regpath or "")
    if path == "" then
        return false, "no plugin_regpath defined"
    end

    -- Check for an existing registration while tolerating registry gaps.
	-- If an existing entry is found beyond a gap, move it forward into the first empty slot so normal startup scanning can reach it.
	
	--future todo: make this async after time-period elapses
    local n = 1
	local empty_count = 0
	local first_empty = nil

	while empty_count < 10 do
		local key = "reg" .. tostring(n)
		local existing = gkini.ReadString("Neo-registry", key, "")

		if existing == "" then
			first_empty = first_empty or n
			empty_count = empty_count + 1

		elseif existing == path then
			if first_empty then
				gkini.WriteString(
					"Neo-registry",
					"reg" .. tostring(first_empty),
					path
				)

				gkini.WriteString(
					"Neo-registry",
					key,
					""
				)

				gkinterface.GKSaveCfg()
				return true, first_empty
			end

			return true, n
		else
			empty_count = 0
		end

		n = n + 1
	end

	local target = first_empty or n

	gkini.WriteString(
		"Neo-registry",
		"reg" .. tostring(target),
		path
	)

	gkinterface.GKSaveCfg()
	return true, target
end


local registry_reset_handler = function()
	for index, reg_table in ipairs(registry) do
		local id   = reg_table.plugin_id
		local ver  = reg_table.plugin_version
		local load = reg_table.nextload or reg_table.load or "NO"
		gkini.WriteString("Neo-pluginstate", id .. "." .. ver, load)
	end
	
	gkinterface.GKSaveCfg()
end

RegisterEvent(registry_reset_handler, "UNLOAD_INTERFACE")
RegisterEvent(registry_reset_handler, "QUIT")



-- internal-only; called from recovery.lua UI
api.cleanse_registration = function()
    local survivors = {}
    local max_seen  = 0

    -- 1) Discover all current regN entries and filter valid ones
    local n = 1
	local empty_counter = 0
    while true do
        local key = "reg" .. n
        local path = gkini.ReadString("Neo-registry", key, "")
		
        if path == "" then
			empty_counter = empty_counter + 1
			if empty_counter > 9 then
				-- stop after 10 empty entries, strongly indicates no more entries
				break
			end
        else
			empty_counter = 0
			max_seen = n
			
			if gksys.IsExist(path) then
				-- Try building INI to make sure it’s still sane
				local ini, err = api.build_ini(path)
				if ini then
					table.insert(survivors, { path = path, ini = ini })
				else
					-- optionally log that regN is stale / broken
					neo.lib.log_error("Stale registry entry at " .. key .. ": " .. tostring(err), 2)
				end
			else
				neo.lib.log_error("Stale registry entry at " .. key .. ": missing file " .. tostring(path), 2)
			end
		end
		
        n = n + 1
    end

    -- 2) Rewrite survivors contiguously: reg1..regM
    -- (for now, keep their current order; later, v7.1 can sort by load_position, type, etc.)
    for i = 1, #survivors do
        local key  = "reg" .. i
        local path = survivors[i].path
        gkini.WriteString("Neo-registry", key, path)
    end

    -- 3) Blank any leftover keys between new end and old max_seen
    for i = #survivors + 1, max_seen do
        local key = "reg" .. i
        local existing = gkini.ReadString("Neo-registry", key, "\255")
        if existing ~= "\255" and existing ~= "" then
            gkini.WriteString("Neo-registry", key, "")
        end
    end

    gkinterface.GKSaveCfg()

    -- 4) Optionally, update in-memory load_position to match new positions
    --    This is safe; it's internal and keeps registry & INI consistent.
    for i = 1, #survivors do
        local ini = survivors[i].ini
        local id  = ini.plugin_id
        local ver = tostring(ini.plugin_version or "0")
        api.update_record_fields(id, ver, { load_position = i })
    end

    return true, #survivors
end

-- returns a shallow-copied list of known versions for this id, oldest→newest
api.get_version_list = function(id)
	local vo = version_order[id]
	if not vo then return {} end
	local out = {}
	for i = 1, #vo do
		out[i] = vo[i]
	end
	return out
end

-- TODO: Replace with a more robust implementation.
api.get_versions_map = function()
	return version_order
end