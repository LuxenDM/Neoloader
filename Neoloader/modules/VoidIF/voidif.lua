--[[
[modreg]
type=interface
API=3
id=voidif
version=1.0.0
name=Vendetta Online No Interface
author=Luxen
path=voidif.lua

[metadata]
description=This stub makes it possible to run Vendetta Online without an interface. Not recommended. Only visible if the user selects "load modding tools" during setup
owner=Neoloader|7.0.0
type=lua
created=2025-08-28
]]--

local class = {
	['IF'] = true,
}

lib.set_class("vosi", "0", class)