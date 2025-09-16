#include "Player.h"
#include "PlayerScript.h"
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
    accountIDs.clear();

    std::string accountIds = sConfigMgr->GetOption<std::string>("GmCommandsModule.AccountIds", "");
    for (auto& itr : Acore::Tokenize(accountIds, ',', false))
    {
        uint32 accountId = Acore::StringTo<uint32>(itr).value();
        accountIDs.push_back(accountId);
    }
}

void GMCommands::LoadAllowedCommands()
{
    allowedCommands.clear();

    std::string allowedCommandsList = sConfigMgr->GetOption<std::string>("GmCommandsModule.AllowedCommands", "");
    for (auto& itr : Acore::Tokenize(allowedCommandsList, ',', false))
    {
        std::string command(itr);
        allowedCommands.push_back(command);
    }
}

bool GMCommands::IsAccountAllowed(uint32 accountId) const
{
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

class mod_gm_commands_playerscript : public PlayerScript
{
public:
    mod_gm_commands_playerscript() : PlayerScript("mod_gm_commands_playerscript") {}

    void OnPlayerSetServerSideVisibility(Player* player, ServerSideVisibilityType& type, AccountTypes& sec) override
    {
        if (type != SERVERSIDE_VISIBILITY_GM)
            return;

        if (!player || player->isGMVisible())
            return;

        WorldSession* session = player->GetSession();
        if (!session)
            return;

        if (!sGMCommands->IsAccountAllowed(session->GetAccountId()))
            return;

        if (sec != SEC_PLAYER)
            return;

        if (!sGMCommands->IsCommandAllowed("gm") && !sGMCommands->IsCommandAllowed("gm visible"))
            return;

        sec = SEC_GAMEMASTER;
    }
};

void AddGmCommandScripts()
{
    new GmCommands();
    new mod_gm_commands_worldscript();
    new mod_gm_commands_playerscript();
}
