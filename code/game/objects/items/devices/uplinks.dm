//This could either be split into the proper DM files or placed somewhere else all together, but it'll do for now -Nodrak

/*

A list of items and costs is stored under the datum of every game mode, alongside the number of crystals, and the welcoming message.

*/

var/list/world_uplinks = list()

/obj/item/device/uplink
	var/welcome 			// Welcoming menu message
	var/uses 				// Numbers of crystals
	var/list/ItemsCategory	// List of categories with lists of items
	var/list/ItemsReference	// List of references with an associated item
	var/list/nanoui_items	// List of items for NanoUI use
	var/nanoui_menu = 0		// The current menu we are in
	var/list/nanoui_data = new // Additional data for NanoUI use

	var/purchase_log = ""
	var/uplink_owner = null//text-only
	var/used_TC = 0

	var/job = null
	var/show_descriptions = 0

/obj/item/device/uplink/nano_host()
	return loc

/obj/item/device/uplink/New()
	..()
	welcome = ticker.mode.uplink_welcome
	uses = ticker.mode.uplink_uses
	ItemsCategory = get_uplink_items()

	world_uplinks += src

/obj/item/device/uplink/Destroy()
	world_uplinks -= src
	return ..()

/obj/item/device/uplink/proc/generate_items(mob/user as mob)
	var/datum/nano_item_lists/IL = generate_item_lists(user)
	nanoui_items = IL.items_nano
	ItemsReference = IL.items_reference

// BS12 no longer use this menu but there are forks that do, hency why we keep it
/obj/item/device/uplink/proc/generate_menu(mob/user as mob)
	if(!job)
		job = user.mind.assigned_role

	var/dat = "<B>[src.welcome]</B><BR>"
	dat += "Telecrystals left: [src.uses]<BR>"
	dat += "<HR>"
	dat += "<B>Request item:</B><BR>"
	dat += "<I>Each item costs a number of telecrystals as indicated by the number following their name.</I><br>"

	var/category_items = 1
	for(var/category in ItemsCategory)
		if(category_items < 1)
			dat += "<i>We apologize, as you could not afford anything from this category.</i><br>"
		dat += "<br>"
		dat += "<b>[category]</b><br>"
		category_items = 0

		for(var/datum/uplink_item/I in ItemsCategory[category])
			if(I.cost > uses)
				continue
			if(I.job && I.job.len)
				if(!(I.job.Find(job)))
					continue
			dat += "<A href='byond://?src=[UID()];buy_item=[I.reference];cost=[I.cost]'>[I.name]</A> ([I.cost])<BR>"
			category_items++

	dat += "<A href='byond://?src=[UID()];buy_item=random'>Random Item (??)</A><br>"
	dat += "<HR>"
	return dat

/*
	Built the item lists for use with NanoUI
*/
/obj/item/device/uplink/proc/generate_item_lists(mob/user as mob)
	if(!job)
		job = user.mind.assigned_role

	var/list/nano = new
	var/list/reference = new

	for(var/category in ItemsCategory)
		nano[++nano.len] = list("Category" = category, "items" = list())
		for(var/datum/uplink_item/I in ItemsCategory[category])
			if(I.job && I.job.len)
				if(!(I.job.Find(job)))
					continue
			nano[nano.len]["items"] += list(list("Name" = sanitize_local(I.name), "Description" = sanitize_local(I.description()),"Cost" = I.cost, "obj_path" = I.reference))
			reference[I.reference] = I

	var/datum/nano_item_lists/result = new
	result.items_nano = nano
	result.items_reference = reference
	return result

//If 'random' was selected
/obj/item/device/uplink/proc/chooseRandomItem()
	if(uses <= 0)
		return

	var/list/random_items = new
	for(var/IR in ItemsReference)
		var/datum/uplink_item/UI = ItemsReference[IR]
		if(UI.cost <= uses)
			random_items += UI
	return pick(random_items)

