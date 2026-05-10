-- ============================================================================
-- 마이그레이션 계정 (DDL 권한)
--
-- 합의: 회신 §5.8 — DDL 권한 보유, 백엔드에서는 사용 금지
--
-- 사용법:
--   mysql -u root < scripts/grants/create_migrator_user.sql
--
-- ⚠️ 글로벌 권한(SUPER/RELOAD/SHUTDOWN)은 부여하지 않음 (DB 단위 ALL만)
-- ============================================================================

SET @migrator_password = 'migrator_local_only_change_me';

DROP USER IF EXISTS 'projectrg_migrator'@'%';
CREATE USER 'projectrg_migrator'@'%' IDENTIFIED BY @migrator_password;

GRANT ALL PRIVILEGES
    ON ProjectRG_Dev.*
    TO 'projectrg_migrator'@'%';

FLUSH PRIVILEGES;

SHOW GRANTS FOR 'projectrg_migrator'@'%';
