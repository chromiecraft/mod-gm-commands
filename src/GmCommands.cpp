#include "Chat.h"
#include "ChatCommand.h"
#include "Config.h"
#include "GmCommands.h"
#include "Log.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "Tokenize.h"
#include "WorldSession.h"
#include <algorithm>
#include <array>
#include <cctype>
#include <limits>
#include <fstream>
#include <sstream>
#include <unordered_map>

namespace
{
    constexpr char const* ACCOUNT_IDS_KEY = "GmCommandsModule.AccountIds";
    constexpr char const* DEFAULT_COMMANDS_KEY = "GmCommandsModule.DefaultCommands";
    constexpr char const* DEFAULT_LEVEL_KEY = "GmCommandsModule.DefaultLevel";
    constexpr char const* MODULE_CONFIG_FILE = "mod_gm_commands.conf";
    constexpr char const* MODULE_CONFIG_DIST_FILE = "mod_gm_commands.conf.dist";

    struct FileAccountOverrides
    {
        std::optional<uint32> Level;
        std::optional<std::string> Commands;
    };

    template <typename T>
    T GetOptionWithoutLog(std::string const& name, T const& def)
    {
        return sConfigMgr->GetOption<T>(name, def, false);
    }

    std::unordered_map<uint32, FileAccountOverrides> ReadAccountOverridesFromConfigFiles()
    {
        std::unordered_map<uint32, FileAccountOverrides> overrides;

        std::string const basePath = Acore::StringFormat("{}modules/", sConfigMgr->GetConfigPath());
        std::array<std::string, 2> const filenames =
        {
            basePath + MODULE_CONFIG_DIST_FILE,
            basePath + MODULE_CONFIG_FILE
        };

        std::string const prefix = "GmCommandsModule.Account.";

        for (std::string const& file : filenames)
        {
            std::ifstream stream(file);
            if (!stream.is_open())
                continue;

            std::string line;
            while (std::getline(stream, line))
            {
                line = Acore::String::Trim(line);
                if (line.empty() || line.front() == '#' || line.front() == '[')
                    continue;

                std::size_t const equalPos = line.find('=');
                if (equalPos == std::string::npos)
                    continue;

                std::string key = Acore::String::Trim(line.substr(0, equalPos));
                if (key.rfind(prefix, 0) != 0)
                    continue;

                std::string value = Acore::String::Trim(line.substr(equalPos + 1));
                value.erase(std::remove(value.begin(), value.end(), '"'), value.end());

                std::string_view const suffix = std::string_view(key).substr(prefix.size());
                std::size_t const dotPos = suffix.find('.');
                if (dotPos == std::string::npos)
                    continue;

                std::string accountString(suffix.substr(0, dotPos));
                std::string_view const field = suffix.substr(dotPos + 1);

                std::optional<uint32> accountIdOpt = Acore::StringTo<uint32>(accountString);
                if (!accountIdOpt)
                    continue;

                FileAccountOverrides& entry = overrides[*accountIdOpt];

                if (field == "Level")
                {
                    if (std::optional<uint32> levelOpt = Acore::StringTo<uint32>(value))
                        entry.Level = *levelOpt;
                }
                else if (field == "Commands")
                {
                    if (!value.empty())
                        entry.Commands = value;
                }
            }
        }

        return overrides;
    }
}

GMCommands* GMCommands::instance()
{
    static GMCommands instance;
    return &instance;
}

