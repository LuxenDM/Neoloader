--uninstall Neoloader when LME operating properly

if type(lib) ~= "table" or lib[0] ~= "LME" then
	lib.log_error("STOP UNINSTALLER_FAILURE LME IS NOT RUNNING", 4)
	gkini.WriteString("Neoloader", "STOP", "UNINSTALLER_FAILURE")
	ReloadInterface()
end


--get_translate_string()
local locale = gkini.ReadString("Vendetta", "locale", "en")
local gts = function(key, val)
	return gkini.ReadString2(locale, key, val, "plugins/Neoloader/lang/unins.ini")
end

local uninstall_process = function(auth_key)
	
	lib.log_error("Uninstaller has been authorized!", 3)
	
	local lme_setting_list = {
		--lme settings to set as ""
		--most will be set as their default config
		"ignoreOverrideState",
		"allowDelayedLoad",
		"allowBadAPIVersion",
		"defaultLoadState",
		"doErrPopup",
		"echoLogging",
		"protectResolveFile",
		"listPresorted",
		"clearCommands",
		"dbgFormatting",
		"dbgIgnoreLevel",
		"current_if",
		"current_mgr",
		"current_notif",
	}
	
	for k, v in ipairs(lme_setting_list) do
		lib.lme_configure(v, "", auth_key)
	end
	
	local counter = 1
	while true do
		local ini_file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
		if ini_file ~= "" then
			local id = gkini.ReadString2("modreg", "id", "null", ini_file)
			local version = gkini.ReadString2("modreg", "version", "null", ini_file)
			
			if id ~= "null" then
				lib.log_error("disabling LME plugin " .. id .. " v" .. version)
				gkini.WriteString("Neo-pluginstate", id .. "." .. version, "NO")
			end
			
			gkini.WriteString("Neo-registry", "reg" .. tostring(counter), "")
			lib.log_error("removing entry " .. tostring(counter) .. " >> " .. ini_file)
			
			counter = counter + 1
		else
			lib.log_error("No more entries to clear")
			break
		end
	end
	
	gkini.WriteString("Vendetta", "if", "")
	gkini.WriteString("Neoloader", "STOP", "")
	gkini.WriteString("Neoloader", "Init", "")
	gkini.WriteString("Neoloader", "first_run", "removed")
	
	local diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationsubframe {
					iup.vbox {
						alignment = "ACENTER",
						iup.label {
							title = gts("msg1", "Uninstall complete!"),
						},
						iup.label {
							title = gts("msg2", "Click to close Vendetta Online"),
						},
						iup.fill {
							size = Font.Default,
						},
						iup.stationbutton {
							title = "OK",
							action = function()
								lib.log_error("Hope you try Neoloader again!", 4)
								Game.Quit()
							end,
						},
						iup.fill {
							size = Font.Default,
						},
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	lib.log_error("Uninstallation complete!\n\n\n")
	
	diag:map()
	diag:show()
end

lib.request_auth("Neoloader LME Uninstaller", uninstall_process)