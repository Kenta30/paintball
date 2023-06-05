---------------------------
    -- Variables --
---------------------------
local paintBallData = {}
local currentGamemode = nil
local flagObject = {}
flagObject.flags = {}
local preGlobalStates = function()
    if currentGamemode == "CTF" and DoesEntityExist(NetworkGetEntityFromNetworkId(flagObject.flags.networkId)) then
        DeleteEntity(NetworkGetEntityFromNetworkId(flagObject.flags.networkId))
        flagObject.flags = {}
    end
    currentGamemode = nil
    GlobalState["ctfFlagTaker"] = false
    GlobalState["gameTimer"] = Config.PaintballGame["gameTime"] 
end
preGlobalStates()
---------------------------
    -- Event Handlers --
---------------------------
RegisterServerEvent('paintball:sendGameData')
AddEventHandler('paintball:sendGameData', function()
    TriggerClientEvent('paintball:updateGameData', -1, paintBallData)
end)

RegisterServerEvent('paintball:createGame')
AddEventHandler('paintball:createGame', function(gameMode, score, teamCap)
    createPaintballGame(source, string.upper(gameMode), tonumber(score), tonumber(teamCap))
end)

RegisterServerEvent('paintball:startPaintballGame')
AddEventHandler('paintball:startPaintballGame', function(gameID)
    startPaintballGame(source, tonumber(gameID))
end)

RegisterServerEvent('paintball:endPaintballGameID')
AddEventHandler('paintball:endPaintballGameID', function(gameID)
    endPaintballGame(source, tonumber(gameID))
end)

RegisterServerEvent('paintball:kickPlayerFromGame')
AddEventHandler('paintball:kickPlayerFromGame', function(playerId)
    kickPlayerFromPaintballGame(source, tonumber(playerId))
end)

RegisterServerEvent('paintball:flagReset')
AddEventHandler('paintball:flagReset', function(gameID)
    paintBallFlagReset(source, tonumber(gameID))
end)

RegisterServerEvent('paintball:joinPaintballGame')
AddEventHandler('paintball:joinPaintballGame', function(teamName)
    local gameID = getCurrentPaintballGameID()
    joinPaintballGame(source, gameID, tostring(teamName))
end)

RegisterServerEvent('paintball:decideWinner')
AddEventHandler('paintball:decideWinner', function(activePaintBallGameID)
    for i = 1, #paintBallData do
        if paintBallData[i][activePaintBallGameID] ~= nil then
            for b = 1, #paintBallData[i][activePaintBallGameID]["playersInGame"] do
                setPlayersRoutingBucketInGame(paintBallData[i][activePaintBallGameID]["playersInGame"][b], activePaintBallGameID, false)
            end
            table.wipe(paintBallData)
            TriggerClientEvent('paintball:endGame', -1)
            preGlobalStates()
        end
    end
end)

RegisterServerEvent('paintball:addKill')
AddEventHandler('paintball:addKill', function(killerId, gameID, team)
    if killerId == source then return end
    for i = 1, #paintBallData do
        if paintBallData[i][gameID][team] ~= nil then
            for k,v in pairs(paintBallData[i][gameID][team]) do
                if killerId == v.playerId then
                    v.kills += 1
                end
            end
        end
    end
    TriggerClientEvent('paintball:updateGameData', -1, paintBallData)
end)

RegisterServerEvent('paintball:addDeath')
AddEventHandler('paintball:addDeath', function(victimId, gameID, team, gameMode)
    for i = 1, #paintBallData do
        if paintBallData[i][gameID][team] ~= nil then
            for k,v in pairs(paintBallData[i][gameID][team]) do
                if victimId == v.playerId then
                    if gameMode == "TDM" then
                        v.deaths += 1
                        paintBallData[i][gameID]["score"][team] -= 1
                        if paintBallData[i][gameID]["score"][team] < 0 then
                            paintBallData[i][gameID]["score"][team] = 0
                        end
                    elseif gameMode == "CTF" then
                        v.deaths += 1
                    elseif gameMode == "SND" then
                        v.deaths += 1
                        v.hasDied = true
                        paintBallData[i][gameID]["score"][team] -= 1
                        if paintBallData[i][gameID]["score"][team] < 0 then
                            paintBallData[i][gameID]["score"][team] = 0
                        end
                    end
                end
            end
        end
    end
    TriggerClientEvent('paintball:updateGameData', -1, paintBallData)
end)

