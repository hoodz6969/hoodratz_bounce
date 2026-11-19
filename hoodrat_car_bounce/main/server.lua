-- Tables to track cooldowns and ownership
local playerCooldowns = {}      -- [playerServerId] = lastToggleTime
local vehicleCooldowns = {}     -- [netId] = lastToggleTime
local vehicleOwners = {}        -- [netId] = playerServerId

-- Check if vehicle model is allowed
local function IsVehicleAllowed(vehicleEntity)
    if not DoesEntityExist(vehicleEntity) then return false end

    local allowed = Config.AllowedVehicles
    if allowed[1] == 'all' then
        return true
    end

    local model = GetEntityModel(vehicleEntity)
    for _, name in pairs(allowed) do
        if GetHashKey(name) == model then
            return true
        end
    end

    return false
end

-- Check if player has permission (license whitelist)
local function HasPermission(playerId)
    if not Config.Restricted then
        return true
    end

    local numIds = GetNumPlayerIdentifiers(playerId)
    for i = 0, numIds - 1 do
        local identifier = GetPlayerIdentifier(playerId, i)
        if identifier and identifier:sub(1, 7) == 'license' then
            for _, allowed in pairs(Config.AllowedLicenses) do
                if allowed == identifier then
                    return true
                end
            end
        end
    end

    return false
end

-- Check if player is the driver of the vehicle
local function IsPlayerDrivingVehicle(playerId, netId)
    if type(netId) ~= 'number' or netId <= 0 then
        return false
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return false
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    local ped = GetPlayerPed(playerId)

    return driver == ped
end

-- Sync bounce state to all clients (or only relevant ones)
local function SyncBounceState(netId, enabled)
    if Config.GlobalSync then
        TriggerClientEvent('hoodzbounce:update', -1, netId, enabled)
    else
        -- Only send to players near the vehicle (optional optimization)
        TriggerClientEvent('hoodzbounce:update', -1, netId, enabled)
    end
end

-- Main toggle request from client
RegisterNetEvent('hoodzbounce:request', function(netId)
    local src = source
    local currentTime = GetGameTimer()

    -- Cooldown check: player-based
    if playerCooldowns[src] and (currentTime - playerCooldowns[src]) < Config.Cooldown then
        TriggerClientEvent('hoodzbounce:error', src, Config.NotifyCooldown)
        return
    end

    -- Cooldown check: vehicle-based
    if vehicleCooldowns[netId] and (currentTime - vehicleCooldowns[netId]) < Config.Cooldown then
        TriggerClientEvent('hoodzbounce:error', src, Config.NotifyCooldown)
        return
    end

    -- License restriction
    if not HasPermission(src) then
        TriggerClientEvent('hoodzbounce:error', src, Config.NotifyLicenseDenied)
        return
    end

    -- Must be driver
    if not IsPlayerDrivingVehicle(src, netId) then
        TriggerClientEvent('hoodzbounce:error', src, Config.NotifyVehicleRequired) -- or custom message
        return
    end

    -- Vehicle model allowed?
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not IsVehicleAllowed(vehicle) then
        TriggerClientEvent('hoodzbounce:error', src, Config.NotifyVehicleNotAllowed)
        return
    end

    -- Update cooldowns and ownership
    playerCooldowns[src] = currentTime
    vehicleCooldowns[netId] = currentTime
    vehicleOwners[netId] = src

    -- Toggle state
    local stateKey = 'hoodzbounce:' .. netId
    local newState = not GlobalState[stateKey]
    GlobalState[stateKey] = newState

    -- Notify client (optional success message can be added on client side)
    SyncBounceState(netId, newState)
end)

-- Cleanup when vehicle is explicitly removed
RegisterNetEvent('hoodzbounce:cleanup', function(netId)
    local stateKey = 'hoodzbounce:' .. netId
    if GlobalState[stateKey] then
        GlobalState[stateKey] = nil
        SyncBounceState(netId, false)
    end
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    playerCooldowns[src] = nil

    for netId, ownerId in pairs(vehicleOwners) do
        if ownerId == src then
            local stateKey = 'hoodzbounce:' .. netId
            if GlobalState[stateKey] then
                GlobalState[stateKey] = nil
                SyncBounceState(netId, false)
            end
            vehicleOwners[netId] = nil
            vehicleCooldowns[netId] = nil
        end
    end
end)

-- Sync active bounces to newly joining players
AddEventHandler('playerJoining', function()
    local src = source

    for key, enabled in pairs(GlobalState) do
        if type(key) == 'string' and key:sub(1, 11) == 'hoodzbounce:' and enabled then
            local netId = tonumber(key:sub(12))
            if netId then
                TriggerClientEvent('hoodzbounce:update', src, netId, true)
            end
        end
    end
end)

-- Clean up when vehicle entity is removed
AddEventHandler('entityRemoved', function(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId > 0 then
        vehicleOwners[netId] = nil
        vehicleCooldowns[netId] = nil

        local stateKey = 'hoodzbounce:' .. netId
        if GlobalState[stateKey] then
            GlobalState[stateKey] = nil
            SyncBounceState(netId, false)
        end
    end
end)