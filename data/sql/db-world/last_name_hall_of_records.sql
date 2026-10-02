-- mod-last_name: Hall of Records
-- Writ of Lineage (mailed at level 20) starts the faction quest. Each capital innkeeper sells one supply while
-- the quest is active. The registry ledger in Orgrimmar or Stormwind inscribes the family name (script).
-- Every ID here must match LastName.h and the client DBC patch in client/DBFilesClient.

SET @MAIL_SENDER    := 911101;
SET @QUEST_HORDE    := 911101;
SET @QUEST_ALLIANCE := 911102;
SET @GO_HORDE       := 911101;
SET @GO_ALLIANCE    := 911102;
SET @GO_DISPLAY     := 10101;
SET @TEXT           := 911101;
SET @ACH_HORDE      := 5101;
SET @ACH_ALLIANCE   := 5102;
SET @PRICE          := 2500; -- 25 silver per supply

-- Items: 911101-911102 writs, 911103-911106 Horde supplies, 911107-911110 Alliance supplies
DELETE FROM `item_template` WHERE `entry` BETWEEN 911101 AND 911110;
INSERT INTO `item_template` (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`, `Quality`, `BuyCount`, `BuyPrice`, `SellPrice`, `maxcount`, `stackable`, `bonding`, `description`, `startquest`, `Material`) VALUES
(911101, 12, 0, -1, 'Writ of Lineage', 3048, 1, 1, 0, 0, 1, 1, 1, 'Issued by the Hall of Records of Orgrimmar.', @QUEST_HORDE, 7),
(911102, 12, 0, -1, 'Writ of Lineage', 3048, 1, 1, 0, 0, 1, 1, 1, 'Issued by the Hall of Records of Stormwind.', @QUEST_ALLIANCE, 7),
(911103, 12, 0, -1, 'Forsaken Iron-Gall Ink', 55108, 1, 1, @PRICE, 0, 1, 1, 4, 'Brewed by the apothecaries of the Undercity. It will not fade.', 0, 3),
(911104, 12, 0, -1, 'Silvermoon Scribe''s Quill', 21370, 1, 1, @PRICE, 0, 1, 1, 4, 'Cut from a dragonhawk plume.', 0, 7),
(911105, 12, 0, -1, 'Mulgore Vellum', 57388, 1, 1, @PRICE, 0, 1, 1, 4, 'Soft, pale and cured in the old ways of the Shu''halo.', 0, 8),
(911106, 12, 0, -1, 'Warchief''s Official Seal', 40184, 1, 1, @PRICE, 0, 1, 1, 4, 'Pressed with the crest of the Horde.', 0, 1),
(911107, 12, 0, -1, 'Ironforge Forge-Black Ink', 55113, 1, 1, @PRICE, 0, 1, 1, 4, 'Ground from forge soot. Dwarves swear it outlasts stone.', 0, 3),
(911108, 12, 0, -1, 'Darnassian Owl-Feather Quill', 19569, 1, 1, @PRICE, 0, 1, 1, 4, 'Shed by the owls of Teldrassil.', 0, 7),
(911109, 12, 0, -1, 'Exodar Crystal Vellum', 57388, 1, 1, @PRICE, 0, 1, 1, 4, 'Faintly luminous. The draenei keep their oldest records on it.', 0, 8),
(911110, 12, 0, -1, 'King''s Official Seal', 40185, 1, 1, @PRICE, 0, 1, 1, 4, 'Pressed with the crest of the Alliance.', 0, 1);

-- Server copy of the client Item.dbc rows
DELETE FROM `item_dbc` WHERE `ID` BETWEEN 911101 AND 911110;
INSERT INTO `item_dbc` (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, `Material`, `DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES
(911101, 12, 0, -1, 7, 3048, 0, 0),
(911102, 12, 0, -1, 7, 3048, 0, 0),
(911103, 12, 0, -1, 3, 55108, 0, 0),
(911104, 12, 0, -1, 7, 21370, 0, 0),
(911105, 12, 0, -1, 8, 57388, 0, 0),
(911106, 12, 0, -1, 1, 40184, 0, 0),
(911107, 12, 0, -1, 3, 55113, 0, 0),
(911108, 12, 0, -1, 7, 19569, 0, 0),
(911109, 12, 0, -1, 8, 57388, 0, 0),
(911110, 12, 0, -1, 1, 40185, 0, 0);

-- Supplies are sold by one innkeeper each, only while the quest is active
DELETE FROM `npc_vendor` WHERE `item` BETWEEN 911103 AND 911110;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(6741, 0, 911103, 0, 0, 0),  -- Innkeeper Norman, Undercity
(16618, 0, 911104, 0, 0, 0), -- Innkeeper Velandra, Silvermoon City
(6746, 0, 911105, 0, 0, 0),  -- Innkeeper Pala, Thunder Bluff
(6929, 0, 911106, 0, 0, 0),  -- Innkeeper Gryshka, Orgrimmar
(5111, 0, 911107, 0, 0, 0),  -- Innkeeper Firebrew, Ironforge
(6735, 0, 911108, 0, 0, 0),  -- Innkeeper Saelienne, Darnassus
(16739, 0, 911109, 0, 0, 0), -- Caregiver Breel, The Exodar
(6740, 0, 911110, 0, 0, 0);  -- Innkeeper Allison, Stormwind

-- 23 = CONDITION_SOURCE_TYPE_NPC_VENDOR, 9 = CONDITION_QUESTTAKEN
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 23 AND `SourceEntry` BETWEEN 911103 AND 911110;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(23, 6741, 911103, 0, 0, 9, 0, @QUEST_HORDE, 0, 0, 0, 0, 0, '', 'mod-last_name: Forsaken Iron-Gall Ink only while A Name Worth Keeping is active'),
(23, 16618, 911104, 0, 0, 9, 0, @QUEST_HORDE, 0, 0, 0, 0, 0, '', 'mod-last_name: Silvermoon Scribe''s Quill only while A Name Worth Keeping is active'),
(23, 6746, 911105, 0, 0, 9, 0, @QUEST_HORDE, 0, 0, 0, 0, 0, '', 'mod-last_name: Mulgore Vellum only while A Name Worth Keeping is active'),
(23, 6929, 911106, 0, 0, 9, 0, @QUEST_HORDE, 0, 0, 0, 0, 0, '', 'mod-last_name: Warchief''s Official Seal only while A Name Worth Keeping is active'),
(23, 5111, 911107, 0, 0, 9, 0, @QUEST_ALLIANCE, 0, 0, 0, 0, 0, '', 'mod-last_name: Ironforge Forge-Black Ink only while A Name Worth Keeping is active'),
(23, 6735, 911108, 0, 0, 9, 0, @QUEST_ALLIANCE, 0, 0, 0, 0, 0, '', 'mod-last_name: Darnassian Owl-Feather Quill only while A Name Worth Keeping is active'),
(23, 16739, 911109, 0, 0, 9, 0, @QUEST_ALLIANCE, 0, 0, 0, 0, 0, '', 'mod-last_name: Exodar Crystal Vellum only while A Name Worth Keeping is active'),
(23, 6740, 911110, 0, 0, 9, 0, @QUEST_ALLIANCE, 0, 0, 0, 0, 0, '', 'mod-last_name: King''s Official Seal only while A Name Worth Keeping is active');

-- Quests. No quest ender: the registry script completes them after the family name passes validation.
-- AllowableRaces 690 = Horde races, 1101 = Alliance races. QuestSortID = Orgrimmar / Stormwind City.
DELETE FROM `quest_template` WHERE `ID` IN (@QUEST_HORDE, @QUEST_ALLIANCE);
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemId5`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `RequiredItemCount5`) VALUES
(@QUEST_HORDE, 2, 20, 20, 1637, 690, 'A Name Worth Keeping',
'Buy Forsaken Iron-Gall Ink from Innkeeper Norman in the Undercity, a Silvermoon Scribe''s Quill from Innkeeper Velandra in Silvermoon City, Mulgore Vellum from Innkeeper Pala in Thunder Bluff and a Warchief''s Official Seal from Innkeeper Gryshka in Orgrimmar. Then bring them and your Writ of Lineage to the Hall of Records registry in Orgrimmar.',
'$N, the Horde remembers its heroes by the names they carry. You have shed enough blood and walked enough roads to earn a family name of your own, one your descendants will speak with pride.$B$BA name worth keeping must be written properly. The Keeper of Records demands ink from the Undercity, a quill from Silvermoon, vellum from Thunder Bluff and an official seal from Orgrimmar itself. The innkeepers of each city keep what you need.$B$BWhen you have all four, sign the ledger at the Hall of Records in Orgrimmar.',
'Inscribe your family name at the Hall of Records registry in Orgrimmar.',
911103, 911104, 911105, 911106, 911101, 1, 1, 1, 1, 1),
(@QUEST_ALLIANCE, 2, 20, 20, 1519, 1101, 'A Name Worth Keeping',
'Buy Ironforge Forge-Black Ink from Innkeeper Firebrew in Ironforge, a Darnassian Owl-Feather Quill from Innkeeper Saelienne in Darnassus, Exodar Crystal Vellum from Caregiver Breel in the Exodar and a King''s Official Seal from Innkeeper Allison in Stormwind. Then bring them and your Writ of Lineage to the Hall of Records registry in Stormwind.',
'$N, the Alliance honors those who defend it, and the King has decreed that such heroes may take a family name of their own, one your descendants will speak with pride.$B$BA name worth keeping must be written properly. The Keeper of Records demands ink from Ironforge, a quill from Darnassus, vellum from the Exodar and an official seal from Stormwind itself. The innkeepers of each city keep what you need.$B$BWhen you have all four, sign the ledger at the Hall of Records in Stormwind.',
'Inscribe your family name at the Hall of Records registry in Stormwind.',
911107, 911108, 911109, 911110, 911102, 1, 1, 1, 1, 1);

-- Registry display: the Arathor book wheel, shipped in client/World. Server copy of the client
-- GameObjectDisplayInfo.dbc row; the geometry box is the model's bounding box and sets the interaction range.
DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` = @GO_DISPLAY;
INSERT INTO `gameobjectdisplayinfo_dbc` (`ID`, `ModelName`, `GeoBoxMinX`, `GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`) VALUES
(@GO_DISPLAY, 'World\\Expansion10\\Doodads\\Arathor\\11AT_Arathor_BookWheel01.mdx', -1.5934, -2.0754, -0.0542, 2.7379, 2.0754, 2.9888);

-- Registry ledgers (type 2 = questgiver). Spawn in-game with .gobject add.
DELETE FROM `gameobject_template` WHERE `entry` IN (@GO_HORDE, @GO_ALLIANCE);
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `size`, `ScriptName`) VALUES
(@GO_HORDE, 2, @GO_DISPLAY, 'Hall of Records Registry', 1, 'go_last_name_registry'),
(@GO_ALLIANCE, 2, @GO_DISPLAY, 'Hall of Records Registry', 1, 'go_last_name_registry');