/obj/item/device/uplink/Topic(href, href_list)
	if(..())
		return 1

	if(href_list["buy_item"] == "random")
		var/datum/uplink_item/UI = chooseRandomItem()
		href_list["buy_item"] = UI.reference
		return buy(UI, "RN")
	else
		var/datum/uplink_item/UI = ItemsReference[href_list["buy_item"]]
		return buy(UI, UI ? UI.reference : "")
	return 0

/obj/item/device/uplink/proc/buy(var/datum/uplink_item/UI, var/reference)
	if(!UI)
		return
	UI.buy(src,usr)
	nanomanager.update_uis(src)

	/* var/list/L = UI.spawn_item(get_turf(usr),src)
	if(ishuman(usr))
		var/mob/living/carbon/human/A = usr
		for(var/obj/I in L)
			A.put_in_any_hand_if_possible(I)

	purchase_log[UI] = purchase_log[UI] + 1 */

	return 1

// HIDDEN UPLINK - Can be stored in anything but the host item has to have a trigger for it.
/* How to create an uplink in 3 easy steps!

 1. All obj/item 's have a hidden_uplink var. By default it's null. Give the item one with "new(src)", it must be in it's contents. Feel free to add "uses".

 2. Code in the triggers. Use check_trigger for this, I recommend closing the item's menu with "usr << browse(null, "window=windowname") if it returns true.
 The var/value is the value that will be compared with the var/target. If they are equal it will activate the menu.

 3. If you want the menu to stay until the users locks his uplink, add an active_uplink_check(mob/user as mob) in your interact/attack_hand proc.
 Then check if it's true, if true return. This will stop the normal menu appearing and will instead show the uplink menu.
*/

/obj/item/device/uplink/hidden
	name = "hidden uplink"
	desc = "There is something wrong if you're examining this."
	var/active = 0

// The hidden uplink MUST be inside an obj/item's contents.
/obj/item/device/uplink/hidden/New()
	spawn(2)
		if(!istype(src.loc, /obj/item))
			qdel(src)
	..()

// Toggles the uplink on and off. Normally this will bypass the item's normal functions and go to the uplink menu, if activated.
/obj/item/device/uplink/hidden/proc/toggle()
	active = !active

// Directly trigger the uplink. Turn on if it isn't already.
/obj/item/device/uplink/hidden/proc/trigger(mob/user as mob)
	if(!active)
		toggle()
	interact(user)

// Checks to see if the value meets the target. Like a frequency being a traitor_frequency, in order to unlock a headset.
// If true, it accesses trigger() and returns 1. If it fails, it returns false. Use this to see if you need to close the
// current item's menu.
/obj/item/device/uplink/hidden/proc/check_trigger(mob/user as mob, var/value, var/target)
	if(value == target)
		trigger(user)
		return 1
	return 0

/*
	NANO UI FOR UPLINK WOOP WOOP
*/
/obj/item/device/uplink/hidden/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	var/title = "Remote Uplink"
	var/data[0]

	data["welcome"] = welcome
	data["crystals"] = uses
	data["menu"] = nanoui_menu
	data["descriptions"] = show_descriptions
	if(!nanoui_items)
		generate_items(user)
	data["nano_items"] = nanoui_items
	data += nanoui_data

	// update the ui if it exists, returns null if no ui is passed/found
	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if(!ui)
		// the ui does not exist, so we'll create a new() one
        // for a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, "uplink.tmpl", title, 700, 600, state = inventory_state)
		// when the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// open the new ui window
		ui.open()


// Interaction code. Gathers a list of items purchasable from the paren't uplink and displays it. It also adds a lock button.
/obj/item/device/uplink/hidden/interact(mob/user)
	ui_interact(user)

