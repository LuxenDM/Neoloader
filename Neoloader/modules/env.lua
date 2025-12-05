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



local diag_tree = {} --tracks dialogs opened with ShowDialog function

HideDialog = HideDialog or function(dlg) 
	if diag_tree[#diag_tree] = dlg then
		diag_tree[#diag_tree] = nil
	end
	dlg:hide() 
end

HideAllDialogs = HideAllDialogs or function()
	for i=#diag_tree, 1, -1 do
		HideDialog(diag_tree[i])
	end
end

ShowDialog = ShowDialog or function(dlg, x, y)
	table.insert(diag_tree, dlg)
	if x then
		dlg:showxy(x, y) 
	else 
		dlg:show()
	end 
end

PopupDialog = PopupDialog or function(dlg, x, y) --depreciated! if you want popup behavior, use :popup() directly!
	ShowDialog(dlg, x, y)
end


---wtf is this function even for?
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

FactionColor_RGB = FactionColor_RGB or { --Matched to paint color instead of standard
	[0] = "212 212 212",--unaligned
	[1] = "3 154 200", --itani
	[2] = "250 97 84", --serco
	[3] = "254 177 25", --uit
	[4] = "118 197 61", --tpg
	[5] = "1 91 161", --biocom
	[6] = "254 141 26", --valent
	[7] = "194 195 194", --orion
	[8] = "96 50 148", --axia
	[9] = "20 21 20", --corvus
	[10] = "105 198 162", --tunguska
	[11] = "143 8 106", --aeolus
	[12] = "170 336 19", --ineubis
	[13] = "5 118 92", --xang xi
	[100] = "85 85 85", --hive generic
	[101] = "100 100 100", --hive skirm small
	[102] = "135 135 135", --hive skirm common
	[103] = "175 175 175", --hive skirm large
	[104] = "215 215 215", --hive skirm critical
	[105] = "255 255 255", --hive skirm central
	[99] = "32 154 21", --developers (?)
}