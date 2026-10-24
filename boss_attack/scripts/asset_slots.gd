extends Resource
class_name BattleAssetSlots

## All fields are intentionally empty. Combat code uses vector fallbacks until
## the art owners provide textures; replacing these textures does not alter
## timings, collision rules, or chart data.

@export_group("Actors")
@export var boss_texture: Texture2D
@export var player_texture: Texture2D

@export_group("Projectiles")
@export var boss_projectile_texture: Texture2D
@export var laser_warning_texture: Texture2D

@export_group("Environment")
@export var arena_background_texture: Texture2D

@export_group("HUD")
@export var heavy_marker_texture: Texture2D

