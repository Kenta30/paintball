---------------------------
    -- ESX Component --
---------------------------
ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end

    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end

    ESX.PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)
---------------------------
    -- Variables --
---------------------------
local paintBallData = {}
PaintballData = {
    Paintball = {
        gameID = 0, -- default : 0
        kills = 0,
        deaths = 0,
        gameTimer = 0,
        inGame = false,
        startGame = false,
        currentGameModePoints = "",
        searchDestroyDict = "timetable@tracy@sleep@",
        searchDestroyAnim = "idle_c",
        flagObject = nil,
        flagObjectData = nil,
        flagTakerPed = nil,
        playerGameId = nil,
        flagTakerTeam = nil,
        flagTakerSide = nil,
        gameMode = nil,
        team = nil,
    },
    MenuData = {
        redTeamTextPos = 0.20,
        blueTeamTextPos = 0.20,
        defaultScaleX = 0.6,
        defaultScaleY = 0.5,
        newTextPos = nil,
        redCoordX = nil,
        redCoordY = nil,
        blueCoordX = nil,
        blueCoordY = nil,
        timerCoordX = nil,
        timerCoordY = nil,
        redScoreCoordX = nil,
        redScoreCoordY = nil,
        blueScoreCoordX = nil,
        blueScoreCoordY = nil,
        redKillCoordX = nil,
        blueKillCoordX = nil,
        scoreText = nil,
    }
}
---------------------------
    -- Event Handlers --
---------------------------
RegisterNetEvent('paintball:createGameData')
AddEventHandler('paintball:createGameData', function(paintBallClientData, paintBallGameID, gameMode)
    paintBallData = paintBallClientData
    PaintballData.Paintball.gameID = paintBallGameID
    PaintballData.Paintball.gameMode = gameMode
    AddRelationshipGroup("red")
    AddRelationshipGroup("blue")
    SetRelationshipBetweenGroups(5, "red", "blue")
    SetRelationshipBetweenGroups(5, "blue", "red")
    SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), false, -1737346484)
    SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), false, -1974111254)
end)

RegisterNetEvent('paintball:updateGameData')
AddEventHandler('paintball:updateGameData', function(paintBallClientData)
    if PaintballData.Paintball.gameID ~= 0 and PaintballData.Paintball.gameMode ~= nil then
        paintBallData = paintBallClientData

        for i = 1, #paintBallData do
            if paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team] ~= nil then
                for b = 1, #paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team] do
                    if paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team][b].playerId == GetPlayerServerId(PlayerId()) then
                        PaintballData.Paintball.kills = paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team][b].kills
                        PaintballData.Paintball.deaths = paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team][b].deaths
                    end
                end
            end
        end

    end
end)

RegisterNetEvent("paintball:handleFlagSpawn")
AddEventHandler("paintball:handleFlagSpawn", function(flagData)
    PaintballData.Paintball.flagObjectData = flagData
    for k,v in pairs(PaintballData.Paintball.flagObjectData.flags) do
        local flagObj = NetworkGetEntityFromNetworkId(v)
        if DoesEntityExist(flagObj) then
            PaintballData.Paintball.flagObject = flagObj
        end
    end
end)

