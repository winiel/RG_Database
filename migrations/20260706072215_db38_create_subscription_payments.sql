-- migrate:up
-- DB38-SUBSCRIPTION-PAYMENTS (DB-38 ②) — RGuardians→학원 서비스 구독 결제 이력 테이블 신설
--
-- 발의: request/RG_Database/2026-07-06-db38-rg-subscription-toss-billing-schema-request.md
-- 근거: 위니엘님 지시 — 토스 빌링(정기결제) 결제 건별 이력 보존. academy_subscriptions(①) 짝.
--       소비(빌링 승인·웹훅 기록)는 BE-76(본 DDL 후).
-- cross-ref: academy_subscriptions(①·구독 상태). ★도메인 분리 = 학생 청구(payments·billing_schedules) 무관.
--
-- 설계 요지(RG_Database 컨벤션 우선):
--   - id BINARY(16) PK = UUID v7(앱 생성).
--   - toss_order_id UNIQUE = 토스 orderId·★멱등 키(웹훅/재시도 중복 결제 방지). 인덱스=UNIQUE.
--   - status/billing_type = VARCHAR + CHECK IN(...)(컨벤션·native ENUM 미사용).
--     billing_type = first(최초 결제·카드 등록 직후·7일 전액환불 창 대상) | recurring(정기 결제·환불 불가)
--       | upgrade(요금제 업그레이드 상위 전액 신규 결제·즉시 전환·정책확정 3d84981 §E). ★'upgrade' 추가=파트 판단.
--   - ★물리 FK 없음 — 전체 스키마 FOREIGN KEY 0건(현행 컨벤션·앱 레벨 무결성). academy_id·subscription_id
--     정합은 앱(BE-76). 논리 참조 = academies.id·academy_subscriptions.id.
--   - raw_response JSON = 토스 응답 원본 보존(감사·디버깅·students.parent 등 JSON 컬럼 선례 정합·json_valid CHECK).
--   - canceled_amount/canceled_at/cancel_reason = 환불 추적(취소/환불 정책 SSOT §D·업그레이드 §E). canceled_amount=
--     ★부분취소(<amount·업그레이드 하위 잔여 일할)·전액취소(=amount·첫결제 7일 이내) 겸용. partial_canceled status 불요
--     (canceled+canceled_amount<amount 로 부분 구분). status ENUM 확장 안 함.
--   - ★이력 보존(append-only) — 삭제하지 않음(is_deleted 불요). 인덱스 = academy_id(학원별 이력)·status(상태 필터).
--
-- 영향: 신규 테이블 추가만(additive). 기존 쿼리 무영향(BE-76 라이브 전 미소비·적용 직후 0행).
--       트리거/SP 없음. 롤백 가능(down = DROP TABLE). ①(academy_subscriptions) 선행 생성·본 파일 후행.

CREATE TABLE `subscription_payments` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조)',
  `subscription_id` binary(16) NOT NULL COMMENT 'academy_subscriptions.id (논리 참조)',
  `toss_payment_key` varchar(255) DEFAULT NULL COMMENT '토스 paymentKey',
  `toss_order_id` varchar(64) NOT NULL COMMENT '토스 orderId(멱등 키)',
  `amount` int NOT NULL COMMENT '결제 금액(KRW)',
  `status` varchar(16) NOT NULL DEFAULT 'pending' COMMENT 'pending | done | failed | canceled',
  `billing_type` varchar(16) NOT NULL COMMENT 'first(최초 결제) | recurring(정기 결제)',
  `requested_at` datetime DEFAULT NULL COMMENT '결제 요청 시각',
  `approved_at` datetime DEFAULT NULL COMMENT '결제 승인 시각',
  `receipt_url` varchar(500) DEFAULT NULL COMMENT '토스 영수증 URL',
  `failure_code` varchar(64) DEFAULT NULL COMMENT '실패 코드(토스)',
  `failure_reason` varchar(255) DEFAULT NULL COMMENT '실패 사유(토스)',
  `raw_response` json DEFAULT NULL COMMENT '토스 응답 원본(감사/디버깅)',
  `canceled_amount` int NOT NULL DEFAULT '0' COMMENT '누적 취소(환불) 금액 — 토스 부분취소(cancelAmount). 부분(<amount·업그레이드 일할)·전액(=amount·7일 이내) 겸용',
  `canceled_at` datetime DEFAULT NULL COMMENT '마지막 취소(환불) 시각',
  `cancel_reason` varchar(255) DEFAULT NULL COMMENT '취소 사유(예: 첫 결제 7일 이내 전액 환불 / 업그레이드 하위 잔여 일할 환불)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_subscription_payments_order` (`toss_order_id`),
  KEY `idx_subscription_payments_academy` (`academy_id`),
  KEY `idx_subscription_payments_status` (`status`),
  CONSTRAINT `chk_subscription_payments_status` CHECK ((`status` in ('pending','done','failed','canceled'))),
  CONSTRAINT `chk_subscription_payments_type` CHECK ((`billing_type` in ('first','recurring','upgrade'))),
  CONSTRAINT `chk_subscription_payments_raw` CHECK (((`raw_response` is null) or json_valid(`raw_response`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='RGuardians→학원 서비스 구독 결제 이력 — 토스 결제 건별·이력 보존(append-only). toss_order_id UNIQUE 멱등. 학생 청구(payments)와 별개 도메인';

-- migrate:down

DROP TABLE `subscription_payments`;
