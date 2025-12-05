--[[
[metadata]
description=provides hardcoded table-lookup for parts of Neoloader
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-23
]]--


local neo = ...
neo_path = neo.path

local err_val = "STRING_LOOKUP_ERROR"

neo.api.lget = function(chapter, header, key)
	local locale_flag = gkini.ReadString("Vendetta", "locale", "en") .. "/"
	
	local lang_path = neo_path .. "lang/" .. locale_flag .. chapter .. ".ini"
	
	return gkini.ReadString2(header, key, err_val, lang_path) or err_val
end