RegisterNetEvent('paintball:startGame')
AddEventHandler('paintball:startGame', function(paintBallGameID, paintBallServerData)
    if PaintballData.Paintball.gameID ~= 0 and PaintballData.Paintball.inGame then
        PaintballData.Paintball.startGame = true
        paintBallData = paintBallServerData
        PaintballData.Paintball.currentGameModePoints = "score"
        paintBallGameTeleportToStart(paintBallGameID, PaintballData.Paintball.team, paintBallData)
        paintBallGameTimer()
        GiveWeaponToPed(PlayerPedId(), GetHashKey("WEAPON_MICROSMG"), 9999, false, true)
        
        CreateThread(function()
            while PaintballData.Paintball.startGame do
                Wait(0)
                if PaintballData.Paintball.inGame and PaintballData.Paintball.gameID ~= 0 and PaintballData.Paintball.team ~= nil then
                    for i = 1, #paintBallData do
                        if IsControlPressed(0, 137) then -- Capslock to open paintball scoreboard
                            paintBallGameModeMenu(i, paintBallGameID, PaintballData.Paintball.gameMode)
                        end
                        if GlobalState["gameTimer"] <= 0 or paintBallData[i][paintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] == 0 or paintBallData[i][paintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] == 0 then
                            TriggerEvent('chat:addMessage', {
                                template = '<div class="chat-message text-'..PaintballData.Paintball.team..'"><b>&raquo; Paintball Stats:</b> You had {0} kills and {1} deaths.</div>',
                                args = {PaintballData.Paintball.kills, PaintballData.Paintball.deaths}
                            })
                            paintBallDecideWinner(paintBallData, i, paintBallGameID)
                            PaintballData.Paintball.startGame = false
                        elseif PaintballData.Paintball.gameMode == "CTF" and GlobalState["gameTimer"] > 0 then
                            if DoesEntityExist(PaintballData.Paintball.flagObject) then
                                if not GlobalState["ctfFlagTaker"] then
                                    if exports['srp_polyzones']:PointInside("ctf_flag_spawn", GetEntityCoords(PlayerPedId())) and not GlobalState["ctfFlagTaker"] then
                                        Utils.DrawText3Ds(GetEntityCoords(PaintballData.Paintball.flagObject), "Press [E] to take flag!", 0.3, nil, true)
                                        if IsControlJustReleased(0, 38) then
                                            PaintballData.Paintball.flagObject = nil
                                            LocalPlayer.state:set("hasCTFFlag", true, true)
                                            TriggerServerEvent('paintball:setFlagTaker')
                                            PaintballData.Paintball.flagTakerPed = PlayerPedId()
                                            PaintballData.Paintball.playerGameId = GetPlayerServerId(PlayerId())
                                        end
                                    end
                                elseif GlobalState["ctfFlagTaker"] == PaintballData.Paintball.playerGameId then
                                    requestFlag(PaintballData.Paintball.flagObject)
                                    PaintballData.Paintball.flagTakerTeam = Player(PaintballData.Paintball.playerGameId).state.paintBallTeam
                                    if PaintballData.Paintball.flagTakerTeam == "red" then
                                        PaintballData.Paintball.flagTakerSide = "red_side"
                                    elseif PaintballData.Paintball.flagTakerTeam == "blue" then
                                        PaintballData.Paintball.flagTakerSide = "blue_side"
                                    end
                                    if Player(PaintballData.Paintball.playerGameId).state.hasCTFFlag and exports['srp_polyzones']:PointInside(PaintballData.Paintball.flagTakerSide, GetEntityCoords(PaintballData.Paintball.flagTakerPed)) then
                                        LocalPlayer.state:set("hasCTFFlag", false, true)
                                        TriggerServerEvent("paintball:setFlagTaker", "flagReturned")
                                        Wait(1000)
                                        TriggerServerEvent('paintball:updateCTFPoints', PaintballData.Paintball.playerGameId, paintBallGameID, Player(PaintballData.Paintball.playerGameId).state.paintBallTeam)
                                        DetachEntity(PaintballData.Paintball.flagObject, true, true)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    else
        exports['mythic_notify']:SendAlert("error", "A match with that game ID does not exist.")
    end
end)

RegisterNetEvent('paintball:endGame')
AddEventHandler('paintball:endGame', function()
    local ped = PlayerPedId()
    if PaintballData.Paintball.gameID ~= 0 and not PaintballData.Paintball.inGame and not PaintballData.Paintball.startGame and not PaintballData.Paintball.team ~= nil and PaintballData.Paintball.gameMode ~= nil then
        paintBallData = {}
        PaintballData.Paintball.gameID = 0
        PaintballData.Paintball.gameMode = nil
        PaintballData.Paintball.startGame = false
        PaintballData.Paintball.inGame = false
        PaintballData.Paintball.team = nil
        PaintballData.Paintball.kills = 0
        PaintballData.Paintball.deaths = 0
        PaintballData.Paintball.gameTimer = 0
        GlobalState["gameTimer"] = Config.PaintballGame["gameTime"]
        LocalPlayer.state:set("inPaintballGame", false, true)
        LocalPlayer.state:set("onPaintballDeath", false, true)
        LocalPlayer.state:set("paintBallTeam", nil, true)
        paintBallDeleteObject()
    elseif PaintballData.Paintball.inGame and PaintballData.Paintball.team ~= nil and PaintballData.Paintball.gameMode ~= nil and PaintballData.Paintball.gameID ~= 0 then
        paintBallData = {}
        PaintballData.Paintball.gameID = 0
        PaintballData.Paintball.gameMode = nil
        PaintballData.Paintball.startGame = false
        PaintballData.Paintball.inGame = false
        PaintballData.Paintball.team = nil
        PaintballData.Paintball.kills = 0
        PaintballData.Paintball.deaths = 0
        PaintballData.Paintball.gameTimer = 0
        GlobalState["gameTimer"] = Config.PaintballGame["gameTime"]
        LocalPlayer.state:set("inPaintballGame", false, true)
        LocalPlayer.state:set("onPaintballDeath", false, true)
        LocalPlayer.state:set("paintBallTeam", nil, true)
        RemoveWeaponFromPed(PlayerPedId(), GetHashKey("WEAPON_MICROSMG"))
        exports['mythic_notify']:SendAlert('inform', 'Game has ended.')
        paintBallDeleteObject()
    end
end)

RegisterNetEvent('paintball:sessionGame')
AddEventHandler('paintball:sessionGame', function(playerId, team, type)
    if playerId == 0 then return end
    if playerId == GetPlayerServerId(PlayerId()) then
        local ped = PlayerPedId()
        if PaintballData.Paintball.gameID ~= 0 then
            if type == "join" and not PaintballData.Paintball.inGame and team ~= nil then
                PaintballData.Paintball.inGame = true
                LocalPlayer.state:set("inPaintballGame", true, true)
                LocalPlayer.state:set("paintBallTeam", team, true)
                PaintballData.Paintball.team = LocalPlayer.state.paintBallTeam
                SetPedRelationshipGroupHash(PlayerPedId(), PaintballData.Paintball.team)
                SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), false, GetPedRelationshipGroupHash(PlayerPedId()))
                TriggerServerEvent('paintball:sendGameData')
            elseif type == "leave" and PaintballData.Paintball.inGame and team ~= nil then
                PaintballData.Paintball.inGame = false
                PaintballData.Paintball.gameTimer = 0
                LocalPlayer.state:set("inPaintballGame", false, true)
                LocalPlayer.state:set("paintBallTeam", nil, true)
                LocalPlayer.state:set("onPaintballDeath", false, true)
                RemoveWeaponFromPed(PlayerPedId(), GetHashKey("WEAPON_MICROSMG"))
                PaintballData.Paintball.team = LocalPlayer.state.paintBallTeam
                SetPedRelationshipGroupHash(PlayerPedId(), GetHashKey("PLAYER"))
                SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), true, GetPedRelationshipGroupHash(PlayerPedId()))
                TriggerServerEvent('paintball:sendGameData')
                paintBallDeleteObject()
            elseif type == "kicked" and PaintballData.Paintball.startGame and PaintballData.Paintball.inGame and team ~= nil then
                paintBallData = {}
                PaintballData.Paintball.gameID = 0
                PaintballData.Paintball.gameMode = nil
                PaintballData.Paintball.startGame = false
                PaintballData.Paintball.inGame = false
                PaintballData.Paintball.team = nil
                PaintballData.Paintball.kills = 0
                PaintballData.Paintball.deaths = 0
                PaintballData.Paintball.gameTimer = 0
                LocalPlayer.state:set("inPaintballGame", false, true)
                LocalPlayer.state:set("paintBallTeam", nil, true)
                LocalPlayer.state:set("onPaintballDeath", false, true)
                RemoveWeaponFromPed(PlayerPedId(), GetHashKey("WEAPON_MICROSMG"))
                PaintballData.Paintball.team = LocalPlayer.state.paintBallTeam
                SetPedRelationshipGroupHash(PlayerPedId(), GetHashKey("PLAYER"))
                SetEntityCanBeDamagedByRelationshipGroup(PlayerPedId(), true, GetPedRelationshipGroupHash(PlayerPedId()))
                TriggerServerEvent('paintball:sendGameData')
                paintBallDeleteObject()
            end
        else
            exports['mythic_notify']:SendAlert("error", "A match with that game ID does not exist.")
        end
    end
