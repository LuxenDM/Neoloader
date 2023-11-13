print = console_print
local cp = console_print

Font = {
	Default = (gkinterface.GetYResolution()/1080) * 24,
}

local dumptable
local tab_amount = 0
function dumptable(_t)
	for k, v in pairs(_t) do
		local tabspace = ""
		for i=1, tab_amount do
			tabspace = tabspace .. "	"
		end
		if type(v) == "table" then
			console_print(tabspace .. tostring(k) .. " >> {")
			tab_amount = tab_amount + 1
			dumptable(v)
			console_print(tabspace .. "}")
			tab_amount = tab_amount - 1
		else
			console_print(tabspace .. tostring(k) .. " >> " .. tostring(v))
		end
	end
end

local button_scalar = function()
	local val = ""
	if gkinterface.IsTouchModeEnabled() then
		val = tostring(Font.Default * 2)
	end
	return val
end

local ctl_create = function()
	local function create_subdlg(ctrl)
		
		local dlg = iup.dialog{
			border="NO",
			menubox="NO",
			resize="NO",
			expand = "YES",
			shrink = "YES",
			bgcolor="0 0 0 0 *",
			ctrl,
		}
		
		return dlg
	end
	
	local lockstate = false
	local contents = {}
	local actual_items = {}
	
	local ctl = iup.list {
		{},
		bgcolor = "0 0 0",
		control = "YES",
		expand = "YES",
		border = "NO",
		scrollbarwidth = button_scalar(),
	}
	
	ctl.unlock = function(self)
		ctl[1] = nil
		lockstate = false
	end
	
	ctl.lock = function(self)
		ctl[1] = 1
		lockstate = true
	end
	
	ctl.add_item = function(self, obj)
		table.insert(contents, obj)
	end
	
	ctl.clear_items = function(self)
		contents = {}
	end
	
	ctl.update = function(self, sorttype)
		if lockstate then
			self:unlock()
		end
		
		for k, v in ipairs(actual_items) do
			v:detach()
			if iup.IsValid(iup.GetNextChild(v)) then
				iup.GetNextChild(v):detach()
			end
			--v:destroy()
		end
		actual_items = {}
		
		--prepare items
		local x_size = string.match(ctl.size, "%d+") or "480"
		for k, v in ipairs(contents) do
			local obj = create_subdlg(v)
			actual_items[k] = obj
			obj:map()
			
			local sizes = {}
			for value in string.gmatch(obj.size, "%d+") do
				value = tonumber(value)
				table.insert(sizes, value)
			end
			obj.size = tostring(tonumber(x_size) - Font.Default) .. "x" .. tostring(sizes[2])
		end
		
		for k, v in ipairs(actual_items) do
			iup.Append(self, v)
		end
		
		self:lock()
		
		iup.Refresh(self)
	end
	
	iup.Append(ctl, create_subdlg(iup.hbox {}))
	
	return ctl
end

--[[
	recovery is a lightweight system meant to recover from catastrophic NON-CTD errors during LME or plugin load time. By displaying a dialog that will close when the game finishes loading, it can provide an interactive environment that can hopefully help the user get the game working again.
]]--

local disable_LME_plugins = function(remove_entry)
	while true do
		local ini_file = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
		if ini_file ~= "" then
			local id = gkini.ReadString2("modreg", "id", "null", ini_file)
			local version = gkini.ReadString2("modreg", "version", "null", ini_file)
			if id ~= "null" then
				cp("disabling LME plugin " .. id .. " v" .. version)
				gkini.WriteString("Neo-pluginstate", id .. "." .. version, "NO")
			end
			
			if remove_entry then
				gkini.WriteString("Neo-registry", "reg" .. tostring(counter), "")
				cp("removing entry " .. tostring(counter) .. " >> " .. ini_file)
			end	
			
			counter = counter + 1
		else
			break
		end
	end
end

local uninstall_neoloader = function()
	disable_LME_plugins(true)
	
	gkini.WriteString("Vendetta", "if", "")
	gkini.WriteString("Neoloader", "first_time", "recovery")
	
	local setting_list = {
		--list of Neoloader config options to clear
		"Init",
		"if",
		"mgr",
		"uninstalled", --depreciated, pre 3.9.x
		"rAllowDelayedLoad",
		"rAllowBadAPIVersion",
		"rEchoLogging",
		"rInitLoopTimeout",
		"rDefaultLoadState",
		"rDoErrPopup",
		"rPresortedList",
		"rPortectResolveFile",
		"iDbgIgnoreLevel",
		"rClearCOmmands",
		"rDbgFormatting",
		"rOverrideDisabledState",
		"current_notif",
		"run_command",
		"STOP",
	}
	for i, v in ipairs(setting_list) do
		gkini.WriteString("Neoloader", v, "")
	end
end

local reset_config_options = function()
	local setting_list = {
		--list of game settings to clear
		"if",
		"skin",
		"usenewui",
		"usefontscaling",
		"fontscale",
		"AudioDriver",
		"VideoDriver",
		"xres",
		"yres",
		"font",
		"enablevoicechat",
		"enabledeviceselection",
		"playbackmode",
		"playbackdevice",
		"capturemode",
		"capturedevice",
	}
	
	for k, v in ipairs(setting_list) do
		gkini.WriteString("Vendetta", v, "")
	end
end























