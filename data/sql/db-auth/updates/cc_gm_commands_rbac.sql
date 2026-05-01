-- ChromieCraft RBAC roles (replaces world-DB commands.sql, depends on #24641).
-- Also absorbs the PTR Player role from mod-ptr-changes.
--
--   1000  PTR Player                (sec 0, realm 2 only)
--   1010  GM Curated Player         (sec 0, all realms)
--   1011  GM Triager (T0)           (sec 1)
--   1012  GM Entertainer (T1)       (sec 2)
--   1013  GM Protector (T2)         (no direct default; sec-3 admins
--                                    inherit it transitively via 1014)
--   1014  GM Administrator          (sec 3)
--
-- GM tier inheritance: 1014 -> 1013 -> 1012 -> 1011 -> 1010 -> 195.
-- PTR Player also links 1000 -> 195 to pick up base player perks.
--
-- This migration DELETES the stock #24641 default rows
--   (3,192,-1) (2,193,-1) (1,194,-1) (0,195,-1)
-- and replaces them with module-role defaults. Effects per sec level:
--   sec 0  KEEPS base player perks (Join BG/Arenas/Dungeon Finder,
--          two-side char creation, etc.) because 1010 and 1000 link
--          back to role 195.
--   sec 1+ LOSE the gameplay perks attached to roles 192-194 (Instant
--          logout, Skip Queue, Skip idle/spam/overspeed checks, Log
--          GM trades, the full GM/Admin "skip check" suite). This is
--          intentional -- only the curated command set is granted.
--          Re-add specific perks via rbac_account_permissions or by
--          restoring the relevant stock row.
--
-- The cpp gating engine in src/GmCommands.cpp is unchanged; under
-- RBAC it becomes redundant with rbac_account_permissions and should
-- be revisited separately. Role IDs 1000 / 1010-1014 sit in the gap
-- between core perms (1-913) and module perms (100000+).
--
-- One #24641 perm-consolidation effect worth flagging: granting
-- RBAC_PERM_COMMAND_NPC_INFO (593) at Player tier also gates
-- `.npc guid`, which the old file kept at T0 Triager. Accepted
-- trade-off of #24641's coarser perm granularity. See inline note
-- on (1010, 593). The analogous debug-tree leak that would have
-- come with perm 300 is avoided by granting it at Triager (1011)
-- rather than Player (1010).
-- ============================================================================

-- Idempotent: clear our roles + the stock sec-level defaults, then re-insert.
DELETE FROM `rbac_default_permissions`
    WHERE `permissionId` IN (1000, 1010, 1011, 1012, 1013, 1014);
DELETE FROM `rbac_default_permissions` WHERE `secId` = 3 AND `permissionId` = 192 AND `realmId` = -1;
DELETE FROM `rbac_default_permissions` WHERE `secId` = 2 AND `permissionId` = 193 AND `realmId` = -1;
DELETE FROM `rbac_default_permissions` WHERE `secId` = 1 AND `permissionId` = 194 AND `realmId` = -1;
DELETE FROM `rbac_default_permissions` WHERE `secId` = 0 AND `permissionId` = 195 AND `realmId` = -1;
DELETE FROM `rbac_linked_permissions`
    WHERE `linkedId` IN (1000, 1010, 1011, 1012, 1013, 1014);
DELETE FROM `rbac_permissions` WHERE `id` IN (1000, 1010, 1011, 1012, 1013, 1014);

INSERT INTO `rbac_permissions` (`id`, `name`) VALUES
(1000, 'Role: PTR Player'),
(1010, 'Role: GM Curated Player'),
(1011, 'Role: GM Triager (T0)'),
(1012, 'Role: GM Entertainer (T1)'),
(1013, 'Role: GM Protector (T2)'),
(1014, 'Role: GM Administrator');

-- GM tier inheritance + base Player role linkage.
-- 1010 -> 195 and 1000 -> 195 restore stock player perks (Join BG/Arenas/
-- Dungeon Finder, two-side char creation, email-confirm-for-pass-change,
-- plus the 199 command bucket) that the stripped (0,195,-1) default would
-- otherwise have lost. Both module player-tier roles link to 195 so each
-- works standalone if the other is removed.
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1000, 195),
(1010, 195),
(1011, 1010),
(1012, 1011),
(1013, 1012),
(1014, 1013);

