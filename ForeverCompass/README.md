# Forever Compass

Forever Compass adds a curved compass to World of Warcraft: Forever (Interface 16001). The cardinal marks follow your character's facing.

- Watch a quest in the quest log to see every available objective location for that quest. Each gold marker shows its own bearing and straight-line distance in yards. When rows fill up, distances move into a compact block centered under the compass. The block shifts to stay visible if you drag the compass near a screen edge, and uses another visible area when there is no room below. Thin gold lines connect shifted labels to their bearings.
- A gold `!` marks a quest objective location. A gold `~` marks the next route waypoint when the game supplies one instead of a usable objective location.
- Ctrl+left-click a supported location on the World Map to place a pin. A purple diamond shows its own bearing and distance. For both marker types, an edge chevron points toward a bearing beyond the visible arc.

1. Extract the `ForeverCompass` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Start WoW Forever or run `/reload`. Enable **Forever Compass** in the AddOns list.

- `/fcompass` shows or hides the compass.
- `/fcompass move` unlocks the compass. Drag it into place and repeat the command to lock it.
- `/fcompass reset` restores the default position and locks it.
- `/fcompass test` toggles 64 sample distances stacked at the center bearing. Use `/fcompass test 128` to try a different count from 1 to 128, or `/fcompass test off` to exit. **Test Mode** replaces live quest labels for the session and keeps the manual pin visible. Turning it off or reloading restores your saved compass visibility.

The arc is a screen overlay. Markers require usable map coordinates in the character's current world space. Blizzard sometimes provides one shared map location for several objective lines, or gives no location. Shared locations appear once per quest.
