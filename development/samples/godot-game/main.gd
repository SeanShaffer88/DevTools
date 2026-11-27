extends Node2D
var score: int = 0
var center := Vector2(320, 180)
func _ready() -> void:
    queue_redraw()
func _draw() -> void:
    draw_circle(center, 38.0, Color(0.3, 0.85, 0.68))
    draw_string(ThemeDB.fallback_font, Vector2(24, 36), "Tap The Circle — Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
func _unhandled_input(event: InputEvent) -> void:
    var position := Vector2(-1000, -1000)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        position = event.position
    elif event is InputEventScreenTouch and event.pressed:
        position = event.position
    if position.distance_to(center) <= 38.0:
        score = mini(score + 1, 1000000)
        center = Vector2(120 + (score * 97) % 400, 100 + (score * 53) % 180)
        queue_redraw()
