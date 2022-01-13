#define HEIGHT_OPTIMAL 	480000
#define HEIGHT_DANGER 	350000
#define HEIGHT_CRITICAL 200000
#define HEIGHT_DEADEND 	100000
#define HEIGHT_CRASH 	0

GLOBAL_LIST_EMPTY(pulse_engines)
GLOBAL_VAR_INIT(station_orbit_height, HEIGHT_OPTIMAL)
GLOBAL_VAR_INIT(station_orbit_speed, 0)
GLOBAL_VAR_INIT(station_orbit_parallax_resize, 1)

/datum/game_mode/ruination
	name = "ruination"
	config_tag = "ruination"
	report_type = "ruination"
	false_report_weight = 1
	required_players = 30
	required_enemies = 4
	recommended_enemies = 4
	reroll_friendly = 1
	enemy_minimum_age = 0

	restricted_jobs = list("Cyborg", "AI")
	protected_jobs = list("Prisoner", "Russian Officer", "Trader", "Hacker","Veteran", "Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Field Medic")

	announce_span = "danger"
	announce_text = "Кто-то решил уронить станцию прямиком на ПЛАНЕТУ!"

	var/list/datum/mind/ruiners = list()

	var/datum/team/ruiners/ruiners_team

	traitor_name = "Террорист"

	var/win_time = 20 MINUTES
	var/result = 0
	var/started_at = 0
	var/announce_stage = 0

	var/current_stage = 0

/datum/game_mode/ruination/pre_setup()

	load_stage()

	if(current_stage == 1)
		return TRUE

	for(var/j = 0, j < max(1, min(num_players(), 4)), j++)
		if (!antag_candidates.len)
			break
		var/datum/mind/traitor = antag_pick(antag_candidates)
		ruiners += traitor
		traitor.special_role = traitor_name
		traitor.restricted_roles = restricted_jobs
		log_game("[key_name(traitor)] has been selected as a [traitor_name]")
		antag_candidates.Remove(traitor)

	var/enough_tators = 4 || ruiners.len > 0

	if(!enough_tators)
		setup_error = "Требуется 4 кандидата"
		return FALSE
	else
		for(var/antag in ruiners)
			GLOB.pre_setup_antags += antag
		return TRUE

/datum/game_mode/ruination/post_setup()

	if(current_stage == 1)
		CONFIG_SET(flag/allow_random_events, FALSE)
		gamemode_ready = FALSE
		addtimer(VARSET_CALLBACK(src, gamemode_ready, TRUE), 101)
		return TRUE

	var/datum/mind/leader_mind = ruiners[1]
	var/datum/antagonist/traitor/ruiner/L = leader_mind.add_antag_datum(/datum/antagonist/traitor/ruiner)
	ruiners_team = L.ruiners_team

	for(var/i = 2 to ruiners.len)
		var/datum/mind/ruiner_mind = ruiners[i]
		ruiner_mind.add_antag_datum(/datum/antagonist/traitor/ruiner)
		GLOB.pre_setup_antags -= ruiners[i]

	..()

	gamemode_ready = FALSE
	addtimer(VARSET_CALLBACK(src, gamemode_ready, TRUE), 101)
	return TRUE

/datum/game_mode/ruination/proc/load_stage()
	var/json_file = file("data/ruination.json")
	if(!fexists(json_file))
		return
	var/list/json = json_decode(file2text(json_file))
	current_stage = json["current_stage"]

/datum/game_mode/ruination/proc/save_stage()
	var/json_file = file("data/ruination.json")
	var/list/file_data = list()
	file_data["current_stage"] = current_stage
	fdel(json_file)
	WRITE_FILE(json_file, json_encode(file_data))

