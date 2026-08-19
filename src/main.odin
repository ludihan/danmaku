package danmaku

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"
import "core:fmt"

SCREEN_W :: 640
SCREEN_H :: 720

PLAY_X0 :: 20
PLAY_Y0 :: 20
PLAY_X1 :: 460
PLAY_Y1 :: 700

PLAYER_SPEED :: 260.0
PLAYER_FOCUS_SPEED :: 120.0
PLAYER_RADIUS :: 3.0
PLAYER_SHOT_COOLDOWN :: 0.06
PLAYER_BULLET_SPEED :: 620.0
PLAYER_BULLET_RADIUS :: 4.0

MAX_PLAYER_BULLETS :: 256
MAX_ENEMY_BULLETS :: 2048
MAX_ENEMIES :: 32

Vec2 :: rl.Vector2

Player :: struct {
	pos:        Vec2,
	lives:      int,
	bombs:      int,
	invuln:     f32,
	shot_timer: f32,
	graze:      int,
	dead:       bool,
}

PlayerBullet :: struct {
	pos:    Vec2,
	vel:    Vec2,
	active: bool,
}

EnemyBulletKind :: enum { Circle, Sliver }

EnemyBullet :: struct {
	pos:    Vec2,
	vel:    Vec2,
	radius: f32,
	kind:   EnemyBulletKind,
	active: bool,
	grazed: bool,
}

EnemyPattern :: enum {
	RingSpread,
	AimedBurst,
	Spiral,
}

Enemy :: struct {
	pos:       Vec2,
	hp:        int,
	max_hp:    int,
	active:    bool,
	pattern:   EnemyPattern,
	timer:     f32,
	spin:      f32,
	move_t:    f32,
	origin:    Vec2,
}

GameState :: struct {
	player:         Player,
	player_bullets: [MAX_PLAYER_BULLETS]PlayerBullet,
	enemy_bullets:  [MAX_ENEMY_BULLETS]EnemyBullet,
	enemies:        [MAX_ENEMIES]Enemy,
	score:          int,
	spawn_timer:    f32,
	time_alive:     f32,
	game_over:      bool,
	win_timer:      f32,
}

gs: GameState

reset_game :: proc() {
	gs = GameState{}
	gs.player.pos = Vec2{(PLAY_X0 + PLAY_X1) / 2, PLAY_Y1 - 60}
	gs.player.lives = 3
	gs.player.bombs = 3
	gs.spawn_timer = 1.0
}

spawn_enemy :: proc() {
	for &e in gs.enemies {
		if !e.active {
			e.active = true
			e.pos = Vec2{f32(rand.int31_max(PLAY_X1 - PLAY_X0 - 80)) + PLAY_X0 + 40, PLAY_Y0 + 40}
			e.origin = e.pos
			e.max_hp = 40 + int(rand.int31_max(40))
			e.hp = e.max_hp
			e.pattern = EnemyPattern(rand.int31_max(3))
			e.timer = 0
			e.spin = 0
			e.move_t = 0
			return
		}
	}
}

spawn_enemy_bullet :: proc(pos: Vec2, vel: Vec2, radius: f32, kind: EnemyBulletKind) {
	for &b in gs.enemy_bullets {
		if !b.active {
			b.active = true
			b.pos = pos
			b.vel = vel
			b.radius = radius
			b.kind = kind
			b.grazed = false
			return
		}
	}
}

spawn_player_bullet :: proc(pos: Vec2, vel: Vec2) {
	for &b in gs.player_bullets {
		if !b.active {
			b.active = true
			b.pos = pos
			b.vel = vel
			return
		}
	}
}

in_bounds :: proc(p: Vec2, margin: f32 = 20) -> bool {
	return p.x > PLAY_X0 - margin && p.x < PLAY_X1 + margin && p.y > PLAY_Y0 - margin && p.y < PLAY_Y1 + margin
}

