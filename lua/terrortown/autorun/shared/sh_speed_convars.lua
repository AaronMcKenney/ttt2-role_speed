--ConVar syncing
CreateConVar("ttt2_speedrunner_time_base", "105", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_time_per_player", "15", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_respawn_time", "15", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_smoke_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_rainbow_enable", "1", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_speed_scale", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_jump_scale", "2.0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_fire_rate_scale", "1.5", {FCVAR_ARCHIVE, FCVAR_NOTFIY})

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicSpeedrunnerCVars", function(tbl)
	tbl[ROLE_SPEEDRUNNER] = tbl[ROLE_SPEEDRUNNER] or {}

	--# The number of seconds that the speedrunner has to win the game is based on the following formula:
	--  ttt2_speedrunner_time_base + n * ttt2_speedrunner_time_per_player
	--  Where n is the number of players who are currently alive and aren't currently on your team.
	--  ttt2_speedrunner_time_base [0..n] (default: 105)
	--  ttt2_speedrunner_time_per_player [0..n] (default: 15)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_time_base",
		slider = true,
		min = 0,
		max = 360,
		decimal = 0,
		desc = "ttt2_speedrunner_time_base (Def: 105)"
	})
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_time_per_player",
		slider = true,
		min = 0,
		max = 90,
		decimal = 0,
		desc = "ttt2_speedrunner_time_per_player (Def: 15)"
	})

	--# Respawn time in seconds (Disabled if 0). Speedrunner will not respawn if they failed the speedrun.
	--  ttt2_speedrunner_respawn_time [0..n] (default: 15)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_respawn_time",
		slider = true,
		min = 0,
		max = 30,
		decimal = 0,
		desc = "ttt2_speedrunner_respawn_time (Def: 15)"
	})

	--# Should the opposition see a bunch of smoke when the Speedrunner spawns/dies/revives?
	--  ttt2_speedrunner_smoke_enable [0/1] (default: 1)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_smoke_enable",
		checkbox = true,
		desc = "ttt2_speedrunner_smoke_enable (Def: 1)"
	})

	--# Should the Speedrunner's role and team icon have a rainbow effect?
	--  ttt2_speedrunner_rainbow_enable [0/1] (default: 1)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_rainbow_enable",
		checkbox = true,
		desc = "ttt2_speedrunner_rainbow_enable (Def: 1)"
	})

	--# Multiplier for the Speedrunner's move speed
	--  ttt2_speedrunner_speed_scale [1.0..n.m] (default: 3.0)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_speed_scale",
		slider = true,
		min = 1.0,
		max = 5.0,
		decimal = 2,
		desc = "ttt2_speedrunner_speed_scale (Def: 3.0)"
	})

	--# Multiplier for the Speedrunner's jump height
	--  ttt2_speedrunner_jump_scale [1.0..n.m] (default: 2.0)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_jump_scale",
		slider = true,
		min = 1.0,
		max = 5.0,
		decimal = 2,
		desc = "ttt2_speedrunner_jump_scale (Def: 2.0)"
	})

	--# Multiplier for the Speedrunner's fire rate
	--  ttt2_speedrunner_fire_rate_scale [1.0..n.m] (default: 1.5)
	table.insert(tbl[ROLE_SPEEDRUNNER], {
		cvar = "ttt2_speedrunner_fire_rate_scale",
		slider = true,
		min = 1.0,
		max = 5.0,
		decimal = 2,
		desc = "ttt2_speedrunner_fire_rate_scale (Def: 1.5)"
	})
end)

hook.Add("TTT2SyncGlobals", "AddSpeedrunnerGlobals", function()
	SetGlobalInt("ttt2_speedrunner_time_base", GetConVar("ttt2_speedrunner_time_base"):GetInt())
	SetGlobalInt("ttt2_speedrunner_time_per_player", GetConVar("ttt2_speedrunner_time_per_player"):GetInt())
	SetGlobalInt("ttt2_speedrunner_respawn_time", GetConVar("ttt2_speedrunner_respawn_time"):GetInt())
	SetGlobalBool("ttt2_speedrunner_smoke_enable", GetConVar("ttt2_speedrunner_smoke_enable"):GetBool())
	SetGlobalBool("ttt2_speedrunner_rainbow_enable", GetConVar("ttt2_speedrunner_rainbow_enable"):GetBool())
	SetGlobalFloat("ttt2_speedrunner_speed_scale", GetConVar("ttt2_speedrunner_speed_scale"):GetFloat())
	SetGlobalFloat("ttt2_speedrunner_jump_scale", GetConVar("ttt2_speedrunner_jump_scale"):GetFloat())
	SetGlobalFloat("ttt2_speedrunner_fire_rate_scale", GetConVar("ttt2_speedrunner_fire_rate_scale"):GetFloat())
end)

cvars.AddChangeCallback("ttt2_speedrunner_time_base", function(name, old, new)
	SetGlobalInt("ttt2_speedrunner_time_base", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_speedrunner_time_per_player", function(name, old, new)
	SetGlobalInt("ttt2_speedrunner_time_per_player", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_speedrunner_respawn_time", function(name, old, new)
	SetGlobalInt("ttt2_speedrunner_respawn_time", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_speedrunner_smoke_enable", function(name, old, new)
	SetGlobalBool("ttt2_speedrunner_smoke_enable", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_speedrunner_rainbow_enable", function(name, old, new)
	SetGlobalBool("ttt2_speedrunner_rainbow_enable", tobool(tonumber(new)))
end)
cvars.AddChangeCallback("ttt2_speedrunner_speed_scale", function(name, old, new)
	SetGlobalFloat("ttt2_speedrunner_speed_scale", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_speedrunner_jump_scale", function(name, old, new)
	SetGlobalFloat("ttt2_speedrunner_jump_scale", tonumber(new))
end)
cvars.AddChangeCallback("ttt2_speedrunner_fire_rate_scale", function(name, old, new)
	SetGlobalFloat("ttt2_speedrunner_fire_rate_scale", tonumber(new))
end)