// The purchasing code.
/obj/item/device/uplink/hidden/Topic(href, href_list)
	if(usr.stat || usr.restrained())
		return 1

	if(!( istype(usr, /mob/living/carbon/human)))
		return 1
	var/mob/user = usr
	var/datum/nanoui/ui = nanomanager.get_open_ui(user, src, "main")
	if((usr.contents.Find(src.loc) || (in_range(src.loc, usr) && istype(src.loc.loc, /turf))))
		usr.set_machine(src)
		if(..(href, href_list))
			return 1
		else if(href_list["lock"])
			toggle()
			ui.close()
			return 1
		if(href_list["return"])
			nanoui_menu = round(nanoui_menu/10)
			update_nano_data()
		if(href_list["menu"])
			nanoui_menu = text2num(href_list["menu"])
			update_nano_data(href_list["id"])
		if(href_list["menu"])
			nanoui_menu = text2num(href_list["menu"])
			update_nano_data(href_list["id"])
		if(href_list["descriptions"])
			show_descriptions = !show_descriptions
			update_nano_data()

	nanomanager.update_uis(src)
	return 1

/obj/item/device/uplink/hidden/proc/update_nano_data(var/id)
	if(nanoui_menu == 1)
		var/permanentData[0]
		for(var/datum/data/record/L in sortRecord(data_core.general))
			permanentData[++permanentData.len] = list(Name = sanitize_local(L.fields["name"]),"id" = L.fields["id"])
		nanoui_data["exploit_records"] = permanentData

	if(nanoui_menu == 11)
		nanoui_data["exploit_exists"] = 0

		for(var/datum/data/record/L in data_core.general)
			if(L.fields["id"] == id)
				nanoui_data["exploit"] = list()  // Setting this to equal L.fields passes it's variables that are lists as reference instead of value.
				nanoui_data["exploit"]["name"] =  lhtml_encode(L.fields["name"])
				nanoui_data["exploit"]["sex"] =  lhtml_encode(L.fields["sex"])
				nanoui_data["exploit"]["age"] =  lhtml_encode(L.fields["age"])
				nanoui_data["exploit"]["species"] =  lhtml_encode(L.fields["species"])
				nanoui_data["exploit"]["rank"] =  lhtml_encode(L.fields["rank"])
				nanoui_data["exploit"]["fingerprint"] =  lhtml_encode(L.fields["fingerprint"])

				nanoui_data["exploit_exists"] = 1
				break

// I placed this here because of how relevant it is.
// You place this in your uplinkable item to check if an uplink is active or not.
// If it is, it will display the uplink menu and return 1, else it'll return false.
// If it returns true, I recommend closing the item's normal menu with "user << browse(null, "window=name")"
/obj/item/proc/active_uplink_check(mob/user as mob)
	// Activates the uplink if it's active
	if(src.hidden_uplink)
		if(src.hidden_uplink.active)
			src.hidden_uplink.trigger(user)
			return 1
	return 0

//Refund proc for the borg teleporter (later I'll make a general refund proc if there is demand for it)
/obj/item/device/radio/uplink/attackby(obj/item/weapon/W as obj, mob/user as mob, params)
	if(istype(W, /obj/item/weapon/antag_spawner/borg_tele))
		var/obj/item/weapon/antag_spawner/borg_tele/S = W
		if(!S.used && !S.checking)
			hidden_uplink.uses += S.TC_cost
			qdel(S)
			to_chat(user, "<span class='notice'>Teleporter refunded.</span>")
		else
			to_chat(user, "<span class='notice'>This teleporter is already used, or is currently being used.</span>")

// PRESET UPLINKS
// A collection of preset uplinks.
//
// Includes normal radio uplink, multitool uplink,
// implant uplink (not the implant tool) and a preset headset uplink.

/obj/item/device/radio/uplink/New()
	hidden_uplink = new(src)
	icon_state = "radio"

/obj/item/device/radio/uplink/attack_self(mob/user as mob)
	if(hidden_uplink)
		hidden_uplink.trigger(user)

/obj/item/device/multitool/uplink/New()
	hidden_uplink = new(src)

/obj/item/device/multitool/uplink/attack_self(mob/user as mob)
	if(hidden_uplink)
		hidden_uplink.trigger(user)

/obj/item/device/radio/headset/uplink
	traitor_frequency = 1445

/obj/item/device/radio/headset/uplink/New()
	..()
	hidden_uplink = new(src)
	hidden_uplink.uses = 20
