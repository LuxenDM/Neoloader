--[[
[metadata]
description=Soft-gates a function behind a dependency check and runs it when safe.
version=1.0.6
owner=Neoloader|7.0.0
type=lua
created=2025-11-8
]]--

local neo   = ...
local lib   = neo.lib
local waitq = neo.runtime.waitq
local rt    = neo.runtime

lib.require = function(intable, callback, id, ver)
    -- your existing type checks...

    table.insert(waitq, {
        deps = intable,
        cb   = callback,
        id   = id,
        ver  = ver,
    })

    -- If pathlock is off and we're NOT already processing the queue,
    -- go ahead and try to drain it.
    if not neo.api.get_pathlock_value() and not rt.in_check_queue then
        lib.check_queue()
    else
        -- If we're already in check_queue, just mark that the queue
        -- changed so the topmost call can do another pass.
        rt.queue_retry = true
    end
end
