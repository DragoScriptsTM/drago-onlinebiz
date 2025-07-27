CREATE TABLE IF NOT EXISTS `player_online_businesses` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `business_key` VARCHAR(50) NOT NULL,
  `level` INT NOT NULL DEFAULT 0,  -- default op 0 gezet ipv 1
  `balance` BIGINT NOT NULL DEFAULT 0,
  `last_income_timestamp` BIGINT NOT NULL DEFAULT 0,
  `upgrade_ready_at` BIGINT NOT NULL DEFAULT 0,  -- Nieuwe kolom voor wachttijd timestamp
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_business_per_player` (`identifier`, `business_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
