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
L["speedrunner_hud_display_" .. SPEEDRUNNER.name] = "{n} PLAYER(S) LEFT ({timeleft})"

-- EVENT STRINGS
-- Need to be very specifically worded, due to how the system translates them.
L["title_event_speed_start_run"] = "A speedrun began"
L["desc_event_speed_start_run"] = "{name} attempted a speedrun, with the goal of winning in {seconds} seconds."
L["title_event_speed_failed_run"] = "A speedrun failed"
L["desc_event_speed_failed_run"] = "{name} was unable to finish the speedrun started by {starter} in time..."
L["title_event_speed_aborted_run"] = "A speedrun was aborted"
L["desc_event_speed_aborted_run"] = "The speedrun started by {name} had to be aborted, as all speedrunners left."