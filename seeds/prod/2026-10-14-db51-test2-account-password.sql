-- DB-51 production 테스트 계정 test2@winielab.com / 1234 생성 (prod 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-10-14) · 선례 DB-32(비번 리셋)
--
-- 생성 경로: 공개 자가가입 POST /api/v1/auth/signup (임시 비번·min8) → HTTP 200 TokenPair
--   ※ 요청 바디는 snake_case(business_number) — camelCase(businessNumber) 는 422 VALIDATION_FAILED(생성 0)
--   academy 테스트학원2 = 0x01A13981DE787452917167064A71805D (business_number 000-00-00002·status=active)
--   user_accounts test2@ = 0x01A13981DE78745291716710751417C4 (owner '테스트2')
--   academy_subscriptions 행 미생성(signup 정상 동작 — 행 없음 = Basic) · 임의 보정 안 함
--
-- 백업: backups/20261014-db50-db51-pre-5tables.sql + RDS 스냅샷 winielab-dev-db-rds-db50-db51-pre-20261014

-- migrate:up (수동 실행·2026-10-14 적용완료·dry-run=1·ROW_COUNT=1)
-- hash = RG_Backend .venv bcrypt 5.0.0 hashpw(b'1234', gensalt()) — 값 기재 금지
UPDATE user_accounts
   SET password_hash = '<bcrypt(1234)>',
       updated_at    = NOW() + INTERVAL 9 HOUR
 WHERE email = 'test2@winielab.com'
   AND tenant_id = UNHEX('01A13981DE787452917167064A71805D');
-- 검증: login 1234 → 200 / Temp12345! → 401

-- migrate:down (계정 제거가 필요하면 별도 오더 — 학원·계정 물리삭제는 본 파일 범위 밖)