RegisterServerEvent('paintball:updateCTFPoints')
AddEventHandler('paintball:updateCTFPoints', function(flagTakerId, gameID, team)
    for i = 1, #paintBallData do
        if paintBallData[i][gameID][team] ~= nil then
            for k,v in pairs(paintBallData[i][gameID][team]) do
                if flagTakerId == v.playerId then
                    if DoesEntityExist(NetworkGetEntityFromNetworkId(flagObject.flags.networkId)) then
                        paintBallData[i][gameID]["score"][team] -= 1
                        if paintBallData[i][gameID]["score"][team] < 0 then
                            paintBallData[i][gameID]["score"][team] = 0
                        end
                    end
                end
            end
        end
    end
    TriggerClientEvent('paintball:updateGameData', -1, paintBallData)
end)

RegisterServerEvent("paintball:setFlagTaker")
AddEventHandler("paintball:setFlagTaker", function(flagData)
    local src = source
    if DoesEntityExist(NetworkGetEntityFromNetworkId(flagObject.flags.networkId)) then
        if GlobalState["ctfFlagTaker"] ~= src then
            GlobalState["ctfFlagTaker"] = src
        elseif GlobalState["ctfFlagTaker"] == src then
            if flagData == "flagReturned" then
                GlobalState["ctfFlagTaker"] = false
            else
                GlobalState["ctfFlagTaker"] = false
            end
        end
    end
end)
---------------------------
    -- Functions  --
---------------------------
createPaintballGame = function(source, gameMode, scores, maxTeamCap)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    if gameMode ~= nil then
        if isValidGameMode(gameMode) then
            currentGamemode = gameMode
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                if xPlayer.job.name == "paintball" and xPlayer.job.grade == 1 then
                    if #paintBallData == 0 then
                        local gameIdentifier = math.random(1,100)
                        table.insert(paintBallData, {
                            [gameIdentifier] = {
                                gameActive = false,
                                ["red"] = {}, 
                                ["blue"] = {},
                                maxTeamCap = maxTeamCap,
                                playersInGame = {}, 
                                score = {
                                    ["red"] = scores,
                                    ["blue"] = scores
                                },
                            }
                        })
                        TriggerClientEvent('paintball:createGameData', -1, paintBallData, gameIdentifier, gameMode)
                        if currentGamemode == "CTF" then
                            paintBallSpawnFlag()
                            CreateThread(function()
                                while currentGamemode == "CTF" do
                                    Wait(2000)
                                    if GlobalState["ctfFlagTaker"] then
                                        TriggerClientEvent('paintball:handleFlagSpawn', -1, flagObject)
                                    else
                                        SetEntityCoords(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), 1718.5, 3243.24, 41.14-1.0)
                                        SetEntityHeading(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), 180)
                                        FreezeEntityPosition(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), true)
                                    end
                                end
                            end)
                        end
                    else
                        TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "There is already a(n) active game going!"})
                    end
                else
                    TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You must be the paintball boss in order to use this command!"})
                end
            else
                print("[^3paintball^7] xPlayer returned nil, did they leave?")
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You've entered an invalid game mode!"})
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You must specify a game mode!"})
    end
end

joinPaintballGame = function(source, gameID, team)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    if team == "red" or team == "blue" then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then 
            if xPlayer.job.name ~= "paintball" then
                for i = 1, #paintBallData do
                    if paintBallData[i][gameID] ~= nil then
                        if not isPaintballGameStarted(gameID) then
                            if countPlayersInTeam(source, gameID, team) ~= paintBallData[i][gameID].maxTeamCap then
                                if not inPaintBallGame(source, gameID) then
                                    table.insert(paintBallData[i][gameID].playersInGame, source)
                                    table.insert(paintBallData[i][gameID][team], {playerId = source, playerName = xPlayer.getName(), kills = 0, deaths = 0, hasDied = false})
                                    TriggerClientEvent('paintball:sessionGame', -1, source, team, "join")
                                    TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "inform", text = "You have joined the match!"})
                                else
                                    TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You are already in a team!"})
                                end
                            else
                                TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "The team you tried joining is full!"})
                            end
                        else
                            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "A game with that game ID has already been started!"})
                        end
                    else
                        TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "This game ID does not exist!"})
                    end
                end
            else
                TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "Employees cannot participate in this game, do your job!"})
            end
        else
            print("[^3paintball^7] xPlayer returned nil, did they leave?")
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You've entered a(n) invalid team name!"})
        return
    end
