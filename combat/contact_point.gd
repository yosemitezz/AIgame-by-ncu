extends RefCounted
## Actual intersection point for presentation. Never decides damage or enlarges reach.
const Query = preload("res://combat/melee_query.gd")
const Profile = preload("res://combat/attack_profile.gd")
static func melee(source: Node2D, target: Node2D) -> Dictionary:
    var first: float = float(source.get("attack_sweep_from"))
    var last: float = float(source.get("attack_sweep_to"))
    var polygon: PackedVector2Array = Profile.world_polygon(source,first,last)
    if polygon.size()<3:return {"valid":false}
    var previous: Vector2=source.global_position
    var saved: Variant=source.get("attack_previous_position")
    if Profile.kind(int(source.get("combo")),str(source.get("weapon")))=="thrust" and saved is Vector2 and saved.is_finite():
        previous=saved
        var extra: PackedVector2Array=polygon.duplicate()
        for p: Vector2 in extra:polygon.append(p+previous-source.global_position)
        polygon=Geometry2D.convex_hull(polygon)
    var intersections: Array[PackedVector2Array]=Geometry2D.intersect_polygons(polygon,Query.target_polygon(target))
    if intersections.is_empty():return {"valid":false}
    var facing: float=-1.0 if int(source.get("facing"))<0 else 1.0
    var local_origin: Vector2=Profile.origin();local_origin.x*=facing
    var current_origin: Vector2=source.global_position+local_origin
    var old_origin: Vector2=previous+local_origin
    var edge: Vector2=Profile.leading_edge(int(source.get("combo")),last,str(source.get("weapon")))
    edge.x*=facing;edge+=source.global_position
    var chosen: Vector2=Vector2.INF
    var best: float=INF
    for intersection: PackedVector2Array in intersections:
        var candidates: Array[Vector2]=[]
        var center: Vector2=Vector2.ZERO
        for i: int in intersection.size():
            center+=intersection[i]
            candidates.append(intersection[i])
            candidates.append(Geometry2D.get_closest_point_to_segment(edge,intersection[i],intersection[(i+1)%intersection.size()]))
        if not intersection.is_empty():candidates.append(center/intersection.size())
        if Geometry2D.is_point_in_polygon(edge,intersection):candidates.append(edge)
        for candidate: Vector2 in candidates:
            var visible: bool=not source.is_inside_tree()
            if source.is_inside_tree():
                for origin: Vector2 in [current_origin,old_origin]:
                    var ray: PhysicsRayQueryParameters2D=PhysicsRayQueryParameters2D.create(origin,candidate,1)
                    ray.hit_from_inside=true
                    if source is CollisionObject2D:ray.exclude=[source.get_rid()]
                    if source.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():visible=true;break
            if visible and edge.distance_squared_to(candidate)<best:
                best=edge.distance_squared_to(candidate);chosen=candidate
    if not chosen.is_finite():return {"valid":false}
    var direction: Vector2=(chosen-current_origin).normalized()
    if direction.is_zero_approx():direction=Vector2(facing,0)
    return {"valid":true,"point":chosen,"direction":direction}