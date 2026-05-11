package utils

import "core:math/linalg"

angle_lerp :: proc(a, b, t: f32) -> f32 {
	diff := b - a
	for diff > linalg.PI {diff -= 2 * linalg.PI}
	for diff < -linalg.PI {diff += 2 * linalg.PI}
	return a + diff * t
}
