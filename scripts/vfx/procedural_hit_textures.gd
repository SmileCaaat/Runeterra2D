class_name ProceduralHitTextures
extends RefCounted

static var _soft_circle: ImageTexture
static var _spark_strip: ImageTexture
static var _debris_square: ImageTexture


static func soft_circle() -> ImageTexture:
	if _soft_circle != null:
		return _soft_circle
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size - 1, size - 1) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var distance := Vector2(x, y).distance_to(center) / center.x
			var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 2.2)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_soft_circle = ImageTexture.create_from_image(image)
	return _soft_circle


static func spark_strip() -> ImageTexture:
	if _spark_strip != null:
		return _spark_strip
	var width := 64
	var height := 12
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			var along := float(x) / float(width - 1)
			var across := absf(float(y) / float(height - 1) * 2.0 - 1.0)
			var alpha := pow(1.0 - across, 2.0) * pow(1.0 - along, 0.45)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_spark_strip = ImageTexture.create_from_image(image)
	return _spark_strip


static func debris_square() -> ImageTexture:
	if _debris_square != null:
		return _debris_square
	var size := 16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var edge := mini(mini(x, y), mini(size - 1 - x, size - 1 - y))
			var alpha := clampf(float(edge + 1) / 3.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_debris_square = ImageTexture.create_from_image(image)
	return _debris_square