local create_recovery_diag = function()
	local ctl = ctl_create()
	
	local recovery_options = {
		{ --1
			action = "Reload",
			descrip = "Reload: Sometimes a bug could be coincidental and fixed just by reloading the game. This is also the option to select if you modify your game files to fix the bug yourself.",
			lua = function()
				ReloadInterface()
			end,
		},
		{
			action = "Close Vendetta Online",
			descrip = "Close: Sometimes, functions can get snagged and won't be removed with a Reload. To fix these, you need to fully quit the game. This most often occurs when trying to update plugins while the game is running.",
			lua = function()
				Game.Quit()
			end,
		},
		{
			action = "Disable all LME plugins",
			descrip = "Disable: If one of your plugins loaded by your LME provider is triggering this issue, then disabling that plugin will prevent the buggy code from running.",
			lua = function()
				disable_LME_plugins(false)
				ReloadInterface()
			end,
		},
		{
			action = "Disable ALL plugins",
			descrip = "Disable All: Turns off the game's ability to load plugins and closes the game; when you launch the game again, it will be the vanilla experience. In order to re-enable plugins, you'll need to re-enable them from your options menu. Your LME will also be disconnected, preventing it from running, but its settings and plugin's load states won't be touched.",
			lua = function()
				gkini.WriteString("Vendetta", "plugins", "0")
				gkini.WriteString("Vendetta", "if", "")
				gkini.WriteString("Neoloader", "first_time", "recovery")
				Game.Quit()
			end,
		},
		{
			action = "Uninstall Neoloader (Clean)",
			descrip = "If your LME environment is misbehaving, this option will remove the settings and prevent Neoloader from executing until installed again. You should also use this option if you want to upgrade Neoloader and the standard uninstaller doesn't work.",
			lua = function()
				uninstall_neoloader()
				Game.Quit()
			end,
		},
		{
			action = "Nuclear",
			descrip = "Removes as much LME data as possible from your config.ini, disables all plugins, and even reverts some game options to known safe settings. If this doesn't fix your game, then you need help that an automated system cannot provide.",
			lua = function()
				uninstall_neoloader()
				reset_config_options()
				gkini.WriteString("Vendetta", "plugins", "0")
				Game.Quit()
			end,
		},
		{
			action = "Advanced Users: Show Game Console",
			descrip = "The game has its own console where you can view printed messages and execute some commands or lua script. Probably only useful if you know what you're doing.",
			lua = function()
				gkinterface.GKProcessCommand("ConsoleToggle")
			end,
		},
		{
			action = "Attempt to launch the game interface anyways",
			descrip = "Not recommended, but you can try to run the game's interface. If this doesn't make the error worse, you might be able to play the game, but chances are low.",
			lua = function()
				iup.GetDialog(iup.GetParent(iup.GetDialog(iup.GetFocus()))):hide()
				dofile("vo/if.lua")
				if not IsConnected() then
					ProcessEvent("START")
				else
					if PlayerInStation() then
						ProcessEvent("SHOW_STATION")
					else
						ProcessEvent("HUD_SHOW")
					end
				end
			end,
		},
	}
	
	if gkini.ReadString("Neo-pluginstate", "neomgr.2.0.0", "YES") == "NO" then
		cp("neomgr not enabled")
		table.insert(recovery_options, 3, {
			action = "Re-enable neomgr",
			descrip = "neomgr is a lightweight interface for managing Neoloader, but it appears to be disabled currently! Click here to enable it",
			lua = function()
				gkini.WriteString("Neo-pluginstate", "neomgr.2.0.0", "YES")
				ReloadInterface()
			end,
		})
	else
		cp("neomgr active")
	end
	
	for k, v in ipairs(recovery_options) do
		local option_button = iup.frame {
			iup.hbox {
				iup.label {
					title = "",
					image = "plugins/Neoloader/img/notif_placeholder.png",
				},
				iup.vbox {
					iup.button {
						title = v.action,
						expand = "HORIZONTAL",
						size = "x" .. button_scalar(),
						action = v.lua
					},
					iup.multiline {
						value = v.descrip,
						readonly = "YES",
						expand = "HORIZONTAL",
						size = "x" .. tostring(Font.Default * 4),
					},
				},
			},
		}
		
		ctl:add_item(option_button)
	end
	
	local diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		focus_cb = function()
			iup.SetFocus(ctl)
		end,
		iup.hbox {
			iup.fill {
				size = "%6",
			},
			iup.vbox {
				alignment = "ACENTER",
				iup.fill {
					size = Font.Default,
				},
				iup.label {
					title = "Neoloader Recovery System",
				},
				iup.fill {
					size = Font.Default,
				},
				iup.multiline {
					size = "x%10",
					expand = "HORIZONTAL",
					readonly = "YES",
					value = "If you see this, then a catastrophic failure occured while your LME or one of your plugins were loading! The options below might help fix your game; it is recommended to try each option top-to-bottom, unless you know what you're doing.",
					border = "NO",
				},
				iup.fill {
					size = Font.Default,
				},
				ctl,
				iup.fill {
					size = Font.Default,
				},
			},
			iup.fill {
				size = "%6",
			},
		},
	}
	
	diag:map()
	ctl:update()
	diag:show()
	
	RegisterEvent(
		function()
			diag:hide()
			RegisterUserCommand("recovery", function()
				gkini.WriteString("Neoloader", "STOP", "recovery")
				ReloadInterface()
			end)
		end,
		"PLUGINS_LOADED"
	)
	
	iup.SetFocus(ctl)
end

create_recovery_diag()