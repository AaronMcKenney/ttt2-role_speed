local L = LANG.GetLanguageTableReference("en")

--GENERAL ROLE LANGUAGE STRINGS
L[SPEEDRUNNER.name] = "Speedrunner"
L["info_popup_" .. SPEEDRUNNER.name] = [[You are a Speedrunner and everyone knows it.

Kill everyone else in the time limit, or perish.]]
L["body_found_" .. SPEEDRUNNER.abbr] = "They were a Speedrunner."
L["search_role_" .. SPEEDRUNNER.abbr] = "This person was a Speedrunner!"
L["target_" .. SPEEDRUNNER.name] = "Speedrunner"
L["ttt2_desc_" .. SPEEDRUNNER.name] = [[You are a Speedrunner and everyone knows it.

Kill everyone else in the time limit, or perish.]]

--SPEEDRUNNER TEAM
L[TEAM_SPEEDRUNNER] = "Team Speedrunners"
L["hilite_win_" .. TEAM_SPEEDRUNNER] = "TEAM SPEEDRUNNER WON"
L["win_" .. TEAM_SPEEDRUNNER] = "The Speedrunner has won!"
L["ev_win_" .. TEAM_SPEEDRUNNER] = "The Speedrunner won the round!"

-- OTHER ROLE LANGUAGE STRINGS
L["hud_display_" .. SPEEDRUNNER.name] = "{n} PLAYER(S) LEFT ({timeleft})"

-- EVENT STRINGS
-- Need to be very specifically worded, due to how the system translates them.
L["title_event_speed_start_run"] = "A speedrun began"
L["desc_event_speed_start_run"] = "{name} attempted a speedrun, with the goal of winning in {seconds} seconds."
L["title_event_speed_failed_run"] = "A speedrun failed"
L["desc_event_speed_failed_run"] = "{name} was unable to finish the speedrun started by {starter} in time..."
L["title_event_speed_aborted_run"] = "A speedrun was aborted"
L["desc_event_speed_aborted_run"] = "The speedrun started by {name} had to be aborted, as all speedrunners left."

-- CONVAR STRINGS
L["label_speedrunner_time_base"] = "Base time Speedrunner has to win game"
L["label_speedrunner_time_per_player"] = "Additional time per player"
L["label_speedrunner_respawn_time"] = "Speedrunner's respawn time"
L["label_speedrunner_time_penalty"] = "Time deduction for dying"
L["label_speedrunner_time_reward"] = "Time reward for killing an opposing player"
L["label_speedrunner_smoke_enable"] = "Smoke occurs on spawn/death"
L["label_speedrunner_rainbow_enable"] = "Speedrunner's color cycles across the rainbow"
L["label_speedrunner_speed_scale"] = "Multi. applied to Speerunner's speed"
L["label_speedrunner_jump_scale"] = "Mult. applied to Speedrunner's jump height"
L["label_speedrunner_fire_rate_scale"] = "Mult. applied to Speedrunner's fire rate"
