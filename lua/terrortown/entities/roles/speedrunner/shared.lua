if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_speed.vmt")
	util.AddNetworkString("TTT2SpeedrunnerSpawnSmoke")
	util.AddNetworkString("TTT2SpeedrunnerRateOfFireUpdate")
end

roles.InitCustomTeam(ROLE.name, {
	icon = "vgui/ttt/dynamic/roles/icon_speed",
	color = Color(193, 87, 255, 255),
})

function ROLE:PreInitialize()
	self.color = Color(193, 87, 255, 255)
	self.abbr = "speed"

	self.score.teamKillsMultiplier = -16
	self.score.killsMultiplier = 5

	self.preventFindCredits = false

	self.fallbackTable = {}
	self.unknownTeam = false -- disables team voice chat.

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
		traitorButton = 0,

		credits = 0,
		--creditsAwardDeadEnable = 1,
		--creditsAwardKillEnable = 1,
		shopFallback = SHOP_DISABLED,

		togglable = true
	}
end

--CONSTANTS
--Hardcoded default that everyone uses.
local DEFAULT_JUMP_POWER = 160

if SERVER then
	--WeaponSpeed functionality taken and modified from TTT2 Super Soda mod
	local function ApplyWeaponSpeedForSpeedrunner(wep)
		local ply = wep.Owner
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(wep) or not IsValid(ply) then
			return
		end
		
		if (wep.Kind == WEAPON_MELEE or wep.Kind == WEAPON_HEAVY or wep.Kind == WEAPON_PISTOL) then
			if not wep.ttt_speedrunner_modded then
				wep.ttt_speedrunner_modded = true
			end
			
			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG ApplyWeaponSpeedForSpeedrunner Before: ", wep.Primary.Delay)
			
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
		if wep.ttt_speedrunner_modded and (wep.Kind == WEAPON_MELEE or wep.Kind == WEAPON_HEAVY or wep.Kind == WEAPON_PISTOL) then
			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG DisableWeaponSpeedForSpeedrunner Before: ", wep.Primary.Delay)
			
			wep.Primary.Delay = wep.Primary.Delay * GetConVar("ttt2_speedrunner_fire_rate_scale"):GetFloat()

			--UNCOMMENT FOR DEBUGGING
			--print("SPEED_DEBUG DisableWeaponSpeedForSpeedrunner After: ", wep.Primary.Delay)
			
			net.Start("TTT2SpeedrunnerRateOfFireUpdate")
			net.WriteEntity(wep)
			net.WriteFloat(wep.Primary.Delay)
			net.Send(ply)
			
			wep.ttt_speedrunner_modded = nil
		end
	end

	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		--More complicated method for setting jump power, which works if other jump modifying effects occur. Downside is that all addons would need to use this method, so...
		ply:SetJumpPower(ply:GetJumpPower() + DEFAULT_JUMP_POWER * (GetConVar("ttt2_speedrunner_jump_scale"):GetFloat() - 1.0))
		--Simpler method would be:
		--ply:SetJumpPower(DEFAULT_JUMP_POWER * GetConVar("ttt2_speedrunner_jump_scale"):GetFloat())
		if ply:GetJumpPower() > DEFAULT_JUMP_POWER then
			ply:GiveEquipmentItem("item_ttt_nofalldmg")
		end

		ApplyWeaponSpeedForSpeedrunner(ply:GetActiveWeapon())

		ply:GiveEquipmentItem("item_ttt_radar")

		net.Start("TTT2SpeedrunnerSpawnSmoke")
		net.WriteVector(ply:GetPos())
		net.Broadcast()
	end

	function ROLE:RemoveRoleLoadout(ply, isRoleChange)
		--More complicated method for setting jump power, which works if other jump modifying effects occur. Downside is that all addons would need to use this method, so...
		ply:SetJumpPower(ply:GetJumpPower() - DEFAULT_JUMP_POWER * (GetConVar("ttt2_speedrunner_jump_scale"):GetFloat() - 1.0))
		--Simpler method would bb:
		--ply:SetJumpPower(DEFAULT_JUMP_POWER)
		ply:RemoveEquipmentItem("item_ttt_nofalldmg")

		ply:RemoveEquipmentItem("item_ttt_radar")

		DisableWeaponSpeedForSpeedrunner(ply, ply:GetActiveWeapon())
	end
	
	--Technically this is called in both the Server and the Client. We can get away with only adding the hook in the server, as the server hook sends TTT2SpeedrunnerRateOfFireUpdate net packets to the client with the updated information.
	hook.Add("PlayerSwitchWeapon", "PlayerSwitchWeaponSpeedrunner", function(ply, old, new)
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(old) or not IsValid(new) or ply:GetSubRole() ~= ROLE_SPEEDRUNNER then
			return
		end
		
		DisableWeaponSpeedForSpeedrunner(ply, old)
		ApplyWeaponSpeedForSpeedrunner(new)
	end)
	
	hook.Add("PlayerDroppedWeapon", "PlayerDroppedWeaponSpeedrunner", function(ply, wep)
		if GetRoundState() ~= ROUND_ACTIVE or not IsValid(wep) or ply:GetSubRole() ~= ROLE_SPEEDRUNNER then
			return
		end
		
		DisableWeaponSpeedForSpeedrunner(ply, wep)
	end)
end

if CLIENT then
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
		local pos = net.ReadVector()

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

				p:SetDieTime(10)

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
end

hook.Add("TTTPlayerSpeedModifier", "TTTPlayerSpeedModifierSpeedrunner", function(ply, _, _, no_lag)
	if ply:GetSubRole() == ROLE_SPEEDRUNNER then
		no_lag[1] = no_lag[1] * GetConVar("ttt2_speedrunner_speed_scale"):GetFloat()
	end
end)
