class_name WorkshopArt
extends RefCounted
const ROOT = "res://assets/workshop/"
const INK = Color("#35271f")
const RED = Color("#b84832")
static var textures: Dictionary = {}
static func texture(name: String) -> Texture2D:
	if not textures.has(name): textures[name] = load(ROOT + name + ".png")
	return textures[name]
static func paper(horizontal: int = 14, vertical: int = 10, red: bool = false, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box = StyleBoxTexture.new()
	box.texture = texture("button_red" if red else "paper")
	box.texture_margin_left = 22
	box.texture_margin_right = 22
	box.texture_margin_top = 14
	box.texture_margin_bottom = 14
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	box.modulate_color = tint
	return box
