local function cp(...)
	console_print(...)
	print(...)
end

local function newloader()
	--Set Neoloader to run as an IF replacement
	UnregisterUserCommand("neosetup")
	cp("Neoloader appears to be setting up for the first time")
	cp("VO will restart with Neoloader momentarily...")
	local prev_if = gkini.ReadString("Vendetta", "if", "")
	if prev_if ~= "" and prev_if ~= "vo/if.lua" then
		cp("A custom interface was already being used! This has been backed up to ['Vendetta', 'if2']")
		gkini.WriteString("Vendetta", "if2", prev_if)
	end
	gkini.WriteString("Vendetta", "if", "plugins/Neoloader/init.lua")
	gkini.WriteInt("Neoloader", "Init", 0)
	RegisterEvent(ReloadInterface, "START")--if someone starts the game, reloads are ignored until this event is fired, so we reg one here.
	RegisterEvent(ReloadInterface, "PLUGINS_LOADED")--if someone /reloads, this is handled
	ReloadInterface() --in case its run by /neosetup
end

if type(lib) ~= "table" or type(lib[1]) ~= "string" then
	local prev_if = gkini.ReadString("Vendetta", "if", "")
	if gkini.ReadString("Neoloader", "uninstalled", "NO") == "NO" and gkini.ReadInt("Vendetta", "Init", 0) == 0 then
		newloader()
	elseif prev_if ~= "vo/if.lua" and prev_if ~= "" then
		cp("You are running a custom interface! Neoloader installation must be manually triggered with /neosetup")
		cp("Run the setup, and then make your own configurations afterwards. Your IF will be saved as if2 in the config.")
		RegisterUserCommand("neosetup", newloader)
	else
		cp("Neoloader appears to have been uninstalled recently, but is still in your game's plugins. If you have installed a new version of Neoloader or wish to run it again, use /neosetup")
		RegisterUserCommand("neosetup", newloader)
	end
end