/datum/game_mode/ruination/process()
	if(!started_at && GLOB.pulse_engines.len)
		for(var/obj/structure/pulse_engine/PE in GLOB.pulse_engines)
			if(PE.engine_active)
				started_at = world.time
				priority_announce("На вашей станции был обнаружен запуск одного или нескольких импульсных двигателей. Не паникуйте, это всего лишь запланированное перемещение вашей станции на новую орбиту.", null, 'sound/misc/announce_dig.ogg', "Priority")
				sound_to_playing_players('white/valtos/sounds/rp0.ogg', 15, FALSE, channel = CHANNEL_RUINATION_OST)
				spawn(300)
					SSshuttle.lastMode = SSshuttle.emergency.mode
					SSshuttle.lastCallTime = SSshuttle.emergency.timeLeft(1)
					SSshuttle.adminEmergencyNoRecall = TRUE
					SSshuttle.emergency.setTimer(0)
					SSshuttle.emergency.mode = SHUTTLE_DISABLED
					priority_announce("Внимание: эвакуационный шаттл был заблокирован.", "Сбой эвакуационного шаттла", 'sound/misc/announce_dig.ogg')
				spawn(600)
					sound_to_playing_players('white/valtos/sounds/rf.ogg', 15, FALSE, channel = CHANNEL_RUINATION_OST)
					spawn(50)
						set_security_level(SEC_LEVEL_DELTA)
					priority_announce("Внимание, сотрудники Нанотрейзен, спешим сообщить вам, что корпорация вас снова обманывает. Они дошли до такого уровня маразма, что ради прибыли готовы утилизировать станцию вместе с вами. Мы перехватили данные сообщающие о том, что на вашей станции на данный момент находится 4 агента Нанотрейзен под прикрытием. Постарайтесь им помешать, пока мы готовим блюспейс-транслокатор для перемещения вашей станции. Это займёт примерно 20 минут.", null, 'sound/misc/announce_dig.ogg', sender_override = "Синдикат")
					spawn(150)
						priority_announce("Вы в курсе, что большая часть сотрудников Нанотрейзен имеют встроенный в их черепную коробку, при клонировании, HUD? Показываем как он работает.", null, 'sound/misc/announce_dig.ogg', sender_override = "Синдикат")
						for(var/m in GLOB.player_list)
							if(ismob(m) && !isnewplayer(m))
								var/mob/M = m
								if(M.hud_used)
									var/datum/hud/H = M.hud_used
									var/atom/movable/screen/station_height/sh = new /atom/movable/screen/station_height()
									var/atom/movable/screen/station_height_bg/shbg = new /atom/movable/screen/station_height_bg()
									H.station_height = sh
									H.station_height_bg = shbg
									sh.hud = H
									shbg.hud = H
									H.infodisplay += sh
									H.infodisplay += shbg
									H.mymob.client.screen += sh
									H.mymob.client.screen += shbg
				break
	if(started_at)
		if((started_at + (win_time - 16 MINUTES)) < world.time && announce_stage == 0)
			announce_stage = 1
			sound_to_playing_players('white/valtos/sounds/rp6.ogg', 25, FALSE, channel = CHANNEL_RUINATION_OST)
			priority_announce("Осталось 15 минут до активации блюспейс-транслокатора.", null, 'sound/misc/announce_dig.ogg', sender_override = "Синдикат")
			general_ert_request("Помешать террористам, мешающим работе невероятно важного оборудования на станции в виде импульсных двигателей.")
		if((started_at + (win_time - 10 MINUTES)) < world.time && announce_stage == 1)
			announce_stage = 2
			sound_to_playing_players('white/valtos/sounds/rp7.ogg', 35, FALSE, channel = CHANNEL_RUINATION_OST)
			priority_announce("Осталось 10 минут до активации блюспейс-транслокатора.", null, 'sound/misc/announce_dig.ogg', sender_override = "Синдикат")
		if((started_at + (win_time - 5 MINUTES)) < world.time && announce_stage == 2)
			deathsquad_request("Уничтожить свидетелей.")
			announce_stage = 3
			sound_to_playing_players('white/valtos/sounds/rp5.ogg', 45, FALSE, channel = CHANNEL_RUINATION_OST)
			priority_announce("Осталось 5 минут до активации блюспейс-транслокатора. Держитесь.", null, 'sound/misc/announce_dig.ogg', sender_override = "Синдикат")
		var/total_speed = 0
		for(var/obj/structure/pulse_engine/PE in GLOB.pulse_engines)
			total_speed += PE.engine_power * 5
		GLOB.station_orbit_height -= total_speed
		for(var/i in GLOB.player_list)
			var/mob/M = i
			if(!M.hud_used?.station_height)
				continue
			var/datum/hud/H = M.hud_used
			H.station_height.update_height()
		GLOB.station_orbit_speed = total_speed

	var/cur_height = GLOB.station_orbit_parallax_resize

	switch(GLOB.station_orbit_height)
		if(HEIGHT_OPTIMAL to INFINITY)
			GLOB.station_orbit_parallax_resize = 0
		if(HEIGHT_DANGER to HEIGHT_OPTIMAL)
			GLOB.station_orbit_parallax_resize = 2
		if(HEIGHT_CRITICAL to HEIGHT_DANGER)
			GLOB.station_orbit_parallax_resize = 3
		if(HEIGHT_DEADEND to HEIGHT_CRITICAL)
			GLOB.station_orbit_parallax_resize = 4
		if(HEIGHT_CRASH to HEIGHT_DEADEND)
			GLOB.station_orbit_parallax_resize = 5

	if(cur_height != GLOB.station_orbit_parallax_resize)
		for(var/m in GLOB.player_list)
			if(ismob(m) && !isnewplayer(m))
				var/mob/M = m
				if(M.hud_used)
					M?.hud_used?.update_parallax_pref(M, GLOB.station_orbit_parallax_resize)
					shake_camera(M, 1, 7)

