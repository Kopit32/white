GLOBAL_LIST_EMPTY(smoke)
/obj/effect/particle_effect/smoke/Initialize()
	. = ..()
	LAZYADD(GLOB.smoke, src)
	create_reagents(250)
	START_PROCESSING(SSreagent_states, src)

/obj/effect/particle_effect/smoke/Destroy()
	LAZYREMOVE(GLOB.smoke, src)
	STOP_PROCESSING(SSreagent_states, src)
	return ..()

/obj/effect/particle_effect/smoke/ex_act()
	return