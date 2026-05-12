package main

import k2 "../../SDKs/karl2d"
import "base:runtime"
import "core:math/linalg"
import "core:math/rand"
import "utils"

Game :: struct {
	player_index:           u32,
	entities:               [dynamic]Entity,
	assets:                 Assets,
	enemy_spawn_chance:     i32,
	blackhole_spawn_chance: i32,
	enemy_safe_zone:        k2.Rect,
}

Assets :: struct {
	player:     k2.Texture,
	bullet:     k2.Texture,
	seeker:     k2.Texture,
	wanderer:   k2.Texture,
	black_hole: k2.Texture,
}

Entity :: struct {
	kind:            Entity_Kind,
	position:        k2.Vec2,
	pivot:           k2.Vec2,
	velocity:        k2.Vec2,
	health:          int,
	max_heatlh:      int,
	orientation:     f32,
	scale:           f32,
	active:          bool,
	active_collider: bool,
	collider:        k2.Rect,
	team:            Entity_Team,
	texture:         ^k2.Texture,
	texture_rect:    k2.Rect,
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
	move_speed:   f32,
	wander_angle: f32,
}

Entity_Kind :: enum {
	Player,
	Player_Bullet,
	Enemy_Seeker,
	Enemy_Wanderer,
	Enemy_BackHole,
}

Entity_Team :: enum {
	Player,
	Enemey,
}

ENTITY_TEMPLATES := [Entity_Kind]Entity {
	.Player = Entity {
		pivot = {32, 32},
		active_collider = true,
		collider = {0, 0, 64, 64},
		team = .Player,
		data = Player_Data{shot_rate = 0.1, shoot_timer = 0.0, move_speed = 400.0},
		max_heatlh = 3,
	},
	.Player_Bullet = Entity {
		active_collider = true,
		collider = {0, 0, 10, 10},
		team = .Player,
		max_heatlh = 1,
		data = Bullet_Data{bullet_speed = 900.0},
	},
	.Enemy_Seeker = Entity {
		pivot = {16, 16},
		active_collider = true,
		collider = {0, 0, 32, 32},
		team = .Enemey,
		max_heatlh = 1,
		data = Enemy_Data{move_speed = 200.0},
	},
	.Enemy_Wanderer = Entity {
		pivot = {16, 16},
		active_collider = true,
		collider = {0, 0, 32, 32},
		team = .Enemey,
		max_heatlh = 1,
		data = Enemy_Data{move_speed = 100.0},
	},
	.Enemy_BackHole = Entity {
		active_collider = true,
		pivot = {16, 16},
		collider = {0, 0, 32, 32},
		team = .Enemey,
		max_heatlh = 10,
		data = Enemy_Data{},
	},
}

game: Game

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

main :: proc() {
	k2.init(SCREEN_WIDTH, SCREEN_HEIGHT, "k2d test")

	assets := Assets {
		player     = k2.load_texture_from_file("Art/Player.png"),
		bullet     = k2.load_texture_from_file("Art/Bullet.png"),
		seeker     = k2.load_texture_from_file("Art/Seeker.png"),
		wanderer   = k2.load_texture_from_file("Art/Wanderer.png"),
		black_hole = k2.load_texture_from_file("Art/Black Hole.png"),
	}

	game = {
		assets                 = assets,
		enemy_spawn_chance     = 100,
		blackhole_spawn_chance = 300,
		enemy_safe_zone        = k2.rect_shrink(
			k2.Rect{0, 0, f32(k2.get_screen_width()), f32(k2.get_screen_height())},
			64,
			64,
		),
	}

	player := entity_create_at(
		&game,
		.Player,
		{f32(k2.get_screen_width() / 2.0), f32(k2.get_screen_height()) / 2.0},
	)

	game.player_index = u32(len(game.entities) - 1)

	for k2.update() {
		if k2.key_went_down(.Escape) do break

		handle_input(&game)
		update_enemy_spawner(&game)
		update_entities(&game)
		update_collisions(&game)
		draw(&game)
		// draw_debug(&game)
		cleanup_inactive_entities(&game)
	}

	k2.shutdown()
}

