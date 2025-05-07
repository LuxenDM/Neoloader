if isdeclared("lib") and type(lib) == "table" and lib[0] == "LME" then
	lib.log_error("Neoloader setup should not run while Neoloader is running", 4)
	
	return
end


--get_translate_string()
local locale = gkini.ReadString("Vendetta", "locale", "en")
local gts = function(key, val)
	return gkini.ReadString2(locale, key, val, "plugins/Neoloader/lang/setup.ini")
end

local button_scalar = function()
	local val = ""
	if gkinterface.IsTouchModeEnabled() then
		val = tostring(Font.Default * 2)
	end
	return val
end

local gkrs	= gkini.ReadString --less typing
local gkri	= gkini.ReadInt
local gkws	= gkini.WriteString
local gkwi	= gkini.WriteInt
local cp	= console_print

gkwi("Neoloader", "Init", 3)
gkws("Neoloader", "mgr", "neomgr")
gkws("Neoloader", "current_notif", "neonotif")
gkws("Neoloader", "uninstalled", "NO")

local counter = 1
while true do
	if gkrs("Neo-registry", "reg" .. tostring(counter), "") ~= "" then
		counter = counter + 1
	else
		--No entry here
		break
	end
end
for i=counter, 1, -1 do
	gkws("Neo-registry", "reg" .. tostring(i), "")
end

local plugin_counter = 0
local register_plugin = function(id, version, ini, state)
	plugin_counter = plugin_counter + 1
	gkws("Neo-registry", "reg" .. tostring(plugin_counter), ini)
	gkws("Neo-pluginstate", id .. "." .. version, state)
	cp("[LME Setup] Added bundled plugin: " .. id .. " v" .. version)
	cp("	plugin located in registry at position " .. tostring(plugin_counter))
end

register_plugin("neomgr", "2.1.0", "plugins/Neoloader/neomgr.lua", "YES")
register_plugin("neonotif", "1.1.0", "plugins/Neoloader/neo_notif.lua", "YES")



local function create_subdlg(ctrl)
	local dlg = iup.dialog{
		border="NO",
		menubox="NO",
		resize="NO",
		expand = "YES",
		shrink = "YES",
		bgcolor="0 0 0 0 *",
		ctrl,
	}
	
	return dlg
end

local ctl_create = function()
	
	local lockstate = false
	local contents = {}
	local actual_items = {}
	
	local ctl = iup.stationsublist {
		{},
		control = "YES",
		expand = "YES",
	}
	
	ctl.unlock = function(self)
		ctl[1] = nil
		lockstate = false
	end
	
	ctl.lock = function(self)
		ctl[1] = 1
		lockstate = true
	end
	
	ctl.add_item = function(self, obj)
		table.insert(contents, obj)
	end
	
	ctl.clear_items = function(self)
		contents = {}
	end
	
	ctl.update = function(self, sorttype)
		if lockstate then
			self:unlock()
		end
		
		for k, v in ipairs(actual_items) do
			v:detach()
			if iup.IsValid(iup.GetNextChild(v)) then
				iup.GetNextChild(v):detach()
			end
			--v:destroy()
		end
		actual_items = {}
		
		--prepare items
		local x_size = string.match(ctl.size, "%d+") or "480"
		for k, v in ipairs(contents) do
			local obj = create_subdlg(v)
			actual_items[k] = obj
			obj:map()
			
			local sizes = {}
			for value in string.gmatch(obj.size, "%d+") do
				value = tonumber(value)
				table.insert(sizes, value)
			end
			obj.size = tostring(tonumber(x_size) - Font.Default) .. "x" .. tostring(sizes[2])
		end
		
		for k, v in ipairs(actual_items) do
			iup.Append(self, v)
		end
		
		self:lock()
		
		iup.Refresh(self)
	end
	
	iup.Append(ctl, create_subdlg(iup.hbox {}))
	
	return ctl
end



local config = {
	defaultLoadState = "NO",
	run_command = "neo",
	
	if_option = "replace",
	--[[
		replace: if will be Neoloader
		adapt: if will be Neoloader, old if will be imported
			--not yet implemented
		keep: if will be kept; Neoloader will not run
	]]--
}

