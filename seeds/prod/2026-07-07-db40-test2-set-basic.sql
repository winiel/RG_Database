-- DB-40 test_2@winielab.com 학원 basic 전환 (prod RDS 데이터·1회성)
-- 오더: request/RG_Database/2026-07-07-db40-test2-account-set-basic-plan-request.md (위니엘님 직접 지시)
-- 전제: DB-39 grandfather seed 로 테스트2 학원에 pro/active 구독행 존재.
--
-- 대상(단일): academy = 테스트2 학원 (owner test_2@winielab.com)
--   academy_id = 0x01A90CA2664211F18FA70A2DEDA3276D
--   subscription_id = 0xE20209A1793E11F18FA70A2DEDA3276D (DB-39 seed·plan=pro·active·billing_key NULL·결제이력 0)
--
-- 채택 방식 = A(구독행 제거). resolver(`resolve_plan_from_row`) 정본 "row 없음 → basic".
--   → GET /subscription effective_plan=basic·AI 게이팅 잠금.
-- 안전: WHERE 에 grandfather 시그니처(plan=pro·status=active·billing_key/customer_key NULL) 명시 → 정확히 1행.
--   나머지 7개 학원(★용인대천일태권도장 실운영 포함) 무접촉.
-- 백업: backups/20260707-db40-predelete-subscriptions.sql (mysqldump) + RDS 스냅샷 winielab-dev-db-rds-db40-predelete-20260707.

-- migrate:up (수동 실행·prod 데이터)
DELETE FROM academy_subscriptions
 WHERE academy_id = UNHEX('01A90CA2664211F18FA70A2DEDA3276D')
   AND plan = 'pro'
   AND status = 'active'
   AND toss_billing_key IS NULL
   AND toss_customer_key IS NULL;
-- 기대 영향 행수: 1

-- migrate:down (롤백 — 제거한 grandfather 행 재삽입·원본 값 그대로 복원)
-- INSERT INTO academy_subscriptions
--   (id, academy_id, plan, status, current_period_start, current_period_end,
--    next_billing_date, price_amount, toss_billing_key, toss_customer_key,
--    is_deleted, created_at, updated_at)
-- VALUES
--   (UNHEX('E20209A1793E11F18FA70A2DEDA3276D'),
--    UNHEX('01A90CA2664211F18FA70A2DEDA3276D'),
--    'pro', 'active', '2026-07-06 13:30:41', '2026-10-06 13:30:41',
--    NULL, 20000, NULL, NULL,
--    0, '2026-07-06 13:30:41', '2026-07-06 13:30:41');
-- (또는 backups/20260707-db40-predelete-subscriptions.sql / RDS 스냅샷 복원)