end)

AddEventHandler('paintball:onPaintballDeath', function(playerId, gameID, paintBallDeathData, type)
    if playerId == 0 then return end
	if PaintballData.Paintball.inGame and gameID ~= 0 and GetCurrentResourceName() == "paintball" then
        local ped = PlayerPedId()
        if type ~= "antispawncamp" then
            if PaintballData.Paintball.gameMode == "SND" then
                Wait(500)
                paintBallSNDHandleTeleport(playerId)
            else
                Wait(0)
                NetworkResurrectLocalPlayer(Config.PaintballGame["teleportLocations"][PaintballData.Paintball.team][1].x, Config.PaintballGame["teleportLocations"][PaintballData.Paintball.team][1].y, Config.PaintballGame["teleportLocations"][PaintballData.Paintball.team][1].z, Config.PaintballGame["teleportLocations"][PaintballData.Paintball.team][1].w, true, false)
                SetEntityHealth(ped, 200)
                ClearPedBloodDamage(ped)
                ClearPedTasks(ped)
                GiveWeaponToPed(ped, GetHashKey("WEAPON_MICROSMG"), 9999, false, true)
            end
        else
            SetEntityCoordsNoOffset(ped, GetEntityCoords(ped), false, false, false, true)
            NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
            SetEntityHealth(ped, 200)
            ClearPedBloodDamage(ped)
            ClearPedTasks(ped)
            GiveWeaponToPed(ped, GetHashKey("WEAPON_MICROSMG"), 9999, false, true)
        end
	end
end)

