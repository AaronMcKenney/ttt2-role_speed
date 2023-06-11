if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_speed.vmt")
end

if CLIENT then
	EVENT.title = "title_event_speed_failed_run"
	EVENT.icon = Material("vgui/ttt/dynamic/roles/icon_speed.vmt")

	function EVENT:GetText()
		return {
			{
				string = "desc_event_speed_failed_run",
				params = {
					name = self.event.speedrunner_name,
					starter = self.event.starter_name
				},
				translateParams = true
			}
		}
    end
end

if SERVER then
	function EVENT:Trigger(speedrunner, starter)
		self:AddAffectedPlayers(
			{speedrunner:SteamID64(), starter:SteamID64()},
			{speedrunner:GetName(), starter:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			speedrunner_name = speedrunner:GetName(),
			starter_name = starter:GetName()
		})
	end

	function EVENT:Serialize()
		return self.event.serialname
	end
end