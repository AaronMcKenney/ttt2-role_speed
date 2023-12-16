if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_speed.vmt")
	util.AddNetworkString("TTT2SpeedrunnerTimeLeft")
	util.AddNetworkString("TTT2SpeedrunnerNumLeft")
	util.AddNetworkString("TTT2SpeedrunnerSpawnSmoke")
	util.AddNetworkString("TTT2SpeedrunnerRateOfFireUpdate")
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
		random = 15,

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

	if CLIENT then
		self.h_ori, self.s_ori, self.v_ori = ColorToHSV(roles.SPEEDRUNNER.color)
		self.h_cur = self.h_ori
		if GetConVar("ttt2_speedrunner_rainbow_enable"):GetBool() then

			--Modified from Pharoah's Ankh.
			function SpeedrunnerDynamicLight(ply, color, brightness)
				-- make sure initial values are set
				if not ply.speed_light_next_state then
					ply.speed_light_next_state = CurTime()
				end

				--Create dynamic light
				local dlight = DynamicLight(ply:EntIndex())
				dlight.r = color.r
				dlight.g = color.g
				dlight.b = color.b
				dlight.brightness = brightness
				dlight.Decay = 1000
				dlight.Size = 200
				dlight.DieTime = CurTime() + 0.1
				dlight.Pos = ply:GetPos() + Vector(0, 0, 35)
			end

			hook.Add("Think", "ThinkTTT2Speedrunner", function()
				--We cache the HSV color here, as the conversion between RGB and HSV is lossy, leading to unwanted color changes
				self.h_cur = self.h_cur + 0.2
				if self.h_cur > 359 then
					self.h_cur = self.h_cur - 360
				end

				self.color = HSVToColor(self.h_cur, self.s_ori, self.v_ori)

				--TTT2 code alters the icon from white to black if the sum of the R,G, and B components is 500 or more.
				--Not sure why 500 was chosen, but we'll need to aim below that lest our icon alternate between black and white.
				--Note: It was determined experimentally that the color spectrum we use is almost always under 500 except during a few dozen frames when we near yellow, cyan, and magenta
				--  Explicitly, it never went higher than 522. But it can be as low as 276.
				--  All in all, the change here to keep the total under 500 should be fairly unnoticeable.
				local rgb_total = self.color.r + self.color.g + self.color.b
				if rgb_total >= 500 then
					local rgb_diff = math.ceil((rgb_total - 499)/3)
					self.color.r = self.color.r - rgb_diff
					self.color.g = self.color.g - rgb_diff
					self.color.b = self.color.b - rgb_diff
				end

				self.dkcolor = util.ColorDarken(self.color, 30)
				self.ltcolor = util.ColorLighten(self.color, 30)
				self.bgcolor = util.ColorComplementary(self.color)

				--Update TEAM_SPEEDRUNNER's color
				TEAMS["speedrunners"].color = self.color
				--Update every Speedrunner's role color (for some reason all players can have their own color. It is odd.
				for _, ply in ipairs(player.GetAll()) do
					if ply:GetSubRole() == ROLE_SPEEDRUNNER then
						ply:SetRoleColor(self.color)
						ply:SetRoleDkColor(self.dkcolor)
						ply:SetRoleLtColor(self.ltcolor)
						ply:SetRoleBgColor(self.bgcolor)
						if ply:Alive() and not IsInSpecDM(ply) then
							SpeedrunnerDynamicLight(ply, self.color, 1)
						end
					end
				end
			end)
		end
	end
end

