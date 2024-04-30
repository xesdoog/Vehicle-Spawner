---@diagnostic disable: undefined-global, lowercase-global

local vehicle_spawner  = gui.get_tab("Vehicle Spawner")
local vehicles         = require ("vehicleList")
local is_typing        = false
local online	       = false
local searchQuery      = ""
local player_name      = ""
local ped              = 0
local selected_vehicle = 0
local spawned_vehicle  = 0
local playerIndex      = 0
script.register_looped("disableInput", function()
	if is_typing then
		PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
	end
end)
vehicle_spawner:add_imgui(function()
	ImGui.PushItemWidth(250)
	searchQuery, used = ImGui.InputTextWithHint("##searchVehicles", "Search", searchQuery, 32)
	ImGui.PopItemWidth()
	if ImGui.IsItemActive() then
	is_typing = true
	else
		is_typing = false
	end
    ImGui.PushItemWidth(270)
end)
local function updateFilteredVehicles()
	filtered_vehicles = {}
	for _, item in ipairs(vehicles) do
		if string.find(string.lower(item.name), string.lower(searchQuery)) then
			table.insert(filtered_vehicles, item)
		end
	end
end
local function displayFilteredList()
	updateFilteredVehicles()
	local vehicle_names = {}
	for _, item in ipairs(filtered_vehicles) do
		table.insert(vehicle_names, item.name)
	end
	selected_vehicle, used = ImGui.ListBox("", selected_vehicle, vehicle_names, #filtered_vehicles)
end
local function updatePlayerList()
	local players 	= entities.get_all_peds_as_handles()
	filteredPlayers = {}
	for _, p in ipairs(players) do
		if PED.IS_PED_A_PLAYER(p) then
			if NETWORK.NETWORK_IS_PLAYER_ACTIVE(p) then
				table.insert(filteredPlayers, p)
			end
		end
	end
end
local function displayPlayerList()
	updatePlayerList()
	local playerNames = {}
	for _, player in ipairs(filteredPlayers) do
		playerName = PLAYER.GET_PLAYER_NAME(NETWORK.NETWORK_GET_PLAYER_INDEX_FROM_PED(player))
		table.insert(playerNames, playerName)
	end
	playerIndex, used = ImGui.Combo("##playerList", playerIndex, playerNames, #filteredPlayers)
end
vehicle_spawner:add_imgui(displayFilteredList)
vehicle_spawner:add_separator()
vehicle_spawner:add_imgui(function()
	if NETWORK.NETWORK_IS_SESSION_ACTIVE() then
		online = true
	else
		online = false
	end
	if not online then
		ped = self.get_ped()
		local playerModel = ENTITY.GET_ENTITY_MODEL(ped)
		if playerModel == 2602752943 then
			player_name = "Franklin"
		elseif playerModel == 225514697 then
			player_name = "Michael"
		elseif playerModel == 2608926626 then
			player_name = "Trevor"
		else
			player_name = "Custom Character"
		end
	else
		ImGui.Text("Select a Player To Spawn For:")
		ImGui.PushItemWidth(250)
		displayPlayerList()
		ImGui.PopItemWidth()
		local selectedPlayer = filteredPlayers[playerIndex + 1]
		ped = selectedPlayer
		local myPed = self.get_ped()
		if ped == myPed then
			player_name = "Your Online Character"
		else
			player_name = PLAYER.GET_PLAYER_NAME(NETWORK.NETWORK_GET_PLAYER_INDEX_FROM_PED(ped))
		end
	end
	spawnInside, used = ImGui.Checkbox("Spawn Inside", spawnInside, true)
	if ImGui.Button("    Spawn   ") then
		script.run_in_fiber(function (script)
			local plyrCoords   = ENTITY.GET_ENTITY_COORDS(ped, false)
			local plyrForwardX = ENTITY.GET_ENTITY_FORWARD_X(ped)
			local plyrForwardY = ENTITY.GET_ENTITY_FORWARD_Y(ped)
			local vehicle  		 = filtered_vehicles[selected_vehicle + 1]
			local counter  		 = 0
			while not STREAMING.HAS_MODEL_LOADED(vehicle.hash) do
				STREAMING.REQUEST_MODEL(vehicle.hash)
				script:yield()
				if counter > 100 then
					return
				else
					counter = counter + 1
				end
			end
			spawned_vehicle = VEHICLE.CREATE_VEHICLE(vehicle.hash, plyrCoords.x + (plyrForwardX * 5), plyrCoords.y + (plyrForwardY * 5), plyrCoords.z, ENTITY.GET_ENTITY_HEADING(ped), true, false, false)
			VEHICLE.SET_VEHICLE_IS_STOLEN(spawned_vehicle, false)
			DECORATOR.DECOR_SET_INT(spawned_vehicle, "MPBitset", 0)
			if spawnInside then
				local controlled = entities.take_control_of(ped, 350)
				if not controlled then
					gui.show_message("Spawn Inside", "Failed to set the player inside the vehicle!\nMaybe they have protections enabled?")
				else
					PED.SET_PED_INTO_VEHICLE(ped, spawned_vehicle, -1)
				end
			end
			ENTITY.SET_ENTITY_AS_NO_LONGER_NEEDED(spawned_vehicle)
			gui.show_message("Vehicle Spawner", "Spawned ' "..vehicle.name.." ' for "..player_name)
		end)
	end
	ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine()
	if ImGui.Button("   Delete  ") then
		script.run_in_fiber(function(del)
			if PED.IS_PED_SITTING_IN_ANY_VEHICLE(ped) then
				local pv = PED.GET_VEHICLE_PED_IS_USING(ped)
				local pvCTRL = entities.take_control_of(pv, 350)
				if pvCTRL then
					ENTITY.SET_ENTITY_AS_MISSION_ENTITY(pv, true, true)
					del:sleep(200)
					VEHICLE.DELETE_VEHICLE(pv)
					gui.show_message("Vehicle Spawner",""..player_name.."'s vehicle has been yeeted.")
				else
					gui.show_error("Vehicle Spawner", "Failed to delete the vehicle! "..player_name.." probably has protections on.")
				end
			else
				gui.show_warning("Vehicle Spawner", ""..player_name.." must be inside a vehicle in order to delete it.")
			end
		end)
	end
end)
