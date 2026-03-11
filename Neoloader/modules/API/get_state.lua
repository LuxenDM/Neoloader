--[[
[metadata]
description=Return Neoloader state/details for a specific plugin version
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

-- shallow copy utility (single-depth, like v6)
local shallow_copy = function(t)
	local out = {}
	if t then for k, v in pairs(t) do out[k] = v end end
	return out
end

lib.get_state = function(name, version)
	name, version = lib.pass_ini_identifier(name, version)

	if lib.err_handle(type(name) ~= "string",
			"lib.get_state expected a string for its first argument, got " .. type(name)) then
		return false, "plugin ID not a string"
	end

	-- Accept "0" → latest (keep v6 behavior)
	version = tostring(version or "0")
	if version == "0" then
		version = lib.get_latest(name) or "0"
	end

	local ok, _, ref = reg.find_plugin(name, version)
	if not ok or not ref then
		-- v6 returned {} when not found
		return {}
	end

	-- versions list: all known versions for this id
	local vers = reg.get_version_list(name) or {"???"}
	local versions_list = {}
	for i = 1, #vers do versions_list[i] = vers[i] end

	-- dependencies_met: prefer stored flag, else compute quickly if available
	local deps_met = ref.dependencies_met
	if not deps_met then
		deps_met = lib.resolve_dep_table(ref.plugin_dependencies) and true or false
	end

	local state = {
		load								= ref.load or "NO",
		complete						= ref.complete == true,
		dependencies_met		= deps_met or false,
		load_position			 = ref.load_position or -1,
		errors							= ref.errors or {},

		latest							= lib.get_latest(name) or "-1",
		versions						= versions_list,

		plugin_id					 = name,
		plugin_version			= version,
		plugin_type				 = ref.plugin_type,
		plugin_name				 = ref.plugin_name,
		plugin_author			 = ref.plugin_author,
		plugin_link				 = ref.plugin_link,
		plugin_folder			 = ref.plugin_folder,
		plugin_ini_file		 = ref.plugin_regpath,

		-- v6: dependent_freeze > 0 ? "YES" : "NO"
		plugin_frozen			 = (ref.dependents_frozen and "YES" or "NO"),

		plugin_dependencies = ref.plugin_dependencies or {},
		plugin_is_new			 = false, --ref.new_entry or false,
		compat_flag				 = ref.compat or "NO",
		plugin_stats				= ref.stats,	-- {timestat, memstat} if present
	}

	return state
end
