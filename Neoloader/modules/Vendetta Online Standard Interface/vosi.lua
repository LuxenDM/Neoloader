--[[
[modreg]
type=interface
API=3
id=vosi-bridge
version=1.0.0
name=Vendetta Online Standard Interface Bridge
author=Guild Software
path=vosi.lua

[metadata]
description=This stub tells the Vendetta Online Standard Interface to load. Neoloader will launch that anyways if no interface is available, but this should help make interface selection and management more user-evident. It also provides methods to access the LME in the default interface directly.
owner=Neoloader|7.0.0
type=lua
created=2025-10-08
]]--

local mod_path = lib.get_path() or lib.get_path("vosi-bridge", "1.0.0")
local self_id, self_ver = lib.pass_ini_identifier(mod_path .. "vosi.lua", "")
if self_id == mod_path then
	error("Catastrophic failure")
end

local cp = function(msg)
	lib.log_error("[VOSI] " .. msg, 1, self_id, self_ver)
end

local cur_if = lib.get_gstate().current_if
local cur_mode = lib.lme_get_config("launch_mode")

local actual_cur_mode = (lib.get_gstate().pathlock and "cooperative" or "independent")

cp("self-check: " .. self_id .. " v" .. self_ver .. " running from " .. mod_path .. " under LME in mode " .. cur_mode .. "; current interface should be " .. cur_if)

if (cur_mode == "independent") and (cur_if == "vosi-bridge") then
	cp("Running in independent mode; executing game interface")
	dofile("vo/if.lua")
end

if (cur_mode ~= actual_cur_mode) and (cur_mode == "cooperative") and (cur_if == "vosi-bridge") then
	cp("Mode mismatch, currently running as independent while reporting as cooperative. Executing game interface 'just in case'.")
	dofile("vo/if.lua")
end







local class = {
	CCD1 = true,
	commands = {},
	manifest = {},
}
class.IF = true

local bstr = function(id, val)
	return val
end

local update_class, lex, ref_id
local babel_func = function()
	local lex_ver = lib.get_latest("lexicon", "1.0.0", "1.4.9")
	lex = lib.get_class("lexicon", lex_ver)
	ref_id = lex.register("vosi-bridge", self_ver, mod_path .. "lang/en.ini")
	
	local supported_lang = {"da", "de", "eo", "es", "fr", "id", "it", "nl", "pl", "pt", "tr"}
	
	for _, lc in ipairs(supported_lang) do
		lex.register("vosi-bridge", self_ver, local_path .. "lang/" .. lc .. ".ini")
	end
	
	private.bstr = function(id, val)
		return lex.fetch(ref_id, id, val)
	end
	
	public.add_translation = function(path)
		lex.register("vosi-bridge", self_ver, path)
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
	
	lib.set_class(self_id, self_ver, class)
end

update_class()

--create buttons on menu


local vosi_timer = Timer()

local recheck_flag = false
local button_creator = function()
	vosi_timer:IsActive() --have to re-reference timer or it might not fire
	
	if recheck_flag then
		return
	end
	
	recheck_flag = true
	
	if ((cur_if ~= self_id) and (cur_mode == "independent")) and (not (cur_if == "vo-if")) then
		cp("Vendetta Online's Standard Interface does not appear to be the current interface; integrations will not be made.")
		return
	end
	
	local angular_check = gkini.ReadString("Vendetta", "usenewui", "1")
	
	local open_config_or_recovery = function()
		local cur_mgr = lib.get_gstate().current_mgr
		if lib.is_ready(cur_mgr) then
			lib.open_config()
		else
			gkinterface.GKProcessCommand("recovery")
		end
	end
	
	if angular_check == "1" and Platform == "Windows" then
		local odbutton = OptionsDialog[1][1][15]
		
		local x_pos = tonumber(odbutton.cx)
		local y_pos = tonumber(odbutton.cy)
		local sizes = {}
		for value in string.gmatch(odbutton.size, "%d+") do
			table.insert(sizes, tonumber(value))
		end
		y_pos = y_pos - (sizes[2] * 1.5)
		
		--SetLocale2("ja")
		local neobutton = iup.button {
			title = bstr(4, "Open Mod Manager"),
			--title = "Open Mod Manager" .. string.char(195, 169) .. ", é 編集",
			font = odbutton.font,
			size = odbutton.size,
			cx = x_pos,
			cy = y_pos,
			image = odbutton.image,
			action = open_config_or_recovery,
		}
		--SetLocale2("en")
		
		
		iup.Append(OptionsDialog[1][1], neobutton)
	else
		local neobutton = iup.stationbutton {
			title = bstr(4, "Open Mod Manager"),
			expand = "HORIZONTAL",
			action = open_config_or_recovery,
		}
		
		local opframe_ref = OptionsDialog[1][1][1]
		local fill_ref
		
		local get_num_children = function(ihandle)
			if not iup.IsValid(ihandle) then
				return -1
			end
			
			local counter = 1
			local child_ref = iup.GetNextChild(ihandle)
			while true do
				local next_child_ref = iup.GetNextChild(ihandle, child_ref)
				if (not next_child_ref) or (not iup.IsValid(next_child_ref)) then
					break
				end
				counter = counter + 1
				child_ref = next_child_ref
			end
			return counter
		end
		
		for i=1, get_num_children(opframe_ref) do
			if iup.GetType(opframe_ref[i]) == "fill" then
				fill_ref = opframe_ref[i]
				break
			end
		end
		
		iup.Append(opframe_ref, neobutton)
		fill_ref.size = "0"
		if (tonumber(opframe_ref.gap) or 8) > 10 then
			opframe_ref.gap = "8"
		else
			opframe_ref.gap = "0"
		end
		iup.Refresh(opframe_ref)
	end
	
	cp("LME integrations for the standard interface have been added")
end

vosi_timer:SetTimeout(100, button_creator)




RegisterEvent(button_creator, "PLUGINS_LOADED")