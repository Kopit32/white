#define ACTION_BUTTON_DEFAULT_BACKGROUND "default"

/atom/movable/screen/movable/action_button
	var/datum/action/linked_action
	var/datum/hud/our_hud
	var/actiontooltipstyle = ""
	screen_loc = null

	var/button_icon_state
	var/appearance_cache
	var/mutable_appearance/button_overlay
	/// Where we are currently placed on the hud. SCRN_OBJ_DEFAULT asks the linked action what it thinks
	var/location = SCRN_OBJ_DEFAULT
	/// A unique bitflag, combined with the name of our linked action this lets us persistently remember any user changes to our position
	var/id
	/// A weakref of the last thing we hovered over
	/// God I hate how dragging works
	var/datum/weakref/last_hovored_ref

/atom/movable/screen/movable/action_button/Destroy()
	if(our_hud)
		var/mob/viewer = our_hud.mymob
		our_hud.hide_action(src)
		viewer?.client?.screen -= src
		linked_action.viewers -= our_hud
		viewer.update_action_buttons()
		our_hud = null
	linked_action = null
	return ..()

/atom/movable/screen/movable/action_button/proc/can_use(mob/user)
	if(linked_action)
		if(linked_action.viewers[user.hud_used])
			return TRUE
		return FALSE
	else if (isobserver(user))
		var/mob/dead/observer/O = user
		return !O.observetarget
	else
		return TRUE

/atom/movable/screen/movable/action_button/Click(location,control,params)
	if (!can_use(usr))
		return FALSE

	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, SHIFT_CLICK))
		var/datum/hud/our_hud = usr.hud_used
		our_hud.position_action(src, SCRN_OBJ_DEFAULT)
		return TRUE
	if(usr.next_click > world.time)
		return
	usr.next_click = world.time + 1
	var/trigger_flags
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		trigger_flags |= TRIGGER_SECONDARY_ACTION
	linked_action.Trigger(trigger_flags = trigger_flags)
	return TRUE

// Entered and Exited won't fire while you're dragging something, because you're still "holding" it
// Very much byond logic, but I want nice behavior, so we fake it with drag
/atom/movable/screen/movable/action_button/MouseDrag(atom/over_object, src_location, over_location, src_control, over_control, params)
	. = ..()
	if(!can_use(usr))
		return
	if(IS_WEAKREF_OF(over_object, last_hovored_ref))
		return
	var/atom/old_object
	if(last_hovored_ref)
		old_object = last_hovored_ref?.resolve()
	else // If there's no current ref, we assume it was us. We also treat this as our "first go" location
		old_object = src
		var/datum/hud/our_hud = usr.hud_used
		our_hud?.generate_landings(src)

	if(old_object)
		old_object.MouseExited(over_location, over_control, params)

	last_hovored_ref = WEAKREF(over_object)
	over_object.MouseEntered(over_location, over_control, params)

/atom/movable/screen/movable/action_button/MouseEntered(location, control, params)
	. = ..()
	if(!QDELETED(src))
		openToolTip(usr, src, params, title = name, content = desc, theme = actiontooltipstyle)

/atom/movable/screen/movable/action_button/MouseExited(location, control, params)
	closeToolTip(usr)
	return ..()

/atom/movable/screen/movable/action_button/MouseDrop(over_object)
	last_hovored_ref = null
	if(!can_use(usr))
		return
	var/datum/hud/our_hud = usr.hud_used
	if(over_object == src)
		our_hud.hide_landings()
		return
	if(istype(over_object, /atom/movable/screen/action_landing))
		var/atom/movable/screen/action_landing/reserve = over_object
		reserve.hit_by(src)
		our_hud.hide_landings()
		save_position()
		return

	our_hud.hide_landings()
	if(istype(over_object, /atom/movable/screen/movable/action_button))
		var/atom/movable/screen/movable/action_button/button = over_object
		our_hud.position_action_relative(src, button)
		save_position()
		return
	. = ..()
	our_hud.position_action(src, screen_loc)
	save_position()

/atom/movable/screen/movable/action_button/proc/save_position()
	var/mob/user = our_hud.mymob
	if(!user?.client)
		return
	var/position_info = ""
	switch(location)
		if(SCRN_OBJ_FLOATING)
			position_info = screen_loc
		if(SCRN_OBJ_IN_LIST)
			position_info = SCRN_OBJ_IN_LIST

	user.client.prefs.action_buttons_screen_locs["[name]_[id]"] = position_info

/atom/movable/screen/movable/action_button/proc/load_position()
	var/mob/user = our_hud.mymob
	if(!user)
		return
	var/position_info = user.client?.prefs?.action_buttons_screen_locs["[name]_[id]"] || SCRN_OBJ_DEFAULT
	user.hud_used.position_action(src, position_info)

/atom/movable/screen/movable/action_button/proc/dump_save()
	var/mob/user = our_hud.mymob
	if(!user?.client)
		return
	user.client.prefs.action_buttons_screen_locs -= "[name]_[id]"

/datum/hud/proc/get_action_buttons_icons()
	. = list()
	.["bg_icon"] = ui_style
	.["bg_state"] = "template"

//see human and alien hud for specific implementations.

/mob/proc/update_action_buttons_icon(status_only = FALSE)
	for(var/X in actions)
		var/datum/action/A = X
		A.UpdateButtons(status_only)

//This is the proc used to update all the action buttons.
/mob/proc/update_action_buttons(reload_screen)
	if(!hud_used || !client)
		return

	if(hud_used.hud_shown != HUD_STYLE_STANDARD)
		return

	for(var/datum/action/action as anything in actions)
		var/atom/movable/screen/movable/action_button/button = action.viewers[hud_used]
		action.UpdateButtons()
		if(reload_screen)
			client.screen += button

	if(reload_screen)
		hud_used.update_our_owner()

/// Exists so you have a place to put your buttons when you move them around
/atom/movable/screen/action_landing
	name = "ПРОСТРАНСТВО КНОПОК"
	desc = "<b>Перемещай</b> кнопки сюда, <br>чтобы добавить их в группу"
	icon = 'icons/hud/screen_gen.dmi'
	icon_state = "reserved"
	// We want our whole 32x32 space to be clickable, so dropping's forgiving
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	var/datum/action_group/owner

/atom/movable/screen/action_landing/Destroy()
	if(owner)
		owner.landing = null
		owner?.owner?.mymob?.client?.screen -= src
		owner.refresh_actions()
		owner = null
	return ..()

/atom/movable/screen/action_landing/proc/set_owner(datum/action_group/owner)
	src.owner = owner
	refresh_owner()

/atom/movable/screen/action_landing/proc/refresh_owner()
	var/datum/hud/our_hud = owner.owner
	var/mob/viewer = our_hud.mymob
	if(viewer.client)
		viewer.client.screen |= src

	//var/list/settings = our_hud.get_action_buttons_icons()
	//icon = settings["bg_icon"]

/// Reacts to having a button dropped on it
/atom/movable/screen/action_landing/proc/hit_by(atom/movable/screen/movable/action_button/button)
	var/datum/hud/our_hud = owner.owner
	our_hud.position_action(button, owner.location)
