extends Node3D

var world: Node3D
var editable_layout_enabled := false
var editable_layout: Node3D
var player: NSPlayer
var time: NSTimeManager
var tasks: NSTaskManager
var customer: NSCustomer
var cctv: NSCCTV
var environment: Environment
var registry: Dictionary = {}
var store_lights: Array = []
var power_on = true
var lights_on = true
var modal_open = true
var ended = false
var reading_rules = false
var pending_autosave = false
var front_right_panel: StaticBody3D
var sensor_delay = 0.0
var door_clear_time = 0.0
var motor: AudioStreamPlayer3D
var hud: CanvasLayer
var clock_label: Label
var task_label: Label
var prompt_label: Label
var hands_label: Label
var message_label: Label
var modal: PanelContainer
var modal_title: Label
var modal_text: Label
var modal_buttons: VBoxContainer
var reticle: Label
var toast_time = 0.0
var door_tweens: Dictionary = {}
var audio: AudioStreamPlayer
var receipt_count = 0
const RULES = "심야 근무 기본 수칙\n\n01   근무 시간은 00:00부터 07:00까지입니다\n02   창고의 음료를 냉장고의 녹색 칸에 채워 주세요\n03   손님 상품을 집어 스캐너에 대고 POS로 결제하세요\n04   쓰레기는 뒷문 밖 쓰레기장에 버려 주세요\n05   정전 시 건물 뒤 차단기를 확인하세요\n\n현재 버전에는 괴담이나 공포 이벤트가 없습니다\n종이를 확인한 뒤 버튼 또는 마우스 클릭으로 돌려놓으세요"

func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	if editable_layout_enabled:
		var layout_scene := load("res://scenes/store_editable.tscn") as PackedScene
		if layout_scene:
			editable_layout = layout_scene.instantiate() as Node3D
			world.add_child(editable_layout)
	time = NSTimeManager.new()
	time.name = "TimeManager"
	add_child(time)
	time.running = false
	tasks = NSTaskManager.new()
	tasks.name = "TaskManager"
	add_child(tasks)
	NSWorldBuilder.new().build(self)
	player = NSPlayer.new()
	player.name = "Player"
	player.game = self
	add_child(player)
	player.position = Vector3(-5.85, 0.05, 2.0)
	player.rotation.y = -PI / 2
	customer = load("res://gameplay/customer/Customer.tscn").instantiate()
	customer.name = "Customer"
	customer.game = self
	world.add_child(customer)
	cctv = NSCCTV.new()
	cctv.name = "CCTV"
	add_child(cctv)
	cctv.setup(self)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	make_ambience()
	build_ui()
	time.hour_changed.connect(func(_hour): pending_autosave = true)
	time.shift_finished.connect(finish_shift)
	open_menu(true)

func make_interactable(id: String, title: String, kind: String, pos: Vector3, size: Vector3, color: Color) -> NSInteractable:
	var obj = NSInteractable.new()
	obj.name = id
	world.add_child(obj)
	obj.setup(id, title, kind, size, color)
	var final_pos := pos
	if editable_layout_enabled and is_instance_valid(editable_layout):
		var marker := editable_layout.find_child("I_" + id, true, false) as Node3D
		if marker:
			final_pos = marker.global_position
	obj.position = final_pos
	obj.home = obj.global_transform
	registry[id] = obj
	return obj

