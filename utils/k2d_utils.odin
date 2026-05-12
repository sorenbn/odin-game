package utils

import k2 "../../../SDKs/karl2d"

rect_scale :: proc(rect: k2.Rect, scale: f32) -> k2.Rect {
	return {rect.x, rect.y, rect.w * scale, rect.h * scale}
}
