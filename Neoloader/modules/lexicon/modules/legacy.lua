--[[
[metadata]
description=Handles legacy import of babel language sheets into the lexicon registry
owner=lexicon|1.0.0
type=lua
created=2026-04-12
]]--

local file_args = {...}
local public = file_args[1]
local private = file_args[2]
local config = file_args[3]

local split_path = function(path_input)
    local dir, file = path_input:match("^(.-)([^/]+)$")
    return dir, file
end

local get_file_name = function(file_input)
    return file_input:match("^(.*)%.([^%.]+)$")
end

private.legacy_import = function(entry_id, entry_version, ini_path) --called by public.register() if using babel language table
	
	local mstime = gkmisc.GetGameTime()
	
	local file_path, file_name = split_path(ini_path)
	
	local lang_code = get_file_name(file_name)
	local lang_name = gkini.ReadString2("babel", "0", "", ini_path)
	
	if lang_name == "" then
		return false, "invalid INI data"
	end
	
	local lang_table = {}
	private.add_page(entry_id, entry_version, lang_code, lang_table)
	
	local ls, gs = public.is_supported(lang_code)
	
	if not ls then
		private.mutate_support_entry(lang_code, {
			status = 0,
			lang = lang_name,
			flag = private.path .. "assets/flag_null.png",
			game_supported = gs,
			provider = ini_path,
			metadata = {
				legacy = true,
			},
		})
	end
	
	--legacy entries always cache, to reduce logic required in public.fetch/retrieve command
	local counter = 0
	while true do
		counter = counter + 1
		
		local output = gkini.ReadString2('babel', tostring(counter), "", ini_path)
		if output == "" then
			break
		end
		lang_table[counter] = output
	end
	private.cp("\tlegacy translation page had " .. tostring(counter) .. " lines to cache!")
	
	private.update_class()
	
	lib.log_error("\tlegacy translation page generated in " .. tostring(gkmisc.GetGameTime() - mstime) .. "ms")
	
	return private.get_fast_id(entry_id, entry_version)
end