-- Sec-level defaults (realmId -1 = all, 2 = PTR).
INSERT INTO `rbac_default_permissions` (`secId`, `permissionId`, `realmId`) VALUES
(0, 1010, -1), -- Player        -> GM Curated Player
(0, 1000,  2), -- Player        -> PTR Player (realm 2)
(1, 1011, -1), -- Moderator     -> GM Triager (T0)
(2, 1012, -1), -- Gamemaster    -> GM Entertainer (T1)
(3, 1014, -1); -- Administrator -> GM Administrator


-- Player -> role 1010
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1010, 394), -- gobject near
(1010, 398), -- gobject target
(1010, 593), -- npc info (also gates `.npc guid`, which old commands.sql
             -- kept at T0; #24641 puts both on the same perm)
(1010, 594), -- npc near
(1010, 602), -- quest, quest status
(1010, 718), -- server
(1010, 736), -- server motd
(1010, 874); -- settings announcer

-- GM T0 (Triager) -> role 1011
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1011, 218), -- account addon
(1011, 236), -- arena info
(1011, 237), -- arena lookup
(1011, 240), -- ban account
(1011, 284), -- character rename
(1011, 285), -- character reputation
(1011, 286), -- character titles
(1011, 292), -- cheat casttime
(1011, 293), -- cheat cooldown
(1011, 294), -- cheat explore
(1011, 295), -- cheat god
(1011, 296), -- cheat power
(1011, 298), -- cheat taxi
(1011, 299), -- cheat waterwalk
(1011, 300), -- debug (BROAD: perm 300 gates the entire `.debug *` tree
             -- under #24641, ~80 subcommands. Granted at Triager so all
             -- GM tiers inherit it; players no longer get debug access.)
