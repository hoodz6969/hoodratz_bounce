-- main/client.lua

-- Active bouncing vehicles (netId -> true)
local activeBounces = {}

-- Safe wrappers for network natives
local function GetVehicleNetId(vehicle)
    if not NetworkGetEntityOwner(vehicle) then return nil end
    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function GetVehicleFromNetId(netId)
    return NetworkGetEntityFromNetworkId(netId)
end

-- Check if vehicle is allowed (same logic as server)
local function IsVehicleAllowed(vehicle)
    if not DoesEntityExist(vehicle) or vehicle == 0 then
        return false
    end

    local allowed = Config.AllowedVehicles
    if allowed and allowed[1] == 'all' then
        return true
    end

    local model = GetEntityModel(vehicle)
    for _, name in pairs(allowed or {}) do
        if GetHashKey(name) == model then
            return true
        end
    end

    return false
end

-- Notification system (ox_lib + fallback)
local function Notify(message)
    if message then
        if Config.Functions and Config.Functions.notify then
            Config.Functions.notify('info', 'Hoodratz Bounce', message, 5000)
        elseif lib and lib.notify then
            lib.notify({
                title = 'Hoodratz Bounce',
                description = message,
                type = 'inform',
                duration = 5000,
                position = 'top'
            })
        else
            -- Native fallback
            BeginTextCommandThefeedPost('STRING')
            AddTextComponentSubstringPlayerName(message)
            EndTextCommandThefeedPostTicker(true, false)
        end
    end
end

-- Toggle notification
local function NotifyToggle(enabled)
    if enabled then
        Notify(Config.NotifyOnText or 'Your ride is now bouncing')
    else
        Notify(Config.NotifyOffText or 'Bounce mode disabled')
    end
end

-- Smooth reset when stopping bounce
local function ResetSuspension(vehicle, currentHeight)
    local steps = math.floor(400 / (Config.UpdateRate or 15))
    for i = 1, steps do
        local progress = 1 - (i / steps)
        SetVehicleSuspensionHeight(vehicle, currentHeight * progress)
        Wait(Config.UpdateRate or 15)
    end
    SetVehicleSuspensionHeight(vehicle, 0.0)
end

-- Main bouncing loop
local function BounceLoop(netId)
    local cycle = Config.CycleDuration or 1100
    local amplitude = Config.Amplitude or -0.075
    local updateRate = Config.UpdateRate or 15

    local phaseOffset = (netId * 97) % cycle
    local startTime = GetGameTimer()
    local checkTimer = 0

    while activeBounces[netId] do
        local vehicle = GetVehicleFromNetId(netId)
        if vehicle == 0 or not DoesEntityExist(vehicle) then
            break
        end

        local now = GetGameTimer()
        local elapsed = (now - startTime + phaseOffset) % cycle
        local t = elapsed / cycle

        -- Fade in during first 400ms
        local fadeIn = math.min(1.0, (now - startTime) / 400)

        local height = amplitude * fadeIn * math.sin(t * math.pi * 2)
        SetVehicleSuspensionHeight(vehicle, height)

        Wait(updateRate)
        checkTimer = checkTimer + updateRate

        -- Every second: verify server still wants bounce active
        if checkTimer >= 1000 then
            if not GlobalState['hoodzbounce:' .. netId] then
                activeBounces[netId] = nil
            end
            checkTimer = 0
        end
    end

    -- Smooth stop
    local vehicle = GetVehicleFromNetId(netId)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local now = GetGameTimer()
        local elapsed = (now + phaseOffset) % cycle
        local t = elapsed / cycle
        local finalHeight = amplitude * math.sin(t * math.pi * 2)
        ResetSuspension(vehicle, finalHeight)
    end

    -- Tell server to clean up if this was our vehicle
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)
    if currentVeh ~= 0 then
        local currentNetId = GetVehicleNetId(currentVeh)
        if currentNetId == netId then
            TriggerServerEvent('hoodzbounce:cleanup', netId)
        end
    end
end

-- Server tells us to start/stop bouncing
RegisterNetEvent('hoodzbounce:update', function(netId, enabled)
    local wasActive = activeBounces[netId] == true

    if enabled and not wasActive then
        activeBounces[netId] = true
        CreateThread(function()
            BounceLoop(netId)
        end)
    elseif not enabled and wasActive then
        activeBounces[netId] = nil
    end

    -- Only notify if it's our current vehicle
    local ped = PlayerPedId()
    local currentVeh = GetVehiclePedIsIn(ped, false)
    if currentVeh ~= 0 then
        local currentNetId = GetVehicleNetId(currentVeh)
        if currentNetId == netId then
            NotifyToggle(enabled)
        end
    end
end)

-- Error messages from server
RegisterNetEvent('hoodzbounce:error', function(message)
    Notify(message)
end)

-- Command / keybind handler
local function ToggleBounce()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        Notify(Config.NotifyVehicleRequired or 'You must be inside a vehicle to use Hoodratz Bounce')
        return
    end

    if not IsVehicleAllowed(vehicle) then
        Notify(Config.NotifyVehicleNotAllowed or 'This vehicle is not compatible with Hoodratz Bounce')
        return
    end

    local netId = GetVehicleNetId(vehicle)
    if not netId then
        Notify('Failed to get vehicle network ID. Try again.')
        return
    end

    TriggerServerEvent('hoodzbounce:request', netId)
end

-- Register command
if Config.CommandEnabled then
    RegisterCommand(Config.CommandName, ToggleBounce, false)
end

-- Register keybind
if Config.KeybindEnabled then
    RegisterCommand('hoodzbounce_key', ToggleBounce, false)
    RegisterKeyMapping('hoodzbounce_key', Config.KeybindLabel or 'Hoodratz Bounce', 'keyboard', Config.DefaultKey or 'K')
end

-- Sync any existing bounces when player joins or resource restarts
CreateThread(function()
    Wait(2000) -- Give time for GlobalState to load

    while true do
        Wait(3000)

        for key, enabled in pairs(GlobalState) do
            if type(key) == 'string' and key:sub(1, 11) == 'hoodzbounce:' and enabled then
                local netId = tonumber(key:sub(12))
                if netId and not activeBounces[netId] then
                    activeBounces[netId] = true
                    CreateThread(function()
                        BounceLoop(netId)
                    end)
                end
            end
        end
    end
end)