#ifndef DEF_GMCOMMANDS_H
#define DEF_GMCOMMANDS_H

#include "Common.h"
#include <optional>
#include <string_view>
#include <unordered_map>
#include <unordered_set>

class ChatHandler;

class GMCommands
{
public:
    static GMCommands* instance();

    void Reload();

    [[nodiscard]] bool IsAccountAllowed(uint32 accountId) const;
    [[nodiscard]] AccountTypes GetAccountLevel(uint32 accountId) const;
    [[nodiscard]] bool IsCommandAllowed(uint32 accountId, std::string_view command) const;

    void RememberCommandMetadata(std::string_view command, uint32 requiredLevel);
    void RememberHandlerCommand(ChatHandler const* handler, std::string_view command);
    [[nodiscard]] std::optional<std::string> GetHandlerCommand(ChatHandler const* handler) const;
    [[nodiscard]] std::optional<uint32> GetCommandRequiredLevel(std::string_view command) const;

private:
    using CommandSet = std::unordered_set<std::string>;

    struct Preset
    {
        AccountTypes Level = SEC_PLAYER;
        CommandSet Commands;
    };

    struct AccountConfiguration
    {
        std::optional<AccountTypes> Level;
        std::optional<CommandSet> Commands;
    };

    struct EffectiveAccountConfig
    {
        AccountTypes Level = SEC_PLAYER;
        CommandSet Commands;
    };

    [[nodiscard]] CommandSet const& GetCommandSetForAccount(uint32 accountId) const;
    static std::string NormalizeCommand(std::string_view command);
    static AccountTypes NormalizeLevel(uint32 level, std::string_view context);
    static void LogInvalidAccountId(std::string_view token);
    void BuildEffectiveConfigs();

    AccountTypes _defaultLevel = SEC_PLAYER;
    CommandSet _defaultCommands;
    std::unordered_set<uint32> _accounts;
    std::unordered_map<std::string, Preset> _presets;
    std::unordered_map<uint32, std::string> _accountToPreset;
    std::unordered_map<uint32, AccountConfiguration> _accountConfigurations;
    std::unordered_map<uint32, EffectiveAccountConfig> _effectiveConfigs;

    std::unordered_map<std::string, uint32> _commandPermissions;
    mutable std::unordered_map<ChatHandler const*, std::string> _lastCommandByHandler;
};

#define sGMCommands GMCommands::instance()

#endif
