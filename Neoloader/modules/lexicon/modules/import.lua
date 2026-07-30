--[[
[metadata]
description=Handles import of lexicon's officially provided language selection
owner=lexicon|1.0.0
type=lua
created=2026-04-12

important note! Call this file AFTER all other files have been managed!
]]--

local file_args = {...}
local public = file_args[1]
local private = file_args[2]
local config = file_args[3]

--loop ./lang/lang.ini entries to build language information. apply metadata for official support
-- [lang]
--	<id>=lang_code
--
--	./lang/lang_code/lang_code.ini -> import and public.register('lexicon', private.version, ini_file)

local lspath = private.path .. "lang/lang.ini" --lexicon supported language definition file
local rini = gkini.ReadString2


private.cp("Lexicon will now begin importing its officially supported languages")

local counter = 0
local once_flag = false
local fast_id = -1
while true do
	counter = counter + 1
	local locale_path = rini("lang", tostring(counter), "", lspath) --officially supported languages folder and lang codes are the same
	
	if locale_path == "" then
		counter = counter - 1
		break
	end
	
	local id, errmsg = public.register("lexicon", private.version, (private.path .. "lang/" .. locale_path .. "/" .. locale_path .. ".ini"))
	
	if not id then
		private.cp("Lexicon failed to register a language that should be officially supported! " .. locale_path .. " gave error message " .. errmsg, 3)
	else
		private.mutate_support_entry(locale_path, {
			status = 2,
			metadata = {
				official = true,
			},
		})
	end
	
	if (not once_flag) and id then
		once_flag = true
		fast_id = id
		private.lstr = function(id, msg)
			return public.fetch(fast_id, id, msg)
		end
	end
end



private.cp("Lexicon loaded " .. tostring(counter) .. " officially supported languages!")
private.skip_class_update = false