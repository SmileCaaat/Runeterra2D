class_name AIUtilityScore
extends RefCounted


static func saturate(value: float) -> float:
	return clampf(value, 0.0, 1.0)


static func inverse_lerp_clamped(a: float, b: float, value: float) -> float:
	if is_equal_approx(a, b):
		return 0.0
	return saturate((value - a) / (b - a))


static func peak(value: float, center: float, half_width: float) -> float:
	if half_width <= 0.0:
		return 0.0
	return 1.0 - saturate(absf(value - center) / half_width)


static func remap01(value: float, min_value: float, max_value: float) -> float:
	return inverse_lerp_clamped(min_value, max_value, value)
