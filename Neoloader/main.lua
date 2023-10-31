local cp = function(...)
	console_print(...)
	print(...)
end

local first_time = gkini.ReadString("Neoloader", "first_time", "YES")
--[[
	YES: First time ever running Neoloader Main.lua
	Removed: Neoloader was removed
	Mute: Don't pester the user about installing
]]--

if type(lib) == "table" and lib[0] == "LME" then
	local run_command = gkini.ReadString("Neoloader", "run_command", "")
	gkini.WriteString("Neoloader", "run_command", "")
	if run_command ~= "" then
		lib.log_error("Executing startup run command: " .. run_command)
		gkinterface.GKProcessCommand(run_command)
	end
	
	return
end

----------------------------------------------------------------------------
--		below this only runs if an LME doesn't exist
----------------------------------------------------------------------------

local lang_code = gkini.ReadString("Vendetta", "locale", "en")
local tprint = function(inikey, default)
	return tprint(inikey, default, "plugins/Neoloader/lang/main.ini")
end

local action_button = iup.stationbutton {
	title = "Install Neoloader",
	select_val = 1,
	action = function(self)
		if self.select_val == 1 then
			dofile("plugins/Neoloader/setup.lua")
		elseif self.select_val == 2 then
			print(tprint("delay", "Neoloader setup has been delayed; you can use /neo to open this dialog again"))
		elseif self.select_val == 3 then
			gkini.WriteString("Neoloader", "first_time", "MUTE")
			print(tprint("muted", "Dialog will no longer auto-appear"))
		end
		
		HideDialog(iup.GetDialog(self))
	end,
}

local request_setup = function(delay_once)
	local diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0 100 *",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationsubframe {
					iup.vbox {
						alignment = "ACENTER",
						iup.fill {
							size = Font.Default,
						},
						iup.label {
							title = tprint("request", "Would you like to install Neoloader?"),
						},
						iup.fill {
							size = Font.Default,
						},
						iup.hbox {
							iup.fill {
								size = Font.Default,
							},
							iup.stationsublist {
								dropdown = "YES",
								action = function(self, t, i, cv)
									if cv == 1 then
										action_button.title = t
										action_button.select_val = i
									end
								end,
								tprint("list_install", "Install Neoloader"),
								tprint("list_delay", "Not right now"),
								tprint("list_mute", "Mute this dialog"),
							},
							iup.fill {
								size = "%5",
							},
							action_button,
							iup.fill {
								size = Font.Default,
							},
						},
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	diag:map()
	if delay_once then
		--making sure it shows up over both game start and /reload events
		--this is so stupid...
		local delay_timer = Timer()
		RegisterEvent(function() 
			delay_timer:SetTimeout(10, function()
				ShowDialog(diag)
			end)
		end, "PLUGINS_LOADED")
	else
		ShowDialog(diag)
	end
end

if first_time == "YES" then
	request_setup(true)
elseif first_time == "Removed" then
	print(tprint("reins_notice", "Neoloader was recently removed; use /neo to reinstall"))
elseif first_time == "MUTE" then
	print(tprint("mute_remind", "Use /neo to start the installation process!"))
elseif first_time == "SKIP" then
	cp("Neoloader was supposed to be launched by an external tool.")
elseif first_time == "recovery" then
	print(tprint("recovery_msg", "Neoloader was removed by the recovery tool! Use /neo to reinitialize Neoloader")
end

RegisterUserCommand("neo", request_setup)