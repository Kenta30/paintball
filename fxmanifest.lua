fx_version 'cerulean'
game 'gta5'
author 'Vinny'
lua54 'yes'

client_scripts {
    '_configs/*.lua',
    'core/client/*.lua'
}

server_scripts {
    '_configs/*.lua',
    'core/server/*.lua'
}

shared_scripts {
    --'@ox_lib/init.lua',
    '@es_extended/imports.lua'
}

--ui_page 'ui/index.html'

--[[files {
    'ui/index.html',
    'ui/asset-manifest.json',
    'ui/static/css/main.css',
    'ui/static/js/main.js',
}]]
