# CompassForever

CompassForever adds a curved compass to World of Warcraft: Forever (Interface 16001). The cardinal marks follow your character's facing.

- Watch a quest in the quest log to see every available objective location for that quest. Each gold marker shows its own bearing and straight-line distance in yards. When rows fill up, distances move into a compact block centered under the compass. The block shifts to stay visible if you drag the compass near a screen edge, and uses another visible area when there is no room below. Thin gold lines connect shifted labels to their bearings.
- A gold `!` marks a quest objective location. A gold `~` marks the next route waypoint when the game supplies one instead of a usable objective location.
- Ctrl+left-click a supported location on the World Map to place a pin. A purple diamond shows its own bearing and distance. For both marker types, an edge chevron points toward a bearing beyond the visible arc.

1. Extract the `CompassForever` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Start WoW Forever or run `/reload`. Enable **CompassForever** in the AddOns list.

If upgrading from a version installed in a folder named `ForeverCompass`, exit WoW and move that old addon folder out of `AddOns` before extracting the new one. To carry over your settings, back up the account's `WTF\Account\<account>\SavedVariables\ForeverCompass.lua` file and copy it to `CompassForever.lua` in the same directory if that file does not already exist.

Left-click the minimap button to show or hide the HUD. Right-click it or run `/fcompass settings` to open the settings window. Drag its title bar to move the window. Choose Classic, Frost, Ember, or High Contrast for color. Arc, Framed, Tactical, and Flight change the HUD shape. Both choices update the live preview and the HUD immediately. The panel also controls opacity, quest distances, the manual map pin, cardinal letters, and the minimap button. Use the slash command to reopen settings if you hide the button.

- `/fcompass` shows or hides the compass.
- `/fcompass move` unlocks the compass. Drag it into place and repeat the command to lock it.
- `/fcompass reset` restores the default position and locks it.
- `/fcompass test` toggles 64 sample distances stacked at the center bearing. Use `/fcompass test 128` to try a different count from 1 to 128, or `/fcompass test off` to exit. **Test Mode** replaces live quest labels for the session and keeps the manual pin visible. Turning it off or reloading restores your saved compass visibility.

The arc is a screen overlay. Markers require usable map coordinates in the character's current world space. Blizzard sometimes provides one shared map location for several objective lines, or gives no location. Shared locations appear once per quest.
