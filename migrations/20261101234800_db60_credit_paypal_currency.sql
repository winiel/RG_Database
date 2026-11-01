-- migrate:up
-- DB60-CREDIT-PAYPAL-CURRENCY — 크레딧 충전 페이팔(USD) 연동용 통화·외화 금액 컬럼 추가
--
-- 설계 정본: Document/RG_Common/credit-paypal/01-paypal-integration-design.md §4. 소비 = BE-101 → DIR-148.
--
-- 설계 요지:
--   - additive. 기존 amount·canceled_amount 와 금액 CHECK 는 무변경 — USD 주문에서도 KRW 기준값으로
--     크레딧 산정·환불 판정에 쓴다(amount = credits × 100). 실제 결제·취소 외화는 paid_* 컬럼에만 기록.
--   - KRW 행 = currency 'KRW' + paid_amount NULL + paid_canceled_amount 0. 기존 행은 DEFAULT 로 이 상태가 되어 CHECK 를 통과.
--   - USD 행 = paid_amount 필수(> 0)·0 ≤ paid_canceled_amount ≤ paid_amount.
--   - credit_refunds 도 동일 규칙: KRW = paid_refund_amount NULL / USD = paid_refund_amount 필수(> 0).
--     refund_amount 등 KRW 컬럼은 USD 환불에서도 기준값으로 유지.
--   - 주문·환불 간 통화 일치는 행 간 규칙이라 앱(BE-101) 보장(FK 미사용 정책).
--
-- 영향: 컬럼 5개·CHECK 4개 추가. 기존 행 값 변경 0. 인덱스 무변경.
-- 주의: ALTER 2문은 테이블별로 순차 적용된다. up 이 둘째 ALTER 에서 실패하면 첫째 테이블만 변경된 채 남으므로
--       재실행 전 credit_charge_orders 컬럼 상태를 확인할 것.
-- 롤백(down): ★첫 문장 = 사전 가드 — USD 주문·환불이 1건이라도 있으면 서브쿼리가 2행 이상이 되어
--             ERROR 1242 로 즉시 중단 → ALTER 미실행(외화 금액 보존·dbmate 기록 유지 = 안전 실패). DB-55·DB-57 패턴 동일.

ALTER TABLE `credit_charge_orders`
  ADD COLUMN `currency` varchar(3) NOT NULL DEFAULT 'KRW' COMMENT '결제 통화 KRW | USD. amount 는 통화와 무관하게 KRW 기준값' AFTER `canceled_amount`,
  ADD COLUMN `paid_amount` decimal(10,2) DEFAULT NULL COMMENT '실제 결제 외화 금액(서버 고정가). KRW 주문은 NULL' AFTER `currency`,
  ADD COLUMN `paid_canceled_amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT '누적 (부분)취소 외화 금액. KRW 주문은 0' AFTER `paid_amount`,
  ADD CONSTRAINT `chk_credit_charge_orders_currency` CHECK ((`currency` in ('KRW','USD'))),
  ADD CONSTRAINT `chk_credit_charge_orders_paid` CHECK (((`currency` = 'KRW') and (`paid_amount` is null) and (`paid_canceled_amount` = 0)) or ((`currency` = 'USD') and (`paid_amount` is not null) and (`paid_amount` > 0) and (`paid_canceled_amount` >= 0) and (`paid_canceled_amount` <= `paid_amount`)));

ALTER TABLE `credit_refunds`
  ADD COLUMN `currency` varchar(3) NOT NULL DEFAULT 'KRW' COMMENT '환불 통화 KRW | USD(원 주문 통화). refund_amount 는 통화와 무관하게 KRW 기준값' AFTER `refund_amount`,
  ADD COLUMN `paid_refund_amount` decimal(10,2) DEFAULT NULL COMMENT '실제 환불 외화 금액. KRW 환불은 NULL' AFTER `currency`,
  ADD CONSTRAINT `chk_credit_refunds_currency` CHECK ((`currency` in ('KRW','USD'))),
  ADD CONSTRAINT `chk_credit_refunds_paid` CHECK (((`currency` = 'KRW') and (`paid_refund_amount` is null)) or ((`currency` = 'USD') and (`paid_refund_amount` is not null) and (`paid_refund_amount` > 0)));

-- migrate:down

-- 사전 가드: USD 주문·환불 행이 있으면 ERROR 1242(Subquery returns more than 1 row)로 down 전체 중단.
DO (
  SELECT 1
  UNION ALL SELECT 1 FROM `credit_charge_orders` WHERE `currency` <> 'KRW'
  UNION ALL SELECT 1 FROM `credit_refunds` WHERE `currency` <> 'KRW'
);

ALTER TABLE `credit_refunds`
  DROP CHECK `chk_credit_refunds_paid`,
  DROP CHECK `chk_credit_refunds_currency`,
  DROP COLUMN `paid_refund_amount`,
  DROP COLUMN `currency`;

ALTER TABLE `credit_charge_orders`
  DROP CHECK `chk_credit_charge_orders_paid`,
  DROP CHECK `chk_credit_charge_orders_currency`,
  DROP COLUMN `paid_canceled_amount`,
  DROP COLUMN `paid_amount`,
  DROP COLUMN `currency`;
