-- DB-50 서유기학원(test@winielab.com) 구독 Basic → Pro(active) 전환 (prod RDS 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-09-16 "실 서버에서 서유기학원의 플랜을 pro 버전으로 변경")
-- 적용: 2026-10-14 17:22 KST (발의 후 약 4주 경과 → 적용 전 실측 재확인)
--
-- 대상(단일): academy_id = 0x11F159AE2F2010788FA70A2DEDA3276D
--   academy_subscriptions.id = 0x01A01483DA1779928D823CAF71DF5C0D
--
-- 발의서와 실측 차이(2026-10-14 실측·적용 판단에 영향 없음 — 매칭 가드 plan=basic·status=canceled 는 그대로 1행):
--   · 2026-08-24 앱 경로 재구독·샌드박스 첫결제 20,000 → 6초 뒤 취소·전액 환불(canceled_amount=20000)
--     → canceled_at=2026-08-24 00:00:08 · 기간 08-24~09-24 · next_billing_date=2026-09-24 (발의서 09-18 아님)
--   · subscription_payments 4건(발의서 0건): 위 1건(canceled) + 앱 Pro 시작 시도 실패 3건
--     (09-16 15:58 ×2 '빌링키 인증 미완료' / 10-14 17:10 NOT_FOUND_MERCHANT) — 샌드박스 빌링키 × 라이브 키 거절·금전 이동 0
--
-- ★next_billing_date = NULL 필수 — 크론 selectDueSubscriptions 의 유일 잔존 가드(빌링키 보유 상태)
--   NULL 이 아니면 샌드박스 빌링키로 라이브 청구 시도 → 실패 → 재시도 소진 → basic 자동 강등.
-- 무변경: toss_billing_key/customer_key(값 기재 금지)·subscription_cards 1장·subscription_payments 4건·price_amount
--
-- 백업: backups/20261014-db50-db51-pre-5tables.sql (mysqldump·5테이블)
--       + RDS 스냅샷 winielab-dev-db-rds-db50-db51-pre-20261014 (생성 개시 08:21:48 UTC = UPDATE 이전)

-- migrate:up (수동 실행·prod 데이터·2026-10-14 적용완료·dry-run=1·ROW_COUNT=1)
UPDATE academy_subscriptions
   SET plan = 'pro',
       status = 'active',
       canceled_at = NULL,
       cancel_at_period_end = 0,
       current_period_start = NOW() + INTERVAL 9 HOUR,   -- KST 벽시계 naive 규약
       current_period_end   = '2026-12-31 23:59:59',     -- DB-44 grandfather 연장선 정렬
       next_billing_date    = NULL,                      -- ★크론 영구 미선정
       updated_at           = NOW() + INTERVAL 9 HOUR
 WHERE academy_id = UNHEX('11F159AE2F2010788FA70A2DEDA3276D')
   AND is_deleted = 0
   AND plan = 'basic' AND status = 'canceled';
-- 기대 영향 행수: 1 (실측 1)

-- migrate:down (롤백 — 전환 직전 실측값 복원)
-- UPDATE academy_subscriptions
--    SET plan = 'basic',
--        status = 'canceled',
--        canceled_at = '2026-08-24 00:00:08',
--        cancel_at_period_end = 0,
--        current_period_start = '2026-08-24 00:00:02',
--        current_period_end = '2026-09-24 00:00:00',
--        next_billing_date = '2026-09-24',
--        updated_at = NOW() + INTERVAL 9 HOUR
--  WHERE academy_id = UNHEX('11F159AE2F2010788FA70A2DEDA3276D')
--    AND is_deleted = 0;
-- (또는 backups/20261014-db50-db51-pre-5tables.sql / RDS 스냅샷 복원)