end

leavePaintballGame = function(source, gameID)
    local teamName = getPlayersCurrentPaintballTeam(source)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    if GetPlayerRoutingBucket(source) == gameID then setPlayersRoutingBucketInGame(source, gameID, false) end
    for i = 1, #paintBallData do
        if paintBallData[i][gameID] ~= nil then
            if inPaintBallGame(source, gameID) then
                for k,v in pairs(paintBallData[i][gameID][teamName]) do
                    if source == v.playerId then
                        removePlayerFromMatch(source, gameID)
                        table.remove(paintBallData[i][gameID][teamName], k)
                        TriggerClientEvent('paintball:sessionGame', -1, source, teamName, "leave")
                        TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "inform", text = "You have left the match!"})
                    end
                end
            else
                TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You aren't in a game!"})
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "This game ID does not exist!"})
        end
    end
end

startPaintballGame = function(source, gameID)
    if currentGamemode == "CTF" and DoesEntityExist(NetworkGetEntityFromNetworkId(flagObject.flags.networkId)) then
        SetEntityRoutingBucket(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), gameID)
    end
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        if xPlayer.job.name == "paintball" and xPlayer.job.grade == 1 then
            for i = 1, #paintBallData do
                if paintBallData[i][gameID] ~= nil then
                    if not isPaintballGameStarted(gameID) then
                        if countPlayersInTeam(source, gameID, "red") == paintBallData[i][gameID].maxTeamCap and countPlayersInTeam(source, gameID, "blue") == paintBallData[i][gameID].maxTeamCap then
                            for b = 1, #paintBallData[i][gameID]["playersInGame"] do
                                paintBallData[i][gameID].gameActive = true
                                setPlayersRoutingBucketInGame(paintBallData[i][gameID]["playersInGame"][b], gameID, true)
                                TriggerClientEvent('paintball:startGame', paintBallData[i][gameID]["playersInGame"][b], gameID, paintBallData)
                            end
                        else
                            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "Both teams must have the required amount of players for the game to start!"})
                            return
                        end
                    else
                        TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "A game with that game ID has already been started!"})
                    end
                else
                    TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "This game ID does not exist!"})
                end
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You must be the paintball boss in order to use this command!"})
        end
    else
        print("[^3paintball^7] xPlayer returned nil, did they leave?")
    end
end

endPaintballGame = function(source, gameID)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        if xPlayer.job.name == "paintball" and xPlayer.job.grade == 1 then
            for i = 1, #paintBallData do
                if paintBallData[i][gameID] ~= nil then
                    for b = 1, #paintBallData[i][gameID]["playersInGame"] do
                        setPlayersRoutingBucketInGame(paintBallData[i][gameID]["playersInGame"][b], gameID, false)
                    end
                    table.wipe(paintBallData)
                    TriggerClientEvent('paintball:endGame', -1)
                    preGlobalStates()
                else
                    TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You've entered an invalid Game ID!"})
                end
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You must be the paintball boss in order to use this command!"})
        end
    else
        print("[^3paintball^7] xPlayer returned nil, did they leave?")
    end
end

kickPlayerFromPaintballGame = function(source, playerId)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    if playerId == 0 then return print("[^3paintball^7] You cannot kick the console you fool!") end
    local gameID = getPlayersCurrentPaintballGameID(playerId)
    local playersTeam = getPlayersCurrentPaintballTeam(playerId)
    if GetPlayerRoutingBucket(playerId) == gameID then setPlayersRoutingBucketInGame(playerId, gameID, false) end
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        if xPlayer.job.name == "paintball" then
            for i = 1, #paintBallData do
                if paintBallData[i][gameID] ~= nil then
                    for k,v in pairs(paintBallData[i][gameID][playersTeam]) do
                        if playerId == v.playerId then
                            removePlayerFromMatch(playerId, gameID)
                            table.remove(paintBallData[i][gameID][playersTeam], k)
                            TriggerClientEvent('paintball:sessionGame', -1, playerId, playersTeam, "kicked")
                            TriggerClientEvent('mythic_notify:client:SendAlert', playerId, {type = "inform", text = "You were kicked from this match!"})
                        end
                    end
                else
                    TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "There is is no active games or you entered an invalid player ID!"})
                end
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', source, {type = "error", text = "You must be a(n) paintball employee in order to use this command!"})
        end
    end
