if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_speed.vmt")
end

if CLIENT then
	EVENT.title = "title_event_speed_start_run"
	EVENT.icon = Material("vgui/ttt/dynamic/roles/icon_speed.vmt")

	function EVENT:GetText()
		return {
			{
				string = "desc_event_speed_start_run",
				params = {
					name = self.event.speedrunner_name,
					seconds = self.event.time_goal
				},
				translateParams = true
			}
		}
    end
end

if SERVER then
	function EVENT:Trigger(speedrunner, max_run_length)
		self:AddAffectedPlayers(
			{speedrunner:SteamID64()},
			{speedrunner:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			speedrunner_name = speedrunner:GetName(),
			time_goal = max_run_length
		})
	end

	function EVENT:Serialize()
		return self.event.serialname
	end
end