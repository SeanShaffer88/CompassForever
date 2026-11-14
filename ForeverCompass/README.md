# Forever Compass

Forever Compass adds a curved compass to World of Warcraft: Forever (Interface 16001). The cardinal marks follow your character's facing.

- Watch a quest in the quest log to see every available objective location for that quest. Each gold marker shows its own bearing and straight-line distance in yards. When rows fill up, distance labels move into on-screen columns. Thin gold lines connect shifted labels to their bearings.
- A gold `!` marks a quest objective location. A gold `~` marks the next route waypoint when the game supplies one instead of a usable objective location.
- Ctrl+left-click a supported location on the World Map to place a pin. A purple diamond shows its own bearing and distance. For both marker types, an edge chevron points toward a bearing beyond the visible arc.

1. Extract the `ForeverCompass` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Start WoW Forever or run `/reload`. Enable **Forever Compass** in the AddOns list.

- `/fcompass` shows or hides the compass.
- `/fcompass move` unlocks the compass. Drag it into place and repeat the command to lock it.
- `/fcompass reset` restores the default position and locks it.

The arc is a screen overlay. Markers require usable map coordinates in the character's current world space. Blizzard sometimes provides one shared map location for several objective lines, or gives no location. Shared locations appear once per quest.
