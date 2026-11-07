# Redrawing the enemies: eerie, quiet, memorable

## Why

Every creature is drawn in code (`CreatureArt`: polygons, lines and circles on a small pixel canvas, animated by a clock). Each is a reasonable shape (a blue spider, a brown insect, a jellyfish), but none is a silhouette you would know in the dark, and none says what it does. In this game the light is the whole fight, so the art should show what a creature does to the light, or to you in the dark.

Tone, chosen: **eerie and quiet.** Sparse, pale, a few strong silhouettes, glowing eyes. It fits the slow, dark exploration the game has been moving toward (M82 to M91).

Success looks like: each of the three enemies and the nest can be told apart, in silhouette and at 1x, by someone who has played once; each shows its mechanic; the Stalker is first seen as two eyes at the edge of the dark.

## What exists

- `CreatureArt` (`scripts/creature_art.gd`): `kind` ("stalker", "burrower", "snuffer", "fuel", "ore"), a clock `t`, and `pose` (0 to 1: a lunge, or how wide the mandibles are). It faces +x; `ArtSprite` mirrors it with `flip_h`. It redraws 20 times a second, and only while on screen.
- `ArtSprite` shows the art through a small `SubViewport` as a nearest-filtered `Sprite2D`, so it is lit like any sprite: in the dark it is black, which is why a creature outside the light cannot be seen at all today.
- The Stalker (`stalker.gd`) drives `pose` (1.0 on a strike) and `flip_h`; the Burrower (`burrower.gd`) the same, with a longer strike pose; the Snuffer (`snuffer.gd`) only `flip_h`. The nest is `GearArt` kind "nest".
- Cells: the Stalker uses 64 by 48 (origin 32, 30); the others 48 by 48. Collision boxes are about 14 by 18 and are not part of this work.
- Today's look, for reference: Stalker, a blue eight-legged spider; Burrower, a brown insect with mandibles; Snuffer, a pale jellyfish with a faint halo; Nest, a cluster of green eggs.

## Style rules (all four)

1. **One accent colour each, and the rest is pale or dark.** Bodies are desaturated and low-contrast against rock; the accent (eyes, a core, a mouth) is the one thing that pops.
2. **Silhouette first.** Each must read as a solid shape at 1x with no interior detail: different height-to-width, different limb count, different motion.
3. **Slow and few moving parts.** Idle motion is a slow breath or sway, not a scuttle. Fast motion is reserved for the one moment that matters (a strike, a lunge).
4. **No outline noise.** One dark outline at most; detail comes from a second and third tone, not from extra pixels.
5. **The gameplay interface does not change.** Same `kind` names, same `pose`, same `flip_h`, same cells where they fit. No change to speed, health, collision, light or noise rules.

## The designs

### Stalker: seen only by its eyes

Hook: at the edge of the dark you see **two cold eyes** before anything else. The body is a tall, thin, pale figure with long forearms; it is only visible while lit.

- Silhouette: narrow and tall (about twice as tall as it is wide), hunched, forearms longer than its legs; unlike every other creature, it has no wide stance.
- Palette: bone and grey body; **one accent, ice blue eyes** (the old red moves to the strike).
- Eyes are drawn **unlit**, so they show in total darkness (see Technical approach). They are small and slow to blink; they swell and narrow into slits as it commits to a strike (`pose` 0 to 1), and flash red on the strike.
- States: lurk (eyes only, a slow sway), approach (a slow lean), flee (the eyes sink and dim), strike (`pose` 1: the forearms reach).
- The deep Stalker (the second one, in the deep rock) gets **four eyes** and a taller body: same drawing with a variant flag, no new class.

### Burrower: a drill with legs

Hook: a **segmented armoured worm with a ring of teeth at its head**, the teeth spinning like a drill bit; it ripples as it moves and kicks rubble off its flanks.

- Silhouette: long and low (about four times as long as tall), a fat head tapering through four or five segments; the strongest horizontal read of the four.
- Palette: dull bronze segments with pale teeth; accent **a hot orange mouth** (the glow of something chewing through stone).
- Idle (tunnelling): the segments ripple front to back, the tooth ring turns. Strike (`pose`): the ring flares open and spins fast, as the mandibles flare now.
- Rubble specks come off in a short, cheap trail (a few pixels, not particles).

### Snuffer: the opposite of a lantern

Hook: the jellyfish stays (it is already the best idea) but becomes **a body that is bright where the world is dim.** Its core glows more the more it drains, and a thin tether reaches to the light it is eating.

