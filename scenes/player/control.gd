extends Control

@export var point_size := 8.0
@export var thickness := 2.0
@export var color := Color.WHITE
@export var gap := 4.0  # small gap in the center, like a real crosshair

func _ready() -> void:
	# make it ignore mouse clicks so it doesn't block UI interaction
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center = get_rect().size / 2

	# horizontal lines (left and right of center gap)
	draw_line(center - Vector2(point_size, 0), center - Vector2(gap, 0), color, thickness)
	draw_line(center + Vector2(gap, 0), center + Vector2(point_size, 0), color, thickness)

	# vertical lines (top and bottom of center gap)
	draw_line(center - Vector2(0, point_size), center - Vector2(0, gap), color, thickness)
	draw_line(center + Vector2(0, gap), center + Vector2(0, point_size), color, thickness)