func _process(delta: float) -> void:
	if not is_instance_valid(clock_label):
		return
	clock_label.text = "NIGHT / 24     %s   →   07:00\n%s" % [time.clock(), "TEST · 30×" if time.speed > 1 else "심야 근무  /  실제 3시간"]
	task_label.text = tasks.summary()
	hands_label.text = "LMB · 왼손  %s       RMB · 오른손  %s" % [player.held[0].title if player.held[0] else "비어 있음", player.held[1].title if player.held[1] else "비어 있음"]
	prompt_label.text = player.target.prompt() if player.target and not modal_open else ""
	reticle.modulate = Color("72f4cd") if player.target else Color(1, 1, 1, 0.6)
	toast_time = maxf(0.0, toast_time - delta)
	message_label.visible = toast_time > 0
	if modal_open or ended:
		return
	var front = registry["front_door"] as NSInteractable
	var entrance = Vector3(0, 0, 6)
	var detected = absf(player.position.x) < 1.85 and absf(player.position.z - 6) < 2.2
	if customer.visible and absf(customer.position.x) < 1.85 and absf(customer.position.z - 6) < 2.2:
		detected = true
	if power_on:
		if detected:
			sensor_delay += delta
			door_clear_time = 0.0
			if (sensor_delay >= 0.45 or front.position.x < -0.8) and not front.door_open:
				set_door(front, true)
		else:
			sensor_delay = 0.0
			door_clear_time += delta
			if front.door_open and door_clear_time >= 3.0:
				set_door(front, false)
	var dawn = clampf((time.minutes - 320.0) / 100.0, 0, 1)
	environment.background_color = Color("07101c").lerp(Color("536774"), dawn)
	environment.ambient_light_energy = lerpf(0.35, 0.67, dawn)
	if pending_autosave and not player.busy:
		pending_autosave = false
		save_game(true)

func _unhandled_input(event: InputEvent) -> void:
	if reading_rules and event is InputEventMouseButton and event.pressed and not player.busy:
		resume()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if player.busy:
				return
			if modal_open and not ended:
				resume()
			elif not ended:
				open_menu(false)
		KEY_F1:
			if not player.busy and not ended:
				show_help()
		KEY_F5:
			if not modal_open and not player.busy and not ended:
				save_game()
		KEY_F9:
			if not player.busy:
				load_game()
		KEY_F6:
			if not modal_open and not ended:
				time.speed = 30.0 if time.speed == 1.0 else 1.0
				toast("테스트 배속 %s" % ("30×" if time.speed > 1 else "1×"))
		KEY_F7:
			if not modal_open and not player.busy and not ended:
				time.advance(60.0)
		KEY_B:
			player.bob_enabled = not player.bob_enabled
			toast("Head bob %s" % ("ON" if player.bob_enabled else "OFF"))

func can_interact(obj: NSInteractable, index: int) -> bool:
	var item = player.held[index] as NSInteractable
	if obj.kind == "pickup" and item:
		toast("이 손이 차 있습니다 · 작업대에 먼저 내려놓으세요")
		return false
	if obj.kind in ["slot", "surface", "bin", "scanner"] and not item:
		toast("물건을 든 손으로 클릭하세요")
		return false
	if obj.kind in ["door", "rules", "phone", "breaker", "switch", "cctv", "pos", "microwave", "sink", "drawer", "appliance"] and item:
		toast("비어 있는 손으로 조작하세요")
		return false
	return not obj.disabled

