--[[
[metadata]
description=Formats and handles message logging
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--


local neo = ...
local reg = neo.api.registry
local rs  = neo.api.recovery_system
local lib = neo.lib

local alignment_offset = neo.api.get_alignment_offset()

neo.lib.log_error = function(msg, alert, id, ver)
	alert = tonumber(alert or 2) or 2
	local use_plugin = (id ~= nil) or (ver ~= nil)

	if use_plugin then
		id, ver = lib.pass_ini_identifier(id, ver)
		id  = tostring(id or "null")
		ver = tostring(ver or "")
		if ver == "0" and id ~= "null" then
			ver = lib.get_latest(id)
		end
	end

	local level_labels = { [1]="DEBUG", [2]="INFO", [3]="WARNING", [4]="ERROR" }
	local status = level_labels[alert] or "ALERT"

	local gtime_ms = (gkmisc.GetGameTime() + alignment_offset) % 1000
	local val = string.format("[%s.%03d] [%s] %s\127FFFFFF",
		os.date("%Y-%m-%d %H:%M:%S"),
		gtime_ms,
		status,
		tostring(msg)
	)

	console_print(filter_colorcodes(val))
	table.insert(neo.log, val)

	if alert > 3 then
		rs.push_error(filter_colorcodes(msg), {
			no_log = true,
		})
	end

	if use_plugin and lib.is_exist(id, ver) then
		local ok, _, rec = reg.find_plugin(id, ver)
		if ok and rec then table.insert(rec.errors, val) end
	end
end
