--[[
[metadata]
description=defines the LME API function lib.get_caller_path(). This function peeks at debug.traceback to figure out the call directory.
added=3.12.0
updated=3.12.0
]]--

lib.get_caller_path = function()
    -- Get the full traceback
    local trace = debug.traceback()

    -- Split into lines
    local lines = {}
    for line in trace:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    -- Track whether we've seen Helium yet
    local skipped_helium = false

    for _, line in ipairs(lines) do
        -- Extract path
        local path = line:match("([^\":]+):%d+")
        if path then
            -- Trim whitespace
            path = path:match("^%s*(.-)%s*$")

            -- Consider only plugins
            if path:find("^plugins/") then
                -- Is this the Helium utility itself?
                if not skipped_helium and path:find("^plugins/Neoloader/") then
                    skipped_helium = true
                    -- Skip this frame
                else
                    -- This is the first non-Helium plugin in the call stack
                    local folder = path:match("^(.-)/[^/]-$")
                    return folder, path, line
                end
            end
        end
    end

    -- Nothing matched
    return nil, nil, nil
end