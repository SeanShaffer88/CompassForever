# SecretCompass

SecretCompass is a navigation HUD for World of Warcraft: Forever (Interface 16001).

## Follow a Secret

- **Standalone:** Run `/secretcompass secrets` or open **Secrets** in the settings window, then choose **Track Cozy Sleeping Bag**. The first stops follow your character's faction.
- **With SecretChecklist:** Open its **Guides** tab, select a guide, and click **Track Secret** beside its Guide button. SecretCompass reads the selected guide's steps and locations into a local route. The companion button uses the Guides layout in SecretChecklist 2.2.0 for WoW: Forever.
- Use **Previous**, **Next**, or **Finish** as you complete each instruction. **Next Location** cycles alternate locations for a step. Steps without coordinates still show their instructions.
- The compass gives the current step's bearing and distance when the game supplies usable positions in the same world space. For other zones and unavailable positions, use the zone and coordinates in the Secrets panel.
- Progress is saved per character. **Stop** returns to your normal compass. Your existing World Map pin is preserved throughout.

Cozy Sleeping Bag references: [Method walkthrough](https://www.method.gg/wow-forever/how-to-unlock-the-cozy-sleeping-bag-in-wow-forever) and [Wowhead route](https://www.wowhead.com/forever/guide/cozy-sleeping-bag-locations-rewards). SecretChecklist compatibility is based on its [Forever Guides source](https://github.com/rousseauxy/SecretChecklist/blob/55dfb9eeff47f51a3429dd5047bd73e3c539ef7f/tabs/TabGuides.lua).

## Install and Upgrade

1. Extract the `SecretCompass` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Start WoW Forever or reload the UI, then enable **SecretCompass** in the AddOns list.

When upgrading from CompassForever or ForeverCompass, exit WoW first and move the old addon folder out of AddOns. To keep its settings, back up the old account SavedVariables file and copy `WTF\Account\<account>\SavedVariables\CompassForever.lua (or ForeverCompass.lua)` to `SecretCompass.lua` in the same directory. If `SecretCompass.lua` already exists, keep a backup before making any changes.

## HUD Controls

Left-click the minimap button to toggle the HUD. Right-click it or run `/secretcompass settings` to open the draggable settings window. Choose from 12 HUD styles with live preview. **HUD Transparency** runs from 0% to 100%, and **HUD Size** runs from 60% to 150%.

Click **Move HUD**, drag the compass, then click **Lock SecretCompass** to save the position. `/secretcompass reset` restores the default position and locks it. `/secretcompass test 128` starts a 128-objective stress test.

Outside an active secret route, the HUD can show watched quest objectives and your World Map pin. Quest distances wrap into a compact block when labels are crowded. Gold ! marks an objective location, ~ marks a route waypoint supplied by the game, and a purple diamond marks your own pin. Each visible distance is straight-line yards.
