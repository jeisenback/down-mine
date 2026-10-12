class_name Groups

## The node groups the game uses to find things without holding references (milestone 67).
## Always use these constants: a mistyped group name is silent (it is just an empty group),
## a mistyped constant does not parse. tests/test_hygiene.gd fails on a bare string.

const MINE_EVENTS := "mine_events"
const MINE_LIGHTS := "mine_lights" # every light: the lantern, lamps, torches, the base, miners
const SNUFFABLE := "snuffable" # the lights a Snuffer hunts
const LAMPS := "lamps" # placed lamps (not torches)
const TORCHES := "torches"
const SNUFFERS := "snuffers"
const STALKERS := "stalkers"
const BURROWERS := "burrowers"
const SUPPORTS := "supports"
const ANCHORS := "anchors"
const GAS_CLOUDS := "gas_clouds"
const PLAYER := "player"
