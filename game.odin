package main

import k2 "../../SDKs/karl2d"
import "core:math/linalg"
import "core:math/rand"

Game :: struct {
	player_index:         int,
	entities:             [dynamic]Entity,
	assets:               Assets,
	enemy_spawn_tickrate: f32,
	enemy_spawn_timer:    f32,
}

Assets :: struct {
	player: k2.Texture,
	bullet: k2.Texture,
}

game: Game

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

main :: proc() {
	k2.init(SCREEN_WIDTH, SCREEN_HEIGHT, "k2d test")

	assets := Assets {
		player = k2.load_texture_from_file("Art/Player.png"),
		bullet = k2.load_texture_from_file("Art/Bullet.png"),
	}

	game = {
		assets               = assets,
		enemy_spawn_tickrate = 1,
		enemy_spawn_timer    = 1,
	}

	player := entity_create_at(
		&game,
		.Player,
		{f32(k2.get_screen_width() / 2.0), f32(k2.get_screen_height()) / 2.0},
	)

	game.player_index = len(game.entities) - 1

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

				bullet := entity_create_at(game, .Bullet, bullet_position)
				bullet_data := bullet.data.(Bullet_Data)
				bullet.velocity = bullet_forward * bullet_data.bullet_speed
				bullet.orientation = bullet_angle
			}
		}
	}
}

update_enemy_spawner :: proc(game: ^Game) {
	game.enemy_spawn_timer -= k2.get_frame_time()

	if game.enemy_spawn_timer < 0 {
		game.enemy_spawn_timer = game.enemy_spawn_tickrate
		enemy := entity_create_at(game, .Enemy, {f32(rand.int_max(k2.get_screen_width())), -100})
		enemy_data := enemy.data.(Enemy_Data)
		enemy.velocity = k2.Vec2{0, enemy_data.move_speed}
	}
}

update_entities :: proc(game: ^Game) {
	for &e, index in game.entities {
		if !e.active do continue

		delta_time := k2.get_frame_time()

		e.position += e.velocity * delta_time

		#partial switch e.kind {

		case .Player:
			player_data := &e.data.(Player_Data)
			player_data.shoot_timer -= delta_time

		case .Bullet:
			if e.position.x < 0 ||
			   e.position.y < 0 ||
			   e.position.x > f32(k2.get_screen_width()) ||
			   e.position.y > f32(k2.get_screen_height()) {
				e.active = false
			}
		}
	}
}

update_collisions :: proc(game: ^Game) {
	for &entity, i in game.entities {
		if !entity.active || !entity.active_collider do continue

		for &other in game.entities[i + 1:] {
			if !other.active || !other.active_collider do continue

			entity_rect := entity_get_world_collider_rect(entity)
			other_rect := entity_get_world_collider_rect(other)

			if !k2.rect_overlapping(entity_rect, other_rect) do continue

			if entity.kind == .Bullet && other.kind == .Enemy {
				entity.active = false
				other.active = false
			} else if entity.kind == .Enemy && other.kind == .Bullet {
				entity.active = false
				other.active = false
			}
		}
	}
}

draw :: proc(game: ^Game) {
	k2.clear(k2.BLACK)

	for e in game.entities {
		if !e.active do continue

		if e.texture != nil {
			src_rect := k2.get_texture_rect(e.texture^)
			k2.draw_texture_rect(
				e.texture^,
				src_rect,
				e.position,
				{src_rect.w / 2.0, src_rect.h / 2.0},
				e.orientation,
			)
		}

		#partial switch e.kind {
		case .Enemy:
			k2.draw_rect_outline(
				{e.position.x - e.pivot.x, e.position.y - e.pivot.y, 32, 32},
				4.0,
				k2.RED,
			)
		}
	}

	k2.present()
}

draw_debug :: proc(game: ^Game) {
	for e in game.entities {
		if !e.active do continue

		if e.active_collider {

			#partial switch e.kind {
			case .Enemy, .Player:
				k2.draw_rect(entity_get_world_collider_rect(e), {0, 255, 0, 125})

			case .Bullet:
				k2.draw_rect(
					{e.position.x, e.position.y, e.collider.w, e.collider.h},
					k2.GREEN,
					{e.collider.w / 2, e.collider.h / 2},
				)
			}
		}
	}

	k2.present()
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
