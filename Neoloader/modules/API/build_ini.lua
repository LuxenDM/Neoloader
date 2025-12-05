--[[
[metadata]
description=Build a parsed INI record (v7 lib wrapper around registry.build_ini)
version=1.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-7
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

lib.build_ini = function(ifp)
	if lib.err_handle(type(ifp) ~= "string", "lib.build_ini expected a string (file path), got "..type(ifp)) then
		return false, "ini file path not a string"
	end
	if gksys.IsExist(ifp) == false then
		lib.err_handle(true, "lib.build_ini failed; file does not exist at "..ifp)
		return false, "no file"
	end

	-- delegate to registry; it will also populate ini_pointer_cache
	local record, err = reg.build_ini(ifp)
	if not record then
		return false, err or "parse failed"
	end
	
	--check API
	local api_expected = tonumber(record.API_required)
	local api_avail = neo.lme_ver[1]
	local skip_api_check = neo.api.config.get_config("allow_bad_api_version") == "YES"

	if (not skip_api_check) and (api_avail ~= api_expected) then
		lib.err_handle(true, "lib.build_ini failed; API mismatched! expected " .. tostring(api_expected) .. ", but API provided is " .. tostring(api_avail))
		return false, "API mismatch"
	end

	return record
end
