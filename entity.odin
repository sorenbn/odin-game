package main

import k2 "../../SDKs/karl2d"

Entity_Kind :: enum {
	Player,
	Enemy,
	Bullet,
}

Entity :: struct {
	kind:            Entity_Kind,
	position:        k2.Vec2,
	pivot:           k2.Vec2,
	velocity:        k2.Vec2,
	active:          bool,
	active_collider: bool,
	collider:        k2.Rect,
	data:            Entity_Data,
}

Entity_Data :: union {
	Player_Data,
	Bullet_Data,
	Enemy_Data,
}

Player_Data :: struct {
	move_speed:  f32,
	shot_rate:   f32,
	shoot_timer: f32,
}

Bullet_Data :: struct {
	bullet_speed: f32,
}

Enemy_Data :: struct {
	move_speed: f32,
}

create_entity :: proc(game: ^Game, kind: Entity_Kind) -> ^Entity {
	entity := Entity {
		kind   = kind,
		active = true,
	}

	switch kind {
	case .Player:
		entity.pivot = {32, 32}
		entity.active_collider = true
		entity.collider = {0, 0, 64, 64}
		entity.data = Player_Data {
			shot_rate   = 0.15,
			shoot_timer = 0.0,
			move_speed  = 400.0,
		}
	case .Bullet:
		entity.active_collider = true
		entity.collider = {0, 0, 10, 10}
		entity.data = Bullet_Data {
			bullet_speed = 500.0,
		}
	case .Enemy:
		entity.pivot = {16, 16}
		entity.active_collider = true
		entity.collider = {0, 0, 32, 32}
		entity.data = Enemy_Data {
			move_speed = 200.0,
		}
	}

	append(&game.entities, entity)
	return &game.entities[len(game.entities) - 1]
}

create_entity_at :: proc(game: ^Game, kind: Entity_Kind, position: k2.Vec2) -> ^Entity {
	entity := create_entity(game, kind)
	entity.position = position

	return entity
}

get_world_collider_rect :: proc(entity: Entity) -> k2.Rect {
	return {
		entity.position.x - entity.pivot.x + entity.collider.x,
		entity.position.y - entity.pivot.y + entity.collider.y,
		entity.collider.w,
		entity.collider.h,
	}
}