void GMCommands::Reload()
{
    _accounts.clear();
    _accountConfigurations.clear();
    _defaultCommands.clear();
    _commandPermissions.clear();
    _lastCommandByHandler.clear();

    uint32 defaultLevelRaw = sConfigMgr->GetOption<uint32>(DEFAULT_LEVEL_KEY, SEC_PLAYER);
    _defaultLevel = NormalizeLevel(defaultLevelRaw, DEFAULT_LEVEL_KEY);

    std::string defaultCommandsConfig = sConfigMgr->GetOption<std::string>(DEFAULT_COMMANDS_KEY, "");

    auto const buildCommandListString = [](CommandSet const& commands)
    {
        if (commands.empty())
            return std::string{};

        std::ostringstream stream;
        bool first = true;
        for (std::string const& cmd : commands)
        {
            if (!first)
                stream << ",";

            stream << cmd;
            first = false;
        }

        return stream.str();
    };

    for (std::string_view token : Acore::Tokenize(defaultCommandsConfig, ',', false))
    {
        std::string normalized = NormalizeCommand(token);
        if (!normalized.empty())
            _defaultCommands.insert(std::move(normalized));
    }

    LOG_INFO("modules.gmcommands", "GmCommands: default level {} with commands [{}]", _defaultLevel, buildCommandListString(_defaultCommands));

    std::unordered_map<uint32, FileAccountOverrides> const fileOverrides = ReadAccountOverridesFromConfigFiles();

    std::string accountIds = sConfigMgr->GetOption<std::string>(ACCOUNT_IDS_KEY, "");
    for (std::string_view token : Acore::Tokenize(accountIds, ',', false))
    {
        std::string trimmed = NormalizeCommand(token);
        if (trimmed.empty())
            continue;

        std::optional<uint32> accountIdOpt = Acore::StringTo<uint32>(trimmed);
        if (!accountIdOpt)
        {
            LogInvalidAccountId(token);
            continue;
        }

        uint32 accountId = *accountIdOpt;

        if (!_accounts.insert(accountId).second)
            continue;

        AccountConfiguration config;

        std::string levelKey = Acore::StringFormat("GmCommandsModule.Account.{}.Level", accountId);
        uint32 levelSentinel = std::numeric_limits<uint32>::max();
        uint32 levelValue = GetOptionWithoutLog(levelKey, levelSentinel);
        if (levelValue != levelSentinel)
            config.Level = NormalizeLevel(levelValue, levelKey);
        else if (auto const fileOverrideIt = fileOverrides.find(accountId); fileOverrideIt != fileOverrides.end() && fileOverrideIt->second.Level)
            config.Level = NormalizeLevel(*fileOverrideIt->second.Level, levelKey);

        std::string commandsKey = Acore::StringFormat("GmCommandsModule.Account.{}.Commands", accountId);
        std::string commandList = GetOptionWithoutLog(commandsKey, std::string{});
        if (commandList.empty())
        {
            if (auto const fileOverrideIt = fileOverrides.find(accountId); fileOverrideIt != fileOverrides.end() && fileOverrideIt->second.Commands)
                commandList = *fileOverrideIt->second.Commands;
        }

        if (!commandList.empty())
        {
            CommandSet customCommands;
            for (std::string_view cmd : Acore::Tokenize(commandList, ',', false))
            {
                std::string normalized = NormalizeCommand(cmd);
                if (!normalized.empty())
                    customCommands.insert(std::move(normalized));
            }

            if (!customCommands.empty())
                config.Commands = std::move(customCommands);
        }

        if (config.Level || config.Commands)
        {
            auto [it, inserted] = _accountConfigurations.emplace(accountId, std::move(config));
            if (inserted)
            {
                std::string const levelStr = it->second.Level ? std::to_string(*it->second.Level) : "<inherit>";
                std::string const commandStr = it->second.Commands ? buildCommandListString(*it->second.Commands) : "<inherit>";
                LOG_INFO("modules.gmcommands", "GmCommands: configured account {} level {} commands [{}]", accountId, levelStr, commandStr);
            }
        }
        else
        {
            LOG_INFO("modules.gmcommands", "GmCommands: managing account {} with inherited settings", accountId);
        }
    }

    LOG_INFO("modules.gmcommands", "GmCommands: managing {} accounts", _accounts.size());
}

bool GMCommands::IsAccountAllowed(uint32 accountId) const
{
    return _accounts.find(accountId) != _accounts.end();
}

AccountTypes GMCommands::GetAccountLevel(uint32 accountId) const
{
    if (!IsAccountAllowed(accountId))
        return SEC_PLAYER;

    auto const configIt = _accountConfigurations.find(accountId);
    if (configIt != _accountConfigurations.end() && configIt->second.Level)
        return *configIt->second.Level;

    return _defaultLevel;
}

bool GMCommands::IsCommandAllowed(uint32 accountId, std::string_view command) const
{
    if (!IsAccountAllowed(accountId))
        return false;

    std::string normalized = NormalizeCommand(command);
    if (normalized.empty())
        return false;

    // Commands that require SEC_PLAYER (0) are always allowed
    auto const permissionIt = _commandPermissions.find(normalized);
    if (permissionIt != _commandPermissions.end() && permissionIt->second <= SEC_PLAYER)
        return true;

    CommandSet const& commands = GetCommandSetForAccount(accountId);
    return commands.find(normalized) != commands.end();
}

void GMCommands::RememberCommandMetadata(std::string_view command, uint32 requiredLevel)
{
    std::string normalized = NormalizeCommand(command);
    if (normalized.empty())
        return;

    _commandPermissions[normalized] = requiredLevel;
}

void GMCommands::RememberHandlerCommand(ChatHandler const* handler, std::string_view command)
{
    if (!handler)
        return;

    std::string normalized = NormalizeCommand(command);
    if (normalized.empty())
        return;

    _lastCommandByHandler[handler] = std::move(normalized);
}

std::optional<std::string> GMCommands::GetHandlerCommand(ChatHandler const* handler) const
{
    if (!handler)
        return std::nullopt;

    auto const it = _lastCommandByHandler.find(handler);
    if (it == _lastCommandByHandler.end())
        return std::nullopt;

    return it->second;
}

std::optional<uint32> GMCommands::GetCommandRequiredLevel(std::string_view command) const
{
    std::string normalized = NormalizeCommand(command);
    if (normalized.empty())
        return std::nullopt;

    auto const it = _commandPermissions.find(normalized);
    if (it == _commandPermissions.end())
        return std::nullopt;

    return it->second;
}

GMCommands::CommandSet const& GMCommands::GetCommandSetForAccount(uint32 accountId) const
{
    auto const it = _accountConfigurations.find(accountId);
    if (it != _accountConfigurations.end() && it->second.Commands)
        return *it->second.Commands;

    return _defaultCommands;
}

