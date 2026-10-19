-- migrate:up
-- DB54-CREDIT-AI-PASS — 크레딧 충전 + AI 비서 이용권 테이블 6종 신설
--
-- 발의: request/RG_Database/2026-10-19-db54-credit-and-ai-pass-tables-order.md
-- 설계 정본: Document/RG_Common/credit-ai-pass/01-credit-ai-pass-design.md (§1 P-1~P-11 · §2 데이터 모델)
-- 근거: 위니엘님 지시(2026-10-19) — 단건 = 크레딧 충전(카드 결제) · 크레딧으로 AI 비서 7/15/30일 이용권 구매.
--       소비(주문·confirm·FIFO 차감·환불·게이팅·만료 배치)는 BE-91(본 DDL 후). 트랙 DB-54 → BE-91 → DIR-139.
-- ★도메인 분리(DB-38·DB-53 원칙): 학생 청구(payments)·구독(academy_subscriptions·subscription_payments)·
--   PG 테스트(pg_test_payments)와 무관. 이용권은 plan 을 바꾸지 않음(구독 상태 영향 0).
--
-- 설계 요지(RG_Database 컨벤션 우선):
--   - id BINARY(16) PK = UUID v7(앱 생성). 상태값 = VARCHAR + CHECK IN(...)(native ENUM 미사용).
--   - ★물리 FK 없음 — 전체 스키마 FOREIGN KEY 0건(현행 컨벤션). 참조 정합은 앱(BE-91). 논리 참조는 컬럼 COMMENT 표기.
--   - 테넌트 격리 — 학원 소유 테이블은 academy_id(academies.id) 보유·학원 단위 인덱스 선두.
--   - 금전 불변식은 DB CHECK 로 가능한 만큼 강제:
--       amount = credits × 100(P-1) · 0 ≤ credits_remaining ≤ credits_total · 0 ≤ canceled_amount ≤ amount ·
--       refund_amount = gross_amount − fee_amount · balance_after ≥ 0 · delta ≠ 0.
--     lot 잔액 합 = 원장 합(행 간 불변식)은 BE-91 트랜잭션 보장(학원 단위 직렬화).
--   - 멱등/중복 방지:
--       credit_charge_orders.order_id UNIQUE(confirm 멱등) · credit_lots.charge_order_id UNIQUE(주문당 lot 1개 = lot 중복 0) ·
--       credit_refunds 활성 환불 토큰 UNIQUE(lot 당 REQUESTED/DONE 1건 — FAILED 만 재시도 허용, VIRTUAL NULL-token 선례) ·
--       ai_pass_credit_allocations (pass_id, lot_id) UNIQUE.
--   - append-only 테이블(credit_ledger·ai_pass_credit_allocations)은 created_at 만(ai_assistant_audit_log 선례).
--   - datetime = KST naive(앱이 명시 기입). DB DEFAULT CURRENT_TIMESTAMP 는 RDS 세션 TZ(UTC) 이므로 앱이 값을 넘길 것.
--
-- 영향: 신규 테이블 추가만(additive). 기존 테이블 ALTER 0·데이터 0행. 트리거/SP 없음. 롤백 = DROP TABLE 6종.

