# AFK Tracker

**AFKTracker** is a lightweight World of Warcraft Classic Era addon designed to help identify and track potential AFK (Away From Keyboard) players in Alterac Valley (AV) battlegrounds. It monitors player performance at the end of each AV match, recording those who appear to be leeching honor without contributing (e.g., 0 honorable kills, minimal deaths, no objectives completed, but still earning honor). The addon provides tools to list suspects, announce histories, and manage a local database of records. It's particularly useful for raid leaders or groups frustrated with AFK farmers in AV.

This addon is inspired by community efforts to promote fair play in battlegrounds. All data is stored locally per character and expires after a configurable time (default: 48 hours).

## Features

- **Automatic Tracking**: At the end of each AV match, scans the scoreboard for players meeting AFK criteria (0 HKs, low deaths, sufficient honor gained, no objectives).
- **Redemption System**: If a tracked player achieves a configurable number of honorable kills (default: 1) in a future match, they are automatically removed from the tracking list.
- **Aggregated Statistics**: View averages for HKs, deaths, and total honor across recorded matches.
- **Graphical UI**: User-friendly settings window accessible via `/afkt ui` for easy configuration.
- **Battle UI**: Compact, moveable interface that auto-shows in AV with quick access buttons for listing AFKers and announcing targets.
- **Slash Commands**: Easy-to-use commands for listing suspects, announcing histories, clearing data, and configuring thresholds.
- **Configurable Thresholds**: Customize criteria like death limits, honor minimums, expiration time, and more via the UI or in-game commands.
- **Chat Integration**: Announce AFK evidence to instance/raid chat or list suspects in BG chat.
- **Local Storage**: Uses SavedVariables for persistence; no server-side data or external dependencies.
- **Debug Logging**: Configurable debug mode for troubleshooting (disabled by default, can be enabled via config).

## How It Works

1. **Entering AV**: The addon detects when you enter Alterac Valley and starts monitoring.
2. **End of Match Detection**: When the battlefield winner is determined (via `UPDATE_BATTLEFIELD_SCORE` event), it requests scoreboard data and delays briefly to ensure scores are updated.
3. **Player Evaluation**:
   - Players are checked against configurable thresholds:
     - Honorable Kills (HKs) == 0
     - Deaths < `deathThreshold` (default: 2)
     - Honor Gained >= `honorThreshold` (default: 1386)
     - Objectives Completed == 0 (towers, graves, mines, leaders, etc.)
   - If criteria are met, the player is recorded with their name, timestamp, HKs, deaths, and honor gained.
4. **Redemption Check**: During the same scan, if any player (tracked or not) achieves >= `redeemThreshold` HKs (default: 1), all their prior records are removed from the database.
5. **Data Expiration**: Records older than `historyExpireHours` (default: 48) are automatically purged on login or when querying.
6. **Queries and Announcements**:
   - Use `/afkt list` to view aggregated stats for tracked players (filtered by `seenThreshold` for relevance).
   - Target a player and use `/afkt history` to announce their AFK evidence to chat.
   - `/afkt announce` to report a targeted player as AFK (with group info if in raid).
7. **Configuration**: Adjust thresholds anytime with `/afkt config set <key> <value>` (e.g., `/afkt config set redeemThreshold 15`).

The addon only tracks data from matches you're in, ensuring it's based on your direct observations. It doesn't detect AFK in real-time during the match—only at the end based on final stats. In a BG it will report players level **60** and above for potential AFKs (lower levels often doing quests or grinding mobs).

## Installation

1. Download the addon from CurseForge or your preferred source.
2. Extract the folder to your WoW `Interface/AddOns` directory (e.g., `World of Warcraft/_classic_era_/Interface/AddOns/AFKTracker`).
3. Restart WoW or reload UI (`/reload`).
4. Enter AV to start tracking—use `/afkt` for commands.

No additional libraries or addons required. Compatible with WoW Classic Era (tested on current patches as of August 2025).

## Commands

