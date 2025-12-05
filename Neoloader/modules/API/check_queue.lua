--[[
[metadata]
description=Dependency wait queue: enqueue unmet deps, re-check and run when ready
version=1.0.6
owner=Neoloader|7.0.0
type=lua
created=2025-11-7
]]--

local neo   = ...
local lib   = neo.lib
local reg   = neo.api.registry
local waitq = neo.runtime.waitq
local rt    = neo.runtime

lib.check_queue = function()
    if #waitq == 0 then return end
    if neo.api.get_pathlock_value() then
        -- still pathlocked; don't activate anything yet
        return
    end

    -- If we're already processing, just set the retry flag and bail.
    if rt.in_check_queue then
        rt.queue_retry = true
        return
    end

    rt.in_check_queue = true

    repeat
        rt.queue_retry = false

        -- optional debug:
        -- dump_table(waitq)

        -- Single pass over the current queue
        for i = #waitq, 1, -1 do
            local item = waitq[i]
            if item and lib.resolve_dep_table(item.deps) then
                lib.log_error("        A dependency was resolved for a mod in the processing queue!", 1)
                table.remove(waitq, i)

                if item.id then
                    lib.block_trap(item.id, item.ver or "0", function() item.cb() end)
                else
                    pcall(item.cb)
                end
            end
        end
        -- If any nested require/check_queue happened while we were
        -- processing, rt.queue_retry will have been set to true.
        -- The loop will spin once more and re-scan the queue.
    until not rt.queue_retry or #waitq == 0

    rt.in_check_queue = false
    rt.queue_retry    = false
end