update_player :: proc(dt: f32) {
	p := &gs.player
	if p.dead {
		return
	}

	focus := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	speed: f32 = focus ? PLAYER_FOCUS_SPEED : PLAYER_SPEED

	dir := Vec2{0, 0}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) do dir.x -= 1
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do dir.x += 1
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) do dir.y -= 1
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) do dir.y += 1

	if dir.x != 0 || dir.y != 0 {
		dir = rl.Vector2Normalize(dir)
	}

	p.pos += dir * speed * dt
	p.pos.x = clamp(p.pos.x, PLAY_X0, PLAY_X1)
	p.pos.y = clamp(p.pos.y, PLAY_Y0, PLAY_Y1)

	p.shot_timer -= dt
	if rl.IsKeyDown(.Z) || rl.IsKeyDown(.J) {
		if p.shot_timer <= 0 {
			p.shot_timer = PLAYER_SHOT_COOLDOWN
			spawn_player_bullet(p.pos + Vec2{-8, 0}, Vec2{0, -PLAYER_BULLET_SPEED})
			spawn_player_bullet(p.pos + Vec2{8, 0}, Vec2{0, -PLAYER_BULLET_SPEED})
		}
	}

	if p.invuln > 0 {
		p.invuln -= dt
	}
}

update_player_bullets :: proc(dt: f32) {
	for &b in gs.player_bullets {
		if !b.active do continue
		b.pos += b.vel * dt
		if !in_bounds(b.pos, 30) {
			b.active = false
		}
	}
}

fire_pattern :: proc(e: ^Enemy, dt: f32) {
	e.timer -= dt
	switch e.pattern {
	case .RingSpread:
		if e.timer <= 0 {
			e.timer = 1.4
			n := 24
			e.spin += 0.15
			for i in 0 ..< n {
				a := f32(i) / f32(n) * math.TAU + e.spin
				v := Vec2{math.cos(a), math.sin(a)} * 140
				spawn_enemy_bullet(e.pos, v, 5, .Circle)
			}
		}
	case .AimedBurst:
		if e.timer <= 0 {
			e.timer = 0.9
			to_player := rl.Vector2Normalize(gs.player.pos - e.pos)
			base_angle := math.atan2(to_player.y, to_player.x)
			for i in -2 ..= 2 {
				a := base_angle + f32(i) * 0.12
				v := Vec2{math.cos(a), math.sin(a)} * 260
				spawn_enemy_bullet(e.pos, v, 4, .Sliver)
			}
		}
	case .Spiral:
		if e.timer <= 0 {
			e.timer = 0.05
			e.spin += 0.35
			for k in 0 ..< 3 {
				a := e.spin + f32(k) * (math.TAU / 3)
				v := Vec2{math.cos(a), math.sin(a)} * 170
				spawn_enemy_bullet(e.pos, v, 5, .Circle)
			}
		}
	}
}

update_enemies :: proc(dt: f32) {
	any_active := false
	for &e in gs.enemies {
		if !e.active do continue
		any_active = true
		e.move_t += dt
		e.pos.x = e.origin.x + math.sin(e.move_t * 0.8) * 90
		e.pos.y = e.origin.y + math.sin(e.move_t * 0.5) * 20
		fire_pattern(&e, dt)

		if e.hp <= 0 {
			e.active = false
			gs.score += 500
		}
	}
	gs.spawn_timer -= dt
	if gs.spawn_timer <= 0 {
		gs.spawn_timer = 3.5
		spawn_enemy()
	}
}

update_enemy_bullets :: proc(dt: f32) {
	p := &gs.player
	for &b in gs.enemy_bullets {
		if !b.active do continue
		b.pos += b.vel * dt
		if !in_bounds(b.pos, 30) {
			b.active = false
			continue
		}

		if !p.dead && p.invuln <= 0 {
			d := rl.Vector2Distance(b.pos, p.pos)
			if d < b.radius + PLAYER_RADIUS {
				p.lives -= 1
				p.invuln = 2.0
				if p.lives <= 0 {
					p.dead = true
					gs.game_over = true
				}
				b.active = false
				continue
			}
			if !b.grazed && d < b.radius + 16 {
				b.grazed = true
				gs.score += 10
				gs.player.graze += 1
			}
		}
	}
}

check_player_hits :: proc() {
	for &pb in gs.player_bullets {
		if !pb.active do continue
		for &e in gs.enemies {
			if !e.active do continue
			d := rl.Vector2Distance(pb.pos, e.pos)
			if d < 18 {
				e.hp -= 5
				pb.active = false
				gs.score += 1
				break
			}
		}
	}
}

update_game :: proc(dt: f32) {
	if gs.game_over {
		return
	}
	gs.time_alive += dt
	update_player(dt)
	update_player_bullets(dt)
	update_enemies(dt)
	update_enemy_bullets(dt)
	check_player_hits()
}

