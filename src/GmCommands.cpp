#include "Player.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "Config.h"

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

        if (!std::count(eligibleAccounts.begin(), eligibleAccounts.end(), accountID))
            return true; // Account is not eligible

        if (std::count(eligibleCommands.begin(), eligibleCommands.end(), name))
            return false; // Command is eligible

        return true; // Command is not eligible
    }

private:
    std::vector<uint32> eligibleAccounts =
    {
        94143, // HEYITSGMCH
    };

    std::vector<std::string> eligibleCommands =
    {
        "gm fly",
    };
};
void AddGmCommandScripts()
{
    new GmCommands();
}
