--[[
[metadata]
description=This file from Neoloader keeps a checkpoint history of certain performance metrics
version=1.0.1
owner=Neoloader|7.0.0
type=lua
created=2025-10-26
]]--

local neo = ...
local stats = neo.stats

local alignment_offset = neo.api.get_alignment_offset()

--[[ fron neoloader init:
stats = {
	timestat_start
	memstat_start
]]--

local gktime = gkmisc.GetGameTime
local gkstep = function(st)
	return (gktime() + alignment_offset) - st
end

local mem_get = function()
	return math.ceil(collectgarbage("count"))
end
local mem_step = function(mv)
	return mem_get() - mv
end

stats.checkpoint_history = {
	{
		checkpoint = "Neoloader start",
		time = stats.timestat_start,
		time_elapsed = 0,
		mem = stats.memstat_start,
		mem_change = 0,
	},
}

stats.timestat_start = nil
stats.memstat_start = nil
--why did I do this?

local get_last = function()
	return stats.checkpoint_history[#stats.checkpoint_history]
end

local first = get_last()

stats.checkpoint = function(label)
	local lcp = get_last() --last checkpoint
	
	local netstats = {gknet.GetStats()}
	--[[
		bitrate out over 1 minute
		bitrate in over 1 minute
		bytes out
		bytes in
		rtt
	]]--
	local rtt = (netstats[5] and (netstats[5] / 10)) or (IsConnected() and 1000) or -1
	
	local ncp = { --next checkpoint
		checkpoint = label,
		time = gktime() + alignment_offset,
		time_elapsed = gkstep(lcp.time),
		mem = mem_get(),
		mem_change = mem_step(lcp.mem),
		--id track FPS but you can only see FPS when the FPS menu is open afaik
		ping = rtt,
	}
	
	neo.lib.log_error("LME checkpoint: " .. label .. "\n\t" .. tostring(ncp.time_elapsed) .. "ms since last checkpoint\n\t" .. tostring(ncp.mem_change) .. " kb memory used", 1)
	
	table.insert(stats.checkpoint_history, ncp)
	
	--todo: make history length configurable, -1 for infinite
	if #stats.checkpoint_history > 100 then
		table.remove(stats.checkpoint_history, 1)
	end
end

stats.get_history_range = function()
	return #stats.checkpoint_history
end

stats.get_history = function(index_start, index_end)
	if (not stats.checkpoint_history[index_start]) then
		index_start = 1
	end
	if (not stats.checkpoint_history[index_end]) then
		index_end = stats.get_history_range()
	end
	
	local history = {}
	for i=index_start, index_end, 1 do
		table.insert(history, stats.checkpoint_history[i])
	end
	
	return history
end

local stat_timer_interval = gkini.ReadInt("Neoloader", "stat_timer_interval_override", 60)
local stat_timer = Timer()
local stat_timer_update = function()
	if neo.api.config.get_config("stat_graphing") == "YES" then
		stats.checkpoint("graph_update")
	end
	stat_timer:SetTimeout(1000 * stat_timer_interval)
end

stat_timer:SetTimeout(1000 * stat_timer_interval, stat_timer_update)