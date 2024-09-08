#include "ScriptMgr.h"
#include "Player.h"

class GmCommands : public PlayerScript
{
public:
    GmCommands() : PlayerScript("GmCommands") {}

    void OnLogin(Player* player) override
    {
        if (player->IsGameMaster())
        {
            player->GetSession()->SendNotification("Welcome, Game Master!");
        }
    }
};

void AddGmCommandScripts()
{
    new GmCommands();
}