if SERVER then
	--Cached server vars
	--Used to handle the sensitive timing wherein a speedrun ends, the speedrunner is killed, and then the speedrunner immediately attempts to revive (which they shouldn't).
	local SPEEDRUN_IN_PROGRESS = false
	local SPEEDRUN_STARTER = nil

	local function GetNumAliveUnaffiliatedPlayers(ply)
		local num_players = 0

		for _, ply_i in ipairs(player.GetAll()) do
			if IsValid(ply_i) and ply_i:IsPlayer() and ply_i:GetTeam() ~= ply:GetTeam() and ply_i:GetTeam() ~= TEAM_NONE and not ply_i:GetSubRoleData().preventWin and (ply_i:Alive() or ply_i:IsReviving()) and not ply_i:IsSpec() and not IsInSpecDM(ply_i) then
				num_players = num_players + 1
			end
		end

		return num_players
	end

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

	local function SendNumPlayersLeft(ply)
		net.Start("TTT2SpeedrunnerNumLeft")
		net.WriteInt(GetNumAliveUnaffiliatedPlayers(ply), 16)
		net.Send(ply)
	end

	local function BroadcastNumPlayersLeft()
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_SPEEDRUNNER then
				SendNumPlayersLeft(ply)
			end
		end
	end

	local function SpawnSmoke(spawner_id, pos, duration)
		if not GetConVar("ttt2_speedrunner_smoke_enable"):GetBool() then
			return
		end

		for _, ply in ipairs(player.GetAll()) do
			local smoke_alpha = 100
			if ply:SteamID64() == spawner_id then
				smoke_alpha = smoke_alpha / 5
			end

			net.Start("TTT2SpeedrunnerSpawnSmoke")
			net.WriteVector(pos)
			net.WriteInt(duration, 16)
			net.WriteInt(smoke_alpha, 16)
			net.Send(ply)
		end
	end

	local function AttemptToStartSpeedrun(ply)
		local smoke_duration = 5

		if GetRoundState() == ROUND_POST then
			return
		end

		if not SPEEDRUN_IN_PROGRESS or not timer.Exists("TTT2SpeedrunnerSpeedrun_Server") then
			run_length = GetConVar("ttt2_speedrunner_time_base"):GetInt() + GetNumAliveUnaffiliatedPlayers(ply) * GetConVar("ttt2_speedrunner_time_per_player"):GetInt()
			timer.Create("TTT2SpeedrunnerSpeedrun_Server", run_length, 1, function()
				SPEEDRUN_IN_PROGRESS = false

				if GetRoundState() ~= ROUND_ACTIVE then
					return
				end

				events.Trigger(EVENT_SPEED_FAILED_RUN, ply, SPEEDRUN_STARTER)
				SPEEDRUN_STARTER = nil

				net.Start("TTT2SpeedrunnerTimeLeft")
				net.WriteInt(-1, 16)
				net.Broadcast()

				--If the speedrun has failed, kill all Speedrunners
				for _, ply_i in ipairs(player.GetAll()) do
					if IsValid(ply_i) and ply_i:IsPlayer() and ply_i:Alive() and not ply_i:IsSpec() and not IsInSpecDM(ply_i) and ply_i:GetSubRole() == ROLE_SPEEDRUNNER then
						ply_i:Kill()
					end
				end
			end)

			BroadcastNumPlayersLeft()
			SPEEDRUN_IN_PROGRESS = true
			SPEEDRUN_STARTER = ply
			events.Trigger(EVENT_SPEED_START_RUN, SPEEDRUN_STARTER, run_length)
		end

		net.Start("TTT2SpeedrunnerTimeLeft")
		net.WriteInt(timer.TimeLeft("TTT2SpeedrunnerSpeedrun_Server"), 16)
		net.Broadcast()

		SpawnSmoke(ply:SteamID64(), ply:GetPos(), smoke_duration)

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

			--Tell clients who were formerly Speedrunners that the speedrun has been stopped.
			net.Start("TTT2SpeedrunnerTimeLeft")
			net.WriteInt(-1, 16)
			net.Broadcast()
		end

		return
	end

	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		if IsInSpecDM(ply) then
			return
		end

		--More complicated method for setting jump power, which works if other jump modifying effects occur. Downside is that all addons would need to use this method, so...
		--Complex version seems to be bugged. Jump is not reset properly if Speedrunner loses and the game ends naturally (explicitly: In the following game the player can't jump at all)
		--ply:SetJumpPower(ply:GetJumpPower() + DEFAULT_JUMP_POWER * (GetConVar("ttt2_speedrunner_jump_scale"):GetFloat() - 1.0))
		--Simpler method:
		ply:SetJumpPower(DEFAULT_JUMP_POWER * GetConVar("ttt2_speedrunner_jump_scale"):GetFloat())
		if ply:GetJumpPower() > DEFAULT_JUMP_POWER then
			ply:GiveEquipmentItem("item_ttt_nofalldmg")
		end

		ApplyWeaponSpeedForSpeedrunner(ply:GetActiveWeapon())

		if GetRoundState() ~= ROUND_ACTIVE then
			--Since not all roles have been allocated, the radar will show almost all players as belonging to TEAM_NONE. so delay by some arbitrary time as a hack.
			timer.Simple(2, function()
				ply:GiveEquipmentItem("item_ttt_radar")
			end)
		else
			--The player has gotten this role mid-game. Attempt to start a speedrun in case it isn't already going on
			AttemptToStartSpeedrun(ply)
			ply:GiveEquipmentItem("item_ttt_radar")
		end

		--Don't attempt to start a speedrun here because not everyone has received their roles yet, which could impact the run length.
		--Do send the number of players left, just in case this is happening mid-game
		SendNumPlayersLeft(ply)
	end

	function ROLE:RemoveRoleLoadout(ply, isRoleChange)
		DisableWeaponSpeedForSpeedrunner(ply, ply:GetActiveWeapon())

		if IsInSpecDM(ply) then
			return
		end

		--More complicated method for setting jump power, which works if other jump modifying effects occur. Downside is that all addons would need to use this method, so...
		--Complex version seems to be bugged. Jump is not reset properly if Speedrunner loses and the game ends naturally (explicitly: In the following game the player can't jump at all)
		--ply:SetJumpPower(ply:GetJumpPower() - DEFAULT_JUMP_POWER * (GetConVar("ttt2_speedrunner_jump_scale"):GetFloat() - 1.0))
		--Simpler method would be:
		ply:SetJumpPower(DEFAULT_JUMP_POWER)
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

	hook.Add("PlayerSpawn", "PlayerSpawnSpeedrunner", function(ply)
		BroadcastNumPlayersLeft()
	end)

	hook.Add("TTT2UpdateSubrole", "TTT2UpdateSubroleSpeedrunner", function(self, oldSubrole, subrole)
		--Prematurely stop the speedrun if the only speedrunner changed roles
		if oldSubrole == ROLE_SPEEDRUNNER then
			AttemptToStopSpeedrun()
		end

		BroadcastNumPlayersLeft()
	end)

	hook.Add("TTT2UpdateTeam", "TTT2UpdateTeamSpeedrunner", function(ply, oldTeam, newTeam)
		--Do not attempt to stop the speedrun if the Speedrunner changed teams.
		--The speedrun will continue with no changes in time left.
		--This leads to a highly unlikely but interesting scenario wherein two speedrunners exist on two different teams who share the same speedrun timer.
		--  In such a scenario, they must compete with eachother to end the game and win before the other.
		BroadcastNumPlayersLeft()
	end)

	hook.Add("PlayerDisconnected", "PlayerDisconnectedSpeedrunner", function(ply)
		--Prematurely stop the speedrun if the only speedrunner disconnected
		if ply:GetSubRole() == ROLE_SPEEDRUNNER then
			AttemptToStopSpeedrun()
		end

		BroadcastNumPlayersLeft()
	end)

	hook.Add("TTT2PostPlayerDeath", "TTT2PostPlayerDeathSpeedrunner", function(victim, inflictor, attacker)
		local time_penalty = GetConVar("ttt2_speedrunner_time_penalty"):GetInt()
		local time_reward = GetConVar("ttt2_speedrunner_time_reward"):GetInt()
		local timer_exists = timer.Exists("TTT2SpeedrunnerSpeedrun_Server")
		BroadcastNumPlayersLeft()

		--Note: "victim" is considered dead at this point.
		if not SPEEDRUN_IN_PROGRESS or not IsValid(victim) or not victim:IsPlayer() or IsInSpecDM(victim) then
			return
		end

		if victim:GetSubRole() == ROLE_SPEEDRUNNER and timer_exists and time_penalty > 0 then
			local time_left = timer.TimeLeft("TTT2SpeedrunnerSpeedrun_Server")
			if time_left - time_penalty <= 0 then
				AttemptToStopSpeedrun()
				return
			end
			timer.Adjust("TTT2SpeedrunnerSpeedrun_Server", time_left - time_penalty)

			net.Start("TTT2SpeedrunnerTimeLeft")
			net.WriteInt(timer.TimeLeft("TTT2SpeedrunnerSpeedrun_Server"), 16)
			net.Broadcast()
		end

		if IsValid(attacker) and attacker:IsPlayer() and not IsInSpecDM(attacker) and attacker:GetSubRole() == ROLE_SPEEDRUNNER and victim:GetTeam() ~= attacker:GetTeam() and timer_exists and time_reward > 0 then
			timer.Adjust("TTT2SpeedrunnerSpeedrun_Server", timer.TimeLeft("TTT2SpeedrunnerSpeedrun_Server") + time_reward)
			net.Start("TTT2SpeedrunnerTimeLeft")
			net.WriteInt(timer.TimeLeft("TTT2SpeedrunnerSpeedrun_Server"), 16)
			net.Broadcast()
		end

		--Now that we've handled time penalty/reward, only handle logic pertaining to the victim being a speedrunner from here on out.
		if victim:GetSubRole() ~= ROLE_SPEEDRUNNER then
			return
		end

		--Extremely unlikely scenario: Two speedrunners on different teams are trying to win. They are all that remains.
		--In this scenario, ordinarily they would be unable to permanently kill the other due to sharing the same speedrun timer.
		--At the end, both would die when the timer stops and it would be a tie.
		--To make things more fun for the players in this scenario, simply prevent the revival from occurring if the speedrunner is killed by an opposing speedrunner.
		if IsValid(attacker) and attacker:IsPlayer() and attacker:GetSubRole() == ROLE_SPEEDRUNNER and attacker:GetTeam() ~= victim:GetTeam() then
			--Don't remove body. It would be funny if someone revives this person.
			--Furthermore, this prevents prolonging the timer by the two opposing speedrunners killing eachother repeatedly.
			--In addition, if we hit this condition both time penalty and reward will proc. Speedrunners are penalized for dying, but are rewarded for killing someone on a different team.
			return
		end

		--If the speedrun is still going on, remove the player's corpse in a puff of smoke and respawn the player after some time has passed
		corpse = victim:FindCorpse()
		if corpse then
			SpawnSmoke(victim:SteamID64(), corpse:GetPos(), 3)
			corpse:Remove()
		end

		victim:Revive(GetConVar("ttt2_speedrunner_respawn_time"):GetInt(), --Delay
			function(ply) --OnRevive function
				SpawnSmoke(ply:SteamID64(), ply:GetPos(), 3)
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

	hook.Add("TTT2SpecialRoleSyncing", "TTT2SpecialRoleSyncingSpeedrunner", function(ply, tbl)
		--Speedrunner should know the roles of everyone who doesn't need to be killed to end the game.
		--Reason for this is straightforward: Not knowing this disrupts the client UI for displaying the actual number of players needed to be killed
		--In addition, many of the roles with "preventWin" need to get rid of their role, which can lead to speedruns that end quickly and anticlimatically (ex. Cursed, Jester, Swapper)
		if GetRoundState() == ROUND_POST or not IsValid(ply) or ply:GetSubRole() ~= ROLE_SPEEDRUNNER then
			return
		end

		for ply_i in pairs(tbl) do
			if ply_i:GetTeam() == TEAM_NONE or ply_i:GetSubRoleData().preventWin then
				tbl[ply_i] = {ply_i:GetSubRole(), ply_i:GetTeam()}
			end
		end
	end)

	hook.Add("TTT2ModifyRadarRole", "TTT2ModifyRadarRoleSpeedrunner", function(ply, target)
		--Same logic as used in TTT2SpecialRoleSyncing hook
		if GetRoundState() == ROUND_POST or not IsValid(ply) or ply:GetSubRole() ~= ROLE_SPEEDRUNNER then
			return
		end

		if target:GetTeam() == TEAM_NONE or target:GetSubRoleData().preventWin then
			return target:GetSubRole(), target:GetTeam()
		end
	end)

	hook.Add("TTTBeginRound", "TTTBeginRoundSpeedrunner", function()
		--Starting a speedrun upon GiveRoleLoadout is likely to not take in consideration the roles that other players have yet to be assigned.
		--In addition, for whatever reason events can't trigger until some point after roles are assigned.
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_SPEEDRUNNER then
				AttemptToStartSpeedrun(ply)
			end

			if SPEEDRUN_IN_PROGRESS then
				break
			end
		end
	end)

	local function ResetSpeedrunnerDataForServer()
		SPEEDRUN_IN_PROGRESS = false
		SPEEDRUN_STARTER = nil
		if timer.Exists("TTT2SpeedrunnerSpeedrun_Server") then
			timer.Remove("TTT2SpeedrunnerSpeedrun_Server")
		end
		
		--Done for sanity. If jump power isn't reset properly then it will carry over to subsequent rounds, destroying the user's experience.
		for _, ply in ipairs(player.GetAll()) do
			if ply:GetSubRole() == ROLE_SPEEDRUNNER then
				ply:SetJumpPower(DEFAULT_JUMP_POWER)
			end
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
		local smoke_alpha = net.ReadInt(16)

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
				p:SetStartAlpha(smoke_alpha)
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

	net.Receive("TTT2SpeedrunnerTimeLeft", function()
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

	net.Receive("TTT2SpeedrunnerNumLeft", function()
		local client = LocalPlayer()
		client.ttt2_speedrunner_num_left = net.ReadInt(16)
	end)

	--Global function so everyone can know how much time is left
	function TTT2SpeedrunnerTimeLeftStr()
		local client = LocalPlayer()
		local bg_color = COLOR_WHITE
		local time_left_str = "0:00:00"
		local cur_time = CurTime()

		if client.ttt2_speedrunner_run_end_time and client.ttt2_speedrunner_run_end_time > cur_time then
			local time_left = client.ttt2_speedrunner_run_end_time - cur_time

			local minutes_left = math.floor(time_left / 60)
			local minutes_left_str = tostring(minutes_left)

			local seconds_left = time_left - minutes_left * 60
			local seconds_left_whole_num = math.floor(seconds_left)
			local seconds_left_whole_num_str = string.format("%02d", seconds_left_whole_num)
			local seconds_left_fract = seconds_left - seconds_left_whole_num
			local seconds_left_fract_str = string.format("%02d", math.floor(seconds_left_fract * 100))

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
		client.ttt2_speedrunner_num_left = nil
	end
	hook.Add("TTTPrepareRound", "TTTPrepareRoundSeanceForClient", ResetSpeedrunnerDataForClient)
	hook.Add("TTTEndRound", "TTTEndRoundSeanceForClient", ResetSpeedrunnerDataForClient)

	-------------
	-- CONVARS --
	-------------
	function ROLE:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_roles_additional")

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_time_base",
			label = "label_speedrunner_time_base",
			min = 0,
			max = 360,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_time_per_player",
			label = "label_speedrunner_time_per_player",
			min = 0,
			max = 90,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_respawn_time",
			label = "label_speedrunner_respawn_time",
			min = 0,
			max = 30,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_time_penalty",
			label = "label_speedrunner_time_penalty",
			min = 0,
			max = 30,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_time_reward",
			label = "label_speedrunner_time_reward",
			min = 0,
			max = 30,
			decimal = 0
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_speedrunner_smoke_enable",
			label = "label_speedrunner_smoke_enable"
		})

		form:MakeCheckBox({
			serverConvar = "ttt2_speedrunner_rainbow_enable",
			label = "label_speedrunner_rainbow_enable"
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_speed_scale",
			label = "label_speedrunner_speed_scale",
			min = 1.0,
			max = 5.0,
			decimal = 2,
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_jump_scale",
			label = "label_speedrunner_jump_scale",
			min = 1.0,
			max = 5.0,
			decimal = 2,
		})

		form:MakeSlider({
			serverConvar = "ttt2_speedrunner_fire_rate_scale",
			label = "label_speedrunner_fire_rate_scale",
			min = 1.0,
			max = 5.0,
			decimal = 2,
		})
	end
end

hook.Add("TTTPlayerSpeedModifier", "TTTPlayerSpeedModifierSpeedrunner", function(ply, _, _, no_lag)
	if ply:GetSubRole() == ROLE_SPEEDRUNNER then
		no_lag[1] = no_lag[1] * GetConVar("ttt2_speedrunner_speed_scale"):GetFloat()
	end
end)
