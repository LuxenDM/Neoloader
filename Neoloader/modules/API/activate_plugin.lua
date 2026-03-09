--[[
[metadata]
description=Activate a registered plugin version (v7 API / registry-backed, stats-integrated)
version=1.0.1
owner=Neoloader|7.0.0
type=lua
created=2025-11-7
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.activate_plugin = function(id, version, verify_key)
	id, version = lib.pass_ini_identifier(id, version)
  -- timing/memory baselines
  local gktime = gkmisc.GetGameTime
  local t0 = gktime()
  local m0 = math.ceil(collectgarbage("count"))

  lib.log_error("attempting activation of " .. tostring(id) .. "." .. tostring(version), 1)

  if type(id) ~= "string" then
    lib.log_error("lib.activate_plugin expected a string for its first argument, got " .. type(id), 1)
    return false, "plugin ID not a string"
  end

  -- manager key guard
  if not neo.api.check_auth(verify_key) then
    lib.log_error("Attempted to activate a plugin, but key is incorrect!", 1)
    return
  end

  -- resolve "0" using registry's ACTIVE pointer
  version = tostring(version or "0")
  if version == "0" then
    local sub = reg.substitute_zero(id, "0")
    if not sub or sub == "?" then
      lib.log_error("Attempted to activate " .. id .. ".0 but no ACTIVE version exists", 1)
      return false, "no active version"
    end
    version = sub
  end

  -- fetch record
  local ok, _, rec = reg.find_plugin(id, version)
  if not ok or not rec then
    lib.log_error("Attempted to activate " .. id .. "." .. tostring(version) .. " but it doesn't exist!", 1)
    return
  end

  local plugin_id = id .. "." .. version

  -- load-state: YES / FORCE / AUTH allowed
  local ls = tostring(rec.load or "NO")
  if not (ls == "YES" or ls == "FORCE" or ls == "AUTH") then
    lib.log_error("Attempted to activate " .. plugin_id .. " but its load state is 'NO'!", 1, id, version)
    return false, "load state is NO"
  end

	reg.mark_launching(id, version)

  -- compat fast path
  if rec.compat == "YES" then
    local dt_ms  = gktime() - t0
    local dmem_k = math.ceil(collectgarbage("count")) - m0
    local _, updated = reg.mark_complete(id, version, { timestat = dt_ms, memstat = dmem_k })
    lib.log_error(plugin_id .. " is a compatibility plugin; empty container created successfully! The default loader will launch it soon.", 1, id, version)
    if neo.stats and neo.stats.checkpoint then
      neo.stats.checkpoint("activate_compat:" .. plugin_id)
    end
    ProcessEvent("COMPAT_PLUGIN_ACTIVATED")
    return --true, updated
  end

  -- dependency gate (unless FORCE)
  local deps_ok = true
  if type(lib.resolve_dep_table) == "function" then
    deps_ok = lib.resolve_dep_table(rec.plugin_dependencies)
  end
  if not deps_ok and ls ~= "FORCE" then
    reg.mark_failure(id, version)
	lib.log_error("Attempted to activate " .. plugin_id .. " but its dependencies aren't fulfilled!", 2)
    if type(lib.notify) == "function" then
      lib.notify("PLUGIN_FAILURE", { plugin_id = id, version = version, error_string = "Unfilled Dependencies!" })
    end
    return false, "unmatched dependencies"
  end

  -- execute entry file
  local status, err = true, nil
  if type(lib.resolve_file) == "function" then
    status, err = lib.resolve_file(rec.plugin_path, nil, rec.plugin_folder)
  end
  if not status then
    reg.mark_failure(id, version)
    lib.log_error("\127FF0000Failed to activate " .. plugin_id .. "\127FFFFFF", 3, id, version)
    lib.log_error("        error message: " .. tostring(err), 3, id, version)
    if type(lib.notify) == "function" then
      lib.notify("PLUGIN_FAILURE", { plugin_id = id, version = version, error_string = tostring(err) })
    end
    return false, ("failed to activate, %s"):format(err or "?")
  end

  -- success → compute deltas in the same units as stats.lua
  local dt_ms  = gktime() - t0
  local dmem_k = math.ceil(collectgarbage("count")) - m0

  local okc, updated = reg.mark_complete(id, version, { timestat = dt_ms, memstat = dmem_k })

  lib.log_error("Activated plugin " .. plugin_id .. " with Neoloader successfully!", 2, id, version)
  lib.log_error("[timestat] activation took: " .. tostring(dt_ms) .. " ms", 1, id, version)
  lib.log_error("[memstat] memory footprint to load: " .. tostring(dmem_k) .. " kb", 1, id, version)

  -- optional per-activation checkpoint
  if neo.stats and neo.stats.checkpoint then
    neo.stats.checkpoint("activate:" .. plugin_id)
  end

  -- unfreeze-dependent queue kick
	if not rec.dependents_frozen and type(lib.check_queue) == "function" then
	  lib.check_queue()
	end

  -- AUTH hook parity
	local current_mgr = neo.api.config.get_config("current_mgr")
	if ls == "AUTH" or id == current_mgr then
		lib.execute(id, version, "auth_key_receiver", neo.auth_key)
	end

  ProcessEvent("LME_PLUGIN_ACTIVATED")
  return --okc, updated
end
