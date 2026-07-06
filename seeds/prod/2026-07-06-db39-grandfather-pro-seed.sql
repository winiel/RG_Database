-- DB-39 기존 학원 Pro 3개월 grandfather seed (prod RDS 데이터·1회성)
-- 오더: request/RG_Database/2026-07-06-db-prod-deploy-and-grandfather-pro-seed-order.md (위니엘님 배포 승인)
-- 전제: DB-38 스키마 prod 적용 완료(academy_subscriptions 존재).
--
-- 효과: prod 모든 기존 학원(academies)에 academy_subscriptions upsert →
--       plan='pro'·status='active'·기간 3개월·next_billing_date=NULL(자동결제 cron 미스캔=과금0·카드없는 Pro 안전).
-- 멱등: academy_id 에 이미 구독 행 있으면 스킵(UNIQUE 안전·재실행 안전).
-- reversible: down = 아래 DELETE(주석) 또는 basic 전환.
-- id: UUID(SQL 생성·standard order binary16)·앱 미개입 seed(row PK만·FK 앱레벨).
-- 날짜: current_period_start=NOW()(오늘)·current_period_end=+3MONTH(DATE_ADD 말일 클램프 native).
--
-- migrate:up (수동 실행·dbmate 미등록·prod 데이터 seed)
INSERT INTO academy_subscriptions
  (id, academy_id, plan, status, current_period_start, current_period_end,
   next_billing_date, price_amount, is_deleted, created_at, updated_at)
SELECT
  UNHEX(REPLACE(UUID(),'-','')), a.id, 'pro', 'active',
  NOW(), DATE_ADD(NOW(), INTERVAL 3 MONTH),
  NULL, 20000, 0, NOW(), NOW()
FROM academies a
WHERE NOT EXISTS (
  SELECT 1 FROM academy_subscriptions s WHERE s.academy_id = a.id
);

-- migrate:down (롤백 — seed 로 생성한 grandfather 행 삭제. billing_key/customer_key NULL 인 pro 활성만 대상)
-- DELETE FROM academy_subscriptions
--  WHERE plan='pro' AND status='active' AND toss_billing_key IS NULL AND toss_customer_key IS NULL;
