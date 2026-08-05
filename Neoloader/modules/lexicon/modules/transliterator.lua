--[[
[metadata]
description=Provides transliteration support for characters not loaded by VO's font atlas
owner=lexicon|1.0.0
type=lua
created=2026-05-10

how it works:
	public.transliterate_for_display(str, lang_code)

1) What font atlas is currently available?
	(GetLocale() -> current glyph family)
2) What glyph family does this translation require?
	(glyph_family_lookup[lang_code])
3) If unavailable, how do we degrade it safely?
	(transliterators[...])
]]--

local file_args = {...}
local public = file_args[1]
local private = file_args[2]
local config = file_args[3]

local trlit = {}
public.transliterator = trlit

local glyph_families = {
	--maps the font atlas to what languages loaded it, and how to destruct it
	latin_basic = {
		loaded_by = {"en"},
		--no transliterator, pass all chars straight through
		--these are the game's default 128 characters, which are _always_ loaded
	},

	latin_extended = {
		loaded_by = {"es", "pt", "de", "fr", "it", "tr", "pl", "id", "vi"},
		transliterator = "latin_extended",
	},

	cyrillic = {
		loaded_by = {"ru", "uk"},
		transliterator = "cyrillic",
	},

	thai = {
		loaded_by = {"th"},
		transliterator = "thai",
	},

	indic = {
		loaded_by = {"hi", "bn"},
		transliterator = "indic",
	},

	korean = {
		loaded_by = {"ko"},
		transliterator = "korean",
	},

	japanese = {
		loaded_by = {"ja"},
		transliterator = "japanese",
	},

	chinese_simplified = {
		loaded_by = {"zh"},
		transliterator = "chinese_simplified",
	},

	chinese_traditional = {
		loaded_by = {"zh-tw"},
		transliterator = "chinese_traditional",
	},

	arabic = {
		loaded_by = {"ar"},
		transliterator = "arabic",
	},
}

local glyph_family_lookup = {
	--add new languages here, such as 'nl="latin_extended"'
	en = "latin_basic",

	es = "latin_extended",
	["pt-br"] = "latin_extended",
	pt = "latin_extended",
	de = "latin_extended",
	fr = "latin_extended",
	it = "latin_extended",
	tr = "latin_extended",
	pl = "latin_extended",
	id = "latin_extended",
	vi = "latin_extended",

	ru = "cyrillic",
	uk = "cyrillic",

	th = "thai",
	hi = "indic",
	bn = "indic",

	ko = "korean",
	ja = "japanese",
	zh = "chinese_simplified",
	["zh-tw"] = "chinese_traditional",

	ar = "arabic",
}

