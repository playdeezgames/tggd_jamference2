package main

// Pure game logic: no browser imports, so it also builds and tests natively.

WORLD_SIZE :: 20 // canvas is WORLD_SIZE x WORLD_SIZE tiles
BOARD_W    :: WORLD_SIZE
BOARD_H    :: WORLD_SIZE - 1 // the top row of the canvas is the HUD panel, not board

START_LIVES  :: 3
MAX_LIVES    :: 9
NAPS_PER_LIFE :: 20 // extra life every this many naps (beyond the first is still open)
NAP_TURNS    :: 3 // consecutive stay-put turns on a spot to finish a nap
VACUUM_STEPS :: 2 // tiles the vacuum moves each turn
VACUUM_STEP_DELAY :: 0.15 // seconds before each of the vacuum's tiles is shown
MAX_QUEUED :: 3 // key presses remembered while the vacuum is moving

MAX_SPOTS :: 8
MAX_ROUTE :: 512

State :: enum {
	Intro, // instructions screen until the first key press
	Playing,
	Dead, // no lives left
}

SpotKind :: enum { Sofa, Basket, Keyboard }

Spot :: struct {
	pos:  Tile,
	kind: SpotKind,
	done: bool, // napped in already this level
}

Game :: struct {
	state:        State,
	message:      string, // one-line event banner, cleared on the next turn
	level:        int, // levels played this run, starting at 1
	level_idx:    int, // index into LEVELS; the five levels repeat
	solid:        [BOARD_H][BOARD_W]bool, // indexed [y][x]
	start:        Tile, // where the cat starts and respawns
	pos:          Tile,
	lives:        int,
	naps:         int, // completed naps over the whole run; also the score
	nap_progress: int, // consecutive stay-put turns on the current spot
	spots:        [MAX_SPOTS]Spot,
	spot_count:   int,
	route:        [MAX_ROUTE]Tile, // every tile of the vacuum's loop, in order
	route_len:    int,
	vac:          int, // index of the vacuum's tile in route
	caught:       bool, // the vacuum got the cat this turn (for a flash)
	pending_vac:  int, // vacuum tiles still to move this turn; the cat cannot act until it is 0
	anim_time:    f64, // seconds since the last vacuum tile (or the cat's move)
	queue:        [MAX_QUEUED]Tile, // presses made while the vacuum moves, acted on in order
	queued:       int,
}

game: Game

reset_game :: proc() {
	intro := game.state == .Intro // main() starts on the intro screen; restarts skip it
	game = {lives = START_LIVES, level = 1, state = .Intro if intro else .Playing}
	load_level()
}

// Builds the current level from LEVELS. Lives and naps carry over.
load_level :: proc() {
	lvl := LEVELS[game.level_idx]
	game.solid = {}
	game.spots = {}
	game.spot_count = 0
	game.nap_progress = 0
	game.caught = false
	game.pending_vac = 0
	game.queued = 0
	vac_start: Tile
	for row, r in lvl.map_rows {
		y := BOARD_H - 1 - r
		for x in 0 ..< BOARD_W {
			p := Tile{x, y}
			switch row[x] {
			case '#': game.solid[y][x] = true
			case 'C': game.start = p
			case 'V': vac_start = p
			case 'S': add_spot(p, .Sofa)
			case 'B': add_spot(p, .Basket)
			case 'K': add_spot(p, .Keyboard)
			}
		}
	}
	game.pos = game.start
	expand_route(lvl.route)
	game.vac = 0
	for i in 0 ..< game.route_len {
		if game.route[i] == vac_start { game.vac = i }
	}
}

add_spot :: proc(p: Tile, kind: SpotKind) {
	game.spots[game.spot_count] = {pos = p, kind = kind}
	game.spot_count += 1
}

// Turns corner waypoints into one tile per step. The loop closes back on the first waypoint.
expand_route :: proc(waypoints: []Tile) {
	game.route_len = 0
	for i in 0 ..< len(waypoints) - 1 {
		a, b := waypoints[i], waypoints[i + 1]
		step := Tile{sign(b.x - a.x), sign(b.y - a.y)}
		for p := a; p != b; p += step {
			game.route[game.route_len] = p
			game.route_len += 1
		}
	}
}

