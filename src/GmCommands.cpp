#include "Player.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "Config.h"
class GmCommands : public PlayerScript
{
public:
    GmCommands() : PlayerScript("GmCommands") {}

    void OnLogin(Player* player) override
    {
        if (player->IsGameMaster())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Welcome, Game Master!");
        }
    }
};

void AddGmCommandScripts()
{
    new GmCommands();
}
