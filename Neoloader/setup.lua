--[[
This file contains all the first-time data that Neoloader sets up during Init. If NEO_UNINSTALL is true, it will remove all this data.
]]--

local getstr = gkini.ReadString --less typing
local getint = gkini.ReadInt
local setstr = gkini.WriteString
local setint = gkini.WriteInt

if NEO_UNINSTALL == false then
	print("Neoloader is performing first-time setup; the game will reset momentarily...")
	
	--Base config data
	setint("Neoloader", "Init", 3)
	setstr("Neoloader", "if", "")
	setstr("Neoloader", "mgr", "neomgr")
	setstr("Neoloader", "uninstalled", "NO")
	
	--before we add packaged plugins, lets remove any possible old plugin registrations from older installations that weren't cleanly removed
	
	local counter = 1
	while true do
		if gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "") ~= "" then
			counter = counter + 1
		else
			--No entry here
			break
		end
	end
	for i=counter, 1, -1 do
		gkini.WriteString("Neo-registry", "reg" .. tostring(i), "")
	end
	
	--packaged plugin for basic functionality
	lib.register("plugins/Neoloader/neomgr.ini")
	setstr("Neo-pluginstate", "neomgr.1", "YES")
	
	--user options
	setstr("Neoloader", "rAllowDelayedLoad", "NO")
	setstr("Neoloader", "rAllowBadAPIVersion", "YES")
	setstr("Neoloader", "rEchoLogging", "YES")
	setint("Neoloader", "rInitLoopTimeout", 0)
	setstr("Neoloader", "rDefaultLoadState", "NO")
	setstr("Neoloader", "rDoErrPopup", "YES")
	
	gkini.WriteString("Neoloader", "installing", "finishing")
	
	
	
	--construct reconfig UI
	local function reconfig()
		local setting_new_loadstate = iup.list {
			[1] = "YES",
			[2] = "NO",
			value = 2,
			dropdown = "YES",
		}
		
		local diag = iup.dialog {
			topmost = "YES",
			fullscreen = "YES",
			bgcolor = "0 0 0",
			iup.vbox {
				iup.fill { },
				iup.hbox {
					iup.fill { },
					iup.frame {
						iup.vbox {
							iup.label {
								title = "Neoloader has finished setting up and is now enabled on Vendetta Online.",
							},
							iup.label {
								title = "Adjust any settings you want, then click OK to reload and begin playing!",
							},
							iup.label {
								title = "",
							},
							iup.hbox {
								iup.label {
									title = "Load new LME-compatible plugins by default: ",
								},
								setting_new_loadstate,
							},
							iup.hbox {
								iup.label {
									title = "",
								},
								--obj
							},
							iup.hbox {
								iup.label {
									title = "",
								},
								--obj
							},
							iup.button {
								title = "OK",
								action = function()
									if setting_new_loadstate.value == "1" then
										gkini.WriteString("Neoloader", "rDefaultLoadState", "YES")
										local pluginlist = lib.get_gstate().pluginlist
										for k, v in ipairs(pluginlist) do
											console_print("v1 " .. v[1] .. "   v2 " .. v[2])
											gkini.WriteString("Neo-pluginstate", v[1] .. "." .. v[2], "YES")
										end
									end
									--obj
									--obj
									gkinterface.GKSaveCfg()
									ReloadInterface()
								end,
							},
						},
					},
					iup.fill { },
				},
				iup.fill { },
			},
		}
		diag:map()
		diag:show()
	end
	
	RegisterEvent(function() reconfig() end, "START")
	RegisterEvent(function() reconfig() end, "PLUGINS_LOADED")
	
else
	print("Neoloader is performing an uninstallation.")
	--base settings to mark Neoloader as uninstalled, preventing main.lua from automating installation
	setstr("Neoloader", "uninstalled", "YES")
	setstr("Vendetta", "if", "")
	setint("Neoloader", "Init", -1)
	
	--try to remove all registered plugins
	local counter = 1
	while true do
		if gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "") ~= "" then
			counter = counter + 1
		else
			--No entry here
			break
		end
	end
	for i=counter, 1, -1 do
		gkini.WriteString("Neo-registry", "reg" .. tostring(i), "")
	end
	
	--try to disable loading of all existing plugins
	local pluginlist = lib.get_gstate().pluginlist
	for k, v in ipairs(pluginlist) do
		if v.plugin_id then
			setstr("Neo-pluginstate", k, "NO")
		end
	end
	
	--use a dialog to force the game to close, to make sure Neoloader is purged from execution
	local diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.frame {
					iup.vbox {
						margin = 1,
						iup.fill {
							size = "%2",
						},
						iup.label {
							title = "Neoloader has been uninstalled! Please close Vendetta Online. You can safely remove Neoloader from your plugins folder at this time; if you do not, you can use /neosetup to reinstall Neoloader.",
							font = Font.H4,
						},
						iup.fill {
							size = "%2",
						},
						iup.button {
							title = "Close Vendetta Online",
							action = function()
								Game.Quit()
							end,
						},
						iup.fill {
							size = "%2",
						},
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	diag:map()
	diag:show()
end