- Silhouette: a bell on top with long trailing tendrils; round and soft against the others' hard edges.
- Palette: translucent grey-blue bell; **accent a magenta core**, brightness tied to what it is doing (dim while drifting, bright while draining).
- It drains lamps and the base light: while draining, a thin pale line runs from the bell to that light and the core pulses with the drain.
- It needs a small interface addition: `pose` set to 1 while draining (the Snuffer does not set `pose` today), and the target's position for the tether.

### Nest: alive before you flare it

Hook: a pulsing cluster of pale sacs with faint dark veins. It breathes slowly; as `burn` rises, it shrivels and darkens.

- Silhouette: a low heap of rounded sacs. Palette: bruised cream and grey; accent a dull amber inside the sacs.
- This is `GearArt` kind "nest", not `CreatureArt`; the redraw stays there.

## Technical approach

- Keep `CreatureArt`'s API. Replace the four draw functions (and the nest's); add a `variant` (`deep` for the second Stalker) next to `pose`.
- **Unlit eyes (the one new mechanism).** The art is lit like any sprite, so eyes that must show in the dark need to be drawn unlit. Plan: `ArtSprite` gains an optional second `SubViewport` for glow-only elements, shown on a `Sprite2D` with an unshaded material, so the eyes ignore the scene's darkening. This is **Phase 0, a spike**: it proves the glow shows in total dark, does not brighten nearby rock, and costs no more than a second tiny viewport that only renders while on screen.
- Drawing style: hand-placed shapes on the pixel grid, using a few polygons per creature. Each creature has a small palette in `PAL`, with its accent colour.
- No new random numbers in drawing (`ArtSprite` already gives art its own phase generator).

## Phases (one PR each; the first two are the gate)

0. **A review harness and the glow spike.** A playtest scenario that renders each creature in each state (idle, move, alert, strike, flee, die where there is one) on a plain background at 1x and 5x, and on the real dark mine at 1x, as screenshots; and the unlit glow layer. Nothing is redrawn yet. This is what every later PR is judged by.
1. **Stalker** (the glow, the figure, the variants).
2. **Burrower.**
3. **Snuffer** (with the drain tether).
4. **Nest.**

Each PR shows before and after sheets in the harness' format and in the real dark, and stays inside the style rules above.

## Testing

- **Fits its cell:** each kind, in each pose, draws no opaque pixel on the border of its cell (it does not clip).
- **Deterministic:** the same `t` and `pose` draw the same pixels.
- **Reads as pose:** `pose` 0 and `pose` 1 draw different pixels, and a flipped sprite is the mirror image.
- **Glow layer:** the Stalker's eyes are drawn on the glow layer (not the lit one), the lit layer has no eye pixels, the glow layer is empty when the creature is off screen.
- **Variants:** the deep Stalker draws four eyes, the ordinary one two.
- **Interface unchanged:** the existing tests for each enemy's behaviour pass without edits; the playtest scenarios still pass.
- **Cost:** `CreatureArt` still redraws at `REDRAW_FPS` and not while off screen; the frame-time budget test is unchanged.
- **By eye:** the harness sheets. The pictures are the real acceptance test; the unit tests only keep the mechanics honest.

## Out of scope

The miner, the gear, the Heart and the hub's art; new enemies or behaviours; any change to speed, health, light, noise or collision; sound (a Stalker's "no sound" could be a separate piece); a hand-drawn art pass (this is code-drawn pixels, and a later hand-drawn replacement would only need to keep the `CreatureArt` API).

## Risks and open questions

- **Quality of code-drawn pixel art.** The risk is that polygons look crude next to hand-drawn art (the cobweb in M90 needed a redraw). Mitigation: Phase 0's harness makes iteration cheap, every PR shows pictures, and the user is the judge; if a creature does not work, we stop and say so instead of shipping it.
- **Unlit eyes in total dark** may make the Stalker too easy to track (you see it coming) or still too hard to see. They are constants (size, brightness) to tune by hand play. Note that today the Stalker is invisible outside the light, so this changes how the threat is read: it becomes a thing you can see approach, which fits "strikes when your light fails" and the rule that the light holds it off.
- **Colour reading.** Ice blue eyes and orange mouths must stay distinguishable for colour-blind players; each creature also differs in silhouette and motion, so no single colour carries the meaning.
- **Open question:** should the deep Stalker be a distinct enemy in name (a different look suggests a different creature)? This spec treats it as the same species with a variant.
