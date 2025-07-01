--[[
This file contains the base "environment" of functions and variables that is normally set up by the default interface.
These functions and variables are often required for certain functions or plugins to run, so we need to create them ourselves in the meantime.
Most of these were ripped from Draugath's BarebonesIF interface replacer - thanks, Draugath!
]]--




HUDSize = HUDSize or function(x, y)
	local xres = gkinterface.GetXResolution()
	local yres = gkinterface.GetYResolution()
	return string.format("%sx%s", x and math.floor(x * xres) or "", y and "%"..math.floor(y * 100) or "")
end

GetFriendlyStatus = GetFriendlyStatus or function()
	return 1
end

HideDialog = HideDialog or function(dlg) 
	dlg:hide() 
end

ShowDialog = ShowDialog or function(dlg, x, y)
	if x then
		dlg:showxy(x, y) 
	else 
		dlg:show()
	end 
end

PopupDialog = PopupDialog or function(dlg, x, y) --depreciated!
	ShowDialog(dlg, x, y)
end

CreditAndCrystal = CreditAndCrystal or function(in1, in2, in3, in4, in5)
	print(type(in1) .. ">" .. tostring(in1))
	print(type(in2) .. ">" .. tostring(in2))
	print(type(in3) .. ">" .. tostring(in3))
	print(type(in4) .. ">" .. tostring(in4))
	print(type(in5) .. ">" .. tostring(in5))
	return 1
end

OpenAlarm = OpenAlarm or function(title, text, buttontext)
	PopupDialog(iup.dialog{
		iup.vbox{
			iup.label{title = title.."\n"..text},
			iup.hbox{
				iup.fill{},
				iup.stationbutton{title = buttontext, action = function(self)
					local d = iup.GetDialog(self)
					HideDialog(d)
					iup.Destroy(d)
				end},
				iup.fill{},
			},
		},
		topmost = "YES",
		menubox = "NO",
		
	}, iup.CENTER, iup.CENTER)
end

IF_DIR = IF_DIR or 'vo/'
IMAGE_DIR = IMAGE_DIR or gkini.ReadString("Vendetta", "skin", "images/station/")
tabseltextcolor = tabseltextcolor or "1 241 255"
tabunseltextcolor = tabunseltextcolor or "0 185 199"

defaultedittextcolor = defaultedittextcolor or "255 255 255"
listboxbordercolor = listboxbordercolor or "0 0 0"
listboxfocusedbordercolor = listboxfocusedbordercolor or "0 0 0"
buttondisabledcolor = buttondisabledcolor or "127 127 127"
textlistboxselcolor = textlistboxselcolor or "127 127 127"
textlistboxunfocusedselcolor = textlistboxunfocusedselcolor or "0 0 0"
UseCondensedUI = UseCondensedUI or "false"
defaulttextcolor = defaulttextcolor or "255 255 255"

dofile('vo/if_fontsize.lua')
dofile('vo/if_templates.lua')

FactionColor_RGB = FactionColor_RGB or { --these should be changed so every faction is properly represented by their color
	[0] = "212 212 212",--unaligned
	[1] = "96 128 255", --itani
	[2] = "255 32 32", --serco
	[3] = "192 192 0", --uit
	[4] = "255 255 255", --tpg
	[5] = "255 255 255", --biocom
	[6] = "255 255 255", --valent
	[7] = "255 255 255", --orion
	[8] = "255 255 255", --axia
	[9] = "128 128 128", --corvus
	[10] = "255 255 255", --tunguska
	[11] = "255 255 255", --aeolus
	[12] = "255 255 255", --ineubis
	[13] = "255 255 255", --xang xi
	[100] = "85 85 85", --hive generic
	[101] = "100 100 100", --hive skirm small
	[102] = "135 135 135", --hive skirm common
	[103] = "175 175 175", --hive skirm large
	[104] = "215 215 215", --hive skirm critical
	[105] = "255 255 255", --hive skirm central
	[99] = "128 32 0", --developers
}