handle_input :: proc(game: ^Game) {
	input: k2.Vec2 = {}
	player := &game.entities[game.player_index]
	player_data := &player.data.(Player_Data)

	if k2.key_is_held(.Left) || k2.key_is_held(.A) {
		input.x -= 1
	}

	if k2.key_is_held(.Right) || k2.key_is_held(.D) {
		input.x += 1
	}

	if k2.key_is_held(.Up) || k2.key_is_held(.W) {
		input.y -= 1
	}

	if k2.key_is_held(.Down) || k2.key_is_held(.S) {
		input.y += 1
	}

	if linalg.length2(input) > 1 {
		input = linalg.normalize(input)
	}

	mouse_pos := k2.get_mouse_position()
	aim_direction := linalg.normalize(mouse_pos - player.position)

	player.velocity = input * player_data.move_speed
	player.orientation = f32(linalg.atan2(aim_direction.y, aim_direction.x))

	if k2.mouse_button_is_held(.Left) {
		if player_data.shoot_timer < 0 {
			player_data.shoot_timer = player_data.shot_rate
			MUZZLE_OFFSET :: 20.0
			BULLET_GAP :: 12

			for i in 0 ..< 2 {
				spread := rand.float32_range(-0.04, 0.04)
				bullet_angle := player.orientation + spread
				bullet_forward := k2.Vec2 {
					linalg.cos(player.orientation + spread),
					linalg.sin(player.orientation + spread),
				}
				right := k2.Vec2{-bullet_forward.y, bullet_forward.x}
				side_offset := f32(i * 2 - 1) * BULLET_GAP

				bullet_position :=
					player.position + bullet_forward * MUZZLE_OFFSET + right * side_offset

				bullet := entity_create_at(game, .Player_Bullet, bullet_position)
				bullet_data := bullet.data.(Bullet_Data)
				bullet.velocity = bullet_forward * bullet_data.bullet_speed
				bullet.orientation = bullet_angle
			}
		}
	}
}

update_enemy_spawner :: proc(game: ^Game) {
	player_pos := game.entities[game.player_index].position

	if rand.int31_max(game.enemy_spawn_chance) == 0 {
		spawn_pos := get_enemy_spawn_pos(player_pos)
		enemy := entity_create_at(game, .Enemy_Seeker, spawn_pos)
	}

	if rand.int31_max(game.enemy_spawn_chance) == 0 {
		spawn_pos := get_enemy_spawn_pos(player_pos)
		enemy := entity_create_at(game, .Enemy_Wanderer, spawn_pos)
	}

	if rand.int31_max(game.blackhole_spawn_chance) == 0 {
		spawn_pos := get_enemy_spawn_pos(player_pos)
		black_hole := entity_create_at(game, .Enemy_BackHole, spawn_pos)
	}
}

get_enemy_spawn_pos :: proc(player_pos: k2.Vec2) -> k2.Vec2 {
	MIN_SPAWN_DISTANCE_FROM_PLAYER :: 500.0
	spawn_pos := k2.Vec2 {
		f32(rand.int_max(k2.get_screen_width())),
		f32(rand.int_max(k2.get_screen_height())),
	}

	for linalg.length2(player_pos - spawn_pos) <
	    MIN_SPAWN_DISTANCE_FROM_PLAYER * MIN_SPAWN_DISTANCE_FROM_PLAYER {
		spawn_pos = k2.Vec2 {
			f32(rand.int_max(k2.get_screen_width())),
			f32(rand.int_max(k2.get_screen_height())),
		}
	}

	return spawn_pos
}

update_entities :: proc(game: ^Game) {
	player_position := game.entities[game.player_index].position
	for &e, index in game.entities {
		if !e.active do continue

		delta_time := k2.get_frame_time()

		switch e.kind {

		case .Player:
			player_data := &e.data.(Player_Data)
			player_data.shoot_timer -= delta_time
			size := k2.Vec2{e.texture_rect.w, e.texture_rect.h}

			e.position = linalg.clamp(
				e.position,
				size / 2,
				k2.Vec2{f32(k2.get_screen_width()), f32(k2.get_screen_height())} - size / 2,
			)

		case .Player_Bullet:
			if e.position.x < 0 ||
			   e.position.y < 0 ||
			   e.position.x > f32(k2.get_screen_width()) ||
			   e.position.y > f32(k2.get_screen_height()) {
				e.active = false
			}

		case .Enemy_Seeker:
			enemy_data := &e.data.(Enemy_Data)
			direction := linalg.normalize(player_position - e.position)
			e.velocity += direction * enemy_data.move_speed
			e.velocity *= 0.8
			e.orientation = linalg.atan2(direction.y, direction.x)

		case .Enemy_Wanderer:
			enemy_data := &e.data.(Enemy_Data)
			enemy_data.wander_angle += rand.float32_range(-0.1, 0.1)

			if !k2.point_in_rect(e.position, game.enemy_safe_zone) {
				center_dir := linalg.normalize(
					k2.Vec2{f32(k2.get_screen_width() / 2.0), f32(k2.get_screen_height() / 2.0)} -
					e.position,
				)
				target_angle := linalg.atan2(center_dir.y, center_dir.x)
				target_angle += rand.float32_range(-linalg.PI / 2, linalg.PI / 2)
				enemy_data.wander_angle = utils.angle_lerp(
					enemy_data.wander_angle,
					target_angle,
					0.05,
				)
			}

			forward := k2.Vec2 {
				linalg.cos(enemy_data.wander_angle),
				linalg.sin(enemy_data.wander_angle),
			}

			e.velocity = forward * enemy_data.move_speed
			e.orientation += 0.01

		case .Enemy_BackHole:
			e.scale = 1.0 + 0.1 * f32(linalg.sin(10 * k2.get_time()))

			query_buffer: [128]u32
			nearby := entity_get_nearby(e.position, 200.0, query_buffer[:])

			for index in nearby {
				other := &game.entities[index]

				if other.kind == .Player_Bullet {
					other.velocity += (other.position - e.position) * 0.3
					other.orientation = linalg.atan2(other.velocity.y, other.velocity.x)
				} else {
					// displacement := e.position - other.position
					// length := linalg.length(displacement)

					// other.velocity +=
					// 	displacement * f32((linalg.lerp(f32(2.0), f32(0.0), f32(length / 250.0))))
				}
			}
		}

		e.position += e.velocity * delta_time
	}
}

