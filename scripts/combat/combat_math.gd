class_name CombatMath
extends RefCounted


static func primary_growth(base_value: float, growth_value: float, level: int) -> float:
	var level_ups := maxf(0.0, float(level - 1))
	return base_value + growth_value * level_ups * (0.7025 + 0.0175 * level_ups)


static func attack_speed_growth(base_attack_speed: float, attack_speed_ratio: float, growth_ratio: float, level: int, bonus_attack_speed := 0.0) -> float:
	var level_ups := maxf(0.0, float(level - 1))
	var growth_bonus := growth_ratio * level_ups * (0.7025 + 0.0175 * level_ups)
	return base_attack_speed + (bonus_attack_speed + growth_bonus) * attack_speed_ratio


static func resolve_resistance(raw_damage: float, resistance: float, curve_constant: float) -> float:
	if resistance >= 0.0:
		return raw_damage * curve_constant / maxf(curve_constant + resistance, 0.001)
	return raw_damage * (2.0 - curve_constant / maxf(curve_constant - resistance, 0.001))


static func resolve_damage(raw_damage: float, damage_type: StringName, armor: float, magic_resistance: float, rules: CombatDatabase) -> float:
	match damage_type:
		&"physical":
			return resolve_resistance(raw_damage, armor, float(rules.get_rule(&"defense.armor_curve_constant", 100.0)))
		&"magic":
			return resolve_resistance(raw_damage, magic_resistance, float(rules.get_rule(&"defense.magic_resist_curve_constant", 100.0)))
		_:
			return raw_damage


static func cooldown_with_haste(base_cooldown: float, ability_haste: float, rules: CombatDatabase) -> float:
	var constant := float(rules.get_rule(&"cooldown.haste_constant", 100.0))
	var minimum := float(rules.get_rule(&"cooldown.minimum_cooldown", 0.1))
	return maxf(minimum, base_cooldown * constant / maxf(constant + ability_haste, 0.001))


static func control_duration(base_duration: float, tenacity: float, rules: CombatDatabase) -> float:
	var cap := float(rules.get_rule(&"control.tenacity_cap", 0.8))
	var minimum := float(rules.get_rule(&"control.minimum_duration", 0.1))
	return maxf(minimum, base_duration * (1.0 - clampf(tenacity, 0.0, cap)))
