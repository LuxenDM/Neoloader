--[[
[metadata]
description=Find and execute a file (pcall-protected); returns status, result_or_err
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-10
]]--

local neo = ...
local lib = neo.lib

lib.resolve_file = function(file, ...)
  if lib.err_handle(type(file) ~= "string",
      "lib.resolve_file expected a string as argument 1, got " .. type(file)) then
    return false, "file not a string"
  end

  local path, pathtable = lib.find_file(file, ...)
  if not path then
    lib.log_error("unable to resolve file provided (" .. tostring(file) .. "); file not found", 2)
    return false, "unable to find file"
  end

  lib.log_error("Attempting to resolve " .. tostring(pathtable[1][1]), 1)

  local chunk = nil
  for _, group in ipairs(pathtable) do
    for i = 1, 3 do
      local candidate = group[i]
      local loaded, err = loadfile(candidate)
      if loaded then
        chunk = loaded
        break
      else
        if not string.find(tostring(err or ""), "No such file or directory", 1, true) then
          lib.log_error("Unable to resolve file: " .. tostring(err or "error?"), 2)
          return false, err
        end
      end
    end
    if chunk then break end
  end

  if not chunk then
    lib.log_error("unable to resolve file: file does not appear to exist or cannot be accessed using known methods", 1)
    return false, "error resolving file"
  end

  -- v7 behavior: always pcall the chunk
  local ok, res = pcall(chunk)
  if not ok then
    lib.log_error("unable to resolve file: pcall caught an error during execution!", 3)
    lib.log_error("  " .. tostring(res), 3)
    lib.log_error(debug.traceback("  trace up to lib.resolve_file(): "), 1)
  end
  return ok, res
end
