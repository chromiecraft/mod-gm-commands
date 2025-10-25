# GM Commands Module

This module lets you curate the set of chat commands that selected accounts can use without granting them the full GM security level. It hooks into the AzerothCore command system to hide or block commands that are not explicitly whitelisted, while still enforcing the regular command security for every other player.

## Capabilities
- Manage a list of account IDs controlled by the module.
- Define reusable presets with specific GM levels and command lists.
- Assign presets to accounts for consistent configuration management.
- Assign a shared default GM level and default command list for accounts without presets.
- Override the GM level or allowed commands per account.
- Allow commands that normally require a higher security level when they are explicitly whitelisted.
- Always allow commands that require security level `SEC_PLAYER` (0).

## Configuration Precedence
The module follows a clear precedence hierarchy when resolving the effective configuration for each account:

1. **Default settings** (lowest priority): `GmCommandsModule.DefaultLevel` and `GmCommandsModule.DefaultCommands`
2. **Preset settings**: If a preset is assigned to an account via `GmCommandsModule.Account.<AccountId>.Preset`, its level and commands override the defaults
3. **Per-account overrides** (highest priority): `GmCommandsModule.Account.<AccountId>.Level` and `GmCommandsModule.Account.<AccountId>.Commands` override everything else

## Configuration Files
The module looks for its configuration in both `modules/mod_gm_commands.conf.dist` and `modules/mod_gm_commands.conf` inside your server configuration directory (for example `env/dist/etc/modules/`).

When the server starts (or the config is reloaded), the module reads `.conf.dist` first and then `.conf`. Keys present in the non-`.dist` file override the defaults. This allows you to keep personal changes out of version control while still benefiting from distribution updates.

### Required Keys
- `GmCommandsModule.Enable`: Set to `1` to activate the module.
- `GmCommandsModule.AccountIds`: Comma-separated list of account IDs that the module manages. Only accounts in this list are affected.

### Optional Defaults
- `GmCommandsModule.DefaultLevel`: GM level applied to managed accounts that do not define their own level. Clamped between `SEC_PLAYER (0)` and `SEC_ADMINISTRATOR (3)`.
- `GmCommandsModule.DefaultCommands`: Comma-separated list of commands granted to managed accounts that do not define their own command list. Commands that require level 0 are still automatically available even if they are not listed.

### Presets
Presets allow you to define reusable configurations that can be assigned to multiple accounts:
- `GmCommandsModule.Presets`: Comma-separated list of preset names.
- `GmCommandsModule.Preset.<PresetName>.Level`: GM level for this preset.
- `GmCommandsModule.Preset.<PresetName>.Commands`: Comma-separated list of commands for this preset.

### Account Configuration
Use the following keys to configure specific accounts, replacing `<AccountId>` with the numeric ID:
- `GmCommandsModule.Account.<AccountId>.Preset`: Assign a preset to this account. Only one preset per account is allowed.
- `GmCommandsModule.Account.<AccountId>.Level`: Override the preset or default level for this account (highest priority).
- `GmCommandsModule.Account.<AccountId>.Commands`: Override the preset or default commands for this account (highest priority).

Both files (`mod_gm_commands.conf.dist` and `mod_gm_commands.conf`) are scanned, so you may define configuration in either place. Values found in the non-`.dist` file take precedence.

#### Command List Formatting
Commands are stored in a normalized, lowercase form:
- Trim spaces around each entry.
- Collapse multiple inner spaces to a single space.
- Use the full chat command path. For example, the command shown in chat as `.character level` must be written as `character level`; `levelup` can be listed as-is because it is a top-level command.

You can list multi-word commands exactly as they appear after the leading dot, separated by commas:
```
GmCommandsModule.Account.3.Commands = "character level, character rename, levelup, gm visible"
```

## Runtime Behaviour
- When a GM account uses a command, the module records the command name and its required security level.
- If an account is in the managed list and the command requires more than `SEC_PLAYER`, the module checks the whitelist before the core performs its visibility/security check.
- Whitelisted commands return early from the visibility hook, effectively bypassing the security-level requirement for that account. Non-whitelisted commands continue through the normal core checks and are blocked with "You are not allowed to use this command."
- The module logs the resolved configuration (defaults → preset → overrides) for each account at startup (log channel `modules.gmcommands`) to aid troubleshooting.

## Reloading Configuration
After editing the configuration, either restart the worldserver or run `.reload config` from a GM account with adequate privileges. The module will re-read both configuration files and log the updated account summaries.

## Troubleshooting
- Ensure the account ID is listed in `GmCommandsModule.AccountIds`; otherwise the account is ignored.
- Use the full command name (including subcommand structure) in the whitelist. If a command still reports "does not exist," verify the spelling and normalization.
- Check the worldserver log for `modules.gmcommands` entries to confirm that the module picked up your presets, assignments, and overrides.
- If a preset is assigned but the account is not configured as expected, verify that the preset name is listed in `GmCommandsModule.Presets` and that the preset definition exists.
- Commands that require only `SEC_PLAYER` never need to be listed; if users cannot run them, the issue lies elsewhere (permissions, syntax, etc.).

## Example
```
GmCommandsModule.Enable = 1
GmCommandsModule.AccountIds = "3,4,5"
GmCommandsModule.DefaultLevel = 0
GmCommandsModule.DefaultCommands = ""

# Define presets
GmCommandsModule.Presets = "tv_account, gm_helper"

GmCommandsModule.Preset.tv_account.Level = 1
GmCommandsModule.Preset.tv_account.Commands = "gm, gm visible, appear, go, teleport, gm fly"

GmCommandsModule.Preset.gm_helper.Level = 2
GmCommandsModule.Preset.gm_helper.Commands = "ticket, summon, learn, gm on, gm off"

# Assign presets to accounts
GmCommandsModule.Account.3.Preset = "tv_account"
GmCommandsModule.Account.4.Preset = "gm_helper"
GmCommandsModule.Account.5.Preset = "tv_account"

# Override commands for account 5 while keeping the preset level
GmCommandsModule.Account.5.Commands = "gm, gm visible, appear, go, teleport, gm fly, gmannounce"
```

In this example:
- Account 3 receives the `tv_account` preset (level 1 with limited commands)
- Account 4 receives the `gm_helper` preset (level 2 with ticket/support commands)
- Account 5 receives the `tv_account` preset level (1) but has an additional command (`gmannounce`) added to its command list

## Development Notes
The implementation lives in `src/GmCommands.cpp` and exposes a singleton (`sGMCommands`) responsible for:
- Loading presets and per-account configurations from `sConfigMgr` and the module config files.
- Building effective configurations by applying precedence rules (defaults → presets → overrides).
- Normalizing command names and caching per-command required security.
- Hooking `AllCommandScript` to hide or allow commands based on the configured whitelist.

Any changes to the command registry should keep the normalization logic in mind so that configuration values remain compatible.

## Development Notes
The implementation lives in `src/GmCommands.cpp` and exposes a singleton (`sGMCommands`) responsible for:
- Loading overrides from `sConfigMgr` and the module config files.
- Normalizing command names and caching per-command required security.
- Hooking `AllCommandScript` to hide or allow commands based on the configured whitelist.

Any changes to the command registry should keep the normalization logic in mind so that configuration values remain compatible.