local transliterators = {
	latin_extended = {
		['¿'] = "?",
		['¡'] = "!",

		['À'] = "A",
		['Á'] = "A",
		['Â'] = "A",
		['Ã'] = "A",
		['Ä'] = "A",
		['Å'] = "A",
		['Æ'] = "AE",

		['Ç'] = "C",

		['È'] = "E",
		['É'] = "E",
		['Ê'] = "E",
		['Ë'] = "E",

		['Ì'] = "I",
		['Í'] = "I",
		['Î'] = "I",
		['Ï'] = "I",

		['Ð'] = "D",

		['Ñ'] = "N",

		['Ò'] = "O",
		['Ó'] = "O",
		['Ô'] = "O",
		['Õ'] = "O",
		['Ö'] = "O",
		['Ø'] = "O",

		['Ù'] = "U",
		['Ú'] = "U",
		['Û'] = "U",
		['Ü'] = "U",

		['Ý'] = "Y",

		['Þ'] = "TH",
		['ß'] = "ss",

		['à'] = "a",
		['á'] = "a",
		['â'] = "a",
		['ã'] = "a",
		['ä'] = "a",
		['å'] = "a",
		['æ'] = "ae",

		['ç'] = "c",

		['è'] = "e",
		['é'] = "e",
		['ê'] = "e",
		['ë'] = "e",

		['ì'] = "i",
		['í'] = "i",
		['î'] = "i",
		['ï'] = "i",

		['ð'] = "d",

		['ñ'] = "n",

		['ò'] = "o",
		['ó'] = "o",
		['ô'] = "o",
		['õ'] = "o",
		['ö'] = "o",
		['ø'] = "o",

		['ù'] = "u",
		['ú'] = "u",
		['û'] = "u",
		['ü'] = "u",

		['ý'] = "y",
		['ÿ'] = "y",

		['þ'] = "th",

		-- Polish
		['Ą'] = "A",
		['ą'] = "a",
		['Ć'] = "C",
		['ć'] = "c",
		['Ę'] = "E",
		['ę'] = "e",
		['Ł'] = "L",
		['ł'] = "l",
		['Ń'] = "N",
		['ń'] = "n",
		['Ś'] = "S",
		['ś'] = "s",
		['Ź'] = "Z",
		['ź'] = "z",
		['Ż'] = "Z",
		['ż'] = "z",

		-- Turkish
		['Ğ'] = "G",
		['ğ'] = "g",
		['İ'] = "I",
		['ı'] = "i",
		['Ş'] = "S",
		['ş'] = "s",

		-- Vietnamese extras
		['Ơ'] = "O",
		['ơ'] = "o",
		['Ư'] = "U",
		['ư'] = "u",
	},

	cyrillic = {},
	thai = {},
	indic = {},
	korean = {},
	japanese = {},
	chinese_simplified = {},
	chinese_traditional = {},
	arabic = {},
}

trlit.register_glyph_family = function(lang_code, family)
	lang_code = trlit.normalize_lang_code(lang_code)
	family = tostring(family or "")

	if lang_code == "" or family == "" then
		return false, "invalid glyph family registration"
	end

	if glyph_family_lookup[lang_code] then
		return true
	end

	glyph_family_lookup[lang_code] = family
	return true
end

trlit.register_transliterator_service = function(family, trtable)
	if transliterators[family] and (#transliterators[family] > 0) then
		return
	end
	
	transliterators[family] = trtable
end

trlit.add_transliteration_char_pairing = function(original_char, output_safe_char, transliterator_name)
	if not transliterators[transliterator_name] then
		return
	end
	
	transliterators[transliterator_name][original_char] = output_safe_char
end

trlit.normalize_lang_code = function(code)
	code = tostring(code or ""):lower():gsub("_", "-")

	local aliases = {
		["pt-br"] = "pt-br", --why did I add these top two?
		["zh-tw"] = "zh-tw",
		jp = "ja",
		ua = "uk",
	}

	return aliases[code] or code
end

private.apply_transliterator = function(str, transliterator)
	for source, replacement in pairs(transliterator or {}) do
		str = string.gsub(str, source, replacement)
	end
	return str
end

local cp = console_print

trlit.transliterate_for_display = function(str, lang_code)
	if config.do_translit == "NO" then
		return str
	end
	
	if type(str) ~= "string" then
		return str
	end
	
	cp("\12700FF00Request to transliterate")
	cp("\tworking on " .. str)

	local game_code = trlit.normalize_lang_code(GetLocale())
	local text_code = trlit.normalize_lang_code(lang_code)
	
	cp("\tgame is running in " .. game_code .. "; text_code is " .. text_code)

	local game_family = glyph_family_lookup[game_code] or "latin_basic"
	local text_family = glyph_family_lookup[text_code] or "latin_basic"
	
	cp("\tfont families: current atlas is " .. game_family .. "; text expects " .. text_family)

	if game_family == text_family then
		cp("\tfont family match, no translit needed.")
		return str
	end
	
	local family = glyph_families[text_family]
	local transliterator_id = family and family.transliterator
	local transliterator = transliterator_id and transliterators[transliterator_id]
	
	if not transliterator then
		return str
	end
	
	return private.apply_transliterator(str, transliterator)
end





