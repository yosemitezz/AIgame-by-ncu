extends RefCounted
## Geometry/line-of-sight only. The root owns damage, per-serial ledgers and impact.
const AttackProfile = preload("res://combat/attack_profile.gd")

static func target_polygon(target: Node2D) -> PackedVector2Array:
	for child: Node in target.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			var bounds: Rect2 = child.shape.get_rect()
			return _rect_polygon(bounds, child.global_transform)
	var fallback: Rect2 = target.get_meta("melee_hurt_rect", Rect2(-7.0, -26.0, 14.0, 26.0))
	return _rect_polygon(fallback, target.global_transform)

static func _rect_polygon(bounds: Rect2, transform: Transform2D) -> PackedVector2Array:
	return PackedVector2Array([transform * bounds.position, transform * Vector2(bounds.end.x, bounds.position.y), transform * bounds.end, transform * Vector2(bounds.position.x, bounds.end.y)])

static func collect(source: Node2D, targets: Array, from_progress: float = -1.0, to_progress: float = -1.0, world_mask: int = 1) -> Array[Node2D]:
	var hits: Array[Node2D] = []
	if not is_instance_valid(source):
		return hits
	var phase: Variant = source.get("attack_phase")
	if phase != null and phase != "active":
		return hits
	if from_progress < 0.0:
		var previous: Variant = source.get("attack_sweep_from")
		from_progress = float(previous) if previous != null else AttackProfile.contact_start()
	if to_progress < 0.0:
		var current: Variant = source.get("attack_sweep_to")
		to_progress = float(current) if current != null else 1.0
	var polygon: PackedVector2Array = AttackProfile.world_polygon(source, from_progress, to_progress)
	if polygon.size() < 3:
		return hits
	var direction: Variant = source.get("facing")
	var facing: float = -1.0 if direction != null and float(direction) < 0.0 else 1.0
	var cast_origin: Vector2 = source.global_position + Vector2(AttackProfile.origin().x * facing, AttackProfile.origin().y)
	var unique: Dictionary = {}
	for candidate: Variant in targets:
		if typeof(candidate) != TYPE_OBJECT or not is_instance_valid(candidate):
			continue
		if not candidate is Node2D or candidate == source:
			continue
		var target: Node2D = candidate
		if unique.has(target.get_instance_id()) or target.get("dead") == true:
			continue
		unique[target.get_instance_id()] = true
		var hurt: PackedVector2Array = target_polygon(target)
		var center: Vector2 = Vector2.ZERO
		for point: Vector2 in hurt:
			center += point
		center /= hurt.size()
		# A behind-center target is never hit just because a large hurtbox overlaps
		# the caster. Actual forward overlap is still required by the swept polygon.
		if (center.x - source.global_position.x) * facing < 0.0:
			continue
		var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(polygon, hurt)
		if intersections.is_empty():
			continue
		var contacts: Array[Vector2] = []
		if Geometry2D.is_point_in_polygon(center, polygon):
			contacts.append(center)
		for intersection: PackedVector2Array in intersections:
			var centroid: Vector2 = Vector2.ZERO
			for point: Vector2 in intersection:
				contacts.append(point)
				centroid += point
			if not intersection.is_empty():
				contacts.append(centroid / intersection.size())
		var visible: bool = world_mask == 0
		if not visible and source.is_inside_tree() and source.get_world_2d() != null:
			var state: PhysicsDirectSpaceState2D = source.get_world_2d().direct_space_state
			for contact: Vector2 in contacts:
				var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(cast_origin, contact, world_mask)
				query.hit_from_inside = true
				if source is CollisionObject2D:
					query.exclude = [source.get_rid()]
				if state.intersect_ray(query).is_empty():
					visible = true
					break
		if visible:
			hits.append(target)
	return hits