- `/afkt ui` or `/afkt settings`: Opens the graphical settings window for easy configuration.
- `/afkt battleui [show|hide|reset]`: Manually show, hide, or reset the position of the battle UI (auto-shows in AV if enabled).
- `/afkt announce`: Announces the targeted player as AFK to raid/instance chat. Requires you to be in a raid and have a target.
- `/afkt list [limit] [bg]`: Lists potential AFKers from the last X hours (includes class when in BG), sorted by times seen and total honor. Optional `limit` for top N results; `bg` to print to instance chat (if in AV).
- `/afkt history`: Announces the targeted player's AFK history/evidence to instance/raid chat. Requires target.
- `/afkt clear`: Clears all recorded data.
- `/afkt config`: Shows current configuration values and descriptions.
- `/afkt config get <key>`: Gets the value and description of a specific config key (e.g., `deathThreshold`).
- `/afkt config set <key> <value>`: Sets a config key to a new value (e.g., `/afkt config set honorThreshold 1500`).

Available config keys (can be configured via UI or commands):
- `deathThreshold`: Number of deaths below which a player is considered AFK (default: 2).
- `honorThreshold`: Minimum honor gained to consider a player for AFK tracking (default: 1386).
- `seenThreshold`: Minimum number of times seen AFK to include in lists or announcements (default: 2).
- `redeemThreshold`: Number of honorable kills in a single match to remove from tracking (default: 1).
- `historyExpireHours`: Hours after which AFK records expire (default: 48).
- `debug`: Enable or disable debug messages (default: false). Can only be set via command line.

## Configuration Examples

Configuration can be done via the graphical UI (`/afkt ui`) or through commands:

- Open settings window: `/afkt ui` or `/afkt settings`
- To make tracking stricter (require more honor): `/afkt config set honorThreshold 2000`
- To forgive players faster: `/afkt config set redeemThreshold 5`
- View all settings: `/afkt config`

The UI provides:
- Input fields for all numeric thresholds
- Customizable announce message template with variables:
  - `{name}` - Player's name
  - `{class}` - Player's class
  - `{group}` - Raid group number (blank if not in raid)
  - Default: `REPORT: {name} the {class} is AFK! (Group {group})`
- Checkbox to enable/disable Battle UI auto-show in AV
- Reset button (next to Battle UI checkbox) to restore default battle UI position
- Reset Defaults button to restore original settings (including announce message)
- Clear History button to remove all tracking records
- Draggable window that remembers its position

## Battle UI

The Battle UI is a compact interface designed for use during Alterac Valley battles:

### Features
- **Auto-shows in AV**: Automatically appears when entering Alterac Valley (can be disabled)
- **Compact Design**: Small 140x70 pixel frame that won't interfere with combat
- **Quick Actions**:
  - "List AFK" button - Lists AFKers in battleground chat
  - "Announce" button - Announces targeted player as AFK (requires being in a raid)
- **Settings Access**: Gear icon to open main settings panel
- **Moveable**: Click and drag to position anywhere on screen
- **Position Memory**: Remembers where you placed it between sessions

### Usage
- The Battle UI will automatically appear when you enter AV (if enabled in settings)
- Click and drag the frame to reposition it
- Use `/afkt battleui show` to manually show it
- Use `/afkt battleui hide` to manually hide it
- Use `/afkt battleui reset` to reset its position to default (right side of screen)
- Click the "Reset" button next to "Show Battle UI in AV" checkbox to reset position from the UI
- Disable auto-show by unchecking "Show Battle UI in AV" in the settings panel
- Position is also reset when using the "Reset Defaults" button

Changes persist across sessions and are per-character.

## Limitations and Notes

- **WoW API Limits**: Relies on battlefield score data, which may not always be 100% accurate or complete.
- **False Positives**: Players who die early or play defensively might trigger tracking—use redemption to clear good players.
- **Privacy**: All data is local; nothing is shared or uploaded.
- **Compatibility**: Works in Classic Era; not tested in retail WoW.
- **Debug Mode**: Debug messages are disabled by default. Enable with `/afkt config set debug 1` for troubleshooting.
- **Customization**: Feel free to edit the Lua file for advanced tweaks (e.g., change bgZone to monitor other BGs).

If you encounter issues, check your WoW logs or report on CurseForge/GitHub.

## Credits

Developed with community feedback in mind. Thanks to the WoW addon community for inspiration from similar tools.

For support or suggestions, visit the addon's page on CurseForge.
