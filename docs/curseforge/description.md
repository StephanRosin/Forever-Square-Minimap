**Summary**

A clean square minimap you resize by dragging its corner, with a flat or gold border. Addon icons stay on the edge, Blizzard's clutter is gone, and zone, clocks, FPS and latency sit inside the map.

---

# Forever Square Minimap

A square minimap for **WoW: Forever** and **TBC Classic Anniversary**, without the round frame, the zoom buttons and the rest of Blizzard's decoration around it. One small addon, no libraries needed. English, Deutsch, Español, Français.

## Resize by dragging
- Hold **Ctrl** and drag the **bottom left corner** of the map: it grows and shrinks from 100 to 400 pixels and stays square.
- The map is anchored at its top right corner, so it grows away from the screen edge and never jumps while you drag.
- Size and position can also be set exactly with sliders in the options or with a slash command.

## Border
- **Flat**: any colour, with opacity.
- **Gold**: shaded like a bevel, light at the top and dark at the bottom, with a dark line along the inside.
- Thickness from 1 to 8 pixels, sharp at any UI scale. Or no border at all.

## Addon icons stay on the edge
- The addon tells other addons that the minimap is square (`GetMinimapShape`), so every LibDBIcon button (Questie, DBM, Details, WeakAuras, Bartender4, AtlasLoot, ...) sits on the square edge instead of a circle inside the map.
- Resize the map and the icons follow the new edge at once. You can still drag them around the edge as usual.

## Less clutter
- Hidden: the round border, the north tag, the zoom buttons (the **mouse wheel zooms** instead), the world map button, the close button and Blizzard's clock and zone buttons.
- Tracking, mail and the battleground queue move into a tidy **column on the right edge**, only while they are shown, without gaps.

## Everything inside the map
- **Zone name** centred at the top, with the **server time** below it.
- **Local time** of your computer in the bottom right corner.
- **FPS and world latency**, coloured green, yellow or red. The display moves out of the way of the button column by itself and can be shifted in the options.
- All text has an outline, so it stays readable on bright map ground.

## Options
- Options window under Interface > AddOns > Forever Square Minimap: language, size, map position, border, position of the button column, FPS/latency on or off and its position. Every slider has a text field for exact values.
- **Profiles**: save your layout under a name and switch between profiles per character. Your language stays when you switch.

## Commands
`/squareminimap` or `/fsm` (status), `/fsm size <100-400>`, `/fsm move <x> <y>`, `/fsm col <x> [y]`, `/fsm reset`, `/fsm dump`

Positive values always mean right or up. `dump` opens a copyable window with the size, anchor and parent of every minimap element, handy for bug reports. It is always in English.

## Notes
- Made for WoW: Forever and TBC Classic Anniversary.
- Languages: English, German (Deutsch), Spanish (Español, also for Latin American clients) and French (Français). The addon follows the game's language; the first option in its settings picks another one, and the change applies at once. Other game languages use English.
- The translations were not written by native speakers: corrections are very welcome on the issue tracker.
- Other minimap addons that reshape or move the minimap (e.g. the minimap module of Leatrix Plus) will fight over the same frames: use only one of them.
- Bug reports and ideas are welcome on the project's issue tracker.
