local base = "pure_skin_element"

DEFINE_BASECLASS(base)

HUDELEMENT.Base = base

--Most code here is taken from Vampire and Bodyguard HUD logic.
if CLIENT then
	local pad = 7
	local iconSize = 64
	
	local const_defaults = {
		basepos = {x = 0, y = 0},
		size = {w = 365, h = 32},
		minsize = {w = 225, h = 32}
	}

	function HUDELEMENT:PreInitialize()
		BaseClass.PreInitialize(self)

		local hud = huds.GetStored("pure_skin")
		if not hud then return end

		hud:ForceElement(self.id)
	end

	function HUDELEMENT:Initialize()
		self.scale = 1.0
		self.basecolor = self:GetHUDBasecolor()
		self.pad = pad
		self.iconSize = iconSize

		BaseClass.Initialize(self)
	end

	-- parameter overwrites
	function HUDELEMENT:IsResizable()
		return true, false
	end
	-- parameter overwrites end

	function HUDELEMENT:GetDefaults()
		const_defaults["basepos"] = {
			x = 10 * self.scale,
			y = ScrH() - self.size.h - 146 * self.scale - self.pad - 10 * self.scale
		}

		return const_defaults
	end

	function HUDELEMENT:PerformLayout()
		self.scale = self:GetHUDScale()
		self.basecolor = self:GetHUDBasecolor()
		self.iconSize = iconSize * self.scale
		self.pad = pad * self.scale

		BaseClass.PerformLayout(self)
	end

	function HUDELEMENT:ShouldDraw()
		local client = LocalPlayer()

		return HUDEditor.IsEditing or (client:GetSubRole() == ROLE_SPEEDRUNNER)
	end

	function HUDELEMENT:DrawComponent(text, bg_color)
		local pos = self:GetPos()
		local size = self:GetSize()
		local x, y = pos.x, pos.y
		local w, h = size.w, size.h
		
		self:DrawBg(x, y, w, h, bg_color)
		draw.AdvancedText(text, "PureSkinBar", x + self.iconSize + self.pad, y + h * 0.5, util.GetDefaultColor(bg_color), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, true, self.scale)
		self:DrawLines(x, y, w, h, self.basecolor.a)
		
		local nSize = self.iconSize - 16
	end
	
	function HUDELEMENT:Draw()
		local client = LocalPlayer()
		local bg_color = COLOR_WHITE
		local cur_time = CurTime()

		if client:GetSubRole() ~= ROLE_SPEEDRUNNER or client.ttt2_speedrunner_display_end_time and cur_time > client.ttt2_speedrunner_display_end_time then
			return
		end

		local num_left = client.ttt2_speedrunner_num_left or 0
		local display_str = LANG.GetParamTranslation("hud_display_" .. SPEEDRUNNER.name, {n = num_left, timeleft = TTT2SpeedrunnerTimeLeftStr()})

		if client.ttt2_speedrunner_run_end_time then
			local time_left = client.ttt2_speedrunner_run_end_time - cur_time
			local minutes_left = math.floor(time_left / 60)
			local seconds_left_whole_num = math.floor(time_left - minutes_left * 60)

			--Two cases here: 1. <60 seconds the timer is red. 2. <30 seconds the timer alternates between red and white.
			if client.ttt2_speedrunner_run_end_time > cur_time and
				(minutes_left == 0 and ((seconds_left_whole_num < 60 and seconds_left_whole_num > 30) or (seconds_left_whole_num < 30 and (seconds_left_whole_num % 2) == 1)))
			then
				bg_color = COLOR_RED
			elseif client.ttt2_speedrunner_run_end_time < 0 then
				--Do not visually signal that the speedrun has failed until we get a clear message from the server that this has been the case.
				bg_color = COLOR_BLACK

				--Make the display blink on/off like a beeping alarm clock.
				if client.ttt2_speedrunner_display_end_time and client.ttt2_speedrunner_display_end_time > cur_time and math.floor((client.ttt2_speedrunner_display_end_time - cur_time)*2) % 2 == 0 then
					display_str = ""
				end
			end
		end

		self:DrawComponent(display_str, bg_color)
	end
end