-- taken from fivem docs https://docs.fivem.net/docs/scripting-reference/events/list/gameEventTriggered/
AddEventHandler('gameEventTriggered', function (name, data)
    if GetCurrentResourceName() == "paintball" then
        if name == "CEventNetworkEntityDamage" and PaintballData.Paintball.inGame and PaintballData.Paintball.gameID ~= 0 and usingPaintBallGun(data[2]) and PaintballData.Paintball.startGame then
            if IsEntityAPed(data[1]) and IsPedAPlayer(data[1]) and IsEntityAPed(data[2]) and IsPedAPlayer(data[2]) then
                local victimId = GetPlayerId(data[1])
                local killerId = GetPlayerId(data[2])
                local victimTeam = Player(GetPlayerId(data[1])).state.paintBallTeam
                local killerTeam = Player(GetPlayerId(data[2])).state.paintBallTeam
                
                if not exports["srp_polyzones"]:PointInside("red_side", GetEntityCoords(data[1])) and not exports["srp_polyzones"]:PointInside("red_side", GetEntityCoords(data[2])) and not exports["srp_polyzones"]:PointInside("blue_side", GetEntityCoords(data[1])) and not exports["srp_polyzones"]:PointInside("blue_side", GetEntityCoords(data[2])) then
                    if PaintballData.Paintball.gameMode == "TDM" or PaintballData.Paintball.gameMode == "SND" then
                        addPaintBallKill(killerId, PaintballData.Paintball.gameID, killerTeam)
                        addPaintBallDeath(victimId, PaintballData.Paintball.gameID, victimTeam)
                    elseif PaintballData.Paintball.gameMode == "CTF" then
                        if Player(victimId).state.hasCTFFlag then
                            addPaintBallKill(killerId, PaintballData.Paintball.gameID, killerTeam)
                            addPaintBallDeath(victimId, PaintballData.Paintball.gameID, victimTeam)
                            LocalPlayer.state:set("hasCTFFlag", false, true)
                            TriggerServerEvent("paintball:setFlagTaker", "flagReturned")
                            Wait(1000)
                            DetachEntity(PaintballData.Paintball.flagObject, true, true)
                        else
                            addPaintBallKill(killerId, PaintballData.Paintball.gameID, killerTeam)
                            addPaintBallDeath(victimId, PaintballData.Paintball.gameID, victimTeam)
                        end
                    end
                elseif data[4] and exports["srp_polyzones"]:PointInside("red_side", GetEntityCoords(data[1])) or exports["srp_polyzones"]:PointInside("blue_side", GetEntityCoords(data[1])) then
                    TriggerEvent('paintball:onPaintballDeath', victimId, PaintballData.Paintball.gameID, paintBallData, "antispawncamp")
                elseif data[4] and exports["srp_polyzones"]:PointInside("red_side", GetEntityCoords(data[2])) or exports["srp_polyzones"]:PointInside("blue_side", GetEntityCoords(data[2])) then 
                    TriggerEvent('paintball:onPaintballDeath', victimId, PaintballData.Paintball.gameID, paintBallData, "antispawncamp")
                end
            end
        end
    end
end)
---------------------------
    -- Threads --
---------------------------
Citizen.CreateThread(function()
    exports["srp_polyzones"]:AddBoxZone("red_side", vector3(1722.33, 3243.92, 41.15), 2, 6.4, {
        name="red_side",
        heading=285,
        debugPoly=Config.Debug,
        minZ=40.15,
        maxZ=42.75,
        data = {
            id = 1,
            ref = "red_side"
        }
    })
    exports["srp_polyzones"]:AddBoxZone("blue_side", vector3(1714.85, 3242.73, 41.15), 2, 6.4, {
        name="blue_side",
        heading=285,
        debugPoly=Config.Debug,
        minZ=40.15,
        maxZ=42.75,
        data = {
            id = 1,
            ref = "blue_side"
        }
    })
    exports["srp_polyzones"]:AddBoxZone("ctf_flag_spawn", vector3(1718.5, 3243.24, 41.14), 1.4, 1.4, {
        name="ctf_flag_spawn",
        heading=16,
        debugPoly=Config.Debug,
        minZ=39.94,
        maxZ=43.14,
        data = {
            id = 1,
            ref = "ctf_flag_spawn"
        }
    })
    for i = 1, #Config.PaintballLocations do
        local coords = vector3(Config.PaintballLocations[i].x,Config.PaintballLocations[i].y,Config.PaintballLocations[i].z)
        local menuText = Config.PaintballLocations[i].text
        local tracking_length, tracking_width = Config.PaintballLocations[i].tracking_length, Config.PaintballLocations[i].tracking_width
        local tracking_minZ, tracking_maxZ = Config.PaintballLocations[i].tracking_minZ, Config.PaintballLocations[i].tracking_maxZ
        local tracking_heading = Config.PaintballLocations[i].tracking_heading
        local tracking_distance = Config.PaintballLocations[i].tracking_distance
        exports["srp_tracking"]:AddBoxZone("Paintball_"..i, coords, tracking_length, tracking_width, {
            name = "Paintball_"..i,
            debugPoly = false,
            heading = tracking_heading,
            minZ = tracking_minZ,
            maxZ = tracking_maxZ,
        }, {
            options = {
                {
                    event = "paintball:paintBallTeamMenu",
                    icon = "fas fa-user-friends",
                    label = menuText,
                    paintballId = i,
                },
            },
            job = {"all"},
            distance = tracking_distance
        })
    end
end)

