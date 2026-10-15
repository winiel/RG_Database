-- DB-52 production 테스트 계정 test3@winielab.com / 1234 생성 (prod 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-10-15) · 선례 DB-32·DB-51
--
-- 생성 경로: 공개 자가가입 POST /api/v1/auth/signup (snake_case 바디·임시 비번 min8) → HTTP 200 TokenPair
--   academy 테스트학원3 = 0x01A13F2ACF7B7AB298FE66BF01340CFE (business_number 000-00-00003·status=active)
--   user_accounts test3@ = 0x01A13F2ACF7B7AB298FE66C9C4CEECA2 (owner '테스트3')
--   academy_subscriptions 행 미생성(행 없음 = Basic·GET /subscription plan=basic) · 카드/빌링키 0 · 임의 보정 안 함
--
-- 백업: backups/20261015-db52-db53-pre-3tables.sql + RDS 스냅샷 winielab-dev-db-rds-db52-db53-pre-20261015

-- migrate:up (수동 실행·2026-10-15 적용완료·dry-run=1·ROW_COUNT=1)
-- hash = RG_Backend .venv bcrypt hashpw(b'1234', gensalt()) — 값 기재 금지
UPDATE user_accounts
   SET password_hash = '<bcrypt(1234)>',
       updated_at    = NOW() + INTERVAL 9 HOUR
 WHERE email = 'test3@winielab.com'
   AND tenant_id = UNHEX('01A13F2ACF7B7AB298FE66BF01340CFE');
-- 검증: login 1234 → 200 / Temp12345! → 401

-- migrate:down (계정 제거가 필요하면 별도 오더 — 학원·계정 물리삭제는 본 파일 범위 밖)
