local function cp(...)
	console_print(...)
	print(...)
end

local function newloader()
	--Set Neoloader to run as an IF replacement
	UnregisterUserCommand("neosetup")
	cp("Neoloader appears to be setting up for the first time")
	cp("VO will restart with Neoloader momentarily...")
	gkini.WriteString("Vendetta", "if", "plugins/Neoloader/init.lua")
	gkini.WriteInt("Neoloader", "Init", 0)
	RegisterEvent(ReloadInterface, "START")--if someone starts the game, reloads are ignored until this event is fired, so we reg one here.
	RegisterEvent(ReloadInterface, "PLUGINS_LOADED")--if someone /reloads, this is handled
	ReloadInterface() --in case its run by /neosetup
end

if type(lib) ~= "table" or type(lib[1]) ~= "string" then
	if gkini.ReadString("Neoloader", "uninstalled", "NO") == "NO" and gkini.ReadInt("Vendetta", "Init", 0) == 0 then
		newloader()
	else
		cp("Neoloader appears to have been uninstalled recently, but is still in your game's plugins. If you have installed a new version of Neoloader or wish to run it again, use /neosetup")
		RegisterUserCommand("neosetup", newloader)
	end
else
	if lib[1] == "Neoloader" then
		if lib.is_ready(lib.get_gstate().manager) then
			--the manager should handle notifications, if neccesary; do not bug the user about Neo being installed <here> at all!
		else
			cp("No manager is set up to handle plugins with Neoloader!")
			cp("'neomgr' is a barebones manager bundled with Neoloader.")
			cp("use /neomgr to turn that plugin on and enable using it as Neoloader's manager!")
			
			RegisterUserCommand("neomgr", function()
				UnregisterUserCommand("neomgr")
				gkini.WriteString("Neo-pluginstate", "neomgr.1", "YES")
				ReloadInterface()
			end)
		end
	end
end