local setup_creator = function()
	local ctl_basic = ctl_create()
	ctl_basic.expand = "NO"
	ctl_basic.size = "%60x%30"
	
	--rDefaultLoadState
	ctl_basic:add_item(iup.stationsubframe {
		iup.vbox {
			iup.hbox {
				alignment = "AMIDDLE",
				iup.label {
					title = gts("def_load", "Load plugins by default") .. ": ",
				},
				iup.fill { },
				iup.stationsublist {
					dropdown = "YES",
					size = "200x" .. button_scalar(),
					action = function(self, t, i, cv)
						if cv == 1 then
							config.defaultLoadState = t
						end
					end,
					"YES",
					"NO",
					value = 2,
				},
			},
			iup.label {
				title = "YES: " .. gts("plug_enable", "New plugins will automatically be enabled"),
			},
			iup.label {
				title = "NO: " .. gts("plug_disable", "New plugins must be manually enabled"),
			},
			iup.label {
				title = gts("def_msg", "Default is") .. " NO",
			},
		},
	})
	
	--first-run
	ctl_basic:add_item( iup.stationsubframe {
		iup.vbox {
			iup.hbox {
				alignment = "AMIDDLE",
				iup.label {
					title = gts("open_msg", "Open manager after install") .. ": ",
				},
				iup.fill { },
				iup.stationsublist {
					dropdown = "YES",
					size = "200x" .. button_scalar(),
					action = function(self, t, i, cv)
						if cv == 1 then
							t = t == "YES" and "neo" or ""
							config.run_command = t
						end
					end,
					"YES",
					"NO",
					value = 1,
				},
			},
			iup.label {
				title = gts("open_opt", "Completely Optional, enable to manage your LME after setup"),
			},
		},
	})
	
	--IF replacement style, not added by default
	local adv_if_option = iup.stationsubframe {
		iup.vbox {
			iup.hbox {
				alignment = "AMIDDLE",
				iup.label {
					title = gts("if_method_msg", "Interface replacement method") .. ": ",
				},
				iup.fill { },
				iup.stationsublist {
					dropdown = "YES",
					size = "200x" .. button_scalar(),
					action = function(self, t, i, cv)
						if cv == 1 then
							config.if_option = t
						end
					end,
					"replace",
					"adapt",
					"keep",
					value = 1,
				},
			},
			iup.label {
				title = gts("def_msg", "Default is") .. " 'replace'",
			},
			iup.label {
				title = gts("if_warning", "DO NOT CHANGE unless you know what you're doing") .. "!",
			},
		},
	}
	
	local setup_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationsubframe {
					iup.vbox {
						alignment = "ACENTER",
						iup.label {
							title = gts("title", "Neoloader Setup"),
						},
						iup.stationsubframe {
							iup.vbox {
								alignment = "ARIGHT",
								iup.stationbutton {
									title = gts("show_adv", "Show advanced options"),
									action = function(self)
										self.visible = "NO"
										self.active = "NO"
										ctl_basic:add_item(adv_if_option)
										ctl_basic:update()
									end,
								},
								ctl_basic,
							},
						},
						iup.fill {
							size = Font.Default,
						},
						iup.stationbutton {
							title = gts("finalize", "Apply settings and reload Vendetta Online"),
							action = function(self)
								cp("Selected default load state " .. config.defaultLoadState)
								gkws("Neoloader", "rDefaultLoadState", config.defaultLoadState)
								
								cp("Selected run command " .. config.run_command)
								gkws("Neoloader", "run_command", config.run_command)
								
								if config.if_option == "replace" then
									cp("IF option was REPLACE; value will be Neoloader")
									gkws("Vendetta", "if", "plugins/Neoloader/init.lua")
								elseif config.if_option == "adapt" then
									cp("IF option was ADAPT; value is " .. "NOT IMPLEMENTED")
									error("ADAPTION NOT IMPLEMENTED YET")
								elseif config.if_option == "keep" then
									cp("IF option was KEPT; value is " .. gkrs("Vendetta", "if", "vo-if"))
								end
								
								gkws("Neoloader", "first_run", "")
								
								gkwi("Neoloader", "Init", 3)
								
								ReloadInterface()
							end,
						},
						iup.fill { },
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	setup_diag:map()
	ctl_basic:update()
	
	ShowDialog(setup_diag)
end

setup_creator()
