--[[
[metadata]
description=Processes new language selection
owner=lexicon|1.0.0
type=lua
created=2026-04-12
]]--

local file_args = {...}
local public = file_args[1]
local private = file_args[2]
local config = file_args[3]



public.get_primary_locale = function()
	return config.extended_locale
end

public.get_secondary_locale = function()
	return config.baseline_locale
end

public.get_safe_locale = function()
	local ls1, gs1 = public.is_supported(config.extended_locale)
	local ls2, gs2 = public.is_supported(config.baseline_locale)
	if gs1 then
		return config.extended_locale
	elseif gs2 then
		return config.baseline_locale
	else
		return gkini.ReadString("Vendetta", "locale", "en") --gotta bug the devs to provide a better method than this
	end
end

public.set_secondary_locale = function(lang_code) --sets the locale to the selection. Only accepts game-safe entries
	local ls, gs = public.is_supported(lang_code)
	if (not ls)then
		return false, "locale doesn't exist"
	end
	
	ls, gs = public.is_supported(config.extended_locale)
	
	if (not gs) and (config.manage_game_locale == "YES") then --set game to secondary if primary isn't game-safe
		gkini.WriteString("Vendetta", "locale", lang_code)
	end
	
	config.baseline_locale = lang_code
	
	public.save_config()
	return true
end

public.set_primary_locale = function(lang_code) --sets the preferred locale to the selection. falls back to baseline
	local ls, gs = public.is_supported(lang_code)
	if (not ls) then
		return false, "locale doesn't exist"
	end
	
	if (gs) and (config.manage_game_locale == "YES") then
		gkini.WriteString("Vendetta", "locale", lang_code)
	end
	
	config.extended_locale = lang_code
	
	public.save_config()
	return true
end

