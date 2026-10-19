-- migrate:up
-- DB55-CREDIT-PASS-CATALOG-V2 — 상품 구성 v2 대응 CHECK 3종 확장 (DB-54 후속)
--
-- 발의: request/RG_Database/2026-10-19-db55-credit-pass-catalog-v2-check-order.md
-- 근거: 위니엘님 지시(2026-10-19 상품 구성 v2) — 충전 credit_150(150C)·credit_300(300C)·credit_3300(3,300C) /
--       이용권 ai_pass_7·ai_pass_15·ai_pass_30·신규 ai_pass_365(365일). 소비는 BE-96(본 DDL 후).
--
-- 설계 요지:
--   - CHECK 를 넓히기만 함(additive). ★구 코드 credit_100·credit_500 유지 — 이미 생성된 READY 주문 행 보호.
--   - DB-54 파일 무수정. 제약 이름은 그대로 두고 정의만 교체.
--   - 각 테이블 DROP CHECK + ADD CONSTRAINT + MODIFY(COMMENT) 를 ALTER 1문으로 묶음 → 테이블 단위 원자 적용.
--   - credit_lots.expires_at COMMENT 도 유효기간 1년(BE-94) 기준으로 정정(동작 영향 0).
--   - amount = credits × 100 CHECK 는 v2 에서도 성립(15,000원=150C·330,000원=3,300C) → 무변경.
--
-- 영향: CHECK 정의·COMMENT 만 변경. 데이터 변경 0·컬럼 타입 무변경.
-- 롤백(down): 구 CHECK 복원. ★첫 문장 = 사전 가드 — v2 코드 행(credit_150·credit_3300·ai_pass_365·days 365)이
--             1건이라도 있으면 서브쿼리가 2행 이상이 되어 ERROR 1242 로 즉시 중단 → 어떤 ALTER 도 실행 안 됨
--             (데이터·v2 CHECK 그대로·dbmate 기록 유지 = 안전 실패). 가드 없이 ALTER 만 두면 테이블별로
--             부분 롤백되는 것을 로컬 실측으로 확인해 가드를 둠.

ALTER TABLE `credit_charge_orders`
  DROP CHECK `chk_credit_charge_orders_package`,
  ADD CONSTRAINT `chk_credit_charge_orders_package` CHECK ((`package_code` in ('credit_100','credit_300','credit_500','credit_150','credit_3300'))),
  MODIFY `package_code` varchar(32) NOT NULL COMMENT 'v2: credit_150 | credit_300 | credit_3300 (구 credit_100 | credit_500 유지)';

ALTER TABLE `ai_passes`
  DROP CHECK `chk_ai_passes_product`,
  DROP CHECK `chk_ai_passes_days`,
  ADD CONSTRAINT `chk_ai_passes_product` CHECK ((`product_code` in ('ai_pass_7','ai_pass_15','ai_pass_30','ai_pass_365'))),
  ADD CONSTRAINT `chk_ai_passes_days` CHECK ((`days` in (7,15,30,365))),
  MODIFY `product_code` varchar(32) NOT NULL COMMENT 'ai_pass_7 | ai_pass_15 | ai_pass_30 | ai_pass_365',
  MODIFY `days` int NOT NULL COMMENT '이용 일수(7 | 15 | 30 | 365)';

ALTER TABLE `credit_lots`
  MODIFY `expires_at` datetime NOT NULL COMMENT '만료 시각(충전 + 1년·BE-94)';

-- migrate:down

-- 사전 가드: v2 전용 값 행이 있으면 ERROR 1242(Subquery returns more than 1 row)로 down 전체 중단.
DO (
  SELECT 1
  UNION ALL SELECT 1 FROM `credit_charge_orders` WHERE `package_code` IN ('credit_150','credit_3300')
  UNION ALL SELECT 1 FROM `ai_passes` WHERE `product_code` = 'ai_pass_365' OR `days` = 365
);

ALTER TABLE `credit_lots`
  MODIFY `expires_at` datetime NOT NULL COMMENT '만료 시각(충전 + 5년)';

ALTER TABLE `ai_passes`
  DROP CHECK `chk_ai_passes_product`,
  DROP CHECK `chk_ai_passes_days`,
  ADD CONSTRAINT `chk_ai_passes_product` CHECK ((`product_code` in ('ai_pass_7','ai_pass_15','ai_pass_30'))),
  ADD CONSTRAINT `chk_ai_passes_days` CHECK ((`days` in (7,15,30))),
  MODIFY `product_code` varchar(32) NOT NULL COMMENT 'ai_pass_7 | ai_pass_15 | ai_pass_30',
  MODIFY `days` int NOT NULL COMMENT '이용 일수(7 | 15 | 30)';

ALTER TABLE `credit_charge_orders`
  DROP CHECK `chk_credit_charge_orders_package`,
  ADD CONSTRAINT `chk_credit_charge_orders_package` CHECK ((`package_code` in ('credit_100','credit_300','credit_500'))),
  MODIFY `package_code` varchar(32) NOT NULL COMMENT 'credit_100 | credit_300 | credit_500';
