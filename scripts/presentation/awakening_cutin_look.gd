class_name AwakeningCutInLook
extends RefCounted

## Canonical awakening cut-in look locked from debug tuning.
## New heroes only need a portrait (and optional theme/voice); presentation uses these defaults.

const PANEL_SCALE := Vector2(1.23, 1.0)
const DARKEN_ALPHA := 0.28

## Portrait framing shared by all profiles unless a row overrides it.
const PORTRAIT_SCALE := 1.01
const PORTRAIT_OFFSET := Vector2(0.10, -0.01)
const SLANT := -0.17
const FEATHER := 0.015

const GLOBAL_ALPHA := 0.38
const EDGE_FADE := 0.16
const GRADIENT_ALPHA_START := 0.84
const GRADIENT_ALPHA_END := 0.49
const GRADIENT_MODE := 2 # top -> bottom
const FILTER_MODE := 1 # cinematic
const FILTER_STRENGTH := 0.74
const VIGNETTE_STRENGTH := 1.0
const SATURATION := 1.61
const CONTRAST := 1.14
const BRIGHTNESS := 0.09
const THEME_MIX := 0.40
const STRIPE_AMOUNT := 0.13
const EDGE_GLOW_AMOUNT := 1.06


static func shader_params() -> Dictionary:
	return {
		"global_alpha": GLOBAL_ALPHA,
		"edge_fade": EDGE_FADE,
		"gradient_alpha_start": GRADIENT_ALPHA_START,
		"gradient_alpha_end": GRADIENT_ALPHA_END,
		"gradient_mode": GRADIENT_MODE,
		"filter_mode": FILTER_MODE,
		"filter_strength": FILTER_STRENGTH,
		"vignette_strength": VIGNETTE_STRENGTH,
		"saturation": SATURATION,
		"contrast": CONTRAST,
		"brightness": BRIGHTNESS,
		"theme_mix": THEME_MIX,
		"stripe_amount": STRIPE_AMOUNT,
		"edge_glow_amount": EDGE_GLOW_AMOUNT,
	}