sign :: proc(n: int) -> int {
	return 1 if n > 0 else -1 if n < 0 else 0
}

vacuum_pos :: proc() -> Tile {
	return game.route[game.vac]
}

// The spot under the cat that has not been napped in yet, or -1.
open_spot_at :: proc(p: Tile) -> int {
	for s, i in game.spots[:game.spot_count] {
		if s.pos == p && !s.done { return i }
	}
	return -1
}

// A key press. While the vacuum is still moving it is remembered (up to MAX_QUEUED) and acted on
// at the cat's next turn; otherwise the cat moves now.
press :: proc(dir: Tile) {
	if game.pending_vac > 0 {
		if game.queued < MAX_QUEUED {
			game.queue[game.queued] = dir
			game.queued += 1
		}
		return
	}
	player_move(dir)
}

// Advances the vacuum's animation by dt seconds, one tile per VACUUM_STEP_DELAY, then starts the
// cat's next queued move once the vacuum has finished.
tick :: proc(dt: f64) {
	if game.state != .Playing { return }
	if game.pending_vac > 0 {
		game.anim_time += dt
		if game.anim_time >= VACUUM_STEP_DELAY {
			game.anim_time -= VACUUM_STEP_DELAY
			vacuum_step()
		}
	}
	if game.pending_vac == 0 && game.queued > 0 && game.state == .Playing {
		dir := game.queue[0]
		for i in 1 ..< game.queued { game.queue[i - 1] = game.queue[i] }
		game.queued -= 1
		player_move(dir)
	}
}

// A whole turn at once, with no animation delay (used by tests).
take_turn :: proc(dir: Tile) {
	player_move(dir)
	for game.pending_vac > 0 { vacuum_step() }
}

// The cat's half of a turn. Walking into a wall leaves the cat where it is and still uses the
// turn: that is how the cat waits. Unless the turn ended early (caught, or the level cleared),
// the vacuum then owes VACUUM_STEPS tiles, which vacuum_step pays one at a time.
player_move :: proc(dir: Tile) {
	game.message = ""
	game.caught = false
	target := game.pos + dir
	stayed := game.solid[target.y][target.x]
	if !stayed { game.pos = target }

	if stayed {
		if i := open_spot_at(game.pos); i >= 0 {
			game.nap_progress += 1
			if game.nap_progress >= NAP_TURNS {
				finish_nap(i)
				if all_napped() {
					next_level()
					return
				}
			}
		}
	} else {
		game.nap_progress = 0
	}

	if game.pos == vacuum_pos() {
		get_caught()
		return
	}
	game.pending_vac = VACUUM_STEPS
	game.anim_time = 0
}

// One tile of the vacuum's move. It catches the cat on any tile it touches.
vacuum_step :: proc() {
	game.vac = (game.vac + 1) % game.route_len
	game.pending_vac -= 1
	if game.pos == vacuum_pos() { get_caught() }
}

finish_nap :: proc(i: int) {
	game.spots[i].done = true
	game.nap_progress = 0
	game.naps += 1
	game.message = "A good nap. The house is quiet."
	if game.naps % NAPS_PER_LIFE == 0 && game.lives < MAX_LIVES {
		game.lives += 1
		game.message = "Extra life! Well rested."
	}
}

all_napped :: proc() -> bool {
	for s in game.spots[:game.spot_count] {
		if !s.done { return false }
	}
	return true
}

next_level :: proc() {
	game.level += 1
	game.level_idx = (game.level_idx + 1) % len(LEVELS)
	load_level()
	game.message = "House napped. On to the next."
}

get_caught :: proc() {
	game.caught = true
	game.pending_vac = 0
	game.queued = 0
	game.lives -= 1
	game.nap_progress = 0
	game.pos = game.start
	game.message = "The vacuum got you!"
	if game.lives <= 0 {
		game.lives = 0
		game.state = .Dead
	}
}