(1011, 368), -- event activelist
(1011, 371), -- gm, gm spectator
(1011, 372), -- gm chat
(1011, 373), -- gm fly
(1011, 374), -- gm ingame
(1011, 376), -- gm visible
(1011, 377), -- go, go creature, go creature id, go creature name, go graveyard, go grid, go quest, go taxinode, go trigger, go xyz, go zonexy
(1011, 388), -- gobject activate
(1011, 392), -- gobject info
(1011, 413), -- instance listbinds
(1011, 414), -- instance unbind
(1011, 417), -- learn, learn all
(1011, 419), -- learn all my, learn all my pettalents, learn all my talents
(1011, 420), -- learn all my class
(1011, 422), -- learn all my spells
(1011, 424), -- learn all gm
(1011, 425), -- learn all crafts
(1011, 426), -- learn all default
(1011, 427), -- learn all lang
(1011, 428), -- learn all recipes
(1011, 429), -- unlearn
(1011, 431), -- lfg player
(1011, 432), -- lfg group
(1011, 433), -- lfg queue
(1011, 437), -- list creature
(1011, 438), -- list item
(1011, 439), -- list object
(1011, 440), -- list auras
(1011, 442), -- lookup, lookup gobject
(1011, 443), -- lookup area
(1011, 444), -- lookup creature
(1011, 445), -- lookup event
(1011, 446), -- lookup faction
(1011, 447), -- lookup item, lookup item set
(1011, 449), -- lookup object
(1011, 450), -- lookup quest
(1011, 455), -- lookup skill
(1011, 456), -- lookup spell
(1011, 457), -- lookup spell id
(1011, 458), -- lookup taxinode
(1011, 459), -- lookup teleport
(1011, 460), -- lookup title
(1011, 461), -- lookup map
(1011, 466), -- gmannounce
(1011, 467), -- gmnameannounce
(1011, 468), -- gmnotify
(1011, 471), -- whispers
(1011, 479), -- pet
(1011, 480), -- pet create
(1011, 481), -- pet learn
(1011, 482), -- pet unlearn
(1011, 490), -- appear
(1011, 493), -- bindsight
(1011, 494), -- combatstop
(1011, 497), -- cooldown
(1011, 501), -- dismount
(1011, 502), -- distance
(1011, 513), -- maxskill
(1011, 515), -- mute
(1011, 516), -- neargrave
(1011, 517), -- pinfo
(1011, 519), -- possess
(1011, 520), -- recall
(1011, 522), -- respawn
(1011, 523), -- revive
(1011, 526), -- setskill
(1011, 527), -- showarea
(1011, 528), -- summon
(1011, 529), -- unaura
(1011, 530), -- unbindsight
(1011, 533), -- unpossess
(1011, 542), -- morph, morph mount, morph reset
(1011, 544), -- modify
(1011, 547), -- modify drunk
(1011, 548), -- modify energy
(1011, 552), -- modify hp
(1011, 553), -- modify mana
(1011, 555), -- modify mount
(1011, 556), -- modify phase
(1011, 557), -- modify rage
(1011, 558), -- modify reputation
(1011, 559), -- modify runicpower
(1011, 560), -- modify scale
(1011, 561), -- modify speed
(1011, 562), -- modify speed all
(1011, 563), -- modify speed backwalk
(1011, 564), -- modify speed fly
(1011, 565), -- modify speed walk
(1011, 566), -- modify speed swim
(1011, 568), -- modify standstate
(1011, 569), -- modify talentpoints
(1011, 596), -- npc playemote
(1011, 597), -- npc say
(1011, 598), -- npc textemote
(1011, 599), -- npc whisper
(1011, 600), -- npc yell
(1011, 603), -- quest add
(1011, 604), -- quest complete
(1011, 605), -- quest remove
(1011, 606), -- quest reward
(1011, 632), -- mutehistory
(1011, 737), -- teleport
(1011, 762), -- titles add
(1011, 763), -- titles current
(1011, 764), -- titles remove
(1011, 766), -- titles set mask
(1011, 777), -- mailbox
(1011, 794), -- guild info
(1011, 796), -- instance getbossstate
(1011, 872), -- server debug
(1011, 897), -- gear repair
(1011, 898), -- gear stats
(1011, 909), -- character check bank
(1011, 910), -- character check bag
(1011, 911); -- character check profession