func interact(obj: NSInteractable, index: int) -> void:
	var item = player.held[index] as NSInteractable
	match obj.kind:
		"pickup":
			# Clear the slot this object previously occupied.
			for other in registry.values():
				if other.occupied_by == obj.stable_id:
					other.occupied_by = ""
			player.take(obj, index)
			if obj.item_type == "stock_drink":
				var count = 0
				for other in registry.values():
					if other.kind == "slot" and other.occupied_by != "":
						count += 1
				tasks.progress.stock = count
			play_sound("pick")
		"slot", "surface":
			if not item:
				return
			if obj.occupied_by != "":
				toast("이미 물건이 놓여 있습니다")
				return
			if obj.kind == "slot" and item.item_type != "stock_drink":
				toast("이 칸에는 창고 음료만 진열할 수 있습니다")
				return
			player.put(index, obj.global_position + Vector3(0, obj.size.y * 0.5 + item.size.y * 0.5 + 0.01, 0))
			obj.occupied_by = item.stable_id
			if obj.kind == "slot":
				var occupied = 0
				for other in registry.values():
					if other.kind == "slot" and other.occupied_by != "":
						occupied += 1
				tasks.progress.stock = occupied
				toast("냉장고 진열 %d/3" % occupied)
				pending_autosave = true
			play_sound("place")
		"door":
			if obj.stable_id == "front_door":
				toast("자동문 · 센서 감지로 열립니다")
			else:
				set_door(obj, not obj.door_open)
		"scanner":
			if not power_on:
				toast("전원이 없습니다 · 차단기를 확인하세요")
			elif item and item.item_type == "order" and customer.state == "waiting":
				item.scanned = true
				toast("상품 스캔 완료 · 빈손으로 POS를 누르세요")
				play_sound("beep")
			else:
				toast("현재 손님의 구매 상품만 계산할 수 있습니다")
		"pos":
			var order = registry["order"] as NSInteractable
			if not power_on:
				toast("POS 전원 꺼짐")
			elif customer.state != "waiting" or not order.scanned:
				toast("손님 상품을 먼저 스캔하세요")
			else:
				for i in range(2):
					if player.held[i] == order:
						player.put(i, order.home.origin)
				for other in registry.values():
					if other.occupied_by == "order":
						other.occupied_by = ""
				order.set_active(false)
				customer.paid()
				tasks.record("sale")
				receipt_count += 1
				toast("결제 완료 · 2,000원 · 손님이 상품을 가져갑니다")
				play_sound("beep")
				pending_autosave = true
		"bin":
			if item and item.item_type == "trash":
				player.put(index, obj.global_position)
				item.set_active(false)
				tasks.record("trash")
				toast("쓰레기 처리 완료")
				play_sound("place")
				pending_autosave = true
			else:
				toast("쓰레기 봉투만 버릴 수 있습니다")
		"switch":
			lights_on = not lights_on
			apply_lights()
			play_sound("click")
		"breaker":
			power_on = not power_on
			tasks.record("power")
			apply_lights()
			toast("차단기 %s · 다시 누르면 전환됩니다" % ("ON" if power_on else "OFF"))
			play_sound("click")
		"rules":
			reading_rules = true
			obj.reparent(player.camera)
			obj.position = Vector3(0.58, -0.13, -0.85)
			obj.rotation = Vector3.ZERO
			obj.collision_layer = 0
			show_modal("근무 규칙표", RULES)
			add_button("종이 내려놓기 / 계속 근무", resume)
		"cctv":
			if power_on:
				cctv.select(cctv.channel + 1)
				toast("CCTV · CAM %02d" % (cctv.channel + 1))
				play_sound("click")
			else:
				toast("CCTV 전원이 꺼져 있습니다")
		"phone":
			toast("수화기를 들었습니다 · 연결음만 들립니다")
			play_sound("phone")
		"microwave":
			if power_on:
				toast("전자레인지 작동 중…")
				get_tree().create_timer(3.0).timeout.connect(func(): play_sound("beep"))
			else:
				toast("전원이 없습니다")
		"drawer":
			obj.door_open = not obj.door_open
			obj.visual.position.z = 0.22 if obj.door_open else 0.0
			play_sound("place")
		"appliance":
			obj.door_open = not obj.door_open
			obj.visual.position.z = -0.6 if obj.door_open else 0.0
			play_sound("place")
		"sink":
			toast("수도 사용 · 손을 씻었습니다")
			play_sound("water")

