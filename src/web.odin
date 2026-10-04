#+build js
package main

// Browser side: key input, canvas drawing and the frame loop.

import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:sys/wasm/js"
import "core:time"

// Implemented in web/index.html (2D canvas); world coordinates, y up.
foreign import canvas "canvas"
@(default_calling_convention = "contextless")
foreign canvas {
	clear_canvas :: proc(r, g, b: f32) ---
	fill_rect :: proc(x, y, w, h: f32, r, g, b, a: f32, tiles: f32) ---
	// tile (col,row) of assets/tileset.png (12px tiles, 1px gap) at world x,y; tint 0 is as drawn, 1 swaps red and blue, 2 brightens; size is the drawn width and height in world units
	draw_sprite :: proc(col, row: i32, x, y: f32, alpha: f32, tiles: f32, tint: i32, size: f32) ---
}

ctx: runtime.Context

main :: proc() {
	ctx = context
	rand.reset(u64(time.now()._nsec))
	js.add_window_event_listener(.Key_Down, nil, on_key)
	reset_game()
}

// For QA: the page calls this for a ?level=N address, to jump straight to level N.
@(export)
debug_level :: proc "c" (n: i32) {
	context = runtime.default_context()
	game.level_idx = (int(n) - 1) % len(LEVELS)
	game.level = int(n)
	load_level()
	if game.state == .Intro { game.state = .Playing }
}

on_key :: proc(e: js.Event) {
	if e.kind != .Key_Down || e.key.repeat { return }
	dir: Tile
	// the logical key first: remote desktops can send wrong e.code values
	switch e.key.key {
	case "ArrowLeft":  dir = {-1, 0}
	case "ArrowRight": dir = {1, 0}
	case "ArrowUp":    dir = {0, 1}
	case "ArrowDown":  dir = {0, -1}
	case "a", "A":     dir = {-1, 0}
	case "d", "D":     dir = {1, 0}
	case "w", "W":     dir = {0, 1}
	case "s", "S":     dir = {0, -1}
	case " ", "Enter":
	case: return
	}
	js.event_prevent_default()
	switch game.state {
	case .Intro:
		game.state = .Playing
	case .Dead:
		reset_game()
	case .Playing:
		if dir != {} { press(dir) }
	}
}

// Tileset coordinates (assets/tileset.png, Urizen 1-bit, CC0).
SPR_CAT      :: Tile{1, 14} // (0,14) is a fox
SPR_VACUUM   :: Tile{57, 12} // a round disc
SPR_SOFA     :: Tile{21, 36}
SPR_BASKET   :: Tile{20, 36}
SPR_KEYBOARD :: Tile{4, 37}

spot_sprite :: proc(kind: SpotKind) -> Tile {
	switch kind {
	case .Sofa:     return SPR_SOFA
	case .Basket:   return SPR_BASKET
	case .Keyboard: return SPR_KEYBOARD
	}
	return SPR_SOFA
}

TINT_NONE   :: i32(0)
TINT_BLUE   :: i32(1)
TINT_BRIGHT :: i32(2)

draw_tile :: proc(spr: Tile, x, y: f32, alpha: f32 = 1, tint := TINT_NONE, size: f32 = 1) {
	draw_sprite(i32(spr.x), i32(spr.y), x, y, alpha, WORLD_SIZE, tint, size)
}

draw_rect :: proc(x, y, w, h: f32, color: [4]f32) {
	fill_rect(x, y, w, h, color.r, color.g, color.b, color.a, WORLD_SIZE)
}

// Bitmap fonts in the tileset. Letters use the decorative font; digits and symbols only
// exist in the plain font, so they fall back to it. Each run is a row, its first column, and its glyphs.
FontRun :: struct {
	row, col: i32,
	chars:    string,
}
FANCY_FONT := [?]FontRun{
	{47, 97, "ABCDEF"},
	{48, 78, "GHIJKLMNOPQRSTUVWXYZabcde"},
	{49, 78, "fghijklmnopqrstuvwxyz"},
}
PLAIN_FONT := [?]FontRun{
	{44, 78, "ABCDEFGHIJKLMNOPQRST12345"},
	{45, 78, "UVWXYZabcdefghijklmn67890"},
	{46, 78, "opqrstuvwxyz()[]{}<>+-?!^"},
	{47, 78, ":#_@%~$\"'&*=`|/\\.,;"},
}
TEXT_SIZE :: 0.6 // 24px per 12px glyph, an exact 2x so pixels stay crisp
LINE_HEIGHT :: 0.9

