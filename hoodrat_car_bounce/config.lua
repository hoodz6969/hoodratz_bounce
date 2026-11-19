Config = {}

-- Chat command
Config.CommandEnabled = true        -- Enable / disable the chat command
Config.CommandName    = 'bounce'    -- Command players type in chat

-- Keybind
Config.KeybindEnabled = true        -- Register a default keybind
Config.DefaultKey     = 'K'         -- Default key (players can remap)
Config.KeybindLabel   = 'Hoodratz Bounce' -- Label shown in key‑mapping menu

-- Access control
Config.Restricted      = false      -- true = only licences below may use
Config.AllowedLicenses = {          -- Rockstar license identifiers
    'license:00000000000000000000'
}

-- Vehicle filter
Config.AllowedVehicles = { 'all' }  -- {'all'} or spawn names like { 'sultan', 'buffalo', 'gel36' }

-- Bounce behaviour
Config.Amplitude     = -0.075       
Config.CycleDuration = 1100         
Config.UpdateRate    = 15           
Config.GlobalSync    = true         

-- Cooldown (ms)
Config.Cooldown       = 5000                                   
Config.NotifyCooldown = 'Suspension cooling down … wait a moment'


Config.NotifyOnText            = 'Your ride is now bouncing'
Config.NotifyOffText           = 'Bounce mode disabled'
Config.NotifyVehicleRequired   = 'You must be inside a vehicle to use Bounce'
Config.NotifyVehicleNotAllowed = 'This vehicle is not compatible with Bounce'
Config.NotifyLicenseDenied     = 'You are not whitelisted to use Bounce'


Config.Functions = {}
Config.Functions.notify = function(ntype, title, text, time)
    local notifyType = ntype or 'inform'  
    if notifyType == 'info' then notifyType = 'inform' end
    if notifyType == 'error' then notifyType = 'error' end
    if notifyType == 'success' then notifyType = 'success' end
    

    lib.notify({
        title       = title or 'Hoodratz Bounce',
        description = text or '',
        duration    = time or 5000,
        type        = notifyType,
        position    = 'top'  
    })
end
