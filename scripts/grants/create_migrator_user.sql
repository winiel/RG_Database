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

-- ⚠️ MySQL의 CREATE USER ... IDENTIFIED BY는 user variable(@var)을 받지 못함.
-- 본 파일은 로컬 Dev 임시 패스워드 literal 사용. Stg/Prod는 Secrets Manager에서
-- envsubst 등으로 placeholder를 치환한 임시 SQL을 만들어 적용 권장.
--
-- 로컬 Dev 임시 패스워드:
--   projectrg_migrator = 'migrator_local_only_change_me'

DROP USER IF EXISTS 'projectrg_migrator'@'%';
CREATE USER 'projectrg_migrator'@'%' IDENTIFIED BY 'migrator_local_only_change_me';

GRANT ALL PRIVILEGES
    ON ProjectRG_Dev.*
    TO 'projectrg_migrator'@'%';

FLUSH PRIVILEGES;

SHOW GRANTS FOR 'projectrg_migrator'@'%';