AddEventHandler('paintball:paintBallTeamMenu', function(data)
    if data.paintballId and data.label == "Boss Actions" then
        if ESX.PlayerData.job.name == "paintball" and ESX.PlayerData.job.grade == 1 then
            local bossActions = exports["nh-context"]:ContextMenu({
                {
                    header = "<strong>Paintball Setup Actions </strong>", 
                },
                {
                    header = "",
                    context = "&raquo; Setup Game",
                    args = {"setupGame"}
                },
                {
                    header = "",
                    context = "&raquo; Start Game",
                    args = {"startGame"}
                },
                {
                    header = "",
                    context = "&raquo; End Game",
                    args = {"endGame"}
                },
                {
                    header = "",
                    context = "&raquo; Kick Player",
                    args = {"kickPlayer"}
                },
                {
                    header = "",
                    context = "&raquo; Reset CTF Flag",
                    args = {"resetFlag"}
                },
            })
            if bossActions ~= nil then
                if bossActions == "setupGame" then
                    local keyboard, gameMode, scoreCap, teamCap = exports["nh-keyboard"]:Keyboard({
                        header = "<strong> Paintball Setup Actions </strong>", 
                        rows = {"Gamemode", "Score Cap", "Team Cap"}
                    })

                    if keyboard then
                        if tonumber(scoreCap) and tonumber(teamCap) then
                            if tostring(gameMode) and isValidPaintballGameMode(gameMode) then
                                TriggerServerEvent('paintball:createGame', gameMode, scoreCap, teamCap)
                            end
                        else
                            exports['mythic_notify']:SendAlert('error', 'This field must be a(n) valid number or can\'t be left blank!')
                        end
                    end
                elseif bossActions == "startGame" then
                    local keyboard, gameID = exports["nh-keyboard"]:Keyboard({
                        header = "<strong> Start Paintball Game </strong>", 
                        rows = {"GameID"}
                    })
                
                    if keyboard then
                        if tonumber(gameID) then
                            TriggerServerEvent('paintball:startPaintballGame', gameID)
                        else
                            exports['mythic_notify']:SendAlert('error', 'This field must be a(n) valid number or can\'t be left blank!')
                        end
                    end
                elseif bossActions == "endGame" then
                    local keyboard, gameID = exports["nh-keyboard"]:Keyboard({
                        header = "<strong> End Paintball Game </strong>", 
                        rows = {"GameID"}
                    })

                    if keyboard then
                        if tonumber(gameID) then
                            TriggerServerEvent('paintball:endPaintballGameID', gameID)
                        else
                            exports['mythic_notify']:SendAlert('error', 'This field must be a(n) valid number or can\'t be left blank!')
                        end
                    end
                elseif bossActions == "kickPlayer" then
                    local keyboard, playerId = exports["nh-keyboard"]:Keyboard({
                        header = "<strong> Kick Player </strong>", 
                        rows = {"PlayerID"}
                    })

                    if keyboard then
                        if tonumber(playerId) then
                            TriggerServerEvent('paintball:kickPlayerFromGame', playerId)
                        else
                            exports['mythic_notify']:SendAlert('error', 'This field must be a(n) valid number or can\'t be left blank!')
                        end
                    end
                elseif bossActions == "resetFlag" then
                    local keyboard, gameID = exports["nh-keyboard"]:Keyboard({
                        header = "<strong> Reset CTF Flag </strong>", 
                        rows = {"GameID"}
                    })
                
                    if keyboard then
                        if tonumber(gameID) then
                            TriggerServerEvent('paintball:flagReset', gameID)
                        else
                            exports['mythic_notify']:SendAlert('error', 'This field must be a(n) valid number or can\'t be left blank!')
                        end
                    end
                end
            end
        else
            exports['mythic_notify']:SendAlert('error', 'You must be the boss of the paintball job to access this!')
        end
    elseif data.paintballId and data.label == "Team Setup" then
        if #paintBallData ~= 0 then
            local red, blue = paintBallReturnTeamCount()
            local joinTeamMenu = exports["nh-context"]:ContextMenu({
                {
                    header = ("<strong> Choose a team | Current Game ID: %s</strong>"):format(PaintballData.Paintball.gameID),
                },
                {
                    header = "Red Team",
                    context = "Players: " .. red,
                    args = {"red"}
                },
                {
                    header = "Blue Team",
                    context = "Players: " .. blue,
                    args = {"blue"}
                },
            })
            if joinTeamMenu ~= nil then
                if joinTeamMenu == "red" then
                    TriggerServerEvent('paintball:joinPaintballGame', joinTeamMenu)
                elseif joinTeamMenu == "blue" then
                    TriggerServerEvent('paintball:joinPaintballGame', joinTeamMenu)
                end
            end
        else
            exports['mythic_notify']:SendAlert('error', 'No active sessions.')
        end
    end
end)
---------------------------
    -- Functions --
---------------------------
paintBallRequestPlayerCount = function()
    for i = 1, #paintBallData do
        for b = 1, #paintBallData[i][PaintballData.Paintball.gameID]["playersInGame"] do
            return #paintBallData[i][PaintballData.Paintball.gameID]["playersInGame"]
        end
    end
end

