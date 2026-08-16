--[[
[metadata]
description=Trap a function call and attribute any error to a specific plugin (by id/ver)
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-7
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

-- v7 port of v6.3.0 lib.block_trap:
-- - resolves "0" via registry.active
-- - validates existence via registry lookup
-- - pcall(func); on error, logs to the plugin and marks it incomplete in the registry
-- - success returns nothing (by design); failures may return false[, reason]

lib.block_trap = function(id, ver, func)
	id, ver = lib.pass_ini_identifier(id, ver)
	-- normalize/resolve version
	ver = tostring(ver or "0")
	if ver == "0" then
		local sub = reg.substitute_zero(id, "0")
		if not sub or sub == "?" then
			return false -- no active version to attribute to
		end
		ver = sub
	end

	-- ensure the plugin exists in the registry
	local ok, idx, rec = reg.find_plugin(id, ver)
	if not ok or not rec then
		return false
	end

	-- require a callable
	if type(func) ~= "function" then
		lib.log_error("lib.block_trap() expects a function to trap, got " .. tostring(type(func)), 1, id, ver)
		return false, "invalid input"
	end

	-- run guarded
	local status, err = pcall(func)
	if not status then
		-- attribute logs to the plugin
		lib.log_error("\127FF0000block_trap caught an error belonging to " .. id .. " v" .. ver .. "\127FFFFFF", 4, id, ver)
		lib.log_error("		" .. tostring(err), 4, id, ver)
		lib.log_error(debug.traceback("		trace up to lib.block_trap(): "), 3, id, ver)

		-- mark incomplete + stash detail (minimal, local write)
		-- (safe to touch the record in-place; we already have idx)
		local record = rec
		reg.mark_failure(id, ver)

		reg.update_record_fields(id, ver, {
			err_details = err,
		})
	end
	-- on success: return nothing
end
