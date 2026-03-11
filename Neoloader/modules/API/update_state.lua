--[[
[metadata]
description=Update a plugin's runtime state and trigger failure handling if applicable
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.update_state = function(id, ver, state_data)
	id, ver = lib.pass_ini_identifier(id, ver)
	ver = tostring(ver or "0")
	if ver == "0" then
		ver = lib.get_latest(id)
	end

	if not lib.is_exist(id, ver) then
		return false
	end

	if lib.err_handle(type(state_data) ~= "table", "lib.update_state() expects a table input!") then
		return false, "invalid input"
	end

	local ok, _, ref = reg.find_plugin(id, ver)
	if not ok or not ref then
		return false, "registry lookup failed"
	end

	lib.log_error("State update for " .. id .. " v" .. ver, 1)

	for k, v in pairs({
		complete = "complete",
		name = "plugin_name",
		link = "plugin_link",
		plugin_name = "plugin_name",
		plugin_link = "plugin_link",
	}) do
		local newval = state_data[k]
		if newval ~= nil then
			if k == "complete" and ref[v] == false then
				lib.log_error("	state 'complete' >> Cannot be changed from false!", 1)
			elseif type(newval) == type(ref[v]) then
				lib.log_error("	state '" .. tostring(k) .. "' >> " .. tostring(newval), 1)
				ref[v] = newval

				-- Handle plugin failure self-report
				if k == "complete" and newval == false then
					lib.log_error("\127FF0000Plugin encountered an error and triggered its own failure state.", 3, id, ver)
					lib.log_error("	stated error: " .. tostring(state_data.err_details or "no passed message"), 3, id, ver)
					lib.notify("PLUGIN_FAILURE", {
						plugin_id = id,
						version = ver,
						error_string = tostring(state_data.err_details or "self triggered error with no passed error message")
					})
				end
			else
				lib.log_error("	state '" .. tostring(k) .. "' failed to change to >> " .. tostring(newval) ..
					" (type mismatch: " .. type(newval) .. " vs " .. type(ref[v]) .. ")", 1)
				lib.log_error("	state was " .. tostring(ref[v]), 1)
			end
		end
	end

	reg.update_plugin(id, ver, ref)
	return true
end