end

removePlayerFromMatch = function(source, gameID)
    for i = 1, #paintBallData do
        if paintBallData[i][gameID] ~= nil then
            for k,v in pairs(paintBallData[i][gameID]["playersInGame"]) do
                if source == v then
                    table.remove(paintBallData[i][gameID]["playersInGame"], k)
                end
            end
        end
    end
end

countPlayersInTeam = function(source, gameID, teamName)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    if type(teamName) ~= "string" or teamName == nil then return end
    if teamName == "red" then
        for i = 1, #paintBallData do 
            return #paintBallData[i][gameID]["red"]
        end
    elseif teamName == "blue" then
        for i = 1, #paintBallData do 
            return #paintBallData[i][gameID]["blue"]
        end
    end
    return false
end

inPaintBallGame = function(source, gameID)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    for i = 1, #paintBallData do
        if paintBallData[i] ~= nil then
            for k,v in pairs(paintBallData[i][gameID]["playersInGame"]) do
                if source == v then
                    return true
                end
            end
        end
    end
    return false
end

isValidGameMode = function(gameMode)
    if #gameMode == 0 then return end
    for i = 1, #Config.PaintballGame.gameModes do
        if Config.PaintballGame.gameModes[i] ~= nil then
            if string.match(string.upper(gameMode), Config.PaintballGame.gameModes[i]) or string.match(string.lower(gameMode), Config.PaintballGame.gameModes[i]) then
                return true
            end
        end
    end
    return false
end

isPaintballGameStarted = function(gameID)
    if gameID == 0 then return print("[^3paintball^7] The game ID can't be 0!") end
    for i = 1, #paintBallData do
        if paintBallData[i] ~= nil then
            for k,v in pairs(paintBallData[i]) do
                if k == gameID then
                    if v.gameActive then
                        return true
                    else
                        return false
                    end
                end
            end
        end
    end
end

setPlayersRoutingBucketInGame = function(playersInMatch, gameID, setPlayers)
    if setPlayers then
        SetPlayerRoutingBucket(playersInMatch, gameID)
    else
        SetPlayerRoutingBucket(playersInMatch, 0)
    end
end

getPlayersCurrentPaintballGameID = function(playerId)
    for i = 1, #paintBallData do
        if paintBallData[i] ~= nil then
            for k,v in pairs(paintBallData[i]) do
                for b = 1,#paintBallData[i][k]["playersInGame"] do
                    if paintBallData[i][k]["playersInGame"][b] == playerId then
                        return k
                    end
                end
            end
        end
    end
end

getPlayersCurrentPaintballTeam = function(playerId)
    local gameID = getPlayersCurrentPaintballGameID(playerId)
    for i = 1, #paintBallData do
        if paintBallData[i][gameID] ~= nil then
            for k,v in pairs(paintBallData[i][gameID]) do
                if k == "red" or k == "blue" then
                    for k2,v2 in pairs(v) do
                        if v2.playerId ~= nil and k ~= nil then
                            if v2.playerId == playerId then
                                return k
                            end
                        end
                    end
                end
            end
        end
    end
end

getCurrentPaintballGameID = function()
    for i = 1, #paintBallData do
        if paintBallData[i] ~= nil then
            for k,v in pairs(paintBallData[i]) do
                return k
            end
        end
    end
end

paintBallSpawnFlag = function()
    Wait(1500)
    if DoesEntityExist(NetworkGetEntityFromNetworkId(flagObject.flags.networkId or 0)) then
        DeleteEntity(NetworkGetEntityFromNetworkId(flagObject.flags.networkId))
        flagObject.flags = {}
        GlobalState["ctfFlagTaker"] = false
    end
    
    local object = CreateObject(GetHashKey("ind_prop_dlc_flag_02"), vector3(1718.5, 3243.24, 41.14-1.0), true, true, true)
    while not DoesEntityExist(object) do Wait(50) end
    FreezeEntityPosition(object, true)
    flagObject.flags = {
        networkId = NetworkGetNetworkIdFromEntity(object)
    }
    TriggerClientEvent('paintball:handleFlagSpawn', -1, flagObject)
