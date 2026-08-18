-- DB-45 test@winielab.com 학원(서유기학원) 즉시 해지 상태 전환 = Basic (prod RDS 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-08-18 "production 환경의 test@winielab.com의 구독 플랜을 basic으로 변경")
-- 경위: DB-43(구독행 제거·19:52) 이후 19:56 신규 구독·실결제 발생 → 19:57 취소했으나
--       FE 결함(DIR-134 "즉시전환 미동작")으로 **기간말 해지**(plan=pro·status=canceled·기간말 09-18)
--       상태에 머물러 Pro 가 유지되고 있었음 → 본 건으로 Basic 확정.
--
-- 대상(단일): academy = 서유기학원 academy_id = 0x11F159AE2F2010788FA70A2DEDA3276D
--   subscription_id = 0x01A01483DA1779928D823CAF71DF5C0D (2026-08-18 19:56 신규 구독행)
--
-- ★채택 방식 = **앱 네이티브 즉시해지 상태 복제** (DB-43 의 행 삭제 방식과 다름)
--   근거 SQL 정본 = RG_Backend `repositories/sql/academy_subscriptions.sql` : cancelImmediate
--     (plan='basic' · status='canceled' · canceled_at=now · WHERE is_deleted=0)
--   → resolver(`resolve_plan_from_row`) 는 plan<>'pro' 이면 즉시 basic 반환 = AI 게이팅 잠금.
--   → DIR-134 FE 수정 배포 후 사용자가 정상 취소했을 때 만들어질 상태와 **동일**(드리프트 0).
--   ※ 행 삭제(DB-43 방식)를 쓰지 않은 이유 = 이번 건은 실결제 1건·카드 1장·빌링키가 딸려 있어
--     구독행 제거 시 결제이력과의 연결 맥락이 끊긴다. 자산 보존이 가능한 방식을 택함.
--
-- 무변경(의도):
--   · subscription_cards 1장 — 앱 즉시해지도 카드를 삭제하지 않음. 보존.
--   · subscription_payments 1건(first/done/20,000원) — **환불 기록을 DB 로 조작하지 않음**.
--     실제 환불은 토스 결제취소 API 호출로만 성립(BE-84 트랙·미구현 발의 상태).
--     canceled_amount/canceled_at 을 임의 기입하면 "환불했다"는 허위 상태가 되므로 손대지 않는다.
--   · next_billing_date = 2026-09-18 잔존 — 앱 cancelImmediate 도 이 값을 지우지 않음(정본 일치).
--     과금 크론은 `status IN(active|trialing|past_due) AND plan='pro'` 조건이라 **이중 배제** → 과금 0.
--
-- 백업: backups/20260818-db45-precancel-subscription-3tables.sql (mysqldump·3테이블)
--       + RDS 스냅샷 winielab-dev-db-rds-db45-precancel-20260818

-- migrate:up (수동 실행·prod 데이터·2026-08-18 적용완료·affected=1)
UPDATE academy_subscriptions
   SET plan = 'basic',
       status = 'canceled',
       canceled_at = NOW() + INTERVAL 9 HOUR,   -- KST 벽시계 naive 저장 규약
       updated_at  = NOW() + INTERVAL 9 HOUR
 WHERE academy_id = UNHEX('11F159AE2F2010788FA70A2DEDA3276D')
   AND is_deleted = 0;
-- 기대 영향 행수: 1 (실측 1)

-- migrate:down (롤백 — 전환 직전 상태 복원: 기간말 해지 예약 Pro)
-- UPDATE academy_subscriptions
--    SET plan = 'pro',
--        status = 'canceled',
--        canceled_at = '2026-08-18 19:57:11',
--        updated_at = NOW() + INTERVAL 9 HOUR
--  WHERE academy_id = UNHEX('11F159AE2F2010788FA70A2DEDA3276D')
--    AND is_deleted = 0;
-- (또는 backups/20260818-db45-precancel-subscription-3tables.sql / RDS 스냅샷 복원)
