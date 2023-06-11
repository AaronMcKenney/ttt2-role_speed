if SERVER then
    AddCSLuaFile()

    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_speed.vmt")
end

if CLIENT then
	EVENT.title = "title_event_speed_aborted_run"
	EVENT.icon = Material("vgui/ttt/dynamic/roles/icon_speed.vmt")

	function EVENT:GetText()
		return {
			{
				string = "desc_event_speed_aborted_run",
				params = {
					name = self.event.speedrunner_name
				},
				translateParams = true
			}
		}
    end
end

if SERVER then
	function EVENT:Trigger(speedrunner)
		self:AddAffectedPlayers(
			{speedrunner:SteamID64()},
			{speedrunner:GetName()}
		)
		
		return self:Add({
			serialname = self.event.title,
			speedrunner_name = speedrunner:GetName()
		})
	end

	function EVENT:Serialize()
		return self.event.serialname
	end
end