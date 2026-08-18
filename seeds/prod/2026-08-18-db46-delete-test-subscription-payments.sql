-- DB-46 서유기학원(test@winielab.com) 구독 결제내역 삭제 (prod RDS 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-08-18 "결제내역을 삭제해주세요")
--
-- 대상: subscription_payments · academy_id = 0x11F159AE2F2010788FA70A2DEDA3276D (3행 전량)
--   ① 19:56:20 first/done   20,000원 tviva20260818195620K9k51  (환불 없음)
--   ② 20:39:56 first/done   20,000원 tviva20260818203956DSvW6  (환불 없음)
--   ③ 21:38:42 first/canceled 20,000원 tviva20260818213842DyB99 (21:38:48 환불 20,000 기록)
--   ※ 셋 다 2026-08-18 DIR-134 취소 e2e 검증 중 발생한 테스트 결제.
--
-- ★금전 영향 없음 근거 = raw_response.mId = "tvivarepublica2" (**토스 테스트 상점 MID**) 3건 전부 동일.
--   실 상점 MID(bill_rguar40wi·빌링 계약심사 진행 중)가 아니므로 실제 청구/정산 대상 아님.
--
-- ★물리 삭제인 이유 = subscription_payments 는 논리삭제 3컬럼(is_deleted/deleted_at/deleted_by)이
--   없는 유일한 구독 테이블(DB-38 신설 시 결제 원장=append-only 전제). 논리삭제 수단 부재 →
--   물리 DELETE 외 선택지 없음. (감사 원장에 소프트삭제를 추가하려면 별도 DDL 발의 필요.)
--
-- 무변경(의도): academy_subscriptions(서유기 plan=basic·canceled 유지)·subscription_cards 2행·
--   ★별개 도메인인 **학생 청구 `payments` 테이블(93행) 무접촉**(네이밍만 유사·구독과 무관).
--
-- 백업: backups/20260818-db46-predelete-payments-3tables.sql (mysqldump·3테이블·삭제 직전)
--       + RDS 스냅샷 winielab-dev-db-rds-db46-predelete-20260818
--   ※ 롤백은 위 덤프에서 subscription_payments INSERT 문 3건을 발췌 적용(toss_order_id UNIQUE 충돌 없음).

-- migrate:up (수동 실행·prod 데이터·2026-08-18 적용완료·affected=3)
DELETE FROM subscription_payments
 WHERE academy_id = UNHEX('11F159AE2F2010788FA70A2DEDA3276D');
-- 기대 영향 행수: 3 (실측 3) · 적용 후 subscription_payments 전체 잔여 0행

-- migrate:down (롤백 — 백업 덤프에서 해당 3행 재삽입)
-- backups/20260818-db46-predelete-payments-3tables.sql 의 `INSERT INTO subscription_payments` 참조
-- (또는 RDS 스냅샷 winielab-dev-db-rds-db46-predelete-20260818 복원)
