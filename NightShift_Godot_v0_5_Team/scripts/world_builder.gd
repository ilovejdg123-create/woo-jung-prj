extends RefCounted
class_name NSWorldBuilder

var game: Node3D
var world: Node3D
var visual_loaded = false
const WALL = Color("67777d")
const DARK = Color("19262e")
const WHITE = Color("bcc9c7")
const TEAL = Color("63e2c8")
const AMBER = Color("f4b36b")

func build(owner_game: Node3D) -> void:
	game = owner_game
	world = game.world
	var visual = load("res://visuals/environment/EnvironmentVisual.tscn").instantiate()
	world.add_child(visual)
	visual_loaded = true
	var env = WorldEnvironment.new()
	world.add_child(env)
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("07101c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("7895b0")
	env.environment.ambient_light_energy = 0.35
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("091421")
	sky_material.sky_horizon_color = Color("637888")
	sky.sky_material = sky_material
	env.environment.sky = sky
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	game.environment = env.environment
	var moon = DirectionalLight3D.new()
	world.add_child(moon)
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.light_color = Color("92b5dd")
	moon.light_energy = 0.17
	moon.shadow_enabled = true
	# 46m x 44m walkable exterior, foreground paths kept deliberately compact.
	box(Vector3(0, -0.2, 0), Vector3(46, 0.3, 44), Color("202a32"))
	box(Vector3(0, -0.04, 0.5), Vector3(14, 0.12, 11), Color("8a999a"))
	box(Vector3(0, -0.04, -7), Vector3(14, 0.12, 4), Color("5b676d"))
	# Floor grid: visual only; no extra collision seams.
	for x in range(-7, 8):
		box(Vector3(x, 0.023, 0.5), Vector3(0.012, 0.004, 11), Color("697c7e"), false)
	for z in range(-5, 7):
		box(Vector3(0, 0.024, z), Vector3(14, 0.004, 0.012), Color("697c7e"), false)
	box(Vector3(-7, 1.65, -1.5), Vector3(0.2, 3.3, 15), WALL)
	box(Vector3(7, 1.65, -1.5), Vector3(0.2, 3.3, 15), WALL)
	# Rear wall with an exit gap at x=-4.7.
	box(Vector3(-6.35, 1.65, -9), Vector3(1.3, 3.3, 0.2), WALL)
	box(Vector3(1.6, 1.65, -9), Vector3(10.8, 3.3, 0.2), WALL)
	door("rear_door", "뒷문", marker_position("H_rear_door", Vector3(-5.7, 0, -9)), 1.9, false)
	# One walk-in behind the beverage wall; no restroom inside the store.
	box(Vector3(-6.15, 1.65, -5), Vector3(1.7, 3.3, 0.16), WALL)
	box(Vector3(1.8, 1.65, -5), Vector3(10.0, 3.3, 0.16), WALL)
	door("stock_door", "워크인 문", Vector3(-5.3, 0, -5), 1.9, false)
	box(Vector3(0, 3.35, -1.5), Vector3(14.2, 0.16, 15.2), Color("39494f"))
	# Front windows and central entrance.
	for x in [-4.15, 4.15]:
		box(Vector3(x, 0.43, 6), Vector3(5.7, 0.85, 0.16), DARK)
		box(Vector3(x, 1.8, 6), Vector3(5.7, 1.85, 0.05), Color(0.34, 0.61, 0.65, 0.22))
		box(Vector3(x, 3.0, 6), Vector3(5.7, 0.6, 0.2), DARK)
		for dx in [-2.7, 0, 2.7]:
			box(Vector3(x + dx, 1.8, 6), Vector3(0.06, 2.0, 0.12), DARK)
	sliding_entrance()
	box(Vector3(0, 3.02, 6.15), Vector3(14.5, 0.55, 0.3), Color("52318b"))
	label("Nice to   CU", Vector3(0, 3.03, 6.33), 90, Color("b6ee37"))
	label("24 HOURS   /   CONVENIENCE STORE", Vector3(0, 2.68, 6.32), 28, WHITE)
	# Lighting fixtures.
	for x in [-4.5, 0.0, 4.5]:
		for z in [-2.5, 3.0]:
			box(Vector3(x, 3.22, z), Vector3(1.8, 0.07, 0.2), Color("d8fff2"), false, 1.5)
			game.store_lights.append(NSGeometry.light(world, Vector3(x, 2.85, z), Color("d1eee1"), 0.8, 6.0))
	for x in [-3.5, 4.7]:
		game.store_lights.append(NSGeometry.light(world, Vector3(x, 2.7, -7), Color("b7dfda"), 0.7, 5))
	# Left of entrance; clerk looks across the shop toward +X.
	box(Vector3(-4.55, 0.50, 2.0), Vector3(0.85, 1.0, 3.6), Color("e0ded5"))
	box(Vector3(-4.55, 1.03, 2.0), Vector3(1.05, 0.08, 3.8), Color("343039"))
	box(Vector3(-4.10, 0.70, 2.0), Vector3(0.025, 0.09, 3.5), Color("b6ee37"), false)
	var pos = game.make_interactable("pos", "POS · 결제 처리", "pos", Vector3(-4.60, 1.38, 1.55), Vector3(0.55, 0.42, 0.12), DARK)
	pos.rotation.y = -PI / 2
	NSGeometry.text(pos, "CU POS\nREADY", Vector3(0, 0, 0.068), 20, TEAL)
	box(Vector3(-4.60, 1.18, 1.55), Vector3(0.13, 0.20, 0.13), DARK, false)
	box(Vector3(-4.60, 1.10, 1.55), Vector3(0.28, 0.04, 0.40), DARK, false)
	game.make_interactable("scanner", "바코드 스캐너", "scanner", Vector3(-4.35, 1.14, 2.35), Vector3(0.32, 0.14, 0.42), DARK)
	box(Vector3(-4.35, 1.22, 2.35), Vector3(0.18, 0.01, 0.06), Color("ef5555"), false, 1)
	game.make_interactable("counter_slot", "상품 작업대", "surface", Vector3(-4.30, 1.09, 2.95), Vector3(0.40, 0.025, 0.55), Color("8a9e91"))
	game.make_interactable("card", "카드 단말기", "pos", Vector3(-4.15, 1.17, 1.05), Vector3(0.23, 0.15, 0.28), DARK)
	game.make_interactable("drawer", "현금 서랍", "drawer", Vector3(-5.0, 0.85, 1.55), Vector3(0.12, 0.18, 0.6), DARK)
	game.make_interactable("phone", "전화기", "phone", Vector3(-4.65, 1.17, 0.55), Vector3(0.30, 0.17, 0.25), DARK)
	box(Vector3(-4.65, 1.28, 0.55), Vector3(0.28, 0.055, 0.09), DARK, false)
	var rules = game.make_interactable("rules", "근무 규칙표", "rules", Vector3(-6.88, 1.7, 1.5), Vector3(0.52, 0.68, 0.035), Color("ece5cd"))
	rules.rotation.y = PI / 2
	NSGeometry.text(rules, "STAFF\nRULES\n01 — 05", Vector3(0, 0, 0.024), 26, DARK)
	game.make_interactable("bag", "봉투", "pickup", Vector3(-4.8, 1.14, 3.25), Vector3(0.23, 0.1, 0.25), WHITE).item_type = "bag"
	box(Vector3(-6.65, 1.4, 2.0), Vector3(0.4, 1.7, 3.2), Color("5c5369"))
	for j in range(5):
		for k in range(12):
			box(Vector3(-6.4, 0.72 + j * 0.27, 0.6 + k * 0.25), Vector3(0.16, 0.22, 0.18), WHITE if k % 2 else Color("bb8570"), false)
	# Shelf islands with deliberate 1.5m+ aisles.
	for x in [-0.3, 3.1]:
		box(Vector3(x, 0.7, -0.5), Vector3(1.0, 1.4, 3.3), Color("3f5056"))
		for y in [0.35, 0.8, 1.28]:
			box(Vector3(x, y, -0.5), Vector3(1.22, 0.05, 3.45), WHITE)
			for z in [-1.8, -1.2, -0.6, 0.0, 0.6]:
				for dx in [-0.43, 0.43]:
					var color = Color("caa06b") if int(absf(z) * 10) % 2 else Color("77aaa0")
					box(Vector3(x + dx, y + 0.13, z), Vector3(0.22, 0.22, 0.27), color, false)
	label("01  /  DAILY", Vector3(-0.3, 1.65, 1.24), 28, WHITE)
	label("02  /  SNACKS", Vector3(3.1, 1.65, 1.24), 28, WHITE)
	# Rear-facing cooler shelves: stock targets face south (+Z).
	box(Vector3(-0.8, 1.05, -4.35), Vector3(3.8, 2.1, 0.9), Color("203b43"))
	for y in [0.35, 0.8, 1.3]:
		box(Vector3(-0.8, y, -3.8), Vector3(3.8, 0.055, 0.65), WHITE)
	for i in range(3):
		game.make_interactable("stock_slot_%d" % i, "음료 진열 %d" % (i+1), "slot", Vector3(-1.95 + i * 1.05, 1.36, -3.75), Vector3(0.55, 0.04, 0.50), Color("70b5a1"))
	label("COLD DRINKS  /  RESTOCK", Vector3(-0.8, 2.23, -3.82), 28, TEAL)
	NSGeometry.light(world, Vector3(-0.8, 1.8, -3.65), TEAL, 0.5, 3)
	# Microwave and freezer, independent interactions.
	box(Vector3(6.1, 0.47, 3.9), Vector3(1.25, 0.94, 2.3), WHITE)
	game.make_interactable("freezer", "냉동고 · 열기/닫기", "appliance", Vector3(6.1, 1.00, 3.9), Vector3(1.25, 0.1, 2.3), Color("75a3a7"))
	box(Vector3(5.95, 0.45, 1.9), Vector3(1.4, 0.9, 0.75), WALL)
	game.make_interactable("microwave", "전자레인지 · 3초 작동", "microwave", Vector3(5.95, 1.17, 1.9), Vector3(0.7, 0.45, 0.5), DARK)
	label("MICROWAVE", Vector3(5.95, 1.17, 2.16), 20, TEAL)
	# Storage shelves, supply drinks, waste bag and staff area.
	box(Vector3(-0.6, 0.45, -7.3), Vector3(3.4, 0.9, 0.8), Color("756859"))
	for i in range(6):
		var item = game.make_interactable("drink_%d" % i, "재고 음료 %d" % (i + 1), "pickup", Vector3(-2.0 + i * 0.52, 1.11, -7.3), Vector3(0.16, 0.30, 0.16), Color("d59c60") if i % 2 else TEAL)
		item.item_type = "stock_drink"
		NSGeometry.text(item, "N", Vector3(0, 0, 0.087), 24, DARK)
	var trash = game.make_interactable("trash_bag", "쓰레기 봉투", "pickup", Vector3(-6.15, 0.36, -7), Vector3(0.42, 0.65, 0.42), Color("20272d"))
	trash.item_type = "trash"
	box(Vector3(1.5, 1.15, -8.5), Vector3(0.9, 2.3, 0.7), Color("4e6a6b"))
	label("STAFF / STORAGE", Vector3(-1.3, 2.55, -8.87), 34, WHITE)
	# Detached rear restroom, accessible via the back alley.
	box(Vector3(6, -0.02, -14), Vector3(4, 0.12, 4), WHITE)
	box(Vector3(4, 1.5, -14), Vector3(0.18, 3, 4), WALL)
	box(Vector3(8, 1.5, -14), Vector3(0.18, 3, 4), WALL)
	box(Vector3(6, 1.5, -16), Vector3(4, 3, 0.18), WALL)
	box(Vector3(4.45, 1.5, -12), Vector3(0.9, 3, 0.18), WALL)
	box(Vector3(7.45, 1.5, -12), Vector3(1.1, 3, 0.18), WALL)
	box(Vector3(6, 3.05, -14), Vector3(4.2, 0.15, 4.2), DARK)
	door("toilet_door", "외부 화장실", Vector3(4.9, 0, -12), 2, false)
	label("RESTROOM", Vector3(6, 2.75, -11.87), 32, WHITE)
	box(Vector3(7, 0.34, -15), Vector3(0.55, 0.68, 0.8), WHITE)
	game.make_interactable("sink", "세면대 · 수도 사용", "sink", Vector3(4.8, 0.95, -14.8), Vector3(0.9, 0.18, 0.7), WHITE)
	NSGeometry.light(world, Vector3(6, 2.6, -14), WHITE, 0.8, 5)
	game.make_interactable("switch", "매장 조명 스위치", "switch", Vector3(-5.68, 1.5, -4.87), Vector3(0.16, 0.25, 0.08), WHITE)
	# Outside: front parking, road, rear waste enclosure and breaker.
	box(Vector3(0, -0.055, 10.3), Vector3(18, 0.09, 7.9), Color("36454c"))
	for x in [-7, -3.5, 3.5, 7]:
		box(Vector3(x, 0.002, 10), Vector3(0.06, 0.005, 4.8), Color("b7b9a4"), false)
	box(Vector3(0, -0.06, 16), Vector3(46, 0.06, 5), Color("171f28"))
	for x in range(-21, 22, 4):
		box(Vector3(x, -0.024, 16), Vector3(2, 0.005, 0.12), Color("a69d72"), false)
	# A test curb with step height 0.12m.
	box(Vector3(0, 0.005, 13.6), Vector3(18, 0.13, 0.30), WALL)
	for x in [-9, 9]:
		box(Vector3(x, 2.45, 11.5), Vector3(0.12, 4.9, 0.12), DARK)
		box(Vector3(x, 4.9, 11.5), Vector3(0.75, 0.08, 0.4), AMBER, false, 2)
		NSGeometry.light(world, Vector3(x, 4.5, 11.5), AMBER, 1.3, 9)
		NSGeometry.light(world, Vector3(x, 2.8, -8), Color("7f9daf"), 0.6, 7)
	game.make_interactable("bin", "쓰레기장 · 봉투 버리기", "bin", Vector3(-4.5, 0.6, -12), Vector3(2.2, 1.2, 1.2), Color("314c45"))
	label("WASTE", Vector3(-4.5, 1, -11.37), 36, WHITE)
	game.make_interactable("breaker", "차단기 · 확인 / 전원 전환", "breaker", Vector3(0.5, 1.4, -9.2), Vector3(0.65, 0.8, 0.25), Color("7a8181"))
	var breaker_label = label("POWER", Vector3(0.5, 1.43, -9.34), 28, AMBER)
	breaker_label.rotation.y = PI
	# Open opposite sidewalk and zebra crossing; no perimeter walls.
	box(Vector3(0, 0, 20), Vector3(46, 0.16, 3), Color("929b99"))
	for z in range(14, 19):
		box(Vector3(0, -0.02, z), Vector3(3.0, 0.015, 0.48), WHITE, false)
	apply_drink_visuals()
	game.make_interactable("order", "손님 구매 음료", "pickup", Vector3(-4.30, 1.29, 2.95), Vector3(0.18, 0.30, 0.18), Color("b18cac")).item_type = "order"
	game.registry["order"].set_active(false)

func box(pos: Vector3, size: Vector3, color: Color, solid: bool = true, glow: float = 0.0) -> Node3D:
	if visual_loaded or game.editable_layout_enabled:
		return world
	return NSGeometry.box(world, pos, size, color, solid, glow)

func marker_position(marker_name: String, fallback: Vector3) -> Vector3:
	if game.editable_layout_enabled and is_instance_valid(game.editable_layout):
		var marker := game.editable_layout.find_child(marker_name, true, false) as Node3D
		if marker:
			return marker.global_position
	return fallback

func label(value: String, pos: Vector3, size: int, color: Color) -> Label3D:
	if visual_loaded:
		var hidden_label = Label3D.new()
		world.add_child(hidden_label)
		hidden_label.visible = false
		return hidden_label
	return NSGeometry.text(world, value, pos, size, color)

func door(id: String, title: String, hinge: Vector3, width: float, glass: bool) -> void:
	var pivot = Node3D.new()
	world.add_child(pivot)
	pivot.position = hinge
	var d = game.make_interactable(id, title, "door", hinge + Vector3(width * 0.5, 1.25, 0), Vector3(width, 2.5, 0.10), Color(0.3, 0.6, 0.62, 0.40) if glass else Color("506569"))
	d.reparent(pivot)
	d.pivot = pivot
	NSGeometry.box(d, Vector3(width * 0.32, 0, 0.09), Vector3(0.06, 0.32, 0.07), AMBER, false)
	NSGeometry.text(d, "ENTRANCE" if glass else title, Vector3(0, 0.43, 0.07), 26, WHITE)
	box(hinge + Vector3(width * 0.5, 2.91, 0), Vector3(width, 0.82, 0.18), WALL)

func apply_drink_visuals() -> void:
	for i in range(6):
		var item = game.registry["drink_%d" % i]
		item.visual.visible = false
		NSGeometry.cylinder(item, Vector3.ZERO, 0.075, 0.26, TEAL if i % 2 else AMBER)
		NSGeometry.cylinder(item, Vector3(0, 0.16, 0), 0.033, 0.07, WHITE)

func sliding_entrance() -> void:
	var left = game.make_interactable("front_door", "정문 · 자동 센서", "door", Vector3(-0.65, 1.25, 6), Vector3(1.3, 2.5, 0.08), Color(0.55, 0.72, 0.78, 0.22))
	left.pivot = left
	var right = StaticBody3D.new()
	right.name = "RightPanel"
	world.add_child(right)
	right.position = Vector3(0.65, 1.25, 6)
	var mesh = MeshInstance3D.new()
	var pane = BoxMesh.new()
	pane.size = Vector3(1.3, 2.5, 0.08)
	mesh.mesh = pane
	mesh.material_override = load("res://visuals/environment/Glass.tres")
	right.add_child(mesh)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = pane.size
	collision.shape = shape
	right.add_child(collision)
	for panel in [left, right]:
		for x in [-0.63, 0.63]:
			NSGeometry.box(panel, Vector3(x, 0, 0), Vector3(0.035, 2.5, 0.10), DARK, false)
		for y in [-1.23, 1.23]:
			NSGeometry.box(panel, Vector3(0, y, 0), Vector3(1.3, 0.035, 0.10), DARK, false)
		NSGeometry.box(panel, Vector3(0, 0.05, 0.055), Vector3(1.2, 0.08, 0.012), Color("b2c4cc"), false)
		NSGeometry.text(panel, "AUTO", Vector3(0, 0.20, 0.07), 18, WHITE)
	left.visual.get_child(0).material_override = load("res://visuals/environment/Glass.tres")
	game.front_right_panel = right