paintBallReturnTeamCount = function()
    for i = 1, #paintBallData do
        if paintBallData[i][PaintballData.Paintball.gameID] ~= nil then
            local red = (#paintBallData[i][PaintballData.Paintball.gameID]["red"] and (#paintBallData[i][PaintballData.Paintball.gameID]["red"] > 0)) or 0
            local blue = (#paintBallData[i][PaintballData.Paintball.gameID]["blue"] and (#paintBallData[i][PaintballData.Paintball.gameID]["blue"] > 0)) or 0
            if red or blue then
                return #paintBallData[i][PaintballData.Paintball.gameID]["red"], #paintBallData[i][PaintballData.Paintball.gameID]["blue"]
            end
        end
    end
end

isValidPaintballGameMode = function(gamemode)
    if #gamemode == 0 then return end
    for i = 1, #Config.PaintballGame.gameModes do
        if Config.PaintballGame.gameModes[i] ~= nil then
            if string.match(string.upper(gamemode), Config.PaintballGame.gameModes[i]) or string.match(string.lower(gamemode), Config.PaintballGame.gameModes[i]) then
                return true
            end
        end
    end
    exports['mythic_notify']:SendAlert('error', 'Invalid gamemode entered, the gamemodes are case sensitive.')
    return false
end

paintBallGameTimer = function()
    CreateThread(function()
        while PaintballData.Paintball.startGame do
            local min = tostring(math.floor(GlobalState["gameTimer"]/60))
            local sec = tostring(GlobalState["gameTimer"] - 60 * min)
            PaintballData.Paintball.gameTimer = ("%s : %s"):format(min,sec)
            GlobalState["gameTimer"] -= 1
            
            if GlobalState["gameTimer"] < 0 then
                GlobalState["gameTimer"] = 0
                PaintballData.Paintball.gameTimer = 0
            end
    
            Wait(1000)
        end
    end)
end

paintBallGameTeleportToStart = function(gameID, teamName, paintBallClientData)
    for i = 1, #paintBallClientData do
        if paintBallClientData[i][gameID][teamName] ~= nil then
            for b = 1, #paintBallClientData[i][gameID][teamName] do
                SetEntityCoordsNoOffset(PlayerPedId(), Config.PaintballGame["teleportLocations"][teamName][i].x-(math.random(0,1)), Config.PaintballGame["teleportLocations"][teamName][i].y-(math.random(1,4)), Config.PaintballGame["teleportLocations"][teamName][i].z)
                SetEntityHeading(PlayerPedId(), Config.PaintballGame["teleportLocations"][teamName][i].w)
            end
        end
    end
end

paintBallDeleteObject = function()
    if DoesEntityExist(PaintballData.Paintball.flagObject) then
        DeleteEntity(PaintballData.Paintball.flagObject)
        DeleteObject(PaintballData.Paintball.flagObject)
        PaintballData.Paintball.flagObject = nil
    end
end

paintBallSNDHandleTeleport = function(playerId)
    if playerId == GetPlayerServerId(PlayerId()) then
        for i = 1, #paintBallData do
            if paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team] ~= nil then
                for k,v in pairs(paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team]) do
                    if paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team][k].playerId == playerId and paintBallData[i][PaintballData.Paintball.gameID][PaintballData.Paintball.team][k].hasDied then
                        LocalPlayer.state:set("onPaintballDeath", true, true)
                        -- teleport them
                    end
                end
            end
        end
    end
end

