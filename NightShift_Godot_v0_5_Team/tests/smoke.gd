extends SceneTree

var failures = 0
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false) # prevent test tasks from triggering the real autosave slot
	await process_frame
	await physics_frame
	check(game.world.has_node("EnvironmentVisual"), "Editable environment visual scene loaded")
	check(game.customer.animator.has_animation("idle") and game.customer.animator.has_animation("walk") and game.customer.animator.has_animation("run"), "Visual animation contract exists")
	check(is_equal_approx(game.player.tuning.run_speed, 5.0), "Player tuning resource loaded")
	check(game.customer.has_node("Visual/CustomerFace/PhotoFace"), "Original face photo material exists")
	check(game.registry.pos.position.x < -4 and is_equal_approx(game.registry.pos.rotation.y, -PI / 2), "Left counter POS faces clerk on west side")
	check(game.registry.cctv.position.z > game.registry.pos.position.z, "CCTV is to clerk right")
	check(game.customer.has_node("Visual/CustomerFace"), "Modeled customer face exists")
	check(game.registry.pos.size.z > 0 and game.registry.scanner.size.z > 0 and game.registry.rules.size.z > 0, "Counter device dimensions are positive")
	check(game.registry.pos.global_position.distance_to(game.registry.scanner.global_position) > 0.7, "POS and scanner are separated")
	check(game.registry.size() >= 30, "World and all interactable IDs built")
	check(game.player.hands.size() == 2 and game.player.legs.size() == 2, "Visible body and independent hands exist")
	game.resume()
	game.time.running = false
	game.customer.set_process(false)
	# Door sensor timing and actual sliding panels.
	var initial_position = game.player.position
	game.player.set_physics_process(false)
	game.player.position = Vector3(0, 0.04, 7.5)
	game.customer.visible = false
	game.sensor_delay = 0
	game.set_door(game.registry.front_door, false, true)
	game._process(0.2)
	check(not game.registry.front_door.door_open, "Sensor delay does not open instantly")
	game._process(0.3)
	check(game.registry.front_door.door_open, "Sensor opens after recognition delay")
	game.set_door(game.registry.front_door, true, true)
	check(is_equal_approx(game.registry.front_door.position.x, -1.95) and is_equal_approx(game.front_right_panel.position.x, 1.95), "Two door panels slide apart")
	game.player.position = Vector3(0, 0.04, 11)
	game._process(2.0)
	check(game.registry.front_door.door_open, "Door holds open after leaving sensor")
	game._process(1.1)
	check(not game.registry.front_door.door_open, "Door closes after clear interval")
	game.player.position = Vector3(0, 0.04, 6)
	game._process(0.05)
	check(game.registry.front_door.door_open, "Closing door reopens on obstruction")
	game.set_door(game.registry.front_door, false, true)
	game.player.position = initial_position
	game.player.set_physics_process(true)
	check(game.environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "Glass has sky reflection source")
	check(game.player.tuning.run_bob > game.player.tuning.head_bob, "Run bob tuning exceeds walking bob")

	# Exercise common interaction contract through both hands.
	var left = game.registry.drink_0
	var right = game.registry.drink_1
	check(game.can_interact(left, 0), "Empty hand can grab")
	game.interact(left, 0)
	game.interact(right, 1)
	check(game.player.held[0] == left and game.player.held[1] == right, "Two different items held simultaneously")
	check(not game.can_interact(game.registry.drink_2, 0), "Full hand cannot duplicate/pick another item")
	game.interact(game.registry.stock_slot_0, 0)
	game.interact(game.registry.stock_slot_1, 1)
	game.interact(game.registry.drink_2, 0)
	game.interact(game.registry.stock_slot_2, 0)
	check(game.tasks.progress.stock == 3, "Three stock slots complete task")
	check(left.get_parent() == game.world and left.collision_layer == 3, "Placed object restores parent and collision")
	# Storage door physically rotates, not just state.
	game.set_door(game.registry.stock_door, true, true)
	check(absf(game.registry.stock_door.pivot.rotation.y) > 1.0, "Door opens in actual world")
	game.set_door(game.registry.stock_door, false, true)
	check(is_zero_approx(game.registry.stock_door.pivot.rotation.y), "Door closes")
	# Complete a purchase including empty-hand POS restriction.
	game.customer.state = "waiting"
	game.customer.visible = true
	var order = game.registry.order
	order.set_active(true)
	game.interact(order, 1)
	game.interact(game.registry.scanner, 1)
	check(order.scanned, "Scanner reads held order")
	check(not game.can_interact(game.registry.pos, 1), "POS requires free hand")
	game.interact(game.registry.pos, 0)
	check(game.tasks.progress.sale == 1 and game.customer.state == "leave", "Payment completes and releases customer")
	check(order.disabled and game.player.held[1] == null, "Purchased item removed from hand without duplication")
	# Waste handling and supply switch.
	game.interact(game.registry.trash_bag, 0)
	game.interact(game.registry.bin, 0)
	check(game.tasks.progress.trash == 1 and game.registry.trash_bag.disabled, "Waste disposal")
	game.interact(game.registry.breaker, 0)
	check(not game.power_on and not game.store_lights[0].visible, "Breaker disables lighting")
	game.interact(game.registry.breaker, 0)
	game.cctv.select(4)
	check(game.cctv.channel == 4 and game.cctv.viewport.world_3d == game.get_world_3d(), "CCTV shares live world and switches to fifth view")
	# Save/load a nontrivial world with two held items, open door, customer in transit.
	game.interact(game.registry.drink_3, 0)
	game.interact(game.registry.drink_4, 1)
	game.set_door(game.registry.stock_door, true, true)
	game.customer.waypoint = 1
	game.time.minutes = 145.5
	var saved_position = game.player.position
	check(NSSaveManager.write(game, "user://smoke_save.json") == OK, "Save writes complete JSON")
	game.player.put(0, Vector3(9, 1, 9))
	game.player.put(1, Vector3(9, 1, 9))
	game.time.minutes = 0
	game.player.position = Vector3(15, 0, 0)
	game.tasks.progress.stock = 0
	game.set_door(game.registry.stock_door, false, true)
	check(NSSaveManager.read_into(game, "user://smoke_save.json") == OK, "Saved state loads")
	check(game.player.held[0] == game.registry.drink_3 and game.player.held[1] == game.registry.drink_4, "Both hand attachments restored")
	check(game.player.position.is_equal_approx(saved_position) and is_equal_approx(game.time.minutes, 145.5), "Position and clock restored")
	check(game.tasks.progress.stock == 3 and game.registry.stock_slot_0.occupied_by == "drink_0", "Task and slot occupancy restored")
	check(game.registry.stock_door.door_open and absf(game.registry.stock_door.pivot.rotation.y) > 1.0, "Door state restores actual rotation")
	check(game.customer.state == "leave" and game.customer.waypoint == 1, "NPC finite state and waypoint restored")
	var bad = FileAccess.open("user://smoke_corrupt.json", FileAccess.WRITE)
	bad.store_string("{bad")
	bad.close()
	check(NSSaveManager.read_into(game, "user://smoke_corrupt.json") == ERR_FILE_CORRUPT, "Corrupt save rejected")
	# Collision and ray reach check against a closed door and an empty aisle.
	game.player.put(0, Vector3(-1, 1.1, -7))
	game.player.put(1, Vector3(-0.5, 1.1, -7))
	game.set_door(game.registry.stock_door, false, true)
	game.player.position = Vector3(-4.3, 0.04, -3.8)
	game.player.rotation = Vector3.ZERO
	game.player.head.rotation.x = 0
	await physics_frame
	await physics_frame
	game.player.ray.force_raycast_update()
	check(game.player.ray.get_collider() == game.registry.stock_door, "Ray finds visible storage door")
	check(game.player.test_move(game.player.global_transform, Vector3(0, 0, -1.4)), "Closed door blocks player")
	game.set_door(game.registry.stock_door, true, true)
	await physics_frame
	check(not game.player.test_move(game.player.global_transform, Vector3(0, 0, -1.4)), "Opened doorway is passable")
	# Verify the real ray -> reach animation -> hold path, not just direct calls.
	game.player.position = Vector3(-2.0, 0.04, -5.9)
	game.player.head.look_at(game.registry.drink_5.global_position)
	# drink_5 is further away; use drink_3 repositioned to an unobstructed table location.
	game.registry.drink_3.global_position = Vector3(-2.0, 1.12, -7.3)
	game.player.head.look_at(game.registry.drink_3.global_position)
	await physics_frame
	await physics_frame
	check(game.player.target == game.registry.drink_3, "Ray detects stocked drink from actual first-person camera")
	game.player.pressed[0] = true
	game.player.use_hand(0)
	await create_timer(0.55).timeout
	check(game.player.held[0] == game.registry.drink_3 and not game.player.busy, "Animated Reach -> Grab -> Hold completes")
	game.player.pressed[0] = false
	game.player.release_hand(0)
	check(game.player.held[0] == null, "Release drops held item")
	# Simulate complete customer route through the defined aisles.
	game.player.position = Vector3(-6, 0.04, 4.2)
	game.customer.state = "idle"
	game.customer.next_visit = 0
	game.time.minutes = 160
	for step in range(5000):
		game.time.minutes += 0.002
		game.customer._process(0.02)
		if game.customer.state == "waiting":
			break
	check(game.customer.state == "waiting" and not game.registry.order.disabled, "Customer walks in, browses and presents an order")
	# Full-shift finish signal and time cap.
	game.time.running = true
	game.time.advance(1000)
	check(game.ended and game.time.minutes == 420 and not game.time.running, "07:00 caps clock and finishes shift")
	print("RESULT: %d/%d passed" % [checks - failures, checks])
	await create_timer(0.8).timeout
	game.stop_audio()
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
