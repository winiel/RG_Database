-- migrate:up
-- DB57-CREDIT-CHARGE-1000 — 충전 상품 v3 대응 package CHECK 확장 (DB-55 후속)
--
-- 근거: 위니엘님 결정(2026-10-28) — 충전 상품 15,000원(credit_150)·30,000원(credit_300)·100,000원(credit_1000) 재구성.
--       토스 포인트충전 업종 보완 요구 "1회 충전 10만원 한도" 대응. 소비 = BE-98(신규 코드 credit_1000, credits=1000, amount=100000).
--
-- 설계 요지:
--   - CHECK 를 넓히기만 함(additive). credit_3300 은 판매 중단이지만 ★CHECK 에서 제거하지 않음(이력 보호).
--     구 코드 credit_100·credit_500 도 계속 유지.
--   - package_code CHECK 는 credit_charge_orders 에만 존재(credit_lots·credit_ledger·credit_refunds 에는 package 컬럼 없음 — DB-54 확인).
--   - DROP CHECK + ADD CONSTRAINT + MODIFY(COMMENT) 를 ALTER 1문으로 묶음 → 단일 테이블 원자 적용.
--   - amount = credits × 100 CHECK 는 credit_1000 에서도 성립(100,000원 = 1,000C × 100) → 무변경.
--
-- 영향: CHECK 정의·COMMENT 만 변경. 데이터 변경 0·컬럼 타입 무변경.
-- 롤백(down): DB-55 상태 복원. ★첫 문장 = 사전 가드 — credit_1000 행이 1건이라도 있으면 서브쿼리가 2행 이상이 되어
--             ERROR 1242 로 즉시 중단 → ALTER 미실행(데이터·v3 CHECK 그대로·dbmate 기록 유지 = 안전 실패). DB-55 패턴 동일.

ALTER TABLE `credit_charge_orders`
  DROP CHECK `chk_credit_charge_orders_package`,
  ADD CONSTRAINT `chk_credit_charge_orders_package` CHECK ((`package_code` in ('credit_100','credit_300','credit_500','credit_150','credit_3300','credit_1000'))),
  MODIFY `package_code` varchar(32) NOT NULL COMMENT 'v3: credit_150 | credit_300 | credit_1000 판매 (credit_3300 | credit_100 | credit_500 이력)';

-- migrate:down

-- 사전 가드: v3 전용 값(credit_1000) 행이 있으면 ERROR 1242(Subquery returns more than 1 row)로 down 전체 중단.
DO (
  SELECT 1
  UNION ALL SELECT 1 FROM `credit_charge_orders` WHERE `package_code` = 'credit_1000'
);

ALTER TABLE `credit_charge_orders`
  DROP CHECK `chk_credit_charge_orders_package`,
  ADD CONSTRAINT `chk_credit_charge_orders_package` CHECK ((`package_code` in ('credit_100','credit_300','credit_500','credit_150','credit_3300'))),
  MODIFY `package_code` varchar(32) NOT NULL COMMENT 'v2: credit_150 | credit_300 | credit_3300 (구 credit_100 | credit_500 유지)';
