#+build !js
package main

import "core:log"
import "core:testing"

@(private = "file")
fresh :: proc() {
	game = {}
	reset_game()
	game.state = .Playing
}

@(test)
route_is_valid :: proc(t: ^testing.T) {
	for idx in 0 ..< len(LEVELS) {
		game = {level_idx = idx}
		load_level()
		testing.expect(t, game.route_len > 0)
		for i in 0 ..< game.route_len {
			a, b := game.route[i], game.route[(i + 1) % game.route_len]
			d := b - a
			testing.expectf(t, abs(d.x) + abs(d.y) == 1, "level %d: route step %d is not adjacent: %v -> %v", idx, i, a, b)
			testing.expectf(t, !game.solid[a.y][a.x], "level %d: route tile %v is a wall", idx, a)
		}
		vac := vacuum_pos()
		testing.expectf(t, game.route[game.vac] == vac && vac != {}, "level %d: no vacuum start", idx)
		for s in game.spots[:game.spot_count] {
			onroute := false
			for i in 0 ..< game.route_len { if game.route[i] == s.pos { onroute = true } }
			testing.expectf(t, onroute, "level %d: nap spot %v is never visited by the vacuum", idx, s.pos)
		}
	}
}

@(test)
spots_reachable :: proc(t: ^testing.T) {
	for idx in 0 ..< len(LEVELS) {
		game = {level_idx = idx}
		load_level()
		seen: [BOARD_H][BOARD_W]bool
		queue: [dynamic]Tile
		defer delete(queue)
		append(&queue, game.start)
		seen[game.start.y][game.start.x] = true
		for head := 0; head < len(queue); head += 1 {
			for d in ([4]Tile{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
				n := queue[head] + d
				if !game.solid[n.y][n.x] && !seen[n.y][n.x] {
					seen[n.y][n.x] = true
					append(&queue, n)
				}
			}
		}
		for s in game.spots[:game.spot_count] {
			testing.expectf(t, seen[s.pos.y][s.pos.x], "level %d: spot %v unreachable", idx, s.pos)
		}
	}
}

@(test)
spots_have_a_wall_to_bump :: proc(t: ^testing.T) {
	for idx in 0 ..< len(LEVELS) {
		game = {level_idx = idx}
		load_level()
		for s in game.spots[:game.spot_count] {
			walled := false
			for d in ([4]Tile{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
				n := s.pos + d
				if game.solid[n.y][n.x] { walled = true }
			}
			testing.expectf(t, walled, "level %d: spot %v has no wall beside it, so no nap is possible", idx, s.pos)
		}
	}
}

@(test)
walking_into_wall_stays_put :: proc(t: ^testing.T) {
	fresh()
	game.pos = {1, 1}
	game.vac = 0
	take_turn({-1, 0})
	testing.expect_value(t, game.pos, Tile{1, 1})
}

@(test)
vacuum_moves_two_tiles :: proc(t: ^testing.T) {
	fresh()
	before := game.vac
	take_turn({1, 0})
	testing.expect_value(t, game.vac, (before + 2) % game.route_len)
}

@(test)
vacuum_sweeps_both_tiles :: proc(t: ^testing.T) {
	fresh()
	game.vac = 0
	game.pos = game.route[1] // the vacuum passes over it on step 1 and ends on route[2]
	lives := game.lives
	take_turn({0, 0}) // zero direction: the cat stays on its own tile
	testing.expect_value(t, game.lives, lives - 1)
	testing.expect_value(t, game.pos, game.start)
}

@(test)
nap_completes_after_three_stays :: proc(t: ^testing.T) {
	fresh()
	// a spot in the corner so that walking into the wall is a stay-put turn
	game.spots[0].pos = {1, 1}
	game.pos = {1, 1}
	game.vac = (game.route_len / 2 + 7) % game.route_len // far from the corner
	for _ in 0 ..< NAP_TURNS - 1 {
		take_turn({-1, 0})
	}
	testing.expect_value(t, game.naps, 0)
	take_turn({-1, 0})
	testing.expect_value(t, game.naps, 1)
	testing.expect(t, game.spots[0].done)
}

@(test)
moving_off_a_spot_resets_nap :: proc(t: ^testing.T) {
	fresh()
	game.spots[0].pos = {1, 1}
	game.pos = {1, 1}
	game.nap_progress = 2
	game.vac = (game.route_len / 2 + 7) % game.route_len
	take_turn({0, 1})
	testing.expect_value(t, game.nap_progress, 0)
}

@(test)
extra_life_at_twenty_naps_capped :: proc(t: ^testing.T) {
	fresh()
	game.naps = NAPS_PER_LIFE - 1
	finish_nap(0)
	testing.expect_value(t, game.lives, START_LIVES + 1)
	game.lives = MAX_LIVES
	game.naps = NAPS_PER_LIFE * 2 - 1
	finish_nap(1)
	testing.expect_value(t, game.lives, MAX_LIVES)
}

@(test)
losing_last_life_ends_game :: proc(t: ^testing.T) {
	fresh()
	game.lives = 1
	get_caught()
	testing.expect_value(t, game.state, State.Dead)
	testing.expect_value(t, game.lives, 0)
}

@(test)
all_spots_clears_level :: proc(t: ^testing.T) {
	fresh()
	for i in 0 ..< game.spot_count { game.spots[i].done = true }
	game.naps = 5
	next_level()
	testing.expect_value(t, game.level, 2)
	testing.expect_value(t, game.naps, 5)
	testing.expect(t, !all_napped())
}

SolveNode :: struct {
	pos:      Tile,
	vac:      int,
	progress: int,
	mask:     int, // bit i set when spot i is done
}

// Breadth-first search over every way to play a level, using the real take_turn. Returns the
// fewest turns that clear it without being caught, or -1 if it cannot be cleared.
@(private = "file")
solve_level :: proc(idx: int) -> int {
	game = {level_idx = idx, level = 1}
	load_level()
	game.state = .Playing
	n_spots, route_len := game.spot_count, game.route_len
	start := game.start
	size := BOARD_W * BOARD_H * route_len * NAP_TURNS * (1 << uint(n_spots))
	seen := make([]bool, size)
	defer delete(seen)
	key :: proc(n: SolveNode, route_len, n_spots: int) -> int {
		k := (n.pos.y * BOARD_W + n.pos.x) * route_len + n.vac
		return (k * NAP_TURNS + n.progress) * (1 << uint(n_spots)) + n.mask
	}
	frontier: [dynamic]SolveNode
	next: [dynamic]SolveNode
	defer delete(frontier)
	defer delete(next)
	first := SolveNode{pos = start, vac = game.vac}
	append(&frontier, first)
	seen[key(first, route_len, n_spots)] = true
	for turns := 1; len(frontier) > 0; turns += 1 {
		clear(&next)
		for node in frontier {
			for d in ([4]Tile{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
				game.lives = 1000
				game.pos = node.pos
				game.vac = node.vac
				game.nap_progress = node.progress
				for i in 0 ..< n_spots { game.spots[i].done = node.mask & (1 << uint(i)) != 0 }
				level_before := game.level
				take_turn(d)
				if game.level != level_before {
					return turns
				}
				if game.caught { continue }
				mask := 0
				for i in 0 ..< n_spots { if game.spots[i].done { mask |= 1 << uint(i) } }
				succ := SolveNode{pos = game.pos, vac = game.vac, progress = game.nap_progress, mask = mask}
				k := key(succ, route_len, n_spots)
				if !seen[k] {
					seen[k] = true
					append(&next, succ)
				}
			}
		}
		frontier, next = next, frontier
	}
	return -1
}

@(test)
levels_are_winnable :: proc(t: ^testing.T) {
	for idx in 0 ..< len(LEVELS) {
		turns := solve_level(idx)
		testing.expectf(t, turns > 0, "level %d cannot be cleared without being caught", idx + 1)
		log.infof("level %d: shortest clear is %d turns (route %d tiles)", idx + 1, turns, game.route_len)
	}
}

@(test)
vacuum_moves_one_tile_at_a_time :: proc(t: ^testing.T) {
	fresh()
	before := game.vac
	press({1, 0})
	testing.expect_value(t, game.pos, game.start + {1, 0}) // the cat moves at once
	testing.expect_value(t, game.pending_vac, VACUUM_STEPS)
	testing.expect_value(t, game.vac, before) // the vacuum has not moved yet
	tick(VACUUM_STEP_DELAY * 0.5)
	testing.expect_value(t, game.vac, before)
	tick(VACUUM_STEP_DELAY * 0.6)
	testing.expect_value(t, game.vac, (before + 1) % game.route_len) // first tile shown
	testing.expect_value(t, game.pending_vac, 1)
	tick(VACUUM_STEP_DELAY)
	testing.expect_value(t, game.vac, (before + 2) % game.route_len)
	testing.expect_value(t, game.pending_vac, 0)
}

@(test)
presses_during_animation_wait_for_the_cats_turn :: proc(t: ^testing.T) {
	fresh()
	start := game.start
	press({1, 0})
	press({1, 0})
	press({0, 1})
	testing.expect_value(t, game.pos, start + {1, 0}) // queued, not acted on
	testing.expect_value(t, game.queued, 2)
	tick(VACUUM_STEP_DELAY) // vacuum tile 1: still the vacuum's turn
	testing.expect_value(t, game.pos, start + {1, 0})
	tick(VACUUM_STEP_DELAY) // vacuum tile 2, then the first queued press is acted on
	testing.expect_value(t, game.pos, start + {2, 0})
	testing.expect_value(t, game.queued, 1)
	testing.expect_value(t, game.pending_vac, VACUUM_STEPS)
}

@(test)
queue_is_capped :: proc(t: ^testing.T) {
	fresh()
	press({1, 0})
	for _ in 0 ..< MAX_QUEUED + 4 { press({1, 0}) }
	testing.expect_value(t, game.queued, MAX_QUEUED)
}

@(test)
catch_mid_animation_stops_vacuum_and_clears_queue :: proc(t: ^testing.T) {
	fresh()
	game.vac = 0
	game.pos = game.route[1]
	press({0, 0}) // stay on the tile the vacuum will pass over on its first step
	press({1, 0})
	lives := game.lives
	tick(VACUUM_STEP_DELAY)
	testing.expect_value(t, game.lives, lives - 1)
	testing.expect_value(t, game.pending_vac, 0)
	testing.expect_value(t, game.queued, 0)
	testing.expect_value(t, game.vac, 1) // it did not go on to its second tile
}
