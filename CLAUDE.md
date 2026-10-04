# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

This repo is the **second entry** for [Jamference: AI Game Jam Hack 1](https://itch.io/jam/jamference-ai-game-jam-hack-1): "Roomba Rights of SPLORR!!", a cat dodging a hidden-route robot vacuum while napping. `DESIGN.md` is the source of truth for rules, open questions and acceptance criteria. All five levels are built and playable, and each has its own wall and floor tiles.

## Jam rules that constrain the design

- Build week is Oct 2–9, 2026; rating week follows. Only bug fixes are allowed in rating week. Everything must be made during jam week (reused personal assets and licensed materials are fine).
- Theme "Cat and Robot" is optional. The **mandatory restriction is "Movement Input Only"**: all input maps to player movement, with no attack, shoot or UI-selection buttons. Menus and instruction screens also have to be dismissed by movement keys (the first entry used any movement key, Space or Enter).
- Judged equally on **Fun**, **AI Use** (thoughtfulness and ambition) and **Polish**. AI must be genuinely involved (code, art, audio, writing, level generation, design ideation, or a live in-game system), and the tools and their roles must be disclosed.
- Multiple entries are allowed, each on its own page and judged separately. Disclose team members and any contribution to other entries.
- Web builds are recommended. Content must be broadly safe, with intensity flags.
- Something playable at the deadline is enough, so keep scope small.

## Commands

```bash
ODIN=/home/yermom/ODIN/odin ./build.sh                       # builds into build/web
python3 -m http.server -d build/web 8123                     # serve locally (not file://)
/home/yermom/ODIN/odin test src -define:ODIN_TEST_THREADS=1  # native logic tests; leaves a stray `odin` binary (git-ignored)
```

Open `http://localhost:8123/?level=N` to jump straight to level N (QA shortcut, wired through the exported `debug_level`).

## Shipping and store assets

`./shippit.sh` tests, builds and zips into `build/roomba-rights-html5.zip` (for a manual itch.io upload), and only runs `butler push` to `thegrumpygamedev/roomba-rights-of-splorr:html` when given `--push`. **Never pass `--push` unless the user explicitly says so**: it publishes the game. Run `./shippit.sh` without `--push` only when asked to. The page slug is an assumption until the user creates the itch.io page. Page copy is `ITCH_DESCRIPTION.md`; `tools/make_cover.py` redraws `assets/cover.png` (630x500); `assets/screenshots/levelN.png` are 800x800 headless-Chrome captures (`google-chrome --headless=new --no-sandbox --window-size=800,800 --virtual-time-budget=4000 --screenshot=out.png "http://localhost:8123/?level=N"`).

## Code layout (`src/`)

- `game.odin`: pure logic (state, `take_turn`, lives, naps, vacuum stepping). No browser imports, so it builds natively. All state changes happen in `take_turn`.
- `levels.odin`: level data. Each level is an ASCII map (`#` wall, `C` cat start, `V` vacuum start, `S`/`B`/`K` nap spots) plus the vacuum's route as corner waypoints. A new level only needs data here, plus sprites for any new spot kinds. `game_test.odin` checks that every route is a valid closed loop, that every nap spot is reachable, on the route and has a wall beside it, and (with a breadth-first solver over the real `take_turn`) that every level can be cleared without being caught. Any new level must pass all of these.
- `web.odin` (`#+build js`): the canvas shim imports, key input, drawing, HUD and the exported `step`. Everything touching `core:sys/wasm/js` belongs here, and `game_test.odin` is `#+build !js`.
- Map rows are listed top to bottom; world y is up (`y = BOARD_H - 1 - row`).

## Related projects and knowledge (outside this repo)

- **Obsidian vault `/home/yermom/git/bok-of-splorr/splorr/`** documents all of the user's SPLORR!! games. Start at `Home.md`. Most useful notes: `Jams/Jamference AI Game Jam Hack 1.md`, `Games/Robokitteh of SPLORR!!.md`, `Tech/Odin wasm recipe.md`, `Tech/Shipping to itch.io.md`, `Gotchas.md`, `Concepts/Metaphor design.md`, `Concepts/Starvation.md`, and `Tech/Urizen tileset.md` (the sheet is in `Assets/`, with other bitmap fonts). Read `Gotchas.md` before writing any Odin/wasm code. The vault has its own standing rules; update it when a new game is added (new note under `Games/` with frontmatter type/jam/year/stack/status/itch/repo, linked from `Home.md` and the jam note).
- **First entry `/home/yermom/git/robokitteh-of-splorr/`** ("Robokitteh of SPLORR!!", shipped Oct 3). It is the template for this entry: copy `build.sh`, `web/index.html` (the 2D canvas shim, which also knocks black out of the tileset), the `src/main.odin` structure, `shippit.sh` and `ITCH_DESCRIPTION.md` as starting points. Its own `CLAUDE.md` documents the stack in detail.

## Established stack and conventions (from the first entry)

- Odin (nightly at `/home/yermom/ODIN/odin`) compiled to `js_wasm32`, run by Odin's own `odin.js` (no emscripten). `main` sets up once; an exported `step(dt, ctx)` runs every animation frame. Event callbacks and `step` must set `context = ctx`.
- Build: `ODIN=/home/yermom/ODIN/odin ./build.sh` writes `build/web`. Serve with `python3 -m http.server -d build/web <port>` (not `file://`). Pick a port other than 8765, which is often taken by another project's server; check the first response.
- Render with a **2D canvas through a JS shim, never WebGL**: the user's Linux Chrome and the in-app browser pane cannot create a WebGL context.
- Seed the RNG in `main` (`rand.reset(u64(time.now()._nsec))`); the default is not random on wasm. Cap every "find a free tile" retry loop, because an infinite loop freezes the whole browser tab.
- Art is usually the CC0 Urizen 1-bit tileset by vurmux (12px tiles, 1px gap; credit vurmux). Check tile coordinates in the vault note, and keep text lines short enough to fit the screen (bitmap font at 0.6 tile per glyph).
- Read the logical `e.key` before `e.code` for keyboard input (remote desktops send wrong codes).
- To test in the browser pane, dispatch `KeyboardEvent("keydown", {code})` on `window` from JavaScript, but note that did not work for one of the games, where real key presses did. Screenshots can lag one step.

## Style of the user's games ("Metaphors")

The user calls their games "interactive experiences (Metaphors)": the mechanic is the message, the look is minimal and retro, copy is short and deadpan and describes the game straight, and titles are absurdist with the "of SPLORR!!" suffix. Do not "fix" difficulty that exists to carry the metaphor.

## Working model (also the AI-use disclosure)

Claude is the primary individual contributor: it writes all the code, the web shim and the build setup. The user is the product owner. They make design decisions together with Claude, and they do manual playtesting as QA against acceptance criteria. The user writes no code. So:

- Propose designs with a clear recommendation and let the user decide; turn each agreed decision into explicit acceptance criteria the user can check by playing.
- Verify what you can yourself (build, run, drive the game in the browser pane) before handing a build over for QA, and say what was and wasn't verified.
- Disclose this split, plus the model used, in `ITCH_DESCRIPTION.md`, as the jam requires.

## Rules for sessions in this repo

- **Never `git push` and never run any ship/publish script (`butler push`, `shippit.sh`) unless the user explicitly says so.** Shipping publishes publicly; build first, commit first, and the user pastes the itch.io page copy by hand.
- The itch.io game page copy (including the jam's AI-use disclosure) belongs in `ITCH_DESCRIPTION.md` once the game exists.
- Commit author is `TheGrumpyGameDev`.