draw_glyph :: proc(runs: []FontRun, c: u8, x, y, size: f32) -> bool {
	for run in runs {
		for j in 0 ..< len(run.chars) {
			if run.chars[j] == c {
				draw_sprite(run.col + i32(j), run.row, x, y, 1, WORLD_SIZE, TINT_NONE, size)
				return true
			}
		}
	}
	return false
}

draw_text :: proc(s: string, x, y: f32, size: f32 = TEXT_SIZE) {
	for i in 0 ..< len(s) {
		gx := x + f32(i) * size
		if !draw_glyph(FANCY_FONT[:], s[i], gx, y, size) {
			draw_glyph(PLAIN_FONT[:], s[i], gx, y, size)
		}
	}
}

draw_text_centered :: proc(s: string, y: f32) {
	draw_text(s, (WORLD_SIZE - f32(len(s)) * TEXT_SIZE) / 2, y)
}

// Dark panel across the board with centered lines of text.
draw_panel :: proc(lines: []string) {
	h := f32(len(lines)) * LINE_HEIGHT + 0.6
	y0 := f32(BOARD_H) / 2 + h / 2
	draw_rect(1, y0 - h, WORLD_SIZE - 2, h, {0.03, 0.04, 0.12, 0.93})
	for line, i in lines {
		draw_text_centered(line, y0 - 0.3 - LINE_HEIGHT * f32(i + 1) + 0.3)
	}
}

// Only draws; all state changes happen in take_turn.
@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = ctx
	tick(dt)

	clear_canvas(0.08, 0.08, 0.12)
	look := LEVELS[game.level_idx]
	for y in 0 ..< BOARD_H {
		for x in 0 ..< BOARD_W {
			if game.solid[y][x] {
				draw_tile(look.wall, f32(x), f32(y))
			} else {
				draw_tile(look.floor, f32(x), f32(y))
			}
		}
	}
	for s in game.spots[:game.spot_count] {
		tint := TINT_BRIGHT if look.bright_baskets && s.kind == .Basket else TINT_NONE
		draw_tile(spot_sprite(s.kind), f32(s.pos.x), f32(s.pos.y), 0.3 if s.done else 1, tint)
	}
	v := vacuum_pos()
	draw_tile(SPR_VACUUM, f32(v.x), f32(v.y))
	if game.caught { draw_rect(f32(game.pos.x), f32(game.pos.y), 1, 1, {1, 0.4, 0.3, 0.6}) }
	draw_tile(SPR_CAT, f32(game.pos.x), f32(game.pos.y), 0.4 if game.state == .Dead else 1)
	if game.nap_progress > 0 {
		zs := [3]string{"z", "zz", "zzz"}
		draw_text(zs[min(game.nap_progress, 3) - 1], f32(game.pos.x) + 0.6, f32(game.pos.y) + 0.8)
	}

	// HUD panel: the canvas row above the board, visibly not part of the playfield
	top := f32(BOARD_H)
	draw_rect(0, top, WORLD_SIZE, 1, {0.16, 0.17, 0.22, 1})
	draw_rect(0, top, WORLD_SIZE, 0.08, {0.45, 0.47, 0.55, 1})
	for i in 0 ..< MAX_LIVES {
		draw_tile(SPR_CAT, 0.3 + f32(i) * 0.6, top + 0.2, 1 if i < game.lives else 0.2, size = 0.6)
	}
	buf: [32]byte
	next_life := (game.naps / NAPS_PER_LIFE + 1) * NAPS_PER_LIFE
	draw_text(fmt.bprintf(buf[:], "Naps %d/%d", game.naps, next_life), 6.0, top + 0.2)
	draw_text(fmt.bprintf(buf[:], "Lv%d", game.level), 11.9, top + 0.2)
	left := 0
	for s in game.spots[:game.spot_count] { if !s.done { left += 1 } }
	draw_text(fmt.bprintf(buf[:], "Spots %d", left), 14.7, top + 0.2)

	switch game.state {
	case .Intro:
		draw_panel({
			"ROOMBA RIGHTS OF SPLORR!!",
			"",
			"You are a cat. Nap in every",
			"spot to settle the house.",
			"The robot vacuum is coming.",
			"",
			"Arrows or WASD: move",
			"Bump a wall to stay put.",
			"Stay put on a spot to nap.",
			"The vacuum moves 2 per turn.",
			"Do not touch the vacuum.",
			"",
			"Press a key to start",
		})
	case .Dead:
		buf2: [2][48]byte
		draw_panel({
			"No lives left!",
			"",
			fmt.bprintf(buf2[0][:], "You reached level %d", game.level),
			fmt.bprintf(buf2[1][:], "Naps: %d", game.naps),
			"",
			"Press a key to try again",
		})
	case .Playing:
		if game.message != "" {
			draw_text_centered(game.message, 0.2)
		}
	}
	return true
}
