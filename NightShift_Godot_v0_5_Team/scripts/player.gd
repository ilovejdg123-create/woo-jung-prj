extends CharacterBody3D
class_name NSPlayer

var game: Node3D
var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var hands: Array[Node3D] = []
var held: Array = [null, null]
var arms: Array = []
var legs: Array = []
var hand_home = [Vector3(-0.32, -0.30, -0.64), Vector3(0.32, -0.30, -0.64)]
var pressed = [false, false]
var busy = false
var target: NSInteractable
var stride = 0.0
var foot_timer = 0.0
var bob_enabled = true
var sensitivity = 0.0022
var tuning: Resource = preload("res://visuals/player/MovementTuning.tres")

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	head = Node3D.new()
	add_child(head)
	head.position.y = 1.66
	camera = Camera3D.new()
	head.add_child(camera)
	camera.current = true
	camera.fov = tuning.fov
	camera.near = 0.04
	ray = RayCast3D.new()
	camera.add_child(ray)
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collision_mask = 3
	ray.add_exception(self)
	ray.enabled = true
	var body = load("res://visuals/player/PlayerBody.tscn").instantiate()
	add_child(body)
	legs = [body.get_node("LeftLeg"), body.get_node("RightLeg")]
	for i in range(2):
		var hand = load("res://visuals/player/LeftHand.tscn" if i == 0 else "res://visuals/player/RightHand.tscn").instantiate()
		camera.add_child(hand)
		hand.position = hand_home[i]
		hands.append(hand)
		var pair = []
		for part in ["UpperArm", "ForeArm"]:
			var mesh = MeshInstance3D.new()
			mesh.mesh = load("res://visuals/player/" + part + "Mesh.tres")
			mesh.material_override = load("res://visuals/player/Sleeve.tres" if part == "UpperArm" else "res://visuals/player/Skin.tres")
			camera.add_child(mesh)
			pair.append(mesh)
		arms.append(pair)

func _unhandled_input(event: InputEvent) -> void:
	if game.modal_open or game.ended:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sensitivity, -1.38, 1.25)
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var index = 0 if event.button_index == MOUSE_BUTTON_LEFT else 1
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		pressed[index] = event.pressed
		if event.pressed:
			use_hand(index)
		else:
			release_hand(index)

func _physics_process(delta: float) -> void:
	if game.modal_open or game.ended:
		velocity = Vector3.ZERO
		for i in range(2):
			if held[i] and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if i == 0 else MOUSE_BUTTON_RIGHT):
				pressed[i] = false
				release_hand(i)
		return
	var axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var direction = transform.basis * Vector3(axis.x, 0, axis.y)
	var speed = tuning.run_speed if Input.is_physical_key_pressed(KEY_SHIFT) else tuning.walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 16)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 16)
	if not is_on_floor():
		velocity.y -= delta * 16.0
	else:
		velocity.y = -0.3
	# Step-up only for an actual low obstacle, with overhead clearance.
	var motion = Vector3(velocity.x, 0, velocity.z) * delta
	if is_on_floor() and motion.length() > 0.001 and test_move(global_transform, motion):
		var raised = global_transform
		raised.origin.y += 0.21
		if not test_move(global_transform, Vector3.UP * 0.21) and not test_move(raised, motion):
			global_position.y += 0.21
	move_and_slide()
	var moving = Vector2(velocity.x, velocity.z).length() > 0.15 and is_on_floor()
	if moving:
		stride += delta * speed * tuning.stride_rate
		foot_timer += delta * speed
		if foot_timer > 1.15:
			foot_timer = 0.0
			game.play_step(global_position.z > 6 or absf(global_position.x) > 7)
	legs[0].rotation.x = sin(stride) * tuning.leg_swing if moving else lerpf(legs[0].rotation.x, 0, delta * 12)
	legs[1].rotation.x = -sin(stride) * tuning.leg_swing if moving else lerpf(legs[1].rotation.x, 0, delta * 12)
	var running = moving and Input.is_physical_key_pressed(KEY_SHIFT)
	var bob_amount = tuning.run_bob if running else tuning.head_bob
	var bob_target = sin(stride * 2) * bob_amount if moving and bob_enabled else 0.0
	camera.position.y = lerpf(camera.position.y, bob_target, 1.0 - exp(-delta * 18))
	camera.position.x = lerpf(camera.position.x, sin(stride) * bob_amount * 0.6 if moving and bob_enabled else 0.0, 1.0 - exp(-delta * 12))
	camera.rotation.z = lerp_angle(camera.rotation.z, sin(stride) * tuning.run_roll if running and bob_enabled else 0.0, 1.0 - exp(-delta * 10))
	for i in range(2):
		var sign_x = -1.0 if i == 0 else 1.0
		var shoulder = Vector3(sign_x * 0.24, -0.28, 0.09)
		var wrist = hands[i].position + Vector3(0, 0, 0.12)
		var elbow = shoulder.lerp(wrist, 0.5) + Vector3(sign_x * 0.10, -0.18, 0.04)
		segment(arms[i][0], shoulder, elbow)
		segment(arms[i][1], elbow, wrist)
	ray.force_raycast_update()
	target = ray.get_collider() as NSInteractable if ray.is_colliding() else null
	for i in range(2):
		if held[i] and target and target.kind == "scanner" and not held[i].scanned:
			game.interact(target, i)
	if target and target.disabled:
		target = null

func segment(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var direction = b - a
	mesh.position = (a + b) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
	mesh.scale = Vector3(1, direction.length(), 1)

func use_hand(index: int) -> void:
	if busy or not target:
		return
	var obj = target
	if not game.can_interact(obj, index):
		return
	busy = true
	var point = camera.to_local(ray.get_collision_point())
	point = point.limit_length(1.0)
	var tween = create_tween()
	tween.tween_property(hands[index], "position", point, 0.16).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if is_instance_valid(obj) and (obj.kind != "pickup" or pressed[index]):
		game.interact(obj, index)
	var back = create_tween()
	back.tween_property(hands[index], "position", hand_home[index], 0.22).set_trans(Tween.TRANS_SINE)
	await back.finished
	busy = false

func take(item: NSInteractable, index: int) -> void:
	held[index] = item
	item.collision_layer = 0
	item.reparent(hands[index])
	item.position = Vector3(0, 0, -0.07)
	item.rotation = Vector3.ZERO

func put(index: int, pos: Vector3) -> NSInteractable:
	var item = held[index] as NSInteractable
	if not item:
		return null
	held[index] = null
	item.reparent(game.world)
	item.global_position = pos
	item.rotation = Vector3.ZERO
	item.collision_layer = 3
	return item

func release_hand(index: int) -> void:
	if not held[index]:
		return
	if target and target.kind in ["slot", "surface", "bin"] and game.can_interact(target, index):
		game.interact(target, index)
		if not held[index]:
			return
	# Drop onto the nearest world surface below the hand, without throwing through walls.
	var item = held[index] as NSInteractable
	var origin = hands[index].global_position
	var query = PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 5, 1)
	query.exclude = [get_rid(), item.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var pos = hit.position + Vector3.UP * (item.size.y * 0.5 + 0.02) if not hit.is_empty() else Vector3(origin.x, item.size.y * 0.5 + 0.04, origin.z)
	put(index, pos)
	game.play_sound("place")
