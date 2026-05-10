package main

import k2 "../../SDKs/karl2d"
import "core:math/rand"

Game :: struct {
	player_index:         int,
	entities:             [dynamic]Entity,
	enemy_spawn_tickrate: f32,
	enemy_spawn_timer:    f32,
}

game: Game

main :: proc() {
	k2.init(720, 800, "k2d test")

	game = {
		enemy_spawn_tickrate = 1,
		enemy_spawn_timer    = 1,
	}

	player := entity_create_at(
		&game,
		.Player,
		{f32(k2.get_screen_width() / 2.0), f32(k2.get_screen_height()) / 1.1},
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
	player := &game.entities[game.player_index]
	player_data := &player.data.(Player_Data)
	player.velocity = {}

	if k2.key_is_held(.Left) || k2.key_is_held(.A) {
		player.velocity.x -= player_data.move_speed
	}

	if k2.key_is_held(.Right) || k2.key_is_held(.D) {
		player.velocity.x += player_data.move_speed
	}

	if k2.key_is_held(.Space) || k2.key_is_held(.Enter) {
		if player_data.shoot_timer < 0 {
			player_data.shoot_timer = player_data.shot_rate

			bullet := entity_create_at(game, .Bullet, player.position + k2.Vec2{0, -40})
			bullet_data := bullet.data.(Bullet_Data)
			bullet.velocity = k2.Vec2{0, -bullet_data.bullet_speed}
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
			if e.position.y < 0 {
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

		#partial switch e.kind {
		case .Player:
			k2.draw_rect({e.position.x, e.position.y, 64, 64}, k2.GRAY, e.pivot)

		case .Bullet:
			k2.draw_circle(e.position, 4, k2.YELLOW)

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
