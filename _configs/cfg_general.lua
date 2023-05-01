---------------------------
    -- Configs --
---------------------------
Config = Config or {}

Config.Debug = false
Config.DebugGamemode = "TDM"
Config.PaintballGame = {
    gameModes = {"TDM", "CTF", "SND"},
    gameTime = 500,
    maxTeamCap = 1,
    teleportLocations = {
        ["red"] = {vector4(1722.37, 3245.88, 41.15, 108.28)},
        ["blue"] = {vector4(1713.99, 3244.78, 41.07, 283.59)}
    }
}

Config.PaintballLocations = {
    { x = 1721.13, y = 3320.05, z = 41.22, tracking_minZ = 41.22, tracking_maxZ = 42.82, tracking_length = 2.6, tracking_width = 1.4, tracking_heading = 285, tracking_distance = 2.0, text = "Boss Actions" },
    { x = 1718.6, y = 3315.49, z = 41.22, tracking_minZ = 40.62, tracking_maxZ = 42.22, tracking_length = 1.4, tracking_width = 1.8, tracking_heading = 200, tracking_distance = 2.0, text = "Team Setup" },
    -- { x = 274.96, y = -295.67, z = 54.69, tracking_minZ = 53.08, tracking_maxZ = 55.08, tracking_length = 1.6, tracking_width = 0.8, tracking_heading = 70, tracking_distance = 2.0 },
}