update_collisions :: proc(game: ^Game) {
	for &entity, i in game.entities {
		if !entity.active || !entity.active_collider do continue
		if entity.kind == .Player do continue // player is invincible for now

		for &other in game.entities[i + 1:] {
			if !other.active || !other.active_collider do continue
			if entity.team == other.team do continue

			entity_rect := entity_get_world_collider_rect(entity)
			other_rect := entity_get_world_collider_rect(other)

			if !k2.rect_overlapping(entity_rect, other_rect) do continue

			entity.health -= 1
			other.health -= 1

			if entity.health <= 0 do entity.active = false
			if other.health <= 0 do other.active = false
		}
	}
}

draw :: proc(game: ^Game) {
	k2.clear(k2.BLACK)

	for e in game.entities {
		if !e.active do continue

		if e.texture != nil {
			dest_rect := utils.rect_scale(e.texture_rect, e.scale)
			k2.draw_texture_fit(
				e.texture^,
				e.texture_rect,
				{e.position.x, e.position.y, dest_rect.w, dest_rect.h},
				{dest_rect.w / 2.0, dest_rect.h / 2.0},
				e.orientation,
			)
		}
	}

	k2.present()
}

draw_debug :: proc(game: ^Game) {
	for e in game.entities {
		if !e.active do continue

		if e.active_collider {

			switch e.kind {
			case .Enemy_Seeker, .Player, .Enemy_Wanderer, .Enemy_BackHole:
				k2.draw_rect(entity_get_world_collider_rect(e), {0, 255, 0, 125})

			case .Player_Bullet:
				k2.draw_rect(
					{e.position.x, e.position.y, e.collider.w, e.collider.h},
					k2.GREEN,
					{e.collider.w / 2, e.collider.h / 2},
				)
			}
		}
	}

	k2.draw_rect_outline(game.enemy_safe_zone, 5.0, k2.GREEN)

	k2.present()
}

entity_create :: proc(game: ^Game, kind: Entity_Kind) -> ^Entity {
	entity := ENTITY_TEMPLATES[kind]
	entity.kind = kind
	entity.active = true
	entity.scale = 1.0
	entity.health = entity.max_heatlh
	texture, rect := get_texture_for_kind(&game.assets, kind)
	entity.texture = texture
	entity.texture_rect = rect

	append(&game.entities, entity)
	return &game.entities[len(game.entities) - 1]
}

entity_create_at :: proc(game: ^Game, kind: Entity_Kind, position: k2.Vec2) -> ^Entity {
	entity := entity_create(game, kind)
	entity.position = position

	return entity
}

get_texture_for_kind :: proc(assets: ^Assets, kind: Entity_Kind) -> (^k2.Texture, k2.Rect) {
	switch kind {
	case .Player:
		return &assets.player, k2.get_texture_rect(assets.player)
	case .Player_Bullet:
		return &assets.bullet, k2.get_texture_rect(assets.bullet)
	case .Enemy_Seeker:
		return &assets.seeker, k2.get_texture_rect(assets.seeker)
	case .Enemy_Wanderer:
		return &assets.wanderer, k2.get_texture_rect(assets.wanderer)
	case .Enemy_BackHole:
		return &assets.black_hole, k2.get_texture_rect(assets.wanderer)
	}

	return nil, {}
}

entity_get_world_collider_rect :: proc(entity: Entity) -> k2.Rect {
	return {
		entity.position.x - entity.pivot.x + entity.collider.x,
		entity.position.y - entity.pivot.y + entity.collider.y,
		entity.collider.w,
		entity.collider.h,
	}
}

entity_get_nearby :: proc(position: k2.Vec2, radius: f32, buffer: []u32) -> []u32 {
	count := 0
	radius_sqr := radius * radius

	for i in 0 ..< len(game.entities) {
		if count > len(buffer) do break

		e := &game.entities[i]
		if !e.active do continue

		if linalg.length2(e.position - position) <= radius_sqr {
			buffer[count] = u32(i)
			count += 1
		}
	}

	return buffer[:count]
}

cleanup_inactive_entities :: proc(game: ^Game) {
	i := 0
	for i < len(game.entities) {
		if !game.entities[i].active {
			unordered_remove_dynamic_array(&game.entities, i)
			continue
		}

		i += 1
	}
}
