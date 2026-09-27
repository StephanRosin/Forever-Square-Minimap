# Forever Square Minimap

A square minimap for WoW: Forever and TBC Classic Anniversary. Hold Ctrl and
drag its bottom left corner to resize it; addon icons stay on the edge.
Flat or gold border, zone, server and local time, FPS and latency inside the
map, profiles, and English, German, Spanish and French.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_classic_beta_/Interface/AddOns"
    tools/package                # dist/ForeverSquareMinimap-<version>.zip
    tools/release release "<changelog>"   # bump ## Version first
