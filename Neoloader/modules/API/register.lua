--[[
[metadata]
description=Public registration: parse INI, add to registry, and (if default_load_state=YES) activate immediately after deps resolve
version=1.0.2
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry
local cfg = neo.api.config

lib.register = function(iniFilePointer)
	if lib.err_handle(type(iniFilePointer) ~= "string",
	"lib.register expected a string (file path) for argument 1, got " .. type(iniFilePointer)) then
		return false, "file pointer not a string"
	end

	-- Build INI (v7 wrapper enforces API/version/file checks and populates the registry INI cache)
	local record, perr = lib.build_ini(iniFilePointer)
	if not record then
		console_print("perr building ini: " .. tostring(perr))
		return false, perr
	end

	local id  = record.plugin_id
	local ver = tostring(record.plugin_version or "0")
	
	if ver == "0" then
		lib.log_error("  Attempted to register a plugin with a version string of '0', which is not allowed (string '0' is placeholder for 'latest enabled version'", 1)
		return false, "invalid new entry: version zero"
	end
	
	-- Skip duplicate id+ver
	local ok_exist, _, existing = reg.find_plugin(id, ver)
	if ok_exist and existing then
		lib.log_error("  plugin registration skipped: plugin is already registered", 1, id, ver)
		return false, "duplicate"
	end

	-- Insert into registry
	local ok_entry, entry_id = reg.ensure_registry_entry(record)
	if not ok_entry then
		lib.log_error("  failed to insert into file registry, error as " .. entry_id)
		return false, entry_id
	end
	record.load_position = entry_id
	
	local ok, err_or_idx = reg.add_new_plugin(record)
	if not ok then
		lib.log_error("  failed to insert into memory, error stated was " .. tostring(err_or_idx))
		return false, err_or_idx or "registry insert failed"
	end

	-- Announce (matches v6 tone)
	lib.log_error("Added NEW " .. id .. " v" .. ver .. " to Neoloader's plugin registry", 2, id, ver)
	lib.notify("NEW_REGISTRY", { plugin_id = id, version = ver })

	-- If user preauthorized immediate activation, wait for this plugin's own deps then activate now.
	if cfg.get_config("default_load_state") == "YES" then
		local deps = record.plugin_dependencies or {}
		lib.require(deps, function() lib.activate_plugin(id, ver, neo.auth_key) end, id, ver)
	end

	return true
end




