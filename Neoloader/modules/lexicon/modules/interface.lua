--[[
[metadata]
description=Provides the selection interface as an embeddable widget or its own dialog
owner=lexicon|1.0.0
type=lua
created=2026-04-12
]]--

local file_args = {...}
local public = file_args[1]
local private = file_args[2]
local config = file_args[3]

local lexif = {} --lexicon interface
public.interface = lexif

--lexif.locale_selector - create scrolling display of supported languages
--lexif.locale_selector_compact - create scrolling display of supported languages in compact list form
--lexif.locale_selector_dialog - open full selector in simple modal dialog

--lexif.settings_diag - unified control surface for all lexicon configuration
--[[
	precache toggle
	apply-to-game toggle
	view baseline and extended locales
		selecting one opens the locale selector
]]--


--interface generation elements copied from Helium v1.1.3

local clearframe = function(intable)
	assert(type(intable) == "table", "Helium.clearframe expects a table for its argument, got a " .. type(intable))
	
	local default = {
		bgcolor = "0 0 0 0 *",
		segmented = "0 0 1 1",
		iup.vbox { },
		expand = "NO",
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	assert((iup.IsValid(default[1])), "Helium.clearframe input table did not have a valid IUP element at [1]; got " .. type(intable[1]))
	
	return iup.frame(default)
end

local create_slider_control = function(intable)
	local scroll_timer = Timer()
	local scroll_flag = false
	local defaults = {
		ymin = 0,
		ymax = 100,
		dy = 30,
		posy = 0,
		scrollbar = "VERTICAL",
		expand = "VERTICAL",
		scroll_event_cb = function() end,
		scroll_cb = function(self)
			scroll_flag = true
		end,
		border = "NO",
	}

	for k, v in pairs(intable) do
		defaults[k] = v
	end

	local scroll = iup.canvas(defaults)
	scroll.get_pos = function(self)
		return self.posy
	end

	local scroll_update
	scroll_update = function()
		if not iup.IsValid(scroll) then
			scroll_timer:Kill()
			return
		end
		
		if scroll_flag then
			defaults.scroll_event_cb(scroll)
			scroll_flag = false
		end
		scroll_timer:SetTimeout(1, scroll_update)
	end

	scroll.init_timer = scroll_update

	return scroll
end

local create_autobox = function(intable)
	local default = {
		expand = "YES",
		[1] = iup.vbox {},
		cx = 0,
		cy = 0,
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	
	local cbox_children = {}
	--add from default
	for k, v in ipairs(default) do
		cbox_children[k] = clearframe {
			cx = v.cx or default.cx,
			cy = v.cy or default.cy,
			v,
		}
	end
	--clear from default
	for k, v in ipairs(cbox_children) do
		default[k] = nil
	end
	
	local imposter = clearframe {
		--used to get size of parent
		expand = "YES",
		iup.vbox {
			iup.hbox {
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	local cbox_area = iup.cbox (cbox_children)
	
	default[1] = iup.zbox {
		cbox_area,
		default.expand ~= "NO" and imposter or nil,
	}
		
	
	local root_frame = clearframe(default)
	root_frame.map_cb = function(self)
		local root = imposter
		local w = tostring(root.w)
		local h = tostring(root.h)
		cbox_area.size = w .. "x" .. h
		for k, v in ipairs(cbox_children) do
			v.size = w .. "x" .. h
		end
		iup.Refresh(self)
	end
	
	root_frame.cbox = cbox_area
	root_frame.cbox_children = cbox_children
	root_frame.imposter = imposter
	
	return root_frame
end

local create_list_control = function(intable)
	local default = {
		expand = "YES",
		scrollbar = "YES",
		[1] = iup.vbox {},
	}

	for k, v in pairs(intable) do
		default[k] = v
	end

	local iup_element = default[1]
	default[1] = nil

	-- use autobox with one child: the scrollable element
	local ab = create_autobox {
		iup_element,
	}

	local scroller
	scroller = create_slider_control {
		scroll_event_cb = function()
			local content = ab.cbox_children[1]
			content.cy = ((scroller:get_pos() * (tonumber(content.h) - tonumber(scroller.h))) / 100) * -1
			iup.Refresh(content)
		end,
	}

	default[1] = iup.hbox {
		ab,
		scroller,
	}

	local root_frame = clearframe(default)

	root_frame.map_cb = function(self)
		if self.expand == "NO" then return end

		local w = ab.imposter.w
		local h = ab.imposter.h

		self.size = tostring(w) .. "x" .. tostring(h)
		scroller.size = tostring(Font.Default) .. "x" .. tostring(h)

		local content = ab.cbox_children[1]

		-- handle scrollbar logic
		local content_h = content.h
		local inner_w = w - Font.Default

		if default.scrollbar == "NO" or content_h < h then
			-- disable scrollbar if content fits
			--scroller:detach()
			ab.cbox.size = w .. "x" .. h
			content.size = w .. "x" .. h
		else
			ab.cbox.size = inner_w .. "x" .. h
			content.size = inner_w .. "x" .. content_h
		end
		
		scroller.posy = 0
		scroller.init_timer()

		iup.Refresh(self)
	end

	return root_frame
end

local coverbutton = function(intable)
	local default = {
		action = function(self) end,
		[1] = iup.vbox { },
	}
	
	for k, v in pairs(intable) do
		default[k] = v
	end
	
	local cover = iup.button {
		title = "", 
		bgcolor = "0 0 0 0 *",
		expand = "YES",
		action = default.action,
	}
	
	return iup.zbox {
		all = "YES",
		expand = "NO",
		alignment = "ACENTER",
		default[1],
		cover,
	}
end

local slide_toggle = function(intable)
	assert(type(intable) == "table", "helium.slide_toggle expects a table")

	local default = {
		value = "NO",
		image_off = private.path .. "assets/slide_off.png",
		image_on  = private.path .. "assets/slide_on.png",
		size = tostring(Font.Default * 2) .. "x" .. tostring(Font.Default),
		action = function(self, value) end,
	}

	for k, v in pairs(intable) do
		default[k] = v
	end

	local img = iup.label {
		title = "",
		image = (default.value == "YES") and default.image_on or default.image_off,
		value = default.value,
		size = default.size,
		--bgcolor = "0 0 0  *",
	}
	
	local toggle_container = coverbutton {
		action = function(self)
			if img.value == "YES" then
				img.value = "NO"
				img.image = default.image_off
			else
				img.value = "YES"
				img.image = default.image_on
			end
			default.action(self, img.value)
		end,
		img,
	}

	return toggle_container
end





local get_locale_list = function(filter_func)
	if not filter_func then
		--no filter, accept all supported locales
		filter_func = function() 
			return true 
		end
	end
	
	local filtered = {}
	local supported = public.get_support_list()
	for i, v in ipairs(supported) do
		if filter_func(v) then
			table.insert(filtered, v)
		end
	end
	
	return filtered
end

local selector_content = function(intab)
	local default = {
		compact = false, --disable full mode, shrink all entries
		show_config = true, --show switch between primary and secondary, and what current values are
		show_labels = true, --in full mode, display notes on languages
		advanced = false, --when true, show technical notes on languages
		
		filter_func = function() return true end, --obtains lang_code, return true or false from each to hide certain entries
		sort_func = function(a, b) return a < b end, --sort order of language list
		action = nil, --if a function, overrides apply_locale
	}
	
	for k, v in pairs(intab) do
		default[k] = v
	end
	
	local selector_list_content = iup.vbox {}
	local selector_list_table = {}
	local selector_mode = 1 --1: primary, 2: secondary
	
	local cur_primary = iup.label {
		title = public.get_language(config.extended_locale).lang,
	}
	
	local cur_secondary = iup.label {
		title = public.get_language(config.baseline_locale).lang,
	}
	
	local apply_locale = function(lang_entry)
		if selector_mode < 2 then
			public.set_primary_locale(lang_entry.code)
			cur_primary.title = lang_entry.lang
		else
			public.set_secondary_locale(lang_entry.code)
			cur_secondary.title = lang_entry.lang
		end
		iup.Refresh(cur_primary)
	end
	
	if type(default.action) == "function" then
		apply_locale = default.action
	end
	
	local lang_status_lookup = { --lookup for quick status, use more detailed labels for other metadata
		[0] = private.lstr(8, "This language was added by a legacy translation book. Support across mods is probably minimal"), --external mod, babel book
		[1] = private.lstr(9, "This language was added by a mod. Support across other mods may vary"), --1: external mod
		[2] = private.lstr(10, "This language is provided by Lexicon."),
	}
	
	local flip_flag = true
	local create_entry = function(lang_code)
		flip_flag = not flip_flag
		local lang_entry = public.get_language(lang_code)
		local flag = iup.label {
			title = "",
			image = lang_entry.flag,
			size = default.compact and (tostring(Font.Default * 4) .. "x" .. tostring(Font.Default * 2)) or "128x85", --"256x171",
		}
		local language_name_text = iup.label {
			title = lang_entry.lang,
			font = default.compact and Font.Default or Font.Default + 8,
		}
		local support_status_label = iup.label {
			title = lang_status_lookup[lang_entry.status]
		}
		local game_supported = iup.label {
			title = private.lstr(11, "The game supports this language natively"),
			--'natively' is bad wording, need to improve this line
		}
		local provider_name = iup.label {
			title = private.lstr(12, "This language was added from this file") .. ": " .. lang_entry.provider,
		}
		local fallback_lang_name = ""
		if lang_entry.fallback ~= "" then
			local fallback_entry = public.get_language(lang_entry.fallback)
			if fallback_entry then
				fallback_lang_name = fallback_entry.lang
			end
		end
		local native_fallback = iup.label {
			title = private.lstr(13, "If this language isn't supported by a mod, it will automatically use the following instead") .. ": " .. fallback_lang_name,
		}
		
		local extended_notes = iup.vbox {
			alignment = "ARIGHT",
			support_status_label,
			(lang_entry.status < 2) and (default.advanced) and provider_name or false,
			lang_entry.game_supported and game_supported or false,
			(lang_entry.fallback ~= "") and native_fallback or false,
		}
		
		local entry_line = coverbutton {
			action = function() apply_locale(lang_entry) end,
			clearframe {
				expand = "HORIZONTAL",
				bgcolor = flip_flag and "0 0 0 0 *" or "255 255 255 50 *",
				padding = "2",
				iup.hbox {
					gap = default.compact and "1" or "6",
					flag,
					iup.fill { },
					iup.vbox {
						alignment = "ARIGHT",
						language_name_text,
						(not default.compact) and (default.show_labels) and extended_notes or false,
					},
				},
			},
		}
		
		return entry_line
	end
	
	local list_view = create_list_control {
		selector_list_content,
	}
	
	local list_view_container = iup.vbox {
		list_view
	}
	
	local update_lang_display = function()
		list_view:detach()
		local supported_langs = get_locale_list(default.filter_func)

		table.sort(supported_langs, default.sort_func)

		for i = #selector_list_table, 1, -1 do
			local line_entry = selector_list_table[i]
			line_entry:detach()
			selector_list_table[i] = nil
		end

		for i, v in ipairs(supported_langs) do
			local line_entry = create_entry(v)
			table.insert(selector_list_table, line_entry)
			selector_list_content:append(line_entry)
		end
		
		list_view_container:append(list_view)

		iup.Refresh(selector_list_content)
		list_view:map_cb()
		
		for i, v in ipairs(selector_list_table) do
			v.size = tostring(list_view.w - (Font.Default)) .. "x"
		end
	end
	
	local prim_label = iup.label {
		title = private.lstr(5, "primary"),
		fgcolor = "255 255 255",
	}
	
	local secn_label = iup.label {
		title = private.lstr(6, "secondary"),
		fgcolor = "100 100 100",
	}
	
	local config_display = iup.vbox {
		alignment = "ACENTER",
		iup.label {
			title = private.lstr(14, "Choose whether you are setting your primary or fallback language"),
		},
		iup.hbox {
			alignment = "ACENTER",
			prim_label,
			slide_toggle {
				value = "NO",
				action = function(self, new_state)
					if new_state == "YES" then
						prim_label.fgcolor = "100 100 100"
						secn_label.fgcolor = "255 255 255"
						selector_mode = 2
					else
						prim_label.fgcolor = "255 255 255"
						secn_label.fgcolor = "100 100 100"
						selector_mode = 1
					end
				end,
			},
			secn_label,
		},
		iup.vbox {
			iup.hbox {
				iup.label {
					title = private.lstr(15, "current preferred language") .. ": ",
				},
				cur_primary,
			},
			iup.hbox {
				iup.label {
					title = private.lstr(16, "current secondary choice") .. ": ",
				},
				cur_secondary,
			},
		},
		iup.label {
			title = private.lstr(17, "Click on a language below to select it"),
			bgcolor = "0 0 0 100 *",
			expand = "HORIZONTAL",
		},
	}
	
	local root_display = iup.stationsubframe {
		map_cb = function()
			update_lang_display()
			list_view:map_cb()
		end,
		update_list = update_lang_display,
		expand = "YES",
		iup.vbox {
			(default.show_config and config_display) or false,
			list_view_container,
		},
	}
	
	return root_display
end

lexif.locale_selector = function(intab)
	
	local default = {}
	
	for k, v in pairs(intab or {}) do
		default[k] = v
	end
	
	local selector_object = selector_content(default)
	
	return selector_object
end

lexif.locale_selector_compact = function(intab) --shortcut for callers
	
	local default = {
		compact = true,
	}
	
	for k, v in pairs(intab or {}) do
		default[k] = v
	end
	
	local selector_object = selector_content(default)
	
	return selector_object
end

lexif.locale_selector_dialog = function(intab)
	local default = {}
	
	for k, v in pairs(intab or {}) do
		default[k] = v
	end
	
	local selector_object = selector_content(default)
	
	local close_btn = iup.stationbutton {
		title = private.lstr(18, "Close"),
		action = function(self)
			HideDialog(iup.GetDialog(self))
		end,
	}
	
	local diag = iup.dialog {
		fullscreen = "YES",
		bgcolor = "0 0 0 200 *",
		topmost = "YES",
		default_esc = close_btn,
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				clearframe {
					size = default.compact and "%30x%30" or "%60x%80",
					expand = "NO",
					iup.vbox {
						iup.hbox {
							iup.label {
								title = private.lstr(19, "Lexicon language selector"),
							},
							iup.fill { },
							close_btn,
						},
						iup.stationsubframe {
							size = default.compact and "%30x%30" or "%60x%80",
							expand = "NO",
							selector_object,
						},
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	diag:map()
	selector_object:map_cb()
	ShowDialog(diag)
end



public.open = function()
	lexif.locale_selector_dialog()
end
