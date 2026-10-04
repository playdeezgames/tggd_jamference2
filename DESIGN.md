# Roomba Rights of SPLORR!!

Design document and acceptance criteria. The user is the product owner and plays the builds as QA; Claude writes all the code. Items marked **[OPEN]** are not decided yet. Items marked **[TUNE]** are decided in shape, but the number is a first guess to adjust in playtesting.

Entry for [Jamference: AI Game Jam Hack 1](https://itch.io/jam/jamference-ai-game-jam-hack-1) (Oct 2–9, 2026). Theme "Cat and Robot". Mandatory restriction: **Movement Input Only**.

## Premise

You are a cat in a house. A robot vacuum patrols the rooms. You want to nap, and the vacuum keeps ending naps. A house run by machines does not leave you any rest. Copy plays this straight, with no winking about the odds.

## Decisions so far

| # | Decision |
| --- | --- |
| 1 | The concept is "cat versus robot vacuum", not the cat-herding of Robokitteh. Ideas from the "quiet robot cat" pitch may be borrowed later. |
| 2 | Turn-based. Each key press is one turn. Nothing happens between presses. |
| 3 | The player moves first, then the vacuum moves. |
| 4 | The vacuum's **route is hidden**. The vacuum itself is always visible on screen. |
| 5 | The vacuum moves a **fixed 2 tiles per turn**, so a one-tile-per-turn cat cannot trivially stay ahead of it. |
| 6 | Lives: start with **3**, maximum **9**. Extra lives are earned from naps. |
| 7 | **Each completed nap earns score.** The first extra life comes at **20 naps** **[TUNE]**. |
| 8 | **No riding the vacuum.** This is a game purely of survival and avoidance. |
| 9 | **5 levels, repeating.** A level is solved when the cat has napped in every nap spot. After level 5 the game loops back to level 1. |

## Rules (proposed, to confirm)

### Turns and input

- Arrow keys or WASD are the only controls. They also dismiss the intro and game-over screens (no separate buttons).
- Each press moves the cat one tile and is one turn. Walking into a wall or furniture is allowed: the cat stays put and the turn is used. That bump is the game's **wait action** (the only way to stay still).
- After the player's move, the vacuum moves 2 tiles along its route. They are shown one at a time with a short pause (0.15 s before each tile). Key presses made while the vacuum is moving are queued (up to 3) and acted on, in order, at the cat's next turn. Being caught clears the queue.

### Naps and score

- The house has **nap spots** (sunbeam, laundry basket, keyboard, the good chair). Stepping onto one starts a nap.
- While on a nap spot, each turn you stay (a bump) counts toward the nap. A nap is **complete after 3 consecutive stay turns** **[TUNE]**. A completed nap adds 1 to the nap count and score. Stepping off early earns nothing.
- Extra life at 20 naps (counted across levels). Later thresholds are **[OPEN]** (for example every 20, or growing). The life cap is 9.
- A nap spot is **used up once a nap on it is completed** (it is marked as done), so the cat cannot farm one spot. Each spot is napped in once per level.

### The vacuum

- It follows a fixed route, hidden from the player, through the house. The route repeats, so it can be learned by watching.
- Moving 2 tiles per turn, it passes through both tiles. **If it touches the cat's tile at either step, the cat is caught.**
- It cannot be blocked or hurt. It is a force, not an enemy with HP.
- The cat can never ride it: any contact is a catch.
- Since the route is hidden and the vacuum can only be watched, a warning cue when it is close (a HUD hint or message) is **[OPEN]**. Leave it out unless playtesting shows the player cannot read the route.

### Lives and game over

- Being caught costs one life. The cat respawns at the level's start tile. The vacuum keeps going (no reset).
- At zero lives the game is over. The game-over screen shows score (nap count). Any movement key restarts.

### Levels

- There are **5 hand-designed levels**, played in order and then repeating from level 1. Each has its own map, nap spots, hidden vacuum route and wall/floor look. Lives, nap count and score carry over between levels.

| # | Name | Idea | Spots | Look (wall / floor) |
| --- | --- | --- | --- | --- |
| 1 | (house) | Four rooms around a hall with a block in the middle | 3 | grey cobblestone / teal carpet |
| 2 | The Long Hall | A one-tile-wide hall between three rooms up and three down. Duck into a doorway to let the vacuum pass | 4 | wood planks / dark parquet |
| 3 | Open Plan | One big room with furniture blocks and no doorways | 4 | dark grey brick / brown zigzag |
| 4 | Upstairs | A one-tile ring around a solid core, with alcoves to hide in and a spot in each corner | 4 | window panels / teal-green carpet |
| 5 | Full House | Six rooms (2 by 3) joined by doorways, with the route visiting every room | 5 | red brick / magenta dots |

- A level is solved when a nap has been completed on every nap spot in it. The next level starts straight away, with the cat at its start tile and the vacuum at its own start.
- Because the vacuum's speed is fixed, difficulty comes from layout and route. **[OPEN]** Whether the repeat of the levels is any harder (for example a longer route or more spots). The default is that it is not.
- Losing a life in a level does not reset the spots already napped in.

## Presentation

- Retro 1-bit, using the CC0 Urizen tileset by vurmux (12 px tiles, 1 px gap) and its bitmap font. Credit vurmux. The black-to-transparent knock-out and the channel-swap recolour live in the first entry's `web/index.html` shim.
- HUD (top panel): lives (cat icons, up to 9), nap count, and progress toward the next life.
- One-line event banner at the bottom (cleared on the next turn). Lines must fit the screen (about 33 characters at 0.6 tile per glyph on a 20-tile-wide screen).
- Intro screen with controls and rules, dismissed by a movement key.
- Deadpan text and an absurdist title in the "of SPLORR!!" style.

## Tech

Same stack as Robokitteh: Odin compiled to `js_wasm32`, 2D canvas through a JS shim, `build.sh` into `build/web`. See `CLAUDE.md` for the conventions and gotchas (seed the RNG, cap retry loops, read `e.key` before `e.code`).

## Acceptance criteria (for QA)

Each item is checked by playing.

1. **Controls.** Arrow keys and WASD move the cat one tile per press. No other key is needed to play, and nothing happens between presses.
2. **Wait.** Walking into a wall costs a turn and leaves the cat where it is.
3. **Vacuum speed.** The vacuum visibly moves 2 tiles per player turn, and the player cannot simply walk away from it in a straight line.
4. **Hidden route.** No route, path or trail is drawn. The same route repeats on each loop.
5. **Catch.** The vacuum touching the cat on either of its 2 steps costs one life and respawns the cat at the level's start. Spots already napped in stay done.
6. **Nap.** Standing on a nap spot for 3 consecutive stay turns completes a nap and raises the nap count by 1. Leaving early earns nothing. A spot that has been napped in is marked as done and earns nothing again that level.
7. **Extra life.** At 20 naps the cat gains a life, never going above 9. The player starts with 3 lives.
8. **Levels.** Napping in every spot of a level solves it and starts the next one. After level 5 the game continues with level 1. Lives and nap count carry over.
9. **Game over.** At zero lives the game-over screen shows the nap count, and a movement key restarts from 3 lives.
10. **Fit.** No text runs off the screen, and no sprite has a black background.
11. **Vacuum animation.** After the cat moves, the vacuum visibly shows its first tile, pauses briefly, then shows its second. Keys pressed meanwhile do nothing until the vacuum is done, then are played in order. Being caught discards them.
12. **Web build.** The game loads and plays from a static `http.server` and as an HTML5 upload on itch.io.

## Out of scope for now

- Riding the vacuum, multiple vacuums, sound and music (unless time allows), saved high scores, touch controls.

## Rules for future sessions

- Do not make the vacuum easier by drawing its route, slowing it, or letting the cat ride it, unless the user asks. Hiding the route, the fixed 2-tile speed and pure avoidance are deliberate.
- Do not add non-movement controls (the jam's restriction).
- Do not run `shippit.sh` or `git push` unless the user says so.