-- GM T1 (Entertainer/Moderator) -> role 1012
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1012, 231), -- achievement add
(1012, 232), -- achievement checkall
(1012, 238), -- arena rename
(1012, 241), -- ban character
(1012, 242), -- ban ip
(1012, 243), -- ban playeraccount
(1012, 245), -- baninfo account
(1012, 246), -- baninfo character
(1012, 247), -- baninfo ip
(1012, 249), -- banlist account
(1012, 250), -- banlist character
(1012, 251), -- banlist ip
(1012, 253), -- unban account
(1012, 254), -- unban character
(1012, 255), -- unban ip
(1012, 256), -- unban playeraccount
(1012, 267), -- cast
(1012, 268), -- cast back
(1012, 269), -- cast dist
(1012, 270), -- cast self
(1012, 271), -- cast target
(1012, 272), -- cast dest
(1012, 274), -- character customize
(1012, 275), -- character changefaction
(1012, 276), -- character changerace
(1012, 287), -- levelup
(1012, 343), -- deserter bg add
(1012, 344), -- deserter bg remove
(1012, 346), -- deserter instance add
(1012, 347), -- deserter instance remove
(1012, 369), -- event start
(1012, 370), -- event stop
(1012, 389), -- gobject add
(1012, 390), -- gobject add temp
(1012, 391), -- gobject delete
(1012, 393), -- gobject move
(1012, 396), -- gobject set phase
(1012, 397), -- gobject set state
(1012, 399), -- gobject turn
(1012, 401), -- guild
(1012, 402), -- guild create
(1012, 403), -- guild delete
(1012, 404), -- guild invite
(1012, 405), -- guild uninvite
(1012, 406), -- guild rank
(1012, 407), -- guild rename
(1012, 435), -- lfg options
(1012, 451), -- lookup player
(1012, 452), -- lookup player ip
(1012, 453), -- lookup player account
(1012, 454), -- lookup player email
(1012, 472), -- group
(1012, 473), -- group leader
(1012, 474), -- group disband
(1012, 475), -- group remove
(1012, 476), -- group join
(1012, 477), -- group list
(1012, 483), -- send
(1012, 485), -- send mail
(1012, 486), -- send message
(1012, 498), -- damage
(1012, 499), -- dev
(1012, 500), -- die
(1012, 504), -- freeze
(1012, 506), -- guid
(1012, 508), -- hidearea
(1012, 510), -- kick
(1012, 514), -- movegens
(1012, 531), -- unfreeze
(1012, 532), -- unmute
(1012, 534), -- unstuck
(1012, 546), -- modify bit
(1012, 550), -- modify gender
(1012, 571), -- npc add
(1012, 572), -- npc add formation
(1012, 573), -- npc add item
(1012, 574), -- npc add move
(1012, 575), -- npc add temp
(1012, 576), -- npc delete
(1012, 577), -- npc delete item
(1012, 578), -- npc follow
(1012, 579), -- npc follow stop
(1012, 580), -- npc set, npc set wanderdistance
(1012, 581), -- npc set allowmove
(1012, 582), -- npc set entry
(1012, 583), -- npc set faction original, npc set faction permanent, npc set faction temp
(1012, 584), -- npc set flag
(1012, 585), -- npc set level
(1012, 586), -- npc set link
(1012, 587), -- npc set model
(1012, 588), -- npc set movetype
(1012, 589), -- npc set phase
(1012, 591), -- npc set spawntime
(1012, 592), -- npc set data
(1012, 595), -- npc move
(1012, 601), -- npc tame
(1012, 740), -- teleport name
(1012, 741), -- teleport group
(1012, 742), -- ticket
(1012, 743), -- ticket assign
(1012, 744), -- ticket close
(1012, 745), -- ticket closedlist
(1012, 746), -- ticket comment
(1012, 747), -- ticket complete
(1012, 749), -- ticket escalate
(1012, 750), -- ticket escalatedlist
(1012, 751), -- ticket list
(1012, 752), -- ticket onlinelist
(1012, 754), -- ticket response, ticket response delete, ticket response show
(1012, 755), -- ticket response append
(1012, 756), -- ticket response appendln
(1012, 758), -- ticket unassign
(1012, 759), -- ticket viewid
(1012, 760), -- ticket viewname
(1012, 795), -- instance setbossstate
(1012, 886), -- item restore
(1012, 887), -- item restore list
(1012, 888), -- item refund
(1012, 889), -- commentator
(1012, 891); -- string

