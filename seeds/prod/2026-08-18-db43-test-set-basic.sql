-- DB-43 test@winielab.com 학원(서유기학원) basic 전환 (prod RDS 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-08-18 "test@winielab.com 구독 플랜을 basic으로 변경" + "production 환경에서 변경")
-- 선례: DB-40 (seeds/prod/2026-07-07-db40-test2-set-basic.sql) — 테스트2 학원 동일 전환
--
-- 대상(단일): academy = 서유기학원 (owner test@winielab.com / user_accounts.tenant_id)
--   academy_id      = 0x11F159AE2F2010788FA70A2DEDA3276D
--   subscription_id = 0xE20208CD793E11F18FA70A2DEDA3276D (DB-39 grandfather seed·plan=pro·active·billing_key NULL)
--
-- 적용 전 실측(prod): plan=pro·status=active·toss_billing_key/customer_key NULL·next_billing_date NULL·
--   price_amount=20000·기간 2026-07-06~2026-10-06·subscription_cards 0장·subscription_payments 0건
--   → DB-40(test_2) 과 동일한 grandfather 시그니처. 실결제·카드 자산 없음 = 제거 부작용 없음.
--
-- 채택 방식 = A(구독행 제거). resolver(`resolve_plan_from_row`) 정본 "row 없음 → basic".
--   → GET /subscription effective_plan=basic·AI 비서 게이팅 잠금.
-- 안전: WHERE 에 grandfather 시그니처(plan=pro·status=active·billing_key/customer_key NULL) 명시 → 정확히 1행.
--   나머지 학원(★용인대천일태권도장 실운영·베테랑스에듀) 무접촉 — 적용 후 updated_at 무변동 확인.
-- 백업: backups/20260818-db43-predelete-subscriptions.sql (mysqldump)
--       + RDS 스냅샷 winielab-dev-db-rds-db43-predelete-20260818

-- migrate:up (수동 실행·prod 데이터·2026-08-18 적용완료·affected=1)
DELETE FROM academy_subscriptions
 WHERE academy_id = UNHEX('11F159AE2F2010788FA70A2DEDA3276D')
   AND plan = 'pro'
   AND status = 'active'
   AND toss_billing_key IS NULL
   AND toss_customer_key IS NULL;
-- 기대 영향 행수: 1 (실측 1)

-- migrate:down (롤백 — 제거한 grandfather 행 재삽입·원본 값 그대로 복원)
-- INSERT INTO academy_subscriptions
--   (id, academy_id, plan, status, current_period_start, current_period_end,
--    next_billing_date, price_amount, toss_billing_key, toss_customer_key,
--    cancel_at_period_end, canceled_at, is_deleted, created_at, updated_at)
-- VALUES
--   (UNHEX('E20208CD793E11F18FA70A2DEDA3276D'),
--    UNHEX('11F159AE2F2010788FA70A2DEDA3276D'),
--    'pro', 'active', '2026-07-06 13:30:41', '2026-10-06 13:30:41',
--    NULL, 20000, NULL, NULL,
--    0, NULL, 0, '2026-07-06 13:30:41', '2026-07-06 13:30:41');
-- (또는 backups/20260818-db43-predelete-subscriptions.sql / RDS 스냅샷 복원)
