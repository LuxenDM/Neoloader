--[[
[metadata]
description=provides hardcoded table-lookup for parts of Neoloader
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-23
]]--


local neo = ...
local neo_path = neo.path

local lex_ready = false
local lex_ver
local lex_class

local get_setup_locale = function()
	if lex_ready then
		return lex_class.get_primary_locale() or "en"
	end
	
	local vo_local = GetCurrentLanguage()
	if vo_local ~= "" then
		return vo_local
	end
	
	return "en"
end

neo.api.lget = function(chapter, header, key, err_val)
	err_val = (type(err_val) == "string" and err_val) or "STRING_LOOKUP_ERROR"
	
	local locale_flag = get_setup_locale() .. "/"
	
	local lang_path = neo_path .. "lang/" .. locale_flag .. chapter .. ".ini"
	
	return gkini.ReadString2(header, key, err_val, lang_path) or err_val
end

neo.api.lex_check = function()
	lex_ready = false
	lex_class = nil
	lex_ver = nil
	
	local ver = lib.get_latest("lexicon", "1.0.0", "1.4.9")
	if not ver then
		return false
	end
	
	local class = lib.get_class("lexicon", ver)
	if type(class) ~= "table"
		or type(class.get_primary_locale) ~= "function"
	then
		return false
	end
	
	lex_ver = ver
	lex_class = class
	lex_ready = true
	return true
end
