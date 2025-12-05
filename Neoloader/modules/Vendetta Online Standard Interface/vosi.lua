--[[
[modreg]
type=interface
API=3
id=Vendetta Online Standard Interface
version=1.0.0
name=Vendetta Online Standard Interface
author=Guild Software
path=vosi.lua

[metadata]
description=This stub tells the Vendetta Online Standard Interface to load. Neoloader will launch that anyways if no interface is available, but this should help make interface selection and management more user-evident.
version=1.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-10-08
]]--

dofile("vo/if.lua")

local mod_path = lib.get_path()
local cp = function(msg)
	lib.log_error("[VOSII] " .. msg, 1, "Vendetta Online Standard Interface", "1.0.0")
end



local class = {
	CCD1 = true,
	commands = {},
	manifest = {},
	
	['IF'] = true,
}

local bstr = function(id, val)
	return val
end

local update_class, babel, ref_id
local babel_func = function()
	babel = lib.get_class("babel", "0")
	ref_id = babel.register(mod_path, "lang/", {'en', 'es', 'fr', 'pt'})
	private.bstr = function(id, val)
		return babel.fetch(ref_id, id, val)
	end
	
	public.add_translation = function(path, lang_code)
		babel.add_new_lang(ref_id, path, lang_code)
	end
	
	update_class()
end
	
update_class = function()
	class.description = bstr(2, "Vendetta Online Standard Interface integration with Neoloader")
	class.smart_config = {
		title = bstr(1, "Vendetta Online Standard Interface"),
		cb = function() end,
		"no_config",
		no_config = {
			type = "text",
			display = bstr(3, "When enabled, Neoloader will add special integrations into the Vendetta Online Standard Interface."),
			align = "center",
		},
	}
	
	lib.set_class("Vendetta Online Standard Interface", "0", class)
end

update_class()


--create buttons on menu
local button_creator = function()
	local cur_if = lib.get_gstate().current_if
	
	if (cur_if ~= "Vendetta Online Standard Interface") and (cur_if ~= "vo-if") then
		cp("Vendetta Online's Standard Interface does not appear to be active; integrations will not be made.")
		return
	end
	
	local angular_check = gkini.ReadString("Vendetta", "usenewui", "1")
	
	if angular_check == "1" and Platform == "Windows" then
		local odbutton = OptionsDialog[1][1][15]
		
		local x_pos = tonumber(odbutton.cx)
		local y_pos = tonumber(odbutton.cy)
		local sizes = {}
		for value in string.gmatch(odbutton.size, "%d+") do
			table.insert(sizes, tonumber(value))
		end
		y_pos = y_pos - (sizes[2] * 1.5)
		
		local neobutton = iup.button {
			title = bstr(4, "Open Mod Manager"),
			size = odbutton.size,
			cx = x_pos,
			cy = y_pos,
			image = odbutton.image,
			action = lib.open_config,
		}
		
		iup.Append(OptionsDialog[1][1], neobutton)
	else
		local neobutton = iup.stationbutton {
			title = bstr(4, "Open Mod Manager"),
			expand = "HORIZONTAL",
			action = neo.open,
		}
		
		iup.Append(OptionsDialog[1][1][1], neobutton)
	end
end


