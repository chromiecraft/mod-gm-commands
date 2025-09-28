# GM Commands Module

This module lets you curate the set of chat commands that selected accounts can use without granting them the full GM security level. It hooks into the AzerothCore command system to hide or block commands that are not explicitly whitelisted, while still enforcing the regular command security for every other player.

## Capabilities
- Manage a list of account IDs controlled by the module.
- Assign a shared default GM level and default command list for those accounts.
- Override the GM level or allowed commands per account.
- Allow commands that normally require a higher security level when they are explicitly whitelisted.
- Always allow commands that require security level `SEC_PLAYER` (0).

## Configuration Files
The module looks for its configuration in both `modules/mod_gm_commands.conf.dist` and `modules/mod_gm_commands.conf` inside your server configuration directory (for example `env/dist/etc/modules/`).

When the server starts (or the config is reloaded), the module reads `.conf.dist` first and then `.conf`. Keys present in the non-`.dist` file override the defaults. This allows you to keep personal changes out of version control while still benefiting from distribution updates.

### Required Keys
- `GmCommandsModule.Enable`: Set to `1` to activate the module.
- `GmCommandsModule.AccountIds`: Comma-separated list of account IDs that the module manages. Only accounts in this list are affected.

### Optional Defaults
- `GmCommandsModule.DefaultLevel`: GM level applied to managed accounts that do not define their own level. Clamped between `SEC_PLAYER (0)` and `SEC_ADMINISTRATOR (3)`.
- `GmCommandsModule.DefaultCommands`: Comma-separated list of commands granted to managed accounts that do not define their own command list. Commands that require level 0 are still automatically available even if they are not listed.

### Per-Account Overrides
Use the following keys to override defaults for a specific account, replacing `<AccountId>` with the numeric ID:
- `GmCommandsModule.Account.<AccountId>.Level`
- `GmCommandsModule.Account.<AccountId>.Commands`

Both files (`mod_gm_commands.conf.dist` and `mod_gm_commands.conf`) are scanned, so you may define an override in either place. Values found in the non-`.dist` file take precedence.

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
- Whitelisted commands return early from the visibility hook, effectively bypassing the security-level requirement for that account. Non-whitelisted commands continue through the normal core checks and are blocked with “You are not allowed to use this command.”
- The module logs the resolved default settings and per-account overrides at startup (log channel `modules.gmcommands`) to aid troubleshooting.

## Reloading Configuration
After editing the configuration, either restart the worldserver or run `.reload config` from a GM account with adequate privileges. The module will re-read both configuration files and log the updated account summaries.

## Troubleshooting
- Ensure the account ID is listed in `GmCommandsModule.AccountIds`; otherwise the account is ignored.
- Use the full command name (including subcommand structure) in the whitelist. If a command still reports “does not exist,” verify the spelling and normalization.
- Check the worldserver log for `modules.gmcommands` entries to confirm that the module picked up your overrides.
- Commands that require only `SEC_PLAYER` never need to be listed; if users cannot run them, the issue lies elsewhere (permissions, syntax, etc.).

## Example
```
GmCommandsModule.Enable = 1
GmCommandsModule.AccountIds = "3,4"
GmCommandsModule.DefaultLevel = 0
GmCommandsModule.DefaultCommands = "go"

GmCommandsModule.Account.3.Level = 1
GmCommandsModule.Account.3.Commands = "character level, levelup, gm, gm visible"

GmCommandsModule.Account.4.Commands = "appeal, go, ticket"
```

In this example account 3 keeps security level 1 but can run `character level` and `levelup`, while account 4 inherits the default security level (0) yet receives a custom command list.

## Development Notes
The implementation lives in `src/GmCommands.cpp` and exposes a singleton (`sGMCommands`) responsible for:
- Loading overrides from `sConfigMgr` and the module config files.
- Normalizing command names and caching per-command required security.
- Hooking `AllCommandScript` to hide or allow commands based on the configured whitelist.

Any changes to the command registry should keep the normalization logic in mind so that configuration values remain compatible.
