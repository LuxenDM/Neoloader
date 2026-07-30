local once_flag = false

local shim_init = function()
	if once_flag then
		return
	end
	once_flag = true
	
	console_print("Lexicon shim is testing for an LME provider...")
	if isdeclared("lib") and type(lib) == "table" and lib[0] == "LME" then
		local my_path = lib.get_path() or "plugins/Lexicon/"
		
		if not lib.is_exist(my_path .. "lexicon.lua") then
			lib.register(my_path .. "lexicon.lua")
		end
	end
end

RegisterEvent(shim_init, "PLUGINS_LOADED") --LME in cooperative mode
RegisterEvent(shim_init, "LIBRARY_MANAGEMENT_ENGINE_COMPLETE") --LME in independent mode
