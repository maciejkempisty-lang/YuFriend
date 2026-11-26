class_name YardSpriteLayout
extends RefCounted

# World-space crop rectangles; every edge follows the three-unit pixel grid.
# Shared by the exporter and the runtime Sprite2D nodes.
const CROPS := {
	"gate": Rect2i(93, 183, 111, 96),
	"garden": Rect2i(477, 264, 150, 66),
	"dig": Rect2i(600, 285, 138, 54),
	"fetch": Rect2i(813, 258, 255, 81),
	"bush_0": Rect2i(270, 204, 162, 93),
	"bush_1": Rect2i(669, 204, 162, 93),
	"bush_2": Rect2i(1068, 204, 162, 93),
	"outing": Rect2i(1269, 246, 54, 57),
	"shade": Rect2i(144, 186, 213, 147),
	"course": Rect2i(975, 231, 63, 66),
	"puddle": Rect2i(351, 294, 144, 51),
	"sprinkler": Rect2i(1281, 279, 102, 81)
}

# Flat ground and the existing composite rest shelter stay below characters.
# Shade includes a bed and bowl in one PNG: splitting that artwork is separate work.
const GROUND_ONLY := ["dig", "puddle", "shade"]
# Feet/base of the upright object, NOT the bottom of its transparent crop/shadow.
const SORT_ORIGINS := {
	"gate": Vector2(150, 276), "garden": Vector2(550, 300),
	"fetch": Vector2(850, 312), "bush_0": Vector2(350, 294),
	"bush_1": Vector2(750, 294), "bush_2": Vector2(1150, 294),
	"outing": Vector2(1296, 300), "course": Vector2(1005, 294),
	"sprinkler": Vector2(1305, 312)
}
