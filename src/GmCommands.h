#ifndef DEF_GMCOMMANDS_H
#define DEF_GMCOMMANDS_H

#include "Player.h"
#include "Config.h"

class GMCommands
{
public:
    static GMCommands* instance();

    void LoadAccountIds();
    void LoadAllowedCommands();

    [[nodiscard]] bool IsAccountAllowed(uint32 accountId) const;
    [[nodiscard]] bool IsCommandAllowed(std::string command) const;

private:
    std::vector<uint32> accountIDs;
    std::vector<std::string> allowedCommands;
};

#define sGMCommands GMCommands::instance()

#endif