/datum/game_mode/ruination/check_finished()
	if(current_stage == 1)
		current_stage = 0
		save_stage()
		spawn(30 SECONDS)
			sound_to_playing_players('white/valtos/sounds/rp3.ogg', 15, FALSE, channel = CHANNEL_RUINATION_OST)
			priority_announce("Приём. Слышит ещё кто-то? Похоже, вы здорово ударились при падении и мы наблюдаем признаки некоторой жизненной активности нашими сенсорами. На северо-востоке есть заброшенный аванпост, постарайтесь вызвать подмогу оттуда, мы уже взломали для вас шаттл. До связи.", "Синдикат", 'sound/misc/announce_dig.ogg')
			SSshuttle.emergency.hijack_status = 5
		return ..()
	if(!started_at)
		return ..()
	if(GLOB.station_orbit_height < HEIGHT_CRASH)
		if(SSticker && SSticker.mode && SSticker.mode.station_was_nuked)
			SSticker.mode.station_was_nuked = TRUE
		result = 1
		Cinematic(CINEMATIC_RUINERS_WIN, world, CALLBACK(SSticker, /datum/controller/subsystem/ticker/proc/station_explosion_detonation, src))
		SSmapping.changemap(config.maplist["Coldstone"])
		current_stage = 1
		save_stage()
	else if ((started_at + win_time) < world.time)
		result = 2
	if(result)
		return TRUE
	else
		return ..()

/datum/game_mode/ruination/special_report()
	if(current_stage == 0)
		if(result == 1)
			return "<div class='panel redborder'><span class='redtext big'>СТАНЦИЯ БЫЛА СБРОШЕНА НА ПЛАНЕТУ! ВЫЖИВШИХ ОБНАРУЖЕНО НЕ БЫЛО...</span></div>"
		else if(result == 2)
			return "<div class='panel redborder'><span class='redtext big'>Экипаж станции смог продержаться до блюспейс-транслокации!</span></div>"
	else if (current_stage == 2)
		return "<div class='panel redborder'><span class='redtext big'>Некоторая часть персонала смогла выжить при падении. Все они были уволены за свою некомпетентность и невероятные убытки!</span></div>"

/datum/game_mode/ruination/set_round_result()
	..()
	if(current_stage == 0)
		if(result == 1)
			SSticker.mode_result = "станция уничтожена"
		else if(result == 2)
			SSticker.mode_result = "станция стабилизирована"
	else if (current_stage == 2)
		SSticker.mode_result = "экипаж эвакуировался"

/datum/game_mode/ruination/generate_report()
	return "Кто-то недавно выкрал несколько импульсных двигателей, которые предназначены для выведения объектов с орбит. \
	Система защиты данных устройств невероятно крутая, что можно говорить и об их удивительно высокой цене производства! \
	Обязательно сообщите нам, если случайно найдёте парочку таких."

