#include "Player.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "Config.h"
#include "GmCommands.h"
#include "Tokenize.h"

GMCommands* GMCommands::instance()
{
    static GMCommands instance;
    return &instance;
}

void GMCommands::LoadAccountIds()
{
    std::string accountIds = sConfigMgr->GetOption<std::string>("GmCommandsModule.AccountIds", "");
    for (auto& itr : Acore::Tokenize(accountIds, ',', false))
    {
        uint32 accountId = Acore::StringTo<uint32>(itr).value();
        accountIDs.push_back(accountId);
    }
}

void GMCommands::LoadAllowedCommands()
{
    std::string allowedCommandsList = sConfigMgr->GetOption<std::string>("GmCommandsModule.AllowedCommands", "");
    for (auto& itr : Acore::Tokenize(allowedCommandsList, ',', false))
    {
        std::string command(itr);
        allowedCommands.push_back(command);
    }
}

bool GMCommands::IsAccountAllowed(uint32 accountId) const
{
    for (auto& itr : accountIDs)
    {
        LOG_ERROR("sql.sql", "AccountId {}", itr);
    }
    return std::find(accountIDs.begin(), accountIDs.end(), accountId) != accountIDs.end();
}

bool GMCommands::IsCommandAllowed(std::string command) const
{
    return std::find(allowedCommands.begin(), allowedCommands.end(), command) != allowedCommands.end();
}

class GmCommands : public AllCommandScript
{
public:
    GmCommands() : AllCommandScript("GmCommands") {}

    bool OnBeforeIsInvokerVisible(std::string name, Acore::Impl::ChatCommands::CommandPermissions permissions, ChatHandler const& who) override
    {
        if (who.IsConsole())
            return true;

        Player* player = who.GetPlayer();

        if (!player)
            return true;

        uint32 accountID = player->GetSession()->GetAccountId();

        if (!sGMCommands->IsAccountAllowed(accountID))
            return true;

        if (!sGMCommands->IsCommandAllowed(name))
            return true;

        return false;
    }
};

class mod_gm_commands_worldscript : public WorldScript
{
public:
    mod_gm_commands_worldscript() : WorldScript("mod_gm_commands_worldscript") {}

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        sGMCommands->LoadAccountIds();
        sGMCommands->LoadAllowedCommands();
    }
};

void AddGmCommandScripts()
{
    new GmCommands();
    new mod_gm_commands_worldscript();
}
