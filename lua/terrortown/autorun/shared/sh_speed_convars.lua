--ConVar syncing
CreateConVar("ttt2_speedrunner_speed_scale", "3.0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_jump_scale", "2.0", {FCVAR_ARCHIVE, FCVAR_NOTFIY})
CreateConVar("ttt2_speedrunner_fire_rate_scale", "1.5", {FCVAR_ARCHIVE, FCVAR_NOTFIY})

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicSpeedrunnerCVars", function(tbl)
	tbl[ROLE_SPEEDRUNNER] = tbl[ROLE_SPEEDRUNNER] or {}

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
	SetGlobalFloat("ttt2_speedrunner_speed_scale", GetConVar("ttt2_speedrunner_speed_scale"):GetFloat())
	SetGlobalFloat("ttt2_speedrunner_jump_scale", GetConVar("ttt2_speedrunner_jump_scale"):GetFloat())
	SetGlobalFloat("ttt2_speedrunner_fire_rate_scale", GetConVar("ttt2_speedrunner_fire_rate_scale"):GetFloat())
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
