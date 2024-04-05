---@diagnostic disable: undefined-global, lowercase-global

local vehicle_spawner = gui.get_tab("Vehicle Spawner")
vehicles = require ("vehicleList")
local selected_vehicle = 1
local searchQuery = ""
local is_typing = false
script.register_looped("Vehicle Spawner", function()
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
local filtered_vehicles = {}
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
local function RequestControl(entity, ticks)
    local tick = 0
    ticks = ticks or 50
    local netID = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(entity)
    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netID, true)
    while not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(entity) and tick < ticks do
        NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(entity)
        tick = tick + 1
    end
    return NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(entity), tick
end
vehicle_spawner:add_imgui(displayFilteredList)
local ped = PLAYER.GET_PLAYER_PED(network.get_selected_player())
local player_name = PLAYER.GET_PLAYER_NAME(network.get_selected_player())
local coords = ENTITY.GET_ENTITY_COORDS(ped, false)
local forwardX = ENTITY.GET_ENTITY_FORWARD_X(ped)
local forwardY = ENTITY.GET_ENTITY_FORWARD_Y(ped)
vehicle_spawner:add_separator()
vehicle_spawner:add_imgui(function()
    spawnInside, used = ImGui.Checkbox("Spawn Inside", spawnInside, true)
    if ImGui.Button("    Spawn   ") then
        script.run_in_fiber(function (script)
            local vehicle = filtered_vehicles[selected_vehicle+1]
            local counter = 0
            while not STREAMING.HAS_MODEL_LOADED(vehicle.hash) do
                STREAMING.REQUEST_MODEL(vehicle.hash)
                script:yield()
                if counter > 100 then
                    return
                else
                    counter = counter + 1
                end
            end
            spawned_vehicle = VEHICLE.CREATE_VEHICLE(vehicle.hash, coords.x + (forwardX * 2), coords.y + (forwardY * 2), coords.z, ENTITY.GET_ENTITY_HEADING(ped), true, false, false)
            DECORATOR.DECOR_SET_INT(spawned_vehicle, "MPBitset", 0)
            local netID = NETWORK.VEH_TO_NET(spawned_vehicle)
            if NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(spawned_vehicle) then
                NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(netID, true)
            end
            VEHICLE.SET_VEHICLE_IS_STOLEN(spawned_vehicle, false)
            if spawnInside then
                e, ticks = RequestControl(ped, 250)
                if not e then
                    return gui.show_message("Spawn Inside", "Failed to set the player inside the vehicle!\nMaybe they have protections enabled?")
                end
                PED.SET_PED_INTO_VEHICLE(ped, spawned_vehicle, -1)
            end
            gui.show_message("Vehicle Spawner", "Spawned ''"..vehicle.name.."'' for [ "..player_name.." ]")
        end)
    end
    ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine()
    if ImGui.Button("   Delete  ") then
        script.run_in_fiber(function()
            if PED.IS_PED_IN_ANY_VEHICLE(ped) then
                local current_vehicle = PED.GET_VEHICLE_PED_IS_USING(ped)
                e, ticks = RequestControl(current_vehicle, 250)
                if not e then
                    return gui.show_message("Delete Vehicle", "Failed to gain control of the vehicle after '"..ticks.."' ticks")
                end
                ENTITY.SET_ENTITY_AS_MISSION_ENTITY(current_vehicle, true, true)
                VEHICLE.DELETE_VEHICLE(current_vehicle)
            else
                gui.show_error("Delete Vehicle", "[ "..player_name.." ] is not using a vehicle.")
            end
        end)
    end
end)