std::string GMCommands::NormalizeCommand(std::string_view command)
{
    std::string value(command);
    if (value.empty())
        return value;

    value = Acore::String::Trim(value);

    std::string normalized;
    normalized.reserve(value.size());

    bool lastWasSpace = false;
    for (char ch : value)
    {
        unsigned char uch = static_cast<unsigned char>(ch);
        if (std::isspace(uch))
        {
            if (!lastWasSpace)
            {
                normalized.push_back(' ');
                lastWasSpace = true;
            }
        }
        else
        {
            normalized.push_back(static_cast<char>(std::tolower(uch)));
            lastWasSpace = false;
        }
    }

    if (!normalized.empty() && normalized.back() == ' ')
        normalized.pop_back();

    return normalized;
}

AccountTypes GMCommands::NormalizeLevel(uint32 level, std::string_view context)
{
    if (level > SEC_ADMINISTRATOR)
    {
        LOG_WARN("modules.gmcommands", "GmCommands: clamping configured level '{}' for '{}' to SEC_ADMINISTRATOR ({}).", level, context, SEC_ADMINISTRATOR);
        level = SEC_ADMINISTRATOR;
    }

    return static_cast<AccountTypes>(level);
}

void GMCommands::LogInvalidAccountId(std::string_view token)
{
    LOG_WARN("modules.gmcommands", "GmCommands: ignoring invalid account id token '{}'", token);
}

class GmCommands : public AllCommandScript
{
public:
    GmCommands() : AllCommandScript("GmCommands") {}

    bool OnBeforeIsInvokerVisible(std::string name, Acore::Impl::ChatCommands::CommandPermissions permissions, ChatHandler const& who) override
    {
        sGMCommands->RememberCommandMetadata(name, permissions.RequiredLevel);
        sGMCommands->RememberHandlerCommand(&who, name);

        if (who.IsConsole())
            return true;

        Player* player = who.GetPlayer();
        if (!player)
            return true;

        WorldSession* session = player->GetSession();
        if (!session)
            return true;

        uint32 accountId = session->GetAccountId();
        if (!sGMCommands->IsAccountAllowed(accountId))
            return true;

        if (permissions.RequiredLevel <= SEC_PLAYER)
            return true;

        if (!sGMCommands->IsCommandAllowed(accountId, name))
            return true;            // lascia il controllo standard (li nascondi / blocchi)

        return false;               // comando whitelist: salta who.IsAvailable()
    }

    bool OnTryExecuteCommand(ChatHandler& handler, std::string_view /*cmdStr*/) override
    {
        if (handler.IsConsole())
            return true;

        WorldSession* session = handler.GetSession();
        if (!session)
            return true;

        uint32 accountId = session->GetAccountId();
        if (!sGMCommands->IsAccountAllowed(accountId))
            return true;

        std::optional<std::string> commandName = sGMCommands->GetHandlerCommand(&handler);
        if (!commandName)
            return true;

        std::optional<uint32> requiredLevel = sGMCommands->GetCommandRequiredLevel(*commandName);
        if (requiredLevel && *requiredLevel <= SEC_PLAYER)
            return true;

        if (sGMCommands->IsCommandAllowed(accountId, *commandName))
            return true;

        handler.SendSysMessage("You are not allowed to use this command.");
        handler.SetSentErrorMessage(true);
        return false;
    }
};

class mod_gm_commands_worldscript : public WorldScript
{
public:
    mod_gm_commands_worldscript() : WorldScript("mod_gm_commands_worldscript") {}

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sGMCommands->Reload();
    }
};

class mod_gm_commands_playerscript : public PlayerScript
{
public:
    mod_gm_commands_playerscript() : PlayerScript("mod_gm_commands_playerscript") {}

    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;

        WorldSession* session = player->GetSession();
        if (!session)
            return;

        uint32 accountId = session->GetAccountId();
        if (!sGMCommands->IsAccountAllowed(accountId))
            return;

        AccountTypes configured = sGMCommands->GetAccountLevel(accountId);
        if (session->GetSecurity() == configured)
            return;

        session->SetSecurity(configured);
    }

    void OnPlayerSetServerSideVisibility(Player* player, ServerSideVisibilityType& type, AccountTypes& sec) override
    {
        if (type != SERVERSIDE_VISIBILITY_GM)
            return;

        if (!player || player->isGMVisible())
            return;

        WorldSession* session = player->GetSession();
        if (!session)
            return;

        uint32 accountId = session->GetAccountId();
        if (!sGMCommands->IsAccountAllowed(accountId))
            return;

        AccountTypes configuredLevel = sGMCommands->GetAccountLevel(accountId);
        if (configuredLevel <= SEC_PLAYER)
            return;

        if (sec == configuredLevel)
            return;

        sec = configuredLevel;
    }
};

void AddGmCommandScripts()
{
    new GmCommands();
    new mod_gm_commands_worldscript();
    new mod_gm_commands_playerscript();
}