end

paintBallFlagReset = function(source, gameID)
    if source == 0 then return print("[^3paintball^7] This command cannot be ran from console!") end
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer.job.name == "paintball" then
        if currentGamemode == "CTF" and DoesEntityExist(NetworkGetEntityFromNetworkId(flagObject.flags.networkId)) then
            for i = 1, #paintBallData do
                if paintBallData[i][gameID] ~= nil then
                    for b = 1, #paintBallData[i][gameID]["playersInGame"] do
                        TriggerClientEvent('mythic_notify:client:SendAlert', paintBallData[i][gameID]["playersInGame"][b], {type = "inform", text = "CTF Flag Reset!"})
                        paintBallSpawnFlag()
                    end
                end
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', src, {type = "error", text = "The gamemode must be capture the flag or the flag entity you are trying to reset doesn't exist!"})
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', src, {type = "error", text = "You must be a(n) paintball employee in order to use this command!"})
    end
end

---------------------------
    -- commands  --
---------------------------
RegisterCommand('paintball', function(source, args, rawCommand)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local cmd = args[1]
    if cmd == "create" and args[2] and args[3] and args[4] then
        createPaintballGame(src, string.upper(args[2]), tonumber(args[3]), tonumber(args[4]))
    elseif cmd == "start" and args[2] then
        startPaintballGame(src, tonumber(args[2]))
    elseif cmd == "kick" and args[2] then
        kickPlayerFromPaintballGame(src, tonumber(args[2]))
    elseif cmd == "end" and args[2] then
        endPaintballGame(src, tonumber(args[2]))
    elseif cmd == "join" and args[2] and args[3] then
        joinPaintballGame(src, tonumber(args[2]), tostring(args[3]))
    elseif cmd == "leave" and args[2] then
        leavePaintballGame(src, tonumber(args[2]))
    elseif cmd == "flagreset" and args[2] then
        paintBallFlagReset(src, tonumber(args[2]))
    end
end)

---------------------------
    -- debug shit  --
---------------------------
if Config.Debug then
    AddEventHandler('onResourceStart', function(resourceName)
        if GetCurrentResourceName() == resourceName and Config.Debug then
            -- paintBallDebug()
        end
        print('The resource ' .. resourceName .. ' has been started.')
    end)

    paintBallDebug = function()
        local gameIdentifier = 69
        currentGamemode = Config.DebugGamemode
        table.insert(paintBallData, {
            [gameIdentifier] = {
                gameActive = false,
                ["red"] = {}, 
                ["blue"] = {},
                maxTeamCap = 1,
                playersInGame = {}, 
                score = {
                    ["red"] = 5,
                    ["blue"] = 5
                },
            }
        })
        Wait(1000)
        TriggerClientEvent('paintball:createGameData', -1, paintBallData, gameIdentifier, currentGamemode)
        if currentGamemode == "CTF" then
            paintBallSpawnFlag()
            CreateThread(function()
                while currentGamemode == "CTF" do
                    Wait(2000)
                    if GlobalState["ctfFlagTaker"] then
                        TriggerClientEvent('paintball:handleFlagSpawn', -1, flagObject)
                    else
                        SetEntityCoords(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), 1718.5, 3243.24, 41.14-1.0)
                        SetEntityHeading(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), 180)
                        FreezeEntityPosition(NetworkGetEntityFromNetworkId(flagObject.flags.networkId), true)
                    end
                end
            end)
        end
    end

    RegisterCommand('serverdata', function(source,args,raw)
        for i = 1, #paintBallData do
            print(json.encode(paintBallData))
        end
    end)

    RegisterCommand('debugdata', function(source,args,user)
        for i = 1, #paintBallData do
            if paintBallData[i] ~= nil then
                for k,v in pairs(paintBallData[i]) do
                    print(k)
                end
            end
        end
    end)

    RegisterCommand('resetbucket', function(source,args,user)
        SetPlayerRoutingBucket(source, 0)
    end)
end