paintBallGameModeMenu = function(index, paintBallGameID, gameMode)
    if paintBallRequestPlayerCount() >= 2 then
        PaintballData.MenuData.defaultScaleY = 0.35
        PaintballData.MenuData.newTextPos = 0.065
    else
        PaintballData.MenuData.defaultScaleY = 0.50
        PaintballData.MenuData.newTextPos = 0.11
    end
    if gameMode == "TDM" or gameMode == "SND" then
        PaintballData.MenuData.redCoordX = 0.8
        PaintballData.MenuData.redCoordY = 0.12
        PaintballData.MenuData.blueCoordX = 0.9
        PaintballData.MenuData.blueCoordY = 0.12
        PaintballData.MenuData.timerCoordX = 0.86
        PaintballData.MenuData.timerCoordY = 0.12
        PaintballData.MenuData.redScoreCoordX = 0.8
        PaintballData.MenuData.redScoreCoordY = 0.15
        PaintballData.MenuData.blueScoreCoordX = 0.9
        PaintballData.MenuData.blueScoreCoordY = 0.15
        PaintballData.MenuData.redKillCoordX = 0.8
        PaintballData.MenuData.blueKillCoordX = 0.9
        PaintballData.MenuData.redTeamTextPos = 0.20
        PaintballData.MenuData.blueTeamTextPos = 0.20
        PaintballData.MenuData.scoreText = "Score: %s"
    elseif gameMode == "CTF" then
        PaintballData.MenuData.redCoordX = 0.35
        PaintballData.MenuData.redCoordY = 0.001
        PaintballData.MenuData.blueCoordX = 0.55
        PaintballData.MenuData.blueCoordY = 0.001
        PaintballData.MenuData.timerCoordX = 0.45
        PaintballData.MenuData.timerCoordY = 0.001
        PaintballData.MenuData.redScoreCoordX = 0.40
        PaintballData.MenuData.redScoreCoordY = 0.001
        PaintballData.MenuData.blueScoreCoordX = 0.60
        PaintballData.MenuData.blueScoreCoordY = 0.001
        PaintballData.MenuData.redKillCoordX = 0.35
        PaintballData.MenuData.blueKillCoordX = 0.55
        PaintballData.MenuData.redTeamTextPos = 0.03
        PaintballData.MenuData.blueTeamTextPos = 0.03
        PaintballData.MenuData.scoreText = "%s"
    end
    Utils.Draw3dTextHud("Red Team:", {220, 20, 60, 255}, PaintballData.MenuData.redCoordX, PaintballData.MenuData.redCoordY, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
    Utils.Draw3dTextHud(("Time \n%s"):format(PaintballData.Paintball.gameTimer), {255, 255, 255, 255}, PaintballData.MenuData.timerCoordX, PaintballData.MenuData.timerCoordY, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
    Utils.Draw3dTextHud("Blue Team:", {30, 144, 255, 255}, PaintballData.MenuData.blueCoordX, PaintballData.MenuData.blueCoordY, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
    Utils.Draw3dTextHud((PaintballData.MenuData.scoreText):format(paintBallData[index][paintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"]), {220, 20, 60, 255}, PaintballData.MenuData.redScoreCoordX, PaintballData.MenuData.redScoreCoordY, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
    Utils.Draw3dTextHud((PaintballData.MenuData.scoreText):format(paintBallData[index][paintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"]), {30, 144, 255, 255}, PaintballData.MenuData.blueScoreCoordX, PaintballData.MenuData.blueScoreCoordY, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
    for b = 1, #paintBallData[index][paintBallGameID]["red"] do
        Utils.Draw3dTextHud(("%s \nK: %s \nD: %s"):format(paintBallData[index][paintBallGameID]["red"][b].playerName, paintBallData[index][paintBallGameID]["red"][b].kills, paintBallData[index][paintBallGameID]["red"][b].deaths), {220, 20, 60, 255}, PaintballData.MenuData.redKillCoordX, PaintballData.MenuData.redTeamTextPos, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
        PaintballData.MenuData.redTeamTextPos += PaintballData.MenuData.newTextPos
    end
    
    for c = 1, #paintBallData[index][paintBallGameID]["blue"] do
        Utils.Draw3dTextHud(("%s \nK: %s \nD: %s"):format(paintBallData[index][paintBallGameID]["blue"][c].playerName, paintBallData[index][paintBallGameID]["blue"][c].kills, paintBallData[index][paintBallGameID]["blue"][c].deaths), {30, 144, 255, 255}, PaintballData.MenuData.blueKillCoordX, PaintballData.MenuData.blueTeamTextPos, PaintballData.MenuData.defaultScaleX, PaintballData.MenuData.defaultScaleY)
        PaintballData.MenuData.blueTeamTextPos += PaintballData.MenuData.newTextPos
    end
end

paintBallDecideWinner = function(activePaintBallGameData, index, activePaintBallGameID)
    if PaintballData.Paintball.gameMode == "TDM" or PaintballData.Paintball.gameMode == "SND" then
        if activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] > activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] then
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message text-red"><b>&raquo; Paintball:</b> Red had more points, therefore they were made the winner!</div>',
                args = {}
            })
        elseif activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] < activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] then
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message text-blue"><b>&raquo; Paintball:</b> Blue had more points, therefore they were made the winner!</div>',
                args = {}
            })
        elseif activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] == activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] or activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] == activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] then
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message text-report"><b>&raquo; Paintball:</b> Both teams were equal in points, therefore this game has been decided as a tie!</div>',
                args = {}
            })
        end
    elseif PaintballData.Paintball.gameMode == "CTF" then
        if activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] < activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] then
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message text-red"><b>&raquo; Paintball:</b> Red had more points, therefore they were made the winner!</div>',
                args = {}
            })
        elseif activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] > activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] then
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message text-blue"><b>&raquo; Paintball:</b> Blue had more points, therefore they were made the winner!</div>',
                args = {}
            })
        elseif activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] == activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] or activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["blue"] == activePaintBallGameData[index][activePaintBallGameID][PaintballData.Paintball.currentGameModePoints]["red"] then
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message text-report"><b>&raquo; Paintball:</b> Both teams were equal in points, therefore this game has been decided as a tie!</div>',
                args = {}
            })
        end
    end
    TriggerServerEvent('paintball:decideWinner', activePaintBallGameID)
end

addPaintBallKill = function(killerId, gameID, team)
    TriggerServerEvent('paintball:addKill', killerId, gameID, team)
end