func set_door(obj: NSInteractable, opened: bool, instant: bool = false) -> void:
	obj.door_open = opened
	if door_tweens.has(obj.stable_id) and is_instance_valid(door_tweens[obj.stable_id]):
		door_tweens[obj.stable_id].kill()
	if obj.stable_id == "front_door":
		var x_left = -1.95 if opened else -0.65
		var x_right = 1.95 if opened else 0.65
		if instant:
			obj.position.x = x_left
			front_right_panel.position.x = x_right
		else:
			var slide = create_tween().set_parallel(true)
			door_tweens[obj.stable_id] = slide
			slide.tween_property(obj, "position:x", x_left, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			slide.tween_property(front_right_panel, "position:x", x_right, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if not is_instance_valid(motor):
				motor = AudioStreamPlayer3D.new()
				world.add_child(motor)
				motor.position = Vector3(0, 2.8, 6)
				motor.stream = load("res://assets/door_motor.wav")
				motor.volume_db = -12
				motor.max_distance = 15
			motor.play()
		return
	var angle = deg_to_rad(-95.0) if opened else 0.0
	if instant:
		obj.pivot.rotation.y = angle
	else:
		var tw = create_tween()
		door_tweens[obj.stable_id] = tw
		tw.tween_property(obj.pivot, "rotation:y", angle, 0.38).set_trans(Tween.TRANS_SINE)
		play_sound("door")

func apply_lights() -> void:
	for light in store_lights:
		light.visible = power_on and lights_on

func save_game(automatic: bool = false) -> void:
	var result = NSSaveManager.write(self)
	toast(("자동 저장 완료" if automatic else "저장 완료 · F9 불러오기") if result == OK else "저장 실패 · 오류 %d" % result)

func load_game() -> void:
	var result = NSSaveManager.read_into(self)
	if result == OK:
		if ended:
			finish_shift()
		else:
			resume()
		toast("저장한 근무를 불러왔습니다 · 배속 1×")
	else:
		toast("저장 파일이 없습니다" if result == ERR_FILE_NOT_FOUND else "저장 파일을 읽을 수 없습니다 · 오류 %d" % result)

func finish_shift() -> void:
	ended = true
	time.running = false
	show_modal("07:00   근무 종료", "교대 시간이 되었습니다\n\n" + tasks.summary() + "\n기본 근무 클리어 · 공포 이벤트 없는 프로토타입\n업무는 연습용이며 미완료여도 07:00에 종료됩니다")
	add_button("처음부터 새 근무", restart)
	add_button("종료", quit_game)

func restart() -> void:
	stop_audio()
	await get_tree().create_timer(0.12).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func resume() -> void:
	if ended:
		return
	modal_open = false
	if reading_rules:
		var paper = registry["rules"] as NSInteractable
		paper.reparent(world)
		paper.global_transform = paper.home
		paper.collision_layer = 3
	reading_rules = false
	modal.visible = false
	time.running = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_menu(first: bool) -> void:
	show_modal("NIGHT / 24", "00:00 — 07:00\n심야 편의점 · 플레이 가능한 시스템 프로토타입\n\n왼쪽 버튼을 누르는 동안 왼손 / 오른쪽 버튼을 누르는 동안 오른손\n가운데 점을 물체에 맞추면 조작 안내가 나옵니다\n\n기본 근무 3시간 · F6 테스트 배속 · F7 한 시간 건너뛰기")
	add_button("00:00 근무 시작" if first else "근무 계속", resume)
	add_button("저장한 근무 불러오기", load_game, not FileAccess.file_exists(NSSaveManager.PATH))
	if not first:
		add_button("현재 근무 저장", save_game)
	add_button("조작법 / 구현 범위", show_help)
	add_button("종료", quit_game)

func show_help() -> void:
	show_modal("조작 안내", "WASD 이동 · 마우스 시점 · Shift 빠르게 걷기\n왼쪽 클릭 = 왼손 / 오른쪽 클릭 = 오른손\n잡은 버튼을 유지하며 진열 칸·작업대를 향해 놓으세요\n스캐너는 든 상품을 가까이 가져가세요\n문·스위치·POS·CCTV는 비어 있는 손을 사용하세요\n\nF5 저장 / F9 불러오기 / Esc 일시정지\nF6 30배속 전환 / F7 게임 속 1시간 건너뛰기\nB 미세한 시점 흔들림 켜기·끄기 / F1 도움말\n\n업무: 창고 음료 → 냉장고 / 쓰레기 → 뒷골목\n계산: 손님 음료 집기 → 스캐너 → 빈손으로 POS\nCCTV 화면 클릭으로 5개 카메라 전환\n\n임시 모델 · 절차적 팔/다리 동작 · 합성 사운드\n전화·수도·전자레인지는 간소화 구현\nNPC는 고정 경로 1명 / 공포·멀티엔딩은 아직 없음")
	add_button("근무 시작 / 계속", resume)

func show_modal(title: String, body: String) -> void:
	modal_open = true
	time.running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal.visible = true
	modal_title.text = title
	modal_text.text = body
	for child in modal_buttons.get_children():
		modal_buttons.remove_child(child)
		child.queue_free()

func add_button(title: String, action: Callable, disabled: bool = false) -> void:
	var b = Button.new()
	b.text = title
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(action)
	modal_buttons.add_child(b)

func toast(message: String) -> void:
	if message_label:
		message_label.text = message
		toast_time = 4.5

func build_ui() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root = Control.new()
	hud.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font_size = 19
	var font = FontVariation.new()
	font.base_font = load("res://assets/NotoSansKR.ttf")
	font.variation_opentype = {"wght": 500}
	font.variation_embolden = 0.7
	theme.default_font = font
	root.theme = theme
	clock_label = ui_label(root, Vector2(28, 22), "", 24, Color("9ef5d6"))
	task_label = ui_label(root, Vector2(28, 110), "", 18, Color("d4dfdc"))
	var hint = ui_label(root, Vector2.ZERO, "WASD  이동     SHIFT  빠른 걸음     F1  도움말     ESC  일시정지", 16, Color("acbebd"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 28
	hint.offset_top = -42
	hint.offset_right = 850
	hint.offset_bottom = -16
	hands_label = ui_label(root, Vector2.ZERO, "", 18, Color("d8e7e2"))
	hands_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hands_label.offset_left = 28
	hands_label.offset_top = -79
	hands_label.offset_right = 1300
	hands_label.offset_bottom = -48
	reticle = ui_label(root, Vector2.ZERO, "+", 22, Color.WHITE)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -7
	reticle.offset_top = -17
	reticle.offset_right = 7
	reticle.offset_bottom = 17
	prompt_label = ui_label(root, Vector2.ZERO, "", 21, Color("bdf8dc"))
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.offset_left = -300
	prompt_label.offset_top = 38
	prompt_label.offset_right = 300
	prompt_label.offset_bottom = 78
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label = ui_label(root, Vector2.ZERO, "", 20, Color("ffd1a1"))
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_left = -450
	message_label.offset_top = 24
	message_label.offset_right = 450
	message_label.offset_bottom = 60
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal = PanelContainer.new()
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -350
	modal.offset_top = -340
	modal.offset_right = 350
	modal.offset_bottom = 340
	modal.custom_minimum_size = Vector2(700, 620)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.065, 0.98)
	panel_style.border_color = Color("537e78")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 28
	modal.add_theme_stylebox_override("panel", panel_style)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	modal.add_child(column)
	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 34)
	modal_title.add_theme_color_override("font_color", Color("a0f0d8"))
	column.add_child(modal_title)
	modal_text = Label.new()
	modal_text.add_theme_font_size_override("font_size", 18)
	modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_text.custom_minimum_size.x = 620
	column.add_child(modal_text)
	modal_buttons = VBoxContainer.new()
	modal_buttons.add_theme_constant_override("separation", 8)
	column.add_child(modal_buttons)

func ui_label(parent: Control, pos: Vector2, value: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	parent.add_child(label)
	label.position = pos
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func play_sound(sound_name: String) -> void:
	var path = "res://assets/" + sound_name + ".wav"
	if ResourceLoader.exists(path):
		audio.stream = load(path)
		audio.volume_db = -13
		audio.play()

func play_step(outside: bool) -> void:
	play_sound("step_out" if outside else "step_in")

func make_ambience() -> void:
	for pos in [Vector3(-0.8, 1.2, -4), Vector3(6, 1, 4)]:
		var a = AudioStreamPlayer3D.new()
		world.add_child(a)
		a.position = pos
		a.stream = load("res://assets/hum.wav")
		a.volume_db = -22
		a.unit_size = 3
		a.max_distance = 14
		a.play()
	var outside = AudioStreamPlayer3D.new()
	world.add_child(outside)
	outside.position = Vector3(0, 1, 12)
	outside.stream = load("res://assets/wind.wav")
	outside.volume_db = -25
	outside.unit_size = 8
	outside.max_distance = 35
	outside.play()

func stop_audio() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	for child in world.get_children():
		if child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null

func quit_game() -> void:
	stop_audio()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