-- GM T2 (Protector) -> role 1013
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1013, 226), -- account set, account set 2fa, account set email
(1013, 227), -- account set addon
(1013, 228), -- account set gmlevel
(1013, 229), -- account set password
(1013, 233), -- arena captain
(1013, 234), -- arena create
(1013, 235), -- arena disband
(1013, 258), -- bf start
(1013, 259), -- bf stop
(1013, 260), -- bf switch
(1013, 261), -- bf timer
(1013, 262), -- bf enable
(1013, 279), -- character deleted list
(1013, 280), -- character deleted restore
(1013, 283), -- character level
(1013, 289), -- pdump load
(1013, 290), -- pdump write
(1013, 351), -- disable add battleground
(1013, 352), -- disable add map
(1013, 354), -- disable add outdoorpvp
(1013, 355), -- disable add quest
(1013, 356), -- disable add spell
(1013, 357), -- disable add vmap
(1013, 360), -- disable remove battleground
(1013, 361), -- disable remove map
(1013, 363), -- disable remove outdoorpvp
(1013, 364), -- disable remove quest
(1013, 365), -- disable remove spell
(1013, 366), -- disable remove vmap
(1013, 375), -- gm list
(1013, 409), -- honor add
(1013, 410), -- honor add kill
(1013, 411), -- honor update
(1013, 416), -- instance savedata
(1013, 434), -- lfg clean
(1013, 462), -- announce
(1013, 469), -- nameannounce
(1013, 470), -- notify
(1013, 484), -- send items
(1013, 487), -- send money
(1013, 488), -- additem
(1013, 489), -- additem set
(1013, 491), -- aura
(1013, 495), -- cometome
(1013, 503), -- flusharenapoints
(1013, 511), -- linkgrave
(1013, 518), -- playall
(1013, 524), -- saveall
(1013, 535), -- wchange
(1013, 536), -- mmap
(1013, 537), -- mmap loadedtiles
(1013, 538), -- mmap loc
(1013, 539), -- mmap path
(1013, 540), -- mmap stats
(1013, 541), -- mmap testarea
(1013, 545), -- modify arenapoints
(1013, 549), -- modify faction
(1013, 551), -- modify honor
(1013, 554), -- modify money
(1013, 607), -- reload, reload command, reload dungeon_access_requirements, reload dungeon_access_template, reload game_graveyard, reload gameobject_loot_template, reload mail_server_template, reload module_string, reload motd, reload npc_trainer, reload player_loot_template, reload spell_proc_event, reload spell_scripts
(1013, 609), -- reload achievement_criteria_data
(1013, 610), -- reload achievement_reward
(1013, 611), -- reload all
(1013, 612), -- reload all achievement
(1013, 613), -- reload all area
(1013, 614), -- reload broadcast_text
(1013, 615), -- reload all gossips
(1013, 616), -- reload all item
(1013, 617), -- reload all locales
(1013, 618), -- reload all loot
(1013, 619), -- reload all npc
(1013, 620), -- reload all quest
(1013, 621), -- reload all scripts
(1013, 622), -- reload all spell
(1013, 623), -- reload areatrigger_involvedrelation
(1013, 624), -- reload areatrigger_tavern
(1013, 625), -- reload areatrigger_teleport
(1013, 626), -- reload auctions
(1013, 627), -- reload autobroadcast
(1013, 629), -- reload conditions
(1013, 630), -- reload config
(1013, 631), -- reload battleground_template
(1013, 633), -- reload creature_linked_respawn
(1013, 634), -- reload creature_loot_template
(1013, 635), -- reload creature_onkill_reputation
(1013, 636), -- reload creature_questender
(1013, 637), -- reload creature_queststarter
(1013, 639), -- reload creature_template
(1013, 640), -- reload creature_text
(1013, 641), -- reload disables
(1013, 642), -- reload disenchant_loot_template
(1013, 643), -- reload event_scripts
(1013, 644), -- reload fishing_loot_template
(1013, 645), -- reload graveyard_zone
(1013, 646), -- reload game_tele
(1013, 647), -- reload gameobject_questender
(1013, 649), -- reload gameobject_queststarter
(1013, 650), -- reload gm_tickets
(1013, 651), -- reload gossip_menu
(1013, 652), -- reload gossip_menu_option
(1013, 653), -- reload item_enchantment_template
(1013, 654), -- reload item_loot_template
(1013, 655), -- reload item_set_names
(1013, 656), -- reload lfg_dungeon_rewards
(1013, 657), -- reload achievement_reward_locale
(1013, 658), -- reload creature_template_locale
(1013, 659), -- reload creature_text_locale
(1013, 660), -- reload gameobject_template_locale
(1013, 661), -- reload gossip_menu_option_locale
(1013, 662), -- reload item_template_locale
(1013, 663), -- reload item_set_name_locale
(1013, 664), -- reload npc_text_locale
(1013, 665), -- reload page_text_locale
(1013, 666), -- reload points_of_interest_locale
(1013, 667), -- reload quest_template_locale
(1013, 668), -- reload mail_level_reward
(1013, 669), -- reload mail_loot_template
(1013, 670), -- reload milling_loot_template
(1013, 671), -- reload npc_spellclick_spells
(1013, 673), -- reload npc_vendor
(1013, 674), -- reload page_text
(1013, 675), -- reload pickpocketing_loot_template
(1013, 676), -- reload points_of_interest
(1013, 677), -- reload prospecting_loot_template
(1013, 678), -- reload quest_poi
(1013, 679), -- reload quest_template
(1013, 681), -- reload reference_loot_template
(1013, 682), -- reload reserved_name
(1013, 685), -- reload skill_discovery_template
(1013, 686), -- reload skill_extra_item_template
(1013, 687), -- reload skill_fishing_base_level
(1013, 688), -- reload skinning_loot_template
(1013, 689), -- reload smart_scripts
(1013, 690), -- reload spell_required
(1013, 691), -- reload spell_area
(1013, 692), -- reload spell_bonus_data
(1013, 693), -- reload spell_group
(1013, 695), -- reload spell_loot_template
(1013, 696), -- reload spell_linked_spell
(1013, 697), -- reload spell_pet_auras
(1013, 698), -- character changeaccount
(1013, 699), -- reload spell_proc
(1013, 701), -- reload spell_target_position
(1013, 702), -- reload spell_threats
(1013, 703), -- reload spell_group_stack_rules
(1013, 704), -- reload acore_string
(1013, 706), -- reload waypoint_scripts
(1013, 707), -- reload waypoint_data
(1013, 708), -- reload vehicle_accessory
(1013, 709), -- reload vehicle_template_accessory
(1013, 719), -- server corpses
(1013, 722), -- server idlerestart cancel
(1013, 724), -- server idleshutdown cancel
(1013, 727), -- server restart
(1013, 728), -- server restart cancel
(1013, 733), -- server set motd
(1013, 734), -- server shutdown
(1013, 735), -- server shutdown cancel
(1013, 738), -- teleport add
(1013, 739), -- teleport del
(1013, 748), -- ticket delete
(1013, 757), -- ticket togglesystem
(1013, 767), -- wp
(1013, 768), -- wp add
(1013, 769), -- wp event
(1013, 770), -- wp load
(1013, 771), -- wp modify
(1013, 772), -- wp unload
(1013, 773), -- wp reload
(1013, 774), -- wp show
(1013, 843), -- reload quest_greeting
(1013, 873), -- reload creature_movement_override
(1013, 890), -- skirmish
(1013, 895), -- aura stack
(1013, 896); -- respawn all

