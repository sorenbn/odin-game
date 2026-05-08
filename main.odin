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

	player := create_entity_at(
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
		draw(&game)
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

			bullet := create_entity_at(game, .Bullet, player.position + k2.Vec2{0, -40})
			bullet_data := bullet.data.(Bullet_Data)
			bullet.velocity = k2.Vec2{0, -bullet_data.bullet_speed}
		}
	}
}

update_enemy_spawner :: proc(game: ^Game) {
	game.enemy_spawn_timer -= k2.get_frame_time()

	if game.enemy_spawn_timer < 0 {
		game.enemy_spawn_timer = game.enemy_spawn_tickrate
		enemy := create_entity_at(game, .Enemy, {f32(rand.int_max(k2.get_screen_width())), -100})
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

draw :: proc(game: ^Game) {
	k2.clear(k2.BLACK)

	for e in game.entities {
		if !e.active do continue

		#partial switch e.kind {
		case .Player:
			k2.draw_rect({e.position.x, e.position.y, 64, 64}, k2.BLUE, {32, 32})

		case .Bullet:
			k2.draw_circle(e.position, 4, k2.YELLOW)

		case .Enemy:
			k2.draw_rect_outline({e.position.x, e.position.y, 32, 32}, 4.0, k2.RED)
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