-- ① 충전 결제 주문(토스 결제위젯 단건결제)
CREATE TABLE IF NOT EXISTS `credit_charge_orders` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조·테넌트 격리)',
  `user_id` binary(16) NOT NULL COMMENT 'user_accounts.id (논리 참조·결제 사용자)',
  `order_id` varchar(64) NOT NULL COMMENT '토스 orderId(서버 생성·멱등 confirm 키)',
  `package_code` varchar(32) NOT NULL COMMENT 'credit_100 | credit_300 | credit_500',
  `amount` int NOT NULL COMMENT '결제 금액(KRW·서버 고정값) = credits × 100',
  `credits` int NOT NULL COMMENT '충전 크레딧',
  `status` varchar(20) NOT NULL DEFAULT 'READY' COMMENT 'READY | DONE | FAILED | CANCELED | PARTIAL_CANCELED',
  `payment_key` varchar(255) DEFAULT NULL COMMENT '토스 paymentKey(confirm·부분취소 대상)',
  `method` varchar(32) DEFAULT NULL COMMENT '결제수단(토스 method)',
  `approved_at` datetime DEFAULT NULL COMMENT '승인 시각',
  `failure_code` varchar(64) DEFAULT NULL COMMENT '실패 코드(토스 원문)',
  `failure_message` varchar(500) DEFAULT NULL COMMENT '실패 메시지(토스 원문)',
  `raw_response` json DEFAULT NULL COMMENT '토스 응답 원본(감사/디버깅)',
  `canceled_amount` int NOT NULL DEFAULT '0' COMMENT '누적 (부분)취소 금액(KRW)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_credit_charge_orders_order` (`order_id`),
  KEY `idx_credit_charge_orders_academy_created` (`academy_id`, `created_at`),
  KEY `idx_credit_charge_orders_status` (`status`),
  CONSTRAINT `chk_credit_charge_orders_status` CHECK ((`status` in ('READY','DONE','FAILED','CANCELED','PARTIAL_CANCELED'))),
  CONSTRAINT `chk_credit_charge_orders_package` CHECK ((`package_code` in ('credit_100','credit_300','credit_500'))),
  CONSTRAINT `chk_credit_charge_orders_credits` CHECK ((`credits` > 0)),
  CONSTRAINT `chk_credit_charge_orders_amount` CHECK ((`amount` = `credits` * 100)),
  CONSTRAINT `chk_credit_charge_orders_canceled` CHECK (((`canceled_amount` >= 0) and (`canceled_amount` <= `amount`))),
  CONSTRAINT `chk_credit_charge_orders_raw` CHECK (((`raw_response` is null) or json_valid(`raw_response`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='크레딧 충전 결제 주문(토스 단건결제) — order_id UNIQUE 멱등. 1크레딧=100원. 구독·학생청구·PG 테스트와 별개 도메인';

-- ② 충전 건(잔액 단위) — FIFO 차감·lot 단위 환불·만료
CREATE TABLE IF NOT EXISTS `credit_lots` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조·테넌트 격리)',
  `charge_order_id` binary(16) DEFAULT NULL COMMENT 'credit_charge_orders.id (논리 참조·주문당 lot 1개). NULL = 결제 없는 lot(운영 보상 등)',
  `credits_total` int NOT NULL COMMENT '충전 크레딧',
  `credits_remaining` int NOT NULL COMMENT '잔여 크레딧(0 ≤ 잔여 ≤ 충전량)',
  `charged_at` datetime NOT NULL COMMENT '충전 시각(환불 7일 판정 기준)',
  `expires_at` datetime NOT NULL COMMENT '만료 시각(충전 + 5년)',
  `status` varchar(16) NOT NULL DEFAULT 'ACTIVE' COMMENT 'ACTIVE | EXHAUSTED | REFUNDED | EXPIRED',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_credit_lots_charge_order` (`charge_order_id`),
  KEY `idx_credit_lots_academy_expires` (`academy_id`, `expires_at`),
  KEY `idx_credit_lots_status_expires` (`status`, `expires_at`),
  CONSTRAINT `chk_credit_lots_status` CHECK ((`status` in ('ACTIVE','EXHAUSTED','REFUNDED','EXPIRED'))),
  CONSTRAINT `chk_credit_lots_total` CHECK ((`credits_total` > 0)),
  CONSTRAINT `chk_credit_lots_remaining` CHECK (((`credits_remaining` >= 0) and (`credits_remaining` <= `credits_total`))),
  CONSTRAINT `chk_credit_lots_expires` CHECK ((`expires_at` > `charged_at`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='크레딧 충전 건(잔액 단위) — 유효기간 먼저 끝나는 lot 부터 차감(FIFO)·lot 단위 환불·만료 소멸';

-- ③ 크레딧 증감 원장 — append-only
CREATE TABLE IF NOT EXISTS `credit_ledger` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조·테넌트 격리)',
  `lot_id` binary(16) NOT NULL COMMENT 'credit_lots.id (논리 참조·증감 대상 lot)',
  `delta` int NOT NULL COMMENT '증감 크레딧(±·0 불가)',
  `reason` varchar(24) NOT NULL COMMENT 'CHARGE | PASS_PURCHASE | PASS_CANCEL_RESTORE | REFUND | EXPIRE | COMPENSATION',
  `ref_type` varchar(32) DEFAULT NULL COMMENT '근거 행 종류(charge_order | ai_pass | refund 등)',
  `ref_id` binary(16) DEFAULT NULL COMMENT '근거 행 id',
  `balance_after` int NOT NULL COMMENT '반영 후 학원 전체 잔액',
  `actor_user_id` binary(16) DEFAULT NULL COMMENT 'user_accounts.id (수행자·배치=NULL)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_credit_ledger_academy_created` (`academy_id`, `created_at`),
  KEY `idx_credit_ledger_lot` (`lot_id`),
  KEY `idx_credit_ledger_ref` (`ref_type`, `ref_id`),
  CONSTRAINT `chk_credit_ledger_reason` CHECK ((`reason` in ('CHARGE','PASS_PURCHASE','PASS_CANCEL_RESTORE','REFUND','EXPIRE','COMPENSATION'))),
  CONSTRAINT `chk_credit_ledger_delta` CHECK ((`delta` <> 0)),
  CONSTRAINT `chk_credit_ledger_balance` CHECK ((`balance_after` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='크레딧 증감 원장(append-only·UPDATE/DELETE 금지) — lot 잔액 합 = 원장 합';

-- ④ 환불 실행 기록 — lot 단위·토스 부분취소
CREATE TABLE IF NOT EXISTS `credit_refunds` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조·테넌트 격리)',
  `lot_id` binary(16) NOT NULL COMMENT 'credit_lots.id (논리 참조·환불 대상 lot)',
  `credits` int NOT NULL COMMENT '환불 대상 크레딧(미사용분)',
  `gross_amount` int NOT NULL COMMENT '대상 금액(KRW) = credits × 100',
  `fee_amount` int NOT NULL COMMENT '공제액(KRW·7일 이내 0·경과 10% 최소 1,000)',
  `refund_amount` int NOT NULL COMMENT '환불액(KRW) = gross − fee',
  `toss_cancel_tx_key` varchar(255) DEFAULT NULL COMMENT '토스 부분취소 transactionKey',
  `status` varchar(16) NOT NULL DEFAULT 'REQUESTED' COMMENT 'REQUESTED | DONE | FAILED',
  `failure_code` varchar(64) DEFAULT NULL COMMENT '실패 코드(토스 원문)',
  `failure_message` varchar(500) DEFAULT NULL COMMENT '실패 메시지(토스 원문)',
  `raw_response` json DEFAULT NULL COMMENT '토스 응답 원본(감사/디버깅)',
  `requested_by` binary(16) NOT NULL COMMENT 'user_accounts.id (요청 사용자)',
  `active_lot_token` binary(16) GENERATED ALWAYS AS (if((`status` in ('REQUESTED','DONE')),`lot_id`,NULL)) VIRTUAL COMMENT 'lot 당 진행/완료 환불 1건 강제(FAILED=NULL 면제)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_credit_refunds_active_lot` (`active_lot_token`),
  KEY `idx_credit_refunds_academy_created` (`academy_id`, `created_at`),
  KEY `idx_credit_refunds_lot` (`lot_id`),
  CONSTRAINT `chk_credit_refunds_status` CHECK ((`status` in ('REQUESTED','DONE','FAILED'))),
  CONSTRAINT `chk_credit_refunds_credits` CHECK ((`credits` > 0)),
  CONSTRAINT `chk_credit_refunds_gross` CHECK ((`gross_amount` = `credits` * 100)),
  CONSTRAINT `chk_credit_refunds_amounts` CHECK (((`fee_amount` >= 0) and (`refund_amount` > 0) and (`refund_amount` = `gross_amount` - `fee_amount`))),
  CONSTRAINT `chk_credit_refunds_raw` CHECK (((`raw_response` is null) or json_valid(`raw_response`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='크레딧 환불 실행 기록(lot 단위·원 결제 부분취소) — lot 당 REQUESTED/DONE 1건(중복 환불 방지)';

-- ⑤ AI 비서 이용권
CREATE TABLE IF NOT EXISTS `ai_passes` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조·테넌트 격리)',
  `user_id` binary(16) NOT NULL COMMENT 'user_accounts.id (논리 참조·구매자)',
  `product_code` varchar(32) NOT NULL COMMENT 'ai_pass_7 | ai_pass_15 | ai_pass_30',
  `days` int NOT NULL COMMENT '이용 일수(7 | 15 | 30)',
  `credits_spent` int NOT NULL COMMENT '차감 크레딧(70 | 120 | 220)',
  `purchased_at` datetime NOT NULL COMMENT '구매 시각(취소 7일 판정 기준)',
  `starts_at` datetime NOT NULL COMMENT '개시 시각(기존 이용권 종료에 이어붙임)',
  `ends_at` datetime NOT NULL COMMENT '종료 시각',
  `status` varchar(16) NOT NULL DEFAULT 'ACTIVE' COMMENT 'SCHEDULED | ACTIVE | PAUSED | ENDED | CANCELED',
  `paused_remaining_seconds` int DEFAULT NULL COMMENT 'Pro 정지 시 남은 초(P-9)',
  `paused_at` datetime DEFAULT NULL COMMENT 'Pro 정지 시각(P-9)',
  `canceled_at` datetime DEFAULT NULL COMMENT '취소 시각(P-8)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ai_passes_academy_status_ends` (`academy_id`, `status`, `ends_at`),
  CONSTRAINT `chk_ai_passes_status` CHECK ((`status` in ('SCHEDULED','ACTIVE','PAUSED','ENDED','CANCELED'))),
  CONSTRAINT `chk_ai_passes_product` CHECK ((`product_code` in ('ai_pass_7','ai_pass_15','ai_pass_30'))),
  CONSTRAINT `chk_ai_passes_days` CHECK ((`days` in (7,15,30))),
  CONSTRAINT `chk_ai_passes_credits` CHECK ((`credits_spent` > 0)),
  CONSTRAINT `chk_ai_passes_period` CHECK ((`ends_at` > `starts_at`)),
  CONSTRAINT `chk_ai_passes_paused` CHECK (((`paused_remaining_seconds` is null) or (`paused_remaining_seconds` >= 0)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='AI 비서 이용권(크레딧 구매) — plan 무변경·AI 비서 권한만. Pro 중 정지/재개';

-- ⑥ 이용권 ↔ lot 차감 내역 — 취소 시 원 lot·원 유효기간 복원 근거(append-only)
CREATE TABLE IF NOT EXISTS `ai_pass_credit_allocations` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `pass_id` binary(16) NOT NULL COMMENT 'ai_passes.id (논리 참조)',
  `lot_id` binary(16) NOT NULL COMMENT 'credit_lots.id (논리 참조·차감된 lot)',
  `credits` int NOT NULL COMMENT '해당 lot 에서 차감한 크레딧',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ai_pass_credit_allocations_pass_lot` (`pass_id`, `lot_id`),
  KEY `idx_ai_pass_credit_allocations_lot` (`lot_id`),
  CONSTRAINT `chk_ai_pass_credit_allocations_credits` CHECK ((`credits` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='이용권 ↔ 충전 건(lot) 차감 내역(append-only) — 이용권 취소 시 원 lot 복원 근거';

-- migrate:down

DROP TABLE IF EXISTS `ai_pass_credit_allocations`;
DROP TABLE IF EXISTS `ai_passes`;
DROP TABLE IF EXISTS `credit_refunds`;
DROP TABLE IF EXISTS `credit_ledger`;
DROP TABLE IF EXISTS `credit_lots`;
DROP TABLE IF EXISTS `credit_charge_orders`;