draw_player :: proc() {
	p := gs.player
	if p.dead do return
	blink := p.invuln > 0 && int(p.invuln * 10) % 2 == 0
	if blink do return

	col := rl.SKYBLUE
	rl.DrawTriangle(
		p.pos + Vec2{0, -14},
		p.pos + Vec2{-10, 10},
		p.pos + Vec2{10, 10},
		col,
	)
	rl.DrawCircleV(p.pos, PLAYER_RADIUS, rl.RED)

	focus := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	if focus {
		rl.DrawCircleLines(i32(p.pos.x), i32(p.pos.y), 16, rl.Color{255, 255, 255, 120})
	}
}

draw_ui :: proc() {
	panel_x := i32(PLAY_X1 + 30)
	rl.DrawText(fmt.ctprintf("SCORE %06d", gs.score), panel_x, 30, 20, rl.WHITE)
	rl.DrawText(fmt.ctprintf("LIVES %d", gs.player.lives), panel_x, 60, 18, rl.WHITE)
	rl.DrawText(fmt.ctprintf("BOMBS %d", gs.player.bombs), panel_x, 85, 18, rl.WHITE)
	rl.DrawText(fmt.ctprintf("GRAZE %d", gs.player.graze), panel_x, 110, 18, rl.WHITE)
	rl.DrawText(fmt.ctprintf("TIME %.1f", gs.time_alive), panel_x, 135, 18, rl.WHITE)

	rl.DrawText("Z: shoot", panel_x, 500, 16, rl.GRAY)
	rl.DrawText("Arrows: move", panel_x, 520, 16, rl.GRAY)
	rl.DrawText("Shift: focus", panel_x, 540, 16, rl.GRAY)
	rl.DrawText("R: restart", panel_x, 560, 16, rl.GRAY)

	if gs.game_over {
		msg :: "GAME OVER"
		w := rl.MeasureText(msg, 40)
		rl.DrawText(msg, i32((PLAY_X0 + PLAY_X1) / 2) - w / 2, PLAY_Y1 / 2, 40, rl.RED)
		msg2 :: "Press R to restart"
		w2 := rl.MeasureText(msg2, 20)
		rl.DrawText(msg2, i32((PLAY_X0 + PLAY_X1) / 2) - w2 / 2, PLAY_Y1 / 2 + 50, 20, rl.WHITE)
	}
}

draw_game :: proc() {
	rl.ClearBackground(rl.Color{10, 10, 20, 255})

	rl.DrawRectangle(PLAY_X0, PLAY_Y0, PLAY_X1 - PLAY_X0, PLAY_Y1 - PLAY_Y0, rl.Color{20, 20, 35, 255})
	rl.DrawRectangleLines(PLAY_X0, PLAY_Y0, PLAY_X1 - PLAY_X0, PLAY_Y1 - PLAY_Y0, rl.DARKGRAY)

	for e in gs.enemies {
		if !e.active do continue
		rl.DrawCircleV(e.pos, 18, rl.MAROON)
		hp_ratio := f32(e.hp) / f32(e.max_hp)
		rl.DrawRectangle(i32(e.pos.x - 20), i32(e.pos.y - 30), 40, 5, rl.DARKGRAY)
		rl.DrawRectangle(i32(e.pos.x - 20), i32(e.pos.y - 30), i32(40 * hp_ratio), 5, rl.GREEN)
	}

	for b in gs.player_bullets {
		if !b.active do continue
		rl.DrawCircleV(b.pos, PLAYER_BULLET_RADIUS, rl.YELLOW)
	}

	for b in gs.enemy_bullets {
		if !b.active do continue
		col := b.kind == .Circle ? rl.Color{255, 80, 80, 255} : rl.Color{255, 160, 255, 255}
		rl.DrawCircleV(b.pos, b.radius, col)
		rl.DrawCircleLines(i32(b.pos.x), i32(b.pos.y), b.radius, rl.Color{255, 255, 255, 100})
	}

	draw_player()
	draw_ui()
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_W, SCREEN_H, "danmaku")
	rl.SetTargetFPS(60)

	reset_game()

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if rl.IsKeyPressed(.R) {
			reset_game()
		}

		update_game(dt)

		rl.BeginDrawing()
		draw_game()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}
