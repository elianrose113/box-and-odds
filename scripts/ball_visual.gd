class_name BallVisual
extends RefCounted
const COLOR = Color.WHITE
static var texture: Texture2D
static func get_texture() -> Texture2D:
	if texture == null:
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var p = (Vector2(x, y) - Vector2(31.5, 31.5)) / 31.0
				var distance = p.length()
				var alpha = clampf((1.0 - distance) * 31.0, 0, 1)
				var normal = Vector3(p.x, p.y, sqrt(maxf(0, 1.0 - p.length_squared())))
				var diffuse = clampf(normal.dot(Vector3(-0.45, -0.55, 0.7).normalized()), 0, 1)
				var color = Color("#986019").lerp(Color("#ffe5a0"), diffuse)
				color = color.lerp(Color("#fffce0"), pow(maxf(0, 1.0 - p.distance_to(Vector2(-0.32, -0.38)) / 0.32), 1.5))
				if distance > 0.87: color = Color("#473019").lerp(color, clampf((0.96 - distance) / 0.09, 0, 1))
				color.a = alpha
				image.set_pixel(x, y, color)
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	return texture
