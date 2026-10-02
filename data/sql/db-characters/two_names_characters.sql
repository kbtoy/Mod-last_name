-- mod-two-names: room for "First Last" (two 12 letter parts and a space), keeping each column's collation
ALTER TABLE `characters` MODIFY COLUMN `name` VARCHAR(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL;
ALTER TABLE `characters` MODIFY COLUMN `deleteInfos_Name` VARCHAR(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
ALTER TABLE `gm_ticket` MODIFY COLUMN `name` VARCHAR(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Name of ticket creator';

-- Characters already mailed a Writ of Lineage
CREATE TABLE IF NOT EXISTS `mod_two_names_writ` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `sent_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every family name inscribed at the Hall of Records, kept per account for a future surname picker.
-- Rows are kept when the character is deleted.
CREATE TABLE IF NOT EXISTS `mod_two_names_surname` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `account` INT UNSIGNED NOT NULL,
  `first_name` VARCHAR(12) NOT NULL,
  `surname` VARCHAR(12) NOT NULL,
  `registered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`),
  KEY `idx_account` (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