/atom/movable/screen/station_height
	icon = 'white/valtos/icons/line.png'
	screen_loc = "SOUTH:420, EAST-3:48"
	maptext_y = -4
	maptext_width = 96
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/station_height/Initialize()
	. = ..()
	flicker_animation()
	overlays += icon('white/valtos/icons/station.png')

/atom/movable/screen/station_height/proc/update_height()
	screen_loc = "SOUTH:[min(round((GLOB.station_orbit_height * 0.001), 1) + 120, 440)], EAST-3:48"
	maptext = "<span style='color: #A35D5B; font-size: 8px;'>[GLOB.station_orbit_height] M</br>[GLOB.station_orbit_speed] M/C</span>"

/atom/movable/screen/station_height_bg
	icon = 'white/valtos/icons/graph.png'
	screen_loc = ui_station_height
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/proc/flicker_animation(anim_len = 50)
	var/haste = 0.1
	alpha = 0
	animate(src, alpha = 0, time = 1, easing = JUMP_EASING)
	for(var/i in 1 to anim_len)
		animate(alpha = 255, time = 1 - haste, easing = JUMP_EASING)
		animate(alpha = 0,   time = 1 - haste, easing = JUMP_EASING)
		haste += 0.1
		if(prob(25))
			haste -= 0.2
	animate(alpha = 255, time = 1, easing = JUMP_EASING)

/datum/team/ruiners
	name = "Террористы"
	var/core_objective = /datum/objective/ruiner

/datum/team/ruiners/proc/update_objectives()
	if(core_objective)
		var/datum/objective/O = new core_objective
		O.team = src
		objectives += O

/datum/antagonist/traitor/ruiner
	name = "Смертник"
	give_objectives = FALSE
	greentext_reward = 150
	antag_hud_type = ANTAG_HUD_OPS
	antag_hud_name = "hog-red-2"
	antag_moodlet = /datum/mood_event/focused
	job_rank = ROLE_OPERATIVE
	var/datum/team/ruiners/ruiners_team

/datum/antagonist/traitor/ruiner/get_team()
	return ruiners_team

/datum/antagonist/traitor/ruiner/create_team(datum/team/ruiners/new_team)
	if(!new_team)
		for(var/datum/antagonist/traitor/ruiner/N in GLOB.antagonists)
			if(!N.owner)
				stack_trace("Antagonist datum without owner in GLOB.antagonists: [N]")
				continue
			if(N.ruiners_team)
				ruiners_team = N.ruiners_team
				return
		ruiners_team = new /datum/team/ruiners
		ruiners_team.update_objectives()
		return
	if(!istype(new_team))
		stack_trace("Wrong team type passed to [type] initialization.")
	ruiners_team = new_team

/datum/antagonist/traitor/ruiner/on_gain()
	. = ..()
	var/datum/objective/ruiner/ruiner_objective = new
	ruiner_objective.owner = owner
	add_objective(ruiner_objective)
	owner.announce_objectives()

	var/mob/living/carbon/H = owner.current
	if(!istype(H))
		return

	to_chat(H, span_userdanger("ДАВАЙ! ДАВАЙ! ДАВАЙ!"))

	H.hallucination = 500

	var/list/slots = list(
		"сумку" = ITEM_SLOT_BACKPACK,
		"левый карман" = ITEM_SLOT_LPOCKET,
		"правый карман" = ITEM_SLOT_RPOCKET
	)

	var/T = new /obj/item/sbeacondrop/pulse_engine(H)
	var/where = H.equip_in_one_of_slots(T, slots)
	if(!where)
		return
	else
		to_chat(H, span_danger("Мне подкинули маяк в [where]."))
		if(where == "сумку")
			SEND_SIGNAL(H.back, COMSIG_TRY_STORAGE_SHOW, H)


#undef HEIGHT_OPTIMAL
#undef HEIGHT_DANGER
#undef HEIGHT_CRITICAL
#undef HEIGHT_DEADEND
#undef HEIGHT_CRASH
