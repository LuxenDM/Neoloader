--[[
[modreg]
API=3
id=neonotif
name=Neoloader Notification Handler
version=1.2.0
author=Luxen
website=https://github.com/LuxenDM/Neoloader
path=neonotif.lua

[metadata]
description=neonotif is the standard LME notification front-end bundled with Neoloader
version=1.2.1
owner=Neoloader|7.0.0
type=lua
created=2025-03-09
]]--



local re_path = lib.get_path() or lib.get_path("neonotif", "1.2.0")
local re_ver = lib.plugin_read_str(re_path .. "neonotif.lua", nil, "modreg", "version")
local re_standalone = "NO"

local cp = function(msg, v)
	lib.log_error("[neonotif] " .. tostring(msg), v or 1, "neonotif", re_ver)
end

cp("neonotif " .. re_ver .. " is operating out of " .. re_path)

--verify API compatibility
local api_check = lib.get_gstate().version_lme
for k, v in ipairs {
	api_check[1] == 3,
	api_check[2] >= 12,
} do
	assert(v, "This version of neonotif is not compatible with the version of Neoloader installed! Please use the version bundled with your latest installation of Neoloader!")
end

local neo = {}



-- Lexicon support

local lexicon
local shelf_id
local update_class

local bstr = function(id, def)
	return def
end

local lexicon_support = function()
	lexicon = lib.get_class("lexicon", "0")

	for _, lang_code in ipairs(lexicon.get_support_list()) do
		local page_id, err = lexicon.register(
			"neonotif",
			re_ver,
			re_path .. "lang/" .. lang_code .. ".ini"
		)

		if not shelf_id and page_id then
			shelf_id = page_id
		end

		if not page_id then
			cp(
				"Unable to register Lexicon locale "
				.. tostring(lang_code)
				.. ": "
				.. tostring(err),
				3
			)
		end
	end

	bstr = function(id, def)
		if not shelf_id then
			return def
		end

		return lexicon.fetch(
			shelf_id,
			id,
			def
		)
	end

	update_class()
end

local config = {
	echo_notif = gkini.ReadString("neomgr", "echo_notif", "YES"),
	img_scale = gkini.ReadString("neomgr", "img_scale", "48"),
}

update_class = function()
	local class = {
		CCD1 = true,
		smart_config = {
			title = bstr(1, "Neoloader Notification Handler"),
			cb = function(cfg, val)
				if config[cfg] then
					config[cfg] = val
					gkini.WriteString("neomgr", cfg, val)
				end
			end,
			echo_notif = {
				type = "toggle",
				display = bstr(2, "Display notifications in chat"),
				[1] = config.echo_notif,
			},
			img_scale = {
				type = "slider",
				display = bstr(13, "Notification image size") .. ":",
				min = 8,
				max = 256,
				default = tonumber(config.img_scale),
			},
			"echo_notif",
			"img_scale",
		},
		description = bstr(3, "neo_notif is the bundled notification handler for Neoloader. It provides a simple system for event handling meant for informing the user about system events."),
		commands = {
			bstr(4, "There are no commands registered for neo_notif. Other plugins and tools use it directly."),
		},
		manifest = {
			re_path .. "neo_notif.lua",
			
			re_path .. "assets/notif_placeholder.png",
			re_path .. "assets/notif_pluginfail.png",
			re_path .. "assets/notif_pluginnew.png",
			re_path .. "assets/notif_regdirty.png",
			re_path .. "assets/notif_success.png",
			re_path .. "assets/notif_unhandled.png",
			
			re_path .. "lang/en.ini",
			re_path .. "lang/es.ini",
			re_path .. "lang/fr.ini",
			re_path .. "lang/pt.ini",
		},
	}
	
	for k, v in pairs(class) do
		neo[k] = v
	end
	
	lib.set_class("neonotif", re_ver, neo)
end

local notif_history = {} --notification history

local notif_constructor = {} --notifications that can be handled
local notif_listener = {} --mods accepting notifications

local new_listener = function(id, callback_func)
	id = tostring(id)
	if type(callback_func) ~= "function" then
		return false
	end
	if notif_listener[id] then
		cp("notif-listener " .. id .. " already exists")
		return false
	end
	
	table.insert(notif_listener, callback_func)
	notif_listener[id] = #notif_listener
end

local unreg_listener = function(id)
	id = tostring(id)
	if not notif_listener[id] then
		return false
	end
	table.remove(notif_listener, notif_listener[id])
	notif_listener[id] = nil
end

local get_scale = function()
	local val = tonumber(config.img_scale) or "48"
	return tostring((Font.Default / 24) * val) .. "x" .. tostring((Font.Default / 24) * val)
end

local new_generator = function(notif_to_handle, echo_func, data_func)
	notif_to_handle = tostring(notif_to_handle)
	
	if type(echo_func) ~= "function" then
		echo_func = function(data)
			return "[" .. (data.title or notif_to_handle).. "] " .. (data.subtitle or bstr(5, "Unable to display unregistered notification type"))
		end
	end
	
	if type(data_func) ~= "function" then
		data_func = function(data)
			return iup.pdarootframe {
				iup.hbox {
					alignment = "ACENTER",
					iup.vbox {
						iup.label {
							title = "",
							image = data.img or re_path .. "assets/notif_placeholder.png",
							size = get_scale(),
						},
					},
					iup.vbox {
						iup.label {
							title = data.title or notif_to_handle,
							font = Font.H4,
						},
						iup.label {
							title = data.subtitle or bstr(6, "Notification"),
							font = Font.H6,
						},
						iup.label {
							title = data.line_1 or " ",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_2 or " ",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_3 or " ",
							font = Font.Tiny,
						},
						iup.label {
							title = data.line_4 or " ",
							font = Font.Tiny,
						},
					},
					iup.fill { },
				},
			}
		end
	end
	
	if not notif_constructor[notif_to_handle] then
		notif_constructor[notif_to_handle] = {
			echo = echo_func,
			data = data_func,
		}
	end
