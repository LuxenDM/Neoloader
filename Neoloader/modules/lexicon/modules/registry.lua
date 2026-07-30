--[[
[metadata]
description=Lexicon's internal registry handler
owner=lexicon|1.0.0
type=lua
created=2026-04-09
]]--

local file_args = {...}
local public = file_args[1]
local private = file_args[2]
local config = file_args[3]

local game_supported = {--these are the lang-codes supported by the game
	'en', 'es', 'fr', 'pt', 'de', 'it', 'pl', 'tr', 'id', 
	'ja', 'ru', 'uk', 'zh', 'ko', 'ar', 'vi', --these are supported by the game, but cannot be rendered by plugins (yet?)
}

local game_requires_locale_to_render = {
	'jp', "ru", 'uk', 'zh', 'ko', 'ar', 'vi',
}

local support = { --list of languages you can select directly in Lexicon
	--[[ example
	en = {
		status = 2, --0: legacy entry, missing info; 1: full entry; 2: official entry
		lang = "English", --full (localized) name of language
		flag = private.path .. "lang/en/flag.png", --path to image for flag
		game_supported = true, --is the language supported by the game
		provider = private.path .. "lang/en/en.ini", --path to the INI where this language was registered out of
		fallback = "",
		metadata = {
			legacy = nil, --imported by legacy handler from Babel
			official = true, --provided directly by Lexicon
		},
	},
	]]--
}
--private.debug.support = support

private.check_game_supported = function(code)
	for _, v in ipairs(game_supported) do
		if code == v then
			return true
		end
	end
	return false
end

local split_path = function(path_input)
    local dir, file = path_input:match("^(.-)([^/]+)$")
    return dir, file
end

public.get_support_list = function()
	local rettab = {}
	for lang_code, lang_table in pairs(support) do
		table.insert(rettab, lang_code)
	end
	
	table.sort(rettab)
	
	return rettab
end

public.is_supported = function(lang_code)
	local gs = (private.check_game_supported(lang_code))
	local ls = (support[lang_code] ~= nil)
	return ls, gs
end

public.get_language = function(lang_code)
	if not public.is_supported(lang_code) then
		return false
	end
	
	local entry = support[lang_code]
	entry.metadata = entry.metadata or {}
	
	return {
		status = entry.status,
		code = lang_code,
		lang = entry.lang,
		flag = entry.flag,
		game_supported = entry.game_supported,
		provider = entry.provider,
		fallback = entry.fallback, 
		legacy = entry.metadata.legacy,
		official = entry.metadata.official,
	}
end

private.add_support = function(lang_code, ini_path)
	local lang_table = support[lang_code]
	if lang_table and lang_table.status > 0 then
		return false, "already implemented"
	end
	
	local default = {
		code = "",
		lang = "",
		flag = "",
		fallback = "",
	}
	
	for k, v in pairs(default) do
		default[k] = gkini.ReadString2("lexicon", k, v, ini_path)
	end
	
	if default.code == "" or default.lang == "" then
		return false, "invalid entry"
	end
	
	default.lang = public.transliterator.transliterate_for_display(default.lang, lang_code)
	
	default.status = 1
	default.game_supported = private.check_game_supported(default.code)
	
	if default.flag == "" then
		default.flag = private.path .. "assets/flag_null.png"
	else
		local path, file = split_path(ini_path)
		default.flag = path .. default.flag
	end
	
	default.provider = ini_path
	
	support[default.code] = default
	
	private.update_class()
end

private.get_fallback = function(lang_code)
	if not support[lang_code] then
		return public.get_safe_locale()
	end
	local fallback = support[lang_code].fallback
	return fallback ~= "" and fallback or public.get_safe_locale()
end

private.mutate_support_entry = function(code, intab) --internal only, used to mark languages with metadata
	local entry = support[code] or {}
	for i, v in pairs(intab) do
		entry[i] = v
	end
	support[code] = entry --redeclared in case 'new'
end	



















local registry = {} --list of external mod tables
--private.debug.registry = registry

local fast_table = {} --list of mod's tables using older ID system (fetch with less steps)

--[[
local registry = {
	[plugin_id] = {
		[plugin_version] = {
			fast_id = numeric_index,
			locale_code = {
				path = "path/to/file.ini",
				[1] = 'precached entry'
				[2] = ...
			},
		},
	}
}

local fast_table = {
	[id] = register[plugin_id][plugin_version]
}
]]--

public.fetch = function(id_lookup, read_key, default_value)
	if not fast_table[id_lookup] then
		lib.log_error("lexicon fetch request failed: id didn't exist!")
		return default_value
	end
	read_key = tostring(read_key)
	default_value = tostring(default_value)
	
	local entry = fast_table[id_lookup]
	local locale = gkini.ReadString("Vendetta", "locale", "en") --this is a lang_code
	for _, v in ipairs {
		config.extended_locale,
		private.get_fallback(config.extended_locale),
		public.get_safe_locale(),
	} do
		if entry[v] then
			locale = v
			break
		end
	end
	
	if not entry[locale] then
		return default_value
	end
	
	if not entry[locale][read_key] then
		local read_value = gkini.ReadString2("lexicon", read_key, "", entry[locale].path)
		if read_value ~= "" then
			read_value = public.transliterator.transliterate_for_display(read_value, locale)
			entry[locale][read_key] = read_value
		end
	end
	
	return entry[locale][read_key] or default_value
end

public.retrieve = function(entry_id, entry_version, read_key, default_value)
	if not (registry[entry_id] and registry[entry_id][entry_version]) then
		return default_value
	end
	local entry = registry[entry_id][entry_version]
	return public.fetch(entry.fast_id, read_key, default_value)
end

private.add_page = function(entry_id, entry_version, lang_code, intab)
	--called by legacy import only
	registry[entry_id][entry_version][lang_code] = intab
end

private.get_fast_id = function(entry_id, entry_version)
	return registry[entry_id][entry_version].fast_id
end

public.register = function(entry_id, entry_version, ini_path)
	private.cp(entry_id .. " v" .. entry_version .. " creating new translation page using " .. ini_path)
	
	local mstime = gkmisc.GetGameTime()
	
	registry[entry_id] = registry[entry_id] or {}
	registry[entry_id][entry_version] = registry[entry_id][entry_version] or {}
	
	local book_entry = registry[entry_id][entry_version]
	
	if not book_entry.fast_id then
		table.insert(fast_table, registry[entry_id][entry_version])
		book_entry.fast_id = #fast_table
	end
	
	local lang_code = gkini.ReadString2("lexicon", "code", "", ini_path)
	
	if lang_code == "" then
		local babel_entry = gkini.ReadString2("babel", "0", "", ini_path)
		if babel_entry == "" then
			return false, "invalid INI data"
		else
			return private.legacy_import(entry_id, entry_version, ini_path)
		end
	end
	
	if book_entry[lang_code] then
		return false, "translation already present"
	end
	
	local lang_table = {
		path = ini_path,
	}
	
	book_entry[lang_code] = lang_table
	
	private.add_support(lang_code, ini_path)
	
	local counter = -1
	if config.precache == "YES" then
		while true do
			counter = counter + 1
			
			local output = gkini.ReadString2('lexicon', tostring(counter), "", ini_path)
			if output == "" then
				break
			end
			output = public.transliterator.transliterate_for_display(output, lang_code)
			lang_table[tostring(counter)] = output
		end
		private.cp("\ttranslation page had " .. tostring(counter) .. " lines to cache!")
	end
	
	lib.log_error("\ttranslation page generated in " .. tostring(gkmisc.GetGameTime() - mstime) .. "ms")
	
	return book_entry.fast_id
end

