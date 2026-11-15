# SecretsCompass

SecretsCompass is a navigation HUD for World of Warcraft: Forever (Interface 16001).

## Follow a Secret

- **Standalone:** Run `/secretscompass secrets` or open **Secrets** in the settings window, then choose **Cozy Sleeping Bag** or **Alcaz Operative Insignia**. Both routes account for your character's faction.
- **With SecretChecklist:** Open its **Guides** tab, select a guide, and click **Track Secret** beside its Guide button. SecretsCompass reads the selected guide's steps and locations into a local route. The companion button uses the Guides layout in SecretChecklist 2.2.0 for WoW: Forever.
- Choose **Clue**, **Distance**, **Coordinates**, or **Full** for each secret. **Clue** shows a hint and a rough bearing when available. **Distance** reveals yards, **Coordinates** adds the map location, and **Full** shows the step title and instructions. The choice is saved per secret.
- Use **Previous**, **Next**, or **Finish** when you complete an instruction. **Next Location** cycles alternatives. When the game can verify earlier quest steps, select the suggested step to jump ahead, or keep navigating manually.
- To revisit or skip to a known step, enter its number under **Go to Step** and choose **Go**, or run `/secretscompass step 3` for step 3. The selected step follows your current spoiler setting.
- In **Coordinates** or **Full**, click **Map Command** for a step with a location, then press **Ctrl+C** to copy the selected `/mappin` text. You can share it or run it in chat to set a World Map pin.
- If a bearing is unavailable, the destination zone and any available travel hint remain visible. Built-in routes have curated access hints. Alcaz marks the approximate prison entrance, Moonbrook Inn, and your faction contact. Assembly is a manual step. Imported guides use the zone when no travel hint is available.
- The compact hunt HUD follows your current step with the guide windows closed. Bind **Next Secret Step** under **Options → Keybindings → AddOns → SecretsCompass**, or run `/secretscompass next`. The action starts unbound.
- Progress is saved per character and per secret. **Pause** returns to your normal compass. Pick **Resume** on a built-in route or select the same guide in SecretChecklist to continue. Switching to another secret saves your previous checkpoint. **Finish** records completion for the current character and clears the checkpoint. The built-in journal shows how many routes you have finished and offers **Replay** from the first step. You can pause and resume a replay. Your World Map pin is preserved throughout.

Cozy Sleeping Bag references: [Method walkthrough](https://www.method.gg/wow-forever/how-to-unlock-the-cozy-sleeping-bag-in-wow-forever) and [Wowhead route](https://www.wowhead.com/forever/guide/cozy-sleeping-bag-locations-rewards). Alcaz route reference is the [WoW Secret Finding walkthrough on Wowhead](https://www.wowhead.com/forever/guide/alcaz-operative-disguise-toy-secret-walkthrough). Coordinates were checked against the [Alcaz entrance guide](https://mobalytics.gg/wow-forever/dungeons/alcaz-prison-complete-dungeon-guide-uncas), the [mapped portal](https://conquestcapped.com/guides/wow-forever/wow-forever-alcaz-prison-guide/), and Forever map pins for [Renzik](https://pd.zroot.it/forever/npcs/6946) and [Rix](https://pd.zroot.it/forever/npcs/214954). SecretChecklist compatibility is based on its [Forever Guides source](https://github.com/rousseauxy/SecretChecklist/blob/55dfb9eeff47f51a3429dd5047bd73e3c539ef7f/tabs/TabGuides.lua).

## Install and Upgrade

1. Extract the `SecretsCompass` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Start WoW Forever or reload the UI, then enable **SecretsCompass** in the AddOns list.

Exit WoW before upgrading and move the old addon folder out of AddOns. Back up your SavedVariables before making changes. Keep any `SecretsCompass.lua` files that already exist.

- **Account settings.** In `WTF\Account\<account>\SavedVariables`, copy `SecretCompass.lua` to `SecretsCompass.lua`. For an earlier installation, use its `CompassForever.lua` or `ForeverCompass.lua` file instead.
- **Character progress.** In `WTF\Account\<account>\<realm>\<character>\SavedVariables`, copy `SecretCompass.lua` to `SecretsCompass.lua` for each character you tracked secrets on.

The `/secretcompass` and `/fcompass` shortcuts still work.

## HUD Controls

Left-click the minimap button to toggle the HUD. Right-click it or run `/secretscompass settings` to open the draggable settings window. Choose from 12 HUD styles with live preview. **HUD Transparency** runs from 0% to 100%, and **HUD Size** runs from 60% to 150%.

Click **Move HUD**, drag the compass, then click **Lock SecretsCompass** to save the position. `/secretscompass reset` restores the default position and locks it. `/secretscompass test 128` starts a 128-objective stress test.

Outside an active secret route, the HUD can show watched quest objectives and your World Map pin. Quest distances wrap into a compact block when labels are crowded. Gold ! marks an objective location, ~ marks a route waypoint supplied by the game, and a purple diamond marks your own pin. Each visible distance is straight-line yards.