-- Administrator -> role 1014
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1014, 219), -- account create
(1014, 220), -- account delete
(1014, 224), -- account onlinelist
(1014, 278), -- character deleted delete
(1014, 282), -- character erase
(1014, 567), -- modify spell
(1014, 710), -- reset, reset items
(1014, 711), -- reset achievements
(1014, 712), -- reset honor
(1014, 713), -- reset level
(1014, 714), -- reset spells
(1014, 715), -- reset stats
(1014, 716), -- reset talents
(1014, 717), -- reset all
(1014, 720), -- server exit
(1014, 721), -- server idlerestart
(1014, 723), -- server idleshutdown
(1014, 730), -- server set closed
(1014, 732), -- server set loglevel
(1014, 753); -- ticket reset

-- PTR Player (1000) -- absorbed from mod-ptr-changes; overlaps with GM tiers.
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(1000, 267), -- cast
(1000, 268), -- cast back
(1000, 269), -- cast dist
(1000, 270), -- cast self
(1000, 272), -- cast dest
(1000, 274), -- character customize
(1000, 275), -- character changefaction
(1000, 276), -- character changerace
(1000, 287), -- levelup
(1000, 292), -- cheat casttime
(1000, 293), -- cheat cooldown
(1000, 294), -- cheat explore
(1000, 295), -- cheat god
(1000, 296), -- cheat power
(1000, 298), -- cheat taxi
(1000, 299), -- cheat waterwalk
(1000, 300), -- debug (and all subcommands)
(1000, 343), -- deserter bg add
(1000, 344), -- deserter bg remove (also gates `bg remove all`)
(1000, 346), -- deserter instance add
(1000, 347), -- deserter instance remove (also gates `instance remove all`)
(1000, 367), -- event info
(1000, 368), -- event activelist
(1000, 369), -- event start
(1000, 370), -- event stop
(1000, 373), -- gm fly
(1000, 377), -- go (and creature/gameobject/graveyard/grid/quest/taxinode/ticket/trigger/xyz/zonexy)
(1000, 388), -- gobject activate
(1000, 409), -- honor add
(1000, 410), -- honor add kill
(1000, 411), -- honor update
(1000, 413), -- instance listbinds
(1000, 414), -- instance unbind
(1000, 415), -- instance stats
(1000, 416), -- instance savedata
(1000, 795), -- instance setbossstate
(1000, 796), -- instance getbossstate
(1000, 417), -- learn (also gates `learn all`)
(1000, 419), -- learn all my (also gates `learn all my pettalents`)
(1000, 420), -- learn all my class
(1000, 422), -- learn all my spells
(1000, 423), -- learn all my talents
(1000, 424), -- learn all gm
(1000, 425), -- learn all crafts
(1000, 426), -- learn all default
(1000, 427), -- learn all lang
(1000, 428), -- learn all recipes
(1000, 429), -- unlearn
(1000, 437), -- list creature
(1000, 438), -- list item
(1000, 439), -- list object
(1000, 440), -- list auras (also gates `list auras id`/`list auras name`)
(1000, 445), -- lookup event
(1000, 449), -- lookup object
(1000, 451), -- lookup player
(1000, 452), -- lookup player ip
(1000, 453), -- lookup player account
(1000, 454), -- lookup player email
(1000, 457), -- lookup spell id
(1000, 458), -- lookup taxinode
(1000, 460), -- lookup title
(1000, 461), -- lookup map
(1000, 488), -- additem
(1000, 489), -- additem set
(1000, 777), -- mailbox
(1000, 892), -- opendoor
(1000, 897), -- gear repair
(1000, 490), -- appear
(1000, 491), -- aura
(1000, 494), -- combatstop
(1000, 497), -- cooldown
(1000, 498), -- damage
(1000, 500), -- die
(1000, 502), -- distance
(1000, 513), -- maxskill
(1000, 520), -- recall
(1000, 522), -- respawn
(1000, 523), -- revive
(1000, 526), -- setskill
(1000, 529), -- unaura
(1000, 542), -- morph (also gates `morph mount`/`morph reset`/`morph target`)
(1000, 544), -- modify
(1000, 545), -- modify arenapoints
(1000, 546), -- modify bit
(1000, 547), -- modify drunk
(1000, 548), -- modify energy
(1000, 549), -- modify faction
(1000, 550), -- modify gender
(1000, 551), -- modify honor
(1000, 552), -- modify hp
(1000, 553), -- modify mana
(1000, 554), -- modify money
(1000, 555), -- modify mount
(1000, 556), -- modify phase
(1000, 557), -- modify rage
(1000, 558), -- modify reputation
(1000, 559), -- modify runicpower
(1000, 560), -- modify scale
(1000, 561), -- modify speed
(1000, 562), -- modify speed all
(1000, 563), -- modify speed backwalk
(1000, 564), -- modify speed fly
(1000, 565), -- modify speed walk
(1000, 566), -- modify speed swim
(1000, 567), -- modify spell
(1000, 568), -- modify standstate
(1000, 569), -- modify talentpoints
(1000, 593), -- npc info (also gates `npc guid`)
(1000, 601), -- npc tame
(1000, 602), -- quest (also gates `quest status`)
(1000, 603), -- quest add
(1000, 604), -- quest complete
(1000, 605), -- quest remove
(1000, 606), -- quest reward
(1000, 716), -- reset talents
(1000, 737); -- teleport (renamed `tele` in #24641)

-- ============================================================================
-- Not granted (no perm in #24641, or visible-by-inference parents):
--   missing perm: gobject respawn, character deleted purge, reset items *,
--                 inventory, inventory count, item move, player learn,
--                 player unlearn, groupsummon, teleport name npc *
--   chromiecraft customs: bags, bags clear, wpgps
--   parents (sub-grants imply visibility): gobject, npc, cache, character,
--     cheat, event, instance, list, ban, unban, baninfo, banlist, bf, honor,
--     titles, titles set, gobject set, lfg, achievement, settings, pdump
--   spect commands map to 899-904 (mod-spectator); IDs depend on #24641 stability.
-- ============================================================================