DELETE FROM `npc_text` WHERE `ID` = @TEXT;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`) VALUES
(@TEXT, 'The great ledger of the Hall of Records lies open. Page after page bears the family names of citizens who proved themselves worthy of them.$B$BA fresh line waits at the bottom of the page.',
'The great ledger of the Hall of Records lies open. Page after page bears the family names of citizens who proved themselves worthy of them.$B$BA fresh line waits at the bottom of the page.', 1);

-- Mail sender only, never spawned. Model borrowed from Innkeeper Gryshka.
DELETE FROM `creature_template` WHERE `entry` = @MAIL_SENDER;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `unit_class`, `type`) VALUES
(@MAIL_SENDER, 'Keeper of Records', 'Hall of Records', 80, 80, 35, 1, 7);

DELETE FROM `creature_template_model` WHERE `CreatureID` = @MAIL_SENDER;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(@MAIL_SENDER, 0, 5706, 1, 1);

-- Achievements, server copy of the client Achievement.dbc / Achievement_Criteria.dbc rows.
-- Faction 0 = Horde, 1 = Alliance. Category 92 = General. IconID 2049 = INV_Feather_07. Criteria type 36 = own item.
DELETE FROM `achievement_dbc` WHERE `ID` IN (@ACH_HORDE, @ACH_ALLIANCE);
INSERT INTO `achievement_dbc` (`ID`, `Faction`, `Instance_Id`, `Supercedes`, `Title_Lang_enUS`, `Title_Lang_Mask`, `Description_Lang_enUS`, `Description_Lang_Mask`, `Category`, `Points`, `Ui_Order`, `Flags`, `IconID`, `Reward_Lang_enUS`, `Reward_Lang_Mask`, `Minimum_Criteria`, `Shares_Criteria`) VALUES
(@ACH_HORDE, 0, -1, 0, 'What''s in a Name?', 16712190, 'Gather ink, a quill, vellum and an official seal from the innkeepers of the four great cities of the Horde.', 16712190, 92, 10, 0, 0, 2049, 'Reward: A family name at the Hall of Records', 16712190, 0, 0),
(@ACH_ALLIANCE, 1, -1, 0, 'What''s in a Name?', 16712190, 'Gather ink, a quill, vellum and an official seal from the innkeepers of the four great cities of the Alliance.', 16712190, 92, 10, 0, 0, 2049, 'Reward: A family name at the Hall of Records', 16712190, 0, 0);

DELETE FROM `achievement_criteria_dbc` WHERE `ID` BETWEEN 20101 AND 20108;
INSERT INTO `achievement_criteria_dbc` (`ID`, `Achievement_Id`, `Type`, `Asset_Id`, `Quantity`, `Description_Lang_enUS`, `Description_Lang_Mask`, `Ui_Order`) VALUES
(20101, @ACH_HORDE, 36, 911103, 1, 'Forsaken Iron-Gall Ink', 16712190, 1),
(20102, @ACH_HORDE, 36, 911104, 1, 'Silvermoon Scribe''s Quill', 16712190, 2),
(20103, @ACH_HORDE, 36, 911105, 1, 'Mulgore Vellum', 16712190, 3),
(20104, @ACH_HORDE, 36, 911106, 1, 'Warchief''s Official Seal', 16712190, 4),
(20105, @ACH_ALLIANCE, 36, 911107, 1, 'Ironforge Forge-Black Ink', 16712190, 1),
(20106, @ACH_ALLIANCE, 36, 911108, 1, 'Darnassian Owl-Feather Quill', 16712190, 2),
(20107, @ACH_ALLIANCE, 36, 911109, 1, 'Exodar Crystal Vellum', 16712190, 3),
(20108, @ACH_ALLIANCE, 36, 911110, 1, 'King''s Official Seal', 16712190, 4);