end

local notif_creator = function(status, data)
	status = tostring(status)
	cp("Notification: " .. status)
	if not notif_constructor[status] then
		data = {
			title = "UNHANDLED_NOTIFICATION",
			subtitle = bstr(7, "Unknown notification type") .. " " .. status,
		}
		status = "UNHANDLED_NOTIFICATION"
	end
	if type(data) ~= "table" then
		data = {}
	end
	
	table.insert(notif_history, {
		timestamp = os.time(),
		data = data,
		notif = status,
	})
	
	for i, v in ipairs(notif_listener) do
		local status, err = pcall(v, status, data)
		if not status then
			lib.log_error("[neomgr] notification handler error - failed to call a notification listener, error returned: " .. tostring(err))
		end
	end
	
	if config.echo_notif == "YES" then
		print(notif_constructor[status].echo(data))
	end
end

local make_interface = function(status, data)
	status = tostring(status)
	if not notif_constructor[status] then
		data = {
			title = "UNHANDLED_NOTIFICATION",
			subtitle = bstr(7, "Unknown notification type") .. " " .. status,
		}
		status = "UNHANDLED_NOTIFICATION"
	end
	if type(data) ~= "table" then
		data = {}
	end
	cp("Making interface element for " .. status)
	
	return notif_constructor[status].data(data)
end

local get_history = function()
	return notif_history
end

local clear_all = function()
	notif_history = {}
end

--------------------------------------------------------------------------
--Default Notifications
--------------------------------------------------------------------------

new_generator("UNHANDLED_NOTIFICATION", nil, nil)
new_generator("SUCCESS",
	function(data) --notification chat print
		return lib[0] .. " " .. lib[1] .. " " .. bstr(8, "has loaded successfully!")
	end,
	function(data) --notification iup generator
		return iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = re_path .. "assets/notif_success.png",
						size = get_scale(),
					},
				},
				iup.vbox {
					iup.label {
						title = lib[0] .. " " .. lib[1] .. " " .. bstr(8, "has loaded successfully!"),
						Font.H4,
					},
				},
				iup.fill { },
			}
		}
	end
)
new_generator("NEW_REGISTRY",
	function(data) --notification chat print
		return bstr(9, "A new plugin has been registered") .. ": " .. tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "???")
	end,
	function(data) --notification iup generator
		return iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = re_path .. "assets/notif_pluginnew.png",
						size = get_scale(),
					},
				},
				iup.vbox {
					iup.label {
						title = bstr(9, "A new plugin has been registered!"),
						font = Font.H4,
					},
					iup.label {
						title = tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "?"),
						font = Font.H6,
					},
				},
				iup.fill { },
			},
		}
	end
)
new_generator("PLUGIN_FAILURE",
	function(data) --notification chat print
		return lib[1] .. " " .. bstr(10, "encountered an error while loading a plugin") .. ": " .. tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "???")
	end,
	function(data) --notification iup generator
		return iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = re_path .. "assets/notif_pluginfail.png",
						size = get_scale(),
					},
				},
				iup.vbox {
					iup.label {
						title = bstr(11, "A plugin failed to load") .. "!",
						font = Font.H4,
					},
					iup.label {
						title = tostring(data.plugin_id or "???") .. " v" .. tostring(data.version or "???"),
						font = Font.H6,
					},
					iup.label {
						title = tostring(data.error_string or ( "<" .. bstr(12, "failed to fetch error string") .. ">")),
						font = Font.H6,
					},
				},
				iup.fill { },
			},
		}
	end
)
new_generator("NEO_REGISTRY_DIRTY", --[1]: expected [2]: total found
	function(data) --notification chat print
		return "Neoloader has detected dirty entries in the registry. This should not cause issues, but can be fixed from the recovery menu."
			.. "\n\t" .. "The registry expected to find" .. " " .. tostring(data.expected) .. " " .. "entries, but instead got" .. " " .. tostring(data.total)
	end,
	function(data) --notification iup generator
		return iup.pdarootframe {
			iup.hbox {
				iup.vbox {
					iup.label {
						title = "",
						image = re_path .. "assets/notif_regdirty.png",
						size = get_scale(),
					},
				},
				iup.vbox {
					iup.label {
						title = bstr(14, "Neoloader has detected dirty entries in the registry") .. "!",
						font = Font.H4,
					},
					iup.label {
						title = bstr(15, "This should not cause issues, but can be fixed from the recovery menu."),
						font = Font.H6,
					},
					iup.label {
						title = bstr(16, "The registry expected to find") .. " " .. tostring(data.expected) .. " " .. bstr(17, "entries, but instead got") .. " " .. tostring(data.total),
						font = Font.H6,
					},
				},
				iup.fill { },
			},
		}
	end
)


--------------------------------------------------------------------------
--Public API
--------------------------------------------------------------------------

neo.notif = notif_creator
neo.make_visual = make_interface
neo.get_history = get_history
neo.handle_new_notif_type = new_generator
neo.register_listener = new_listener
neo.unregister_listener = unreg_listener
neo.clear_all = clear_all
neo.get_thumb_image = function() return {
	image = re_path .. "assets/thumb.png",
	size = get_scale(),
} end
neo.get_scale = get_scale
neo.notif_handler = true

update_class()

lib.require({{name="babel", version="0"}}, lexicon_support)
