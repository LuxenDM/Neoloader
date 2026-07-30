--[[
[modreg]
API=3
id=lexicon
version=1.0.0
name=Lexicon Translation Library
author=Luxen
website=<tbd>
path=lexicon.lua

[metadata]
description=Core file for Lexicon
owner=lexicon|1.0.0
type=lua
created=2026-4-10
]]--

local re_path = lib.get_path() or lib.get_path("lexicon", "1.0.0") or "plugins/Lexicon/"
local re_ver = lib.plugin_read_str(re_path .. "lexicon.lua", nil, "modreg", "version")
local re_standalone = (re_path == "plugins/Lexicon/") and "YES" or "NO"

local cp = function(msg, v)
	lib.log_error("[lexicon] " .. tostring(msg), v or 1, "lexicon", re_ver)
end

cp("Lexicon " .. re_ver .. " is operating out of " .. re_path)



local config, public, private

config = {
	precache = "NO", --if entries are loaded during book creation. Slows initial game load, better performance.
	manage_game_locale = "NO", --when yes, baseline and game locale are adjusted at the same time
	do_translit = "YES", --handle transliteration of characters not loaded by the game
	baseline_locale = "en", --what locale to use. Only accepts game-safe entries.
	extended_locale = "en", --what preferred locale to use. All entries accepted. Falls back to baseline.
}

public = {
	
	CCD1 = true,
	commands = {},
	manifest = {
		"main.lua",
		"lexicon.lua",
		
		"assets/",
		"lang/",
		"modules/",
		"tools/",
	},
	get_config_list = function()
		local ret = {}
		for id in pairs(config) do
			table.insert(ret, id)
		end
		return ret
	end,
	get_config = function(cfg)
		return config[cfg]
	end,
	set_config = function(cfg, val)
		if config[cfg] then
			config[cfg] = tostring(val)
		end
	end,
	save_config = function()
		for k, v in pairs(config) do
			gkini.WriteString("Lexicon", k, v)
		end
	end,
	load_config = function()
		for k, v in pairs(config) do
			config[k] = gkini.ReadString("Lexicon", k, v)
		end
	end,
}

public.load_config()

private = {
	path = re_path,
	version = re_ver,
	standalone = re_standalone,
	cp = cp,
	
	--debug = {},
	
	load_module = function(file_path)
		local valid_file_path = lib.find_file(private.path .. "modules/" .. file_path)
		if valid_file_path then
			cp("executing module " .. valid_file_path)
			
			local file_f, err = loadfile(valid_file_path)
			
			if file_f then
				file_f(public, private, config)
			else
				error("failed to load required module " .. file_path .. ": " .. err)
			end
		else
			error("failed to find required module " .. file_path)
		end
	end,
	
	lstr = function(index, default_str)
		return default_str
	end,
	
	skip_class_update = true, --prevent spamming class updates when loading from internal languages
}

private.update_class = function()
	if private.skip_class_update then
		return
	end

	public.load_config()
	
	local class = {
		description = private.lstr(1, "Lexicon makes it easier for other plugins to provide translations for other languages through an indexed dictionary library."),
	}
	
	local lang_name_to_code_lookup = {}
	local lang_code_to_name_lookup = {}
	
	class.smart_config = {
		title = private.lstr(2, "Lexicon translation dictionary library"),
		cb = function(id, val)
			if id == "extended_locale" then
				config[id] = lang_name_to_code_lookup[val]
				gkini.WriteString("Lexicon", id, config[id])
			elseif id == "baseline_locale" then
				config[id] = lang_name_to_code_lookup[val]
				gkini.WriteString("Lexicon", id, config[id])
			elseif config[id] then
				config[id] = val
				gkini.WriteString("Lexicon", id, val)
			end
		end,
		spacer = {
			type = "spacer",
		},
		precache = {
			type = "toggle",
			display = private.lstr(3, "Precache and save all entries when a translation is loaded"),
			[1] = config.precache,
		},
		manage_game_locale = {
			type = "toggle",
			display = private.lstr(4, "Match game locale to your preferred language when valid"),
			[1] = config.manage_game_locale,
		},
		extended_locale = {
			type = "dropdown",
			display = private.lstr(5, "primary locale") .. ":",
			default = 1,
		},
		baseline_locale = {
			type = "dropdown",
			display = private.lstr(6, "secondary locale") .. ":",
			default = 1,
		},
		locale_display_text = {
			type = "text",
			alignment = "left",
			display = private.lstr(7, "The primary locale will be used first when supported. The secondary locale is a fallback"),
		},
		do_translit = {
			type = "toggle",
			display = private.lstr(20, "Do transliteration of invalid font characters"),
			[1] = lib.log_error("\t\12700FF00Config do-translit is " .. config.do_translit) or config.do_translit,
		},
		"locale_display_text",
		"extended_locale",
		"baseline_locale",
		"spacer",
		"precache",
		"manage_game_locale",
		"do_translit",
	}
	
	--get list of languages supported by Lexicon and prepare them for smart-config dropdowns
	local lang_entries = public.get_support_list()
	local primary_names = {}
	local secondary_names = {}
	for i, v in ipairs(lang_entries) do
		--get supported language entry; add to reverse-lookup table
		local entry = public.get_language(v)
		lang_name_to_code_lookup[entry.lang] = v
		lang_code_to_name_lookup[v] = entry.lang
		
		--insert into relevant tables
		table.insert(primary_names, entry.lang)
		if entry.game_supported then
			table.insert(secondary_names, entry.lang)
		end
	end
	
	--sort by language name alphabetically (normally sorted by 'code' instead of full name)
	table.sort(primary_names)
	table.sort(secondary_names)
	
	--actually add to dropdowns
	for i, v in ipairs(primary_names) do
		class.smart_config.extended_locale[i] = v
		if lang_name_to_code_lookup[v] == config.extended_locale then
			class.smart_config.extended_locale.default = i
		end
	end
	
	for i, v in ipairs(secondary_names) do
		class.smart_config.baseline_locale[i] = v
		if lang_name_to_code_lookup[v] == config.baseline_locale then
			class.smart_config.baseline_locale.default = i
		end
	end
	
	--overwrite entries in the public table
	for k, v in pairs(class) do
		public[k] = v
	end
	
	--push to class table
	lib.set_class("lexicon", private.version, public)
end


private.load_module("transliterator.lua") --transliterate characters not loaded by the font atlas based on game locale
private.load_module("registry.lua") --base registry to contain languages and support selection
private.load_module("legacy.lua") --enables import of legacy Babel language files
private.load_module("select.lua") --handles functionality when language is selected

private.load_module("import.lua") --[ALWAYS CALL AFTER ENVIRONMENT!] handles importing officially provided lexicon languages

private.load_module("interface.lua") --provides language selection widget and dialog

private.update_class()