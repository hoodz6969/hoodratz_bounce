fx_version 'cerulean'
game 'gta5'
author 'https://discord.gg/thecoll'
version '1.0.0'

lua54 'yes'  

dependencies {
    'ox_lib' 
}

shared_scripts {
    '@ox_lib/init.lua',  
    'config.lua'
}

client_scripts {
    'main/client.lua'
}

server_scripts {
    'main/server.lua'
}

escrow_ignore {
    'config.lua'
}

dependency '/assetpacks'