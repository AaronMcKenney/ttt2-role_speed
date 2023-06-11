if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_speed.vmt")
	util.AddNetworkString("TTT2SpeedrunnerAnnounceSpeedrun")
	util.AddNetworkString("TTT2SpeedrunnerSpawnSmoke")
	util.AddNetworkString("TTT2SpeedrunnerRateOfFireUpdate")
end

roles.InitCustomTeam(ROLE.name, {
	icon = "vgui/ttt/dynamic/roles/icon_speed",
	color = Color(255, 13, 134, 255),
})

function ROLE:PreInitialize()
	self.color = Color(255, 13, 134, 255)
	self.abbr = "speed"

	self.score.teamKillsMultiplier = -16
	self.score.killsMultiplier = 5

	self.preventFindCredits = false

	self.fallbackTable = {}
	self.unknownTeam = false

	self.defaultTeam = TEAM_SPEEDRUNNER
	self.defaultEquipment = SPECIAL_EQUIPMENT

	--The player's role is broadcasted to all other players.
	self.isPublicRole = true

	--Traitor like behavior: Able to see missing in action players as well as the haste mode timer.
	self.isOmniscientRole = true

	-- ULX ConVars
	self.conVarData = {
		pct = 0.13,
		maximum = 1,
		minPlayers = 6,
		random = 30,

		--Speedrunner can use traitor buttons, to handle the case where traitors hide in traitor rooms, preventing the Speedrunner from winning
		--Traitor buttons also give Speedrunner a small edge without opening the pandora's box of traitor shop items
		traitorButton = 1,

		--Despite not having a shop, credits may be needed to open traitor rooms on some maps. Also allows the use of some traitor traps
		credits = 2,
		--creditsAwardDeadEnable = 1,
		--creditsAwardKillEnable = 1,
		shopFallback = SHOP_DISABLED,

		togglable = true
	}
end

--CONSTANTS
--Hardcoded default that everyone uses.
local DEFAULT_JUMP_POWER = 160

local function IsInSpecDM(ply)
	if SpecDM and (ply.IsGhost and ply:IsGhost()) then
		return true
	end

	return false
end

function GetNumAliveUnaffiliatedPlayers(ply)
	local num_players = 0

	for _, ply_i in ipairs(player.GetAll()) do
		if IsValid(ply_i) and ply_i:IsPlayer() and ply_i:GetTeam() ~= ply:GetTeam() and (ply_i:Alive() or ply_i:IsReviving()) and not ply_i:IsSpec() and not IsInSpecDM(ply_i) then
			num_players = num_players + 1
		end
	end

	return num_players
end

if SERVER then
	--Cached server vars
	--Used to handle the sensitive timing wherein a speedrun ends, the speedrunner is killed, and then the speedrunner immediately attempts to revive (which they shouldn't).
	local SPEEDRUN_IN_PROGRESS = false
	local SPEEDRUN_STARTER = nil

	--WeaponSpeed functionality taken and modified from TTT2 Super Soda mod
	local function ApplyWeaponSpeedForSpeedrunner(wep)
		local ply = wep.Owner
		if not IsValid(wep) or not IsValid(ply) then
			return
		end
		
		if (wep.Kind == WEAPON_MELEE or wep.Kind == WEAPON_HEAVY or wep.Kind == WEAPON_PISTOL) then
			
			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG ApplyWeaponSpeedForSpeedrunner Before: ", wep.Primary.Delay)
			
			wep.ttt2_speedrunner_modded = true
			wep.Primary.Delay = wep.Primary.Delay / GetConVar("ttt2_speedrunner_fire_rate_scale"):GetFloat()
			
			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG ApplyWeaponSpeedForSpeedrunner After: ", wep.Primary.Delay)
			
			--Notify client of rate of fire changes.
			net.Start("TTT2SpeedrunnerRateOfFireUpdate")
			net.WriteEntity(wep)
			net.WriteFloat(wep.Primary.Delay)
			net.Send(ply)
		end
	end
	
	local function DisableWeaponSpeedForSpeedrunner(ply, wep)
		if not IsValid(wep) or not IsValid(ply) then
			return
		end
		
		--Only remove speed if the weapon was tinkered with by the Speedrunner.
		--Prevents issue where the weapon may otherwise get stats removed multiple times on player death (Due to Drop and Switch being called).
		if wep.ttt2_speedrunner_modded and (wep.Kind == WEAPON_MELEE or wep.Kind == WEAPON_HEAVY or wep.Kind == WEAPON_PISTOL) then
			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG DisableWeaponSpeedForSpeedrunner Before: ", wep.Primary.Delay)
			
			wep.Primary.Delay = wep.Primary.Delay * GetConVar("ttt2_speedrunner_fire_rate_scale"):GetFloat()

			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG DisableWeaponSpeedForSpeedrunner After: ", wep.Primary.Delay)
			
			net.Start("TTT2SpeedrunnerRateOfFireUpdate")
			net.WriteEntity(wep)
			net.WriteFloat(wep.Primary.Delay)
			net.Send(ply)
			
			wep.ttt2_speedrunner_modded = nil
		end
	end

	local function SpawnSmoke(pos, duration)
		if not GetConVar("ttt2_speedrunner_smoke_enable"):GetBool() then
			return
		end

		for _, ply in ipairs(player.GetAll()) do
			net.Start("TTT2SpeedrunnerSpawnSmoke")
			net.WriteVector(pos)
			if ply:GetSubRole() ~= ROLE_SPEEDRUNNER then
				net.WriteInt(duration, 16)
			else
				net.WriteInt(duration/6, 16)
			end
			net.Send(ply)
		end
	end

	local function AttemptToStartSpeedrun(ply)
		local smoke_duration = 5

		if GetRoundState() == ROUND_POST then
			return
		end

		if not timer.Exists("TTT2SpeedrunnerSpeedrun_Server") then
			run_length = GetConVar("ttt2_speedrunner_time_base"):GetInt() + GetNumAliveUnaffiliatedPlayers(ply) * GetConVar("ttt2_speedrunner_time_per_player"):GetInt()
			timer.Create("TTT2SpeedrunnerSpeedrun_Server", run_length, 1, function()
				SPEEDRUN_IN_PROGRESS = false

				if GetRoundState() ~= ROUND_ACTIVE then
					return
				end

				events.Trigger(EVENT_SPEED_FAILED_RUN, ply, SPEEDRUN_STARTER)
				SPEEDRUN_STARTER = nil

				net.Start("TTT2SpeedrunnerAnnounceSpeedrun")
				net.WriteInt(-1, 16)
				net.Broadcast()

				--If the speedrun has failed, kill all Speedrunners
				for _, ply_i in ipairs(player.GetAll()) do
					if IsValid(ply_i) and ply_i:IsPlayer() and ply_i:Alive() and not ply_i:IsSpec() and not IsInSpecDM(ply_i) and ply_i:GetSubRole() == ROLE_SPEEDRUNNER then
						ply_i:Kill()
					end
				end
			end)

			SPEEDRUN_IN_PROGRESS = true
			SPEEDRUN_STARTER = ply
			if GetRoundState() ~= ROUND_BEGIN then
				--For whatever reason events can't trigger until some point after roles are assigned. So this event only triggers if someone triggers a speedrun mid-game
				events.Trigger(EVENT_SPEED_START_RUN, ply, run_length)
			end
			smoke_duration = 10
		end

		net.Start("TTT2SpeedrunnerAnnounceSpeedrun")
		net.WriteInt(timer.TimeLeft("TTT2SpeedrunnerSpeedrun_Server"), 16)
		net.Broadcast()

		SpawnSmoke(ply:GetPos(), smoke_duration)

		return
	end

	local function AttemptToStopSpeedrun()
		--If there are no alive speedrunners left, can safely stop the speedrun and mark it as a failure
		if timer.Exists("TTT2SpeedrunnerSpeedrun_Server") then
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and ply:IsPlayer() and ply:GetSubRole() == ROLE_SPEEDRUNNER and (ply:Alive() or ply:IsReviving()) and not ply:IsSpec() and not IsInSpecDM(ply) then
					return
				end
			end

			timer.Remove("TTT2SpeedrunnerSpeedrun_Server")
			SPEEDRUN_IN_PROGRESS = false
			events.Trigger(EVENT_SPEED_ABORTED_RUN, SPEEDRUN_STARTER)
			SPEEDRUN_STARTER = nil
		end

		return
	end

	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		if IsInSpecDM(ply) then
			return
		end

		--More complicated method for setting jump power, which works if other jump modifying effects occur. Downside is that all addons would need to use this method, so...
		ply:SetJumpPower(ply:GetJumpPower() + DEFAULT_JUMP_POWER * (GetConVar("ttt2_speedrunner_jump_scale"):GetFloat() - 1.0))
		--Simpler method would be:
		--ply:SetJumpPower(DEFAULT_JUMP_POWER * GetConVar("ttt2_speedrunner_jump_scale"):GetFloat())
		if ply:GetJumpPower() > DEFAULT_JUMP_POWER then
			ply:GiveEquipmentItem("item_ttt_nofalldmg")
		end

		ApplyWeaponSpeedForSpeedrunner(ply:GetActiveWeapon())

		ply:GiveEquipmentItem("item_ttt_radar")

		AttemptToStartSpeedrun(ply)
	end

	function ROLE:RemoveRoleLoadout(ply, isRoleChange)
		DisableWeaponSpeedForSpeedrunner(ply, ply:GetActiveWeapon())

		if IsInSpecDM(ply) then
			return
		end

		--More complicated method for setting jump power, which works if other jump modifying effects occur. Downside is that all addons would need to use this method, so...
		ply:SetJumpPower(ply:GetJumpPower() - DEFAULT_JUMP_POWER * (GetConVar("ttt2_speedrunner_jump_scale"):GetFloat() - 1.0))
		--Simpler method would be:
		--ply:SetJumpPower(DEFAULT_JUMP_POWER)
		ply:RemoveEquipmentItem("item_ttt_nofalldmg")

		ply:RemoveEquipmentItem("item_ttt_radar")
	end

	--Technically this is called in both the Server and the Client. We can get away with only adding the hook in the server, as the server hook sends TTT2SpeedrunnerRateOfFireUpdate net packets to the client with the updated information.
	hook.Add("PlayerSwitchWeapon", "PlayerSwitchWeaponSpeedrunner", function(ply, old, new)
		DisableWeaponSpeedForSpeedrunner(ply, old)

		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(old) or not IsValid(new) or ply:GetSubRole() ~= ROLE_SPEEDRUNNER or IsInSpecDM(ply) then
			return
		end

		ApplyWeaponSpeedForSpeedrunner(new)
	end)

	hook.Add("PlayerDroppedWeapon", "PlayerDroppedWeaponSpeedrunner", function(ply, wep)
		DisableWeaponSpeedForSpeedrunner(ply, wep)

		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(wep) or ply:GetSubRole() ~= ROLE_SPEEDRUNNER or IsInSpecDM(ply) then
			return
		end
	end)

	hook.Add("TTT2UpdateSubrole", "TTT2UpdateSubroleSpeedrunner", function(self, oldSubrole, subrole)
		--Prematurely stop the speedrun if the only speedrunner changed roles
		if oldSubrole == ROLE_SPEEDRUNNER then
			AttemptToStopSpeedrun()
		end
	end)

	hook.Add("PlayerDisconnected", "PlayerDisconnectedSpeedrunner", function(ply)
		--Prematurely stop the speedrun if the only speedrunner disconnected
		if ply:GetSubRole() == ROLE_SPEEDRUNNER then
			AttemptToStopSpeedrun()
		end
	end)

	hook.Add("TTT2PostPlayerDeath", "TTT2PostPlayerDeathSpeedrunner", function(victim, inflictor, attacker)
		--Note: "victim" is considered dead at this point.
		if not IsValid(victim) or not victim:IsPlayer() or IsInSpecDM(victim) or victim:GetSubRole() ~= ROLE_SPEEDRUNNER or not SPEEDRUN_IN_PROGRESS then
			return
		end

		--If the speedrun is still going on, remove the player's corpse in a puff of smoke and respawn the player with some time penalty
		corpse = victim:FindCorpse()
		if corpse then
			SpawnSmoke(corpse:GetPos(), 5)
			corpse:Remove()
		end

		victim:Revive(GetConVar("ttt2_speedrunner_respawn_time"):GetInt(), --Delay
			function(ply) --OnRevive function
				SpawnSmoke(ply:GetPos(), 5)
			end,
			function(ply) --DoCheck function
				--Return false (do not go through with the revival) if doing so could cause issues
				--Here that means: Do not revive if the speedrun failed while the speedrunner was reviving.
				return GetRoundState() == ROUND_ACTIVE and (not ply:Alive() or IsInSpecDM(ply)) and SPEEDRUN_IN_PROGRESS
			end,
			false, --needsCorpse
			REVIVAL_BLOCK_AS_ALIVE, --blocksRound (Prevents anyone from winning during respawn delay)
			nil, --OnFail function
			nil, --The player's respawn point (If nil, will be their corpse if present, and their point of death otherwise)
			nil --spawnEyeAngle (Used to handle where the player is looking upon respawn)
		)
	end)

	hook.Add("TTTBeginRound", "TTTBeginRoundSpeedrunner", function()
		--For whatever reason events can't trigger until some point after roles are assigned. So this event only triggers a bit after that, and only if there's a speedrunner at the start.
		if SPEEDRUN_IN_PROGRESS and SPEEDRUN_STARTER then
			print("BMF CALLING TTTBeginRoundSpeedrunner")
			run_length = GetConVar("ttt2_speedrunner_time_base"):GetInt() + GetNumAliveUnaffiliatedPlayers(SPEEDRUN_STARTER) * GetConVar("ttt2_speedrunner_time_per_player"):GetInt()
			events.Trigger(EVENT_SPEED_START_RUN, SPEEDRUN_STARTER, run_length)
		end
	end)

	local function ResetSpeedrunnerDataForServer()
		SPEEDRUN_IN_PROGRESS = false
		SPEEDRUN_STARTER = nil
		if timer.Exists("TTT2SpeedrunnerSpeedrun_Server") then
			timer.Remove("TTT2SpeedrunnerSpeedrun_Server")
		end
	end
	hook.Add("TTTPrepareRound", "TTTPrepareRoundSeanceForServer", ResetSpeedrunnerDataForServer)
	hook.Add("TTTEndRound", "TTTEndRoundSeanceForServer", ResetSpeedrunnerDataForServer)
end

if CLIENT then
	local material_speedrunner = Material("vgui/ttt/dynamic/roles/icon_speed.vmt")
	local smokeparticles = {
		Model("particle/particle_smokegrenade"),
		Model("particle/particle_noisesphere")
	}

	net.Receive("TTT2SpeedrunnerRateOfFireUpdate", function()
		local wep = net.ReadEntity()
		if wep and wep.Primary then
			wep.Primary.Delay = net.ReadFloat()
		end
	end)

	net.Receive("TTT2SpeedrunnerSpawnSmoke", function()
		local client = LocalPlayer()
		local pos = net.ReadVector()
		local smoke_duration = net.ReadInt(16)

		--Following code was used from the TTT2 Pharaoh&Graverobber role
		-- smoke spawn code by Alf21
		local em = ParticleEmitter(pos)
		local r = 1.5 * 64

		for i = 1, 75 do
			local prpos = VectorRand() * r
			prpos.z = prpos.z + 332
			prpos.z = math.min(prpos.z, 52)

			local p = em:Add(table.Random(smokeparticles), pos + prpos)
			if p then
				local gray = math.random(125, 255)
				p:SetColor(gray, gray, gray)
				p:SetStartAlpha(200)
				p:SetEndAlpha(0)
				p:SetVelocity(VectorRand() * math.Rand(900, 1300))
				p:SetLifeTime(0)

				p:SetDieTime(smoke_duration)

				p:SetStartSize(math.random(140, 150))
				p:SetEndSize(math.random(1, 40))
				p:SetRoll(math.random(-180, 180))
				p:SetRollDelta(math.Rand(-0.1, 0.1))
				p:SetAirResistance(600)

				p:SetCollide(true)
				p:SetBounce(0.4)

				p:SetLighting(false)
			end
		end

		em:Finish()
	end)

	net.Receive("TTT2SpeedrunnerAnnounceSpeedrun", function()
		client = LocalPlayer()
		time_left = net.ReadInt(16)

		if time_left < 0 then
			client.ttt2_speedrunner_run_end_time = -1
			--After 5 seconds, remove the info box, since the dead player no longer needs to look at it.
			client.ttt2_speedrunner_display_end_time = CurTime() + 5
		else
			client.ttt2_speedrunner_run_end_time = CurTime() + time_left
			client.ttt2_speedrunner_display_end_time = nil
		end
	end)

	--Global function so everyone can know how much time is left
	function TTT2SpeedrunnerTimeLeftStr()
		local client = LocalPlayer()
		local bg_color = COLOR_WHITE
		local time_left_str = "0:00:00"
		local cur_time = CurTime()

		if client.ttt2_speedrunner_run_end_time and client.ttt2_speedrunner_run_end_time > cur_time then
			time_left = client.ttt2_speedrunner_run_end_time - cur_time

			minutes_left = math.floor(time_left / 60)
			minutes_left_str = tostring(minutes_left)

			seconds_left = time_left - minutes_left * 60
			seconds_left_whole_num = math.floor(seconds_left)
			seconds_left_whole_num_str = string.format("%02d", seconds_left_whole_num)
			seconds_left_fract = seconds_left - seconds_left_whole_num
			seconds_left_fract_str = string.format("%02d", math.floor(seconds_left_fract * 100))

			time_left_str = minutes_left_str .. ":" .. seconds_left_whole_num_str .. ":" .. seconds_left_fract_str
		end

		return time_left_str
	end

	hook.Add("TTTRenderEntityInfo", "TTTRenderEntityInfoSpeedrunner", function(tData)
		local client = LocalPlayer()
		local ply = tData:GetEntity()

		if not ply:IsPlayer() or ply:GetSubRole() ~= ROLE_SPEEDRUNNER or not client.ttt2_speedrunner_run_end_time or client.ttt2_speedrunner_run_end_time < 0 then
			return
		end

		tData:AddDescriptionLine(
			TTT2SpeedrunnerTimeLeftStr(),
			COLOR_RED
		)
	end)

	local function ResetSpeedrunnerDataForClient()
		client = LocalPlayer()
		client.ttt2_speedrunner_run_end_time = nil
		client.ttt2_speedrunner_display_end_time = nil
	end
	hook.Add("TTTPrepareRound", "TTTPrepareRoundSeanceForClient", ResetSpeedrunnerDataForClient)
	hook.Add("TTTEndRound", "TTTEndRoundSeanceForClient", ResetSpeedrunnerDataForClient)
end

hook.Add("TTTPlayerSpeedModifier", "TTTPlayerSpeedModifierSpeedrunner", function(ply, _, _, no_lag)
	if ply:GetSubRole() == ROLE_SPEEDRUNNER then
		no_lag[1] = no_lag[1] * GetConVar("ttt2_speedrunner_speed_scale"):GetFloat()
	end
end)