addPaintBallDeath = function(victimId, gameID, team)
    TriggerServerEvent('paintball:addDeath', victimId, gameID, team, PaintballData.Paintball.gameMode)
    TriggerEvent('paintball:onPaintballDeath', victimId, gameID, paintBallData)
end

usingPaintBallGun = function(entity)
    return (GetSelectedPedWeapon(entity) == GetHashKey("WEAPON_MICROSMG"))
end

requestFlag = function(flag)
    while not NetworkHasControlOfEntity(flag) and GetEntityType(flag) == 3 do
        NetworkRequestControlOfEntity(flag)
        Wait(0)
    end
    DetachEntity(flag)
    AttachEntityToEntity(flag, PaintballData.Paintball.flagTakerPed, GetPedBoneIndex(PaintballData.Paintball.flagTakerPed, 57597), 0.0, -0.20, 0.1, 0.0, 120.0, 0.0, false, false, false, false, 0, true)
end

GetPlayerId = function(entity)
    return GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
end
---------------------------
    -- debug / cmd shit --
---------------------------
if Config.Debug then
    CreateThread(function()
        while true do
            Wait(0)
            Utils.drawTxt(0.70, 0.30, "~w~game ID: ~s~".. tostring(PaintballData.Paintball.gameID))
            Utils.drawTxt(0.70, 0.30, "\n~w~in game: ~s~".. tostring(PaintballData.Paintball.inGame))
            Utils.drawTxt(0.70, 0.30, "\n\n~w~start game: ~s~".. tostring(PaintballData.Paintball.startGame))
            Utils.drawTxt(0.70, 0.30, "\n\n\n~w~player death: ~s~".. tostring(LocalPlayer.state.onPaintballDeath))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n~w~player team: ~s~".. tostring(PaintballData.Paintball.team))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n~w~paintball game state: ~s~".. tostring(LocalPlayer.state.inPaintballGame))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n~w~paintball kills: ~s~".. tostring(PaintballData.Paintball.kills))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n~w~paintball deaths: ~s~".. tostring(PaintballData.Paintball.deaths))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n~w~paintball global state timer: ~s~".. tostring(GlobalState["gameTimer"]))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n~w~paintball game time: ~s~".. tostring(PaintballData.Paintball.gameTimer))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n~w~paintball gamemode: ~s~".. tostring(PaintballData.Paintball.gameMode))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n~w~flag object: ~s~".. tostring(PaintballData.Paintball.flagObject))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n\n~w~flag object globalstate: ~s~".. tostring(GlobalState["ctfFlagEntity"]))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n\n\n~w~has ctf flag: ~s~".. tostring(LocalPlayer.state.hasCTFFlag))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n~w~flag taker: ~s~".. tostring(GlobalState["ctfFlagTaker"]))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n~w~flag taker team: ~s~".. tostring(PaintballData.Paintball.flagTakerTeam))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n~w~coords: ~s~".. tostring(GetEntityCoords(PlayerPedId())))
            Utils.drawTxt(0.70, 0.30, "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n~w~current gamemode points: ~s~".. tostring(PaintballData.Paintball.currentGameModePoints))
            -- Utils.drawTxt(0.70, 0.30, "\n\n~w~string name for table here:~s~ ".. tostring(json.encode(table)))
        end
    end)

    local state = false
    RegisterCommand('loadstate',function()
        state = not state
        LocalPlayer.state:set("inPaintballGame", state, true)
        print("in paintball game state reset: ", LocalPlayer.state.inPaintballGame)
    end)

    resetShit = function ()
        print("states reset")
        local ped = PlayerPedId()
        GlobalState["gameTimer"] = Config.PaintballGame["gameTime"]
        LocalPlayer.state:set("inPaintballGame", false, true)
        LocalPlayer.state:set("paintBallTeam", nil, true)
        LocalPlayer.state:set("hasCTFFlag", false, true)
        LocalPlayer.state:set("onPaintballDeath", false, true)
        SetPedRelationshipGroupHash(ped, GetHashKey("PLAYER"))
        RemoveWeaponFromPed(ped, GetHashKey("WEAPON_MICROSMG"))
        SetEntityCanBeDamagedByRelationshipGroup(ped, true, GetHashKey("PLAYER"))
        print("in paintball game state reset: ", LocalPlayer.state.inPaintballGame)
        ClearScenarioObject()
    end

    ClearScenarioObject = function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local flagEntity = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 1000.0, GetHashKey("ind_prop_dlc_flag_02"), false)
        if DoesEntityExist(flagEntity) then
            DeleteEntity(flagEntity)
            DeleteObject(flagEntity)
            ClearAreaOfObjects(playerCoords, 20.0, 0)
        end
    end

    AddEventHandler('onClientResourceStart',function(resource)
        if GetCurrentResourceName() == "paintball" then
            resetShit()
        end
    end)

    RegisterCommand('clientdata',function()
        print(json.encode(paintBallData))
    end)

    RegisterCommand('debugcfg', function()
        for i = 1, #Config.PaintballLocations do
            print(json.encode(Config.PaintballLocations[i][1]))
        end
    end)
end