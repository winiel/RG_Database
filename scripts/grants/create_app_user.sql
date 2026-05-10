-- ============================================================================
-- 백엔드 애플리케이션 계정 (DML만)
--
-- 합의: 회신 §5.8 — SELECT/INSERT/UPDATE/DELETE만 허용, DDL/SUPER/RELOAD 차단
--
-- 사용법:
--   mysql -u root < scripts/grants/create_app_user.sql
--
-- ⚠️ 환경별 호스트 범위 주의 (회신 §5.8):
--   - Dev/로컬: '%'  허용
--   - Stg:     '10.10.%'  ← 실제 VPC CIDR로 교체
--   - Prod:    '10.20.%'  ← 실제 VPC CIDR로 교체
-- 본 스크립트는 로컬 Dev 기준. Stg/Prod 적용 시 호스트 부분을 반드시 변경할 것.
-- ============================================================================

-- ⚠️ MySQL의 CREATE USER ... IDENTIFIED BY는 user variable(@var)을 받지 못함.
-- 본 파일은 로컬 Dev 임시 패스워드 literal 사용. Stg/Prod는 Secrets Manager에서
-- envsubst 등으로 placeholder를 치환한 임시 SQL을 만들어 적용 권장.
--
-- 로컬 Dev 임시 패스워드 (실제 운영에서는 절대 평문 commit 금지):
--   projectrg_app = 'app_local_only_change_me'

DROP USER IF EXISTS 'projectrg_app'@'%';
CREATE USER 'projectrg_app'@'%' IDENTIFIED BY 'app_local_only_change_me';

GRANT SELECT, INSERT, UPDATE, DELETE
    ON ProjectRG_Dev.*
    TO 'projectrg_app'@'%';

-- 명시적 차단 확인 (GRANT되지 않은 권한은 자동으로 거부됨)
-- 즉 CREATE/ALTER/DROP/GRANT/SUPER/RELOAD/SHUTDOWN 등은 부여하지 않음.

FLUSH PRIVILEGES;

-- 검증
SHOW GRANTS FOR 'projectrg_app'@'%';
