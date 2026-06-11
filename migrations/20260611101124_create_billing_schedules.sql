-- migrate:up
-- RECURRING-BILLING-SCHEMA (DB-5) — 정기 결제(매달 자동 청구) 생성용 청구 소스 테이블 신설
--
-- 발의: request/RG_Database/2026-06-11-recurring-billing-schema-request.md
-- 채택: 옵션 2(신규 billing_schedules) — payment 오염 분리·멱등 키 명확·다중 청구라인/구독 관리. parent BE-28-IMPL.
-- cross-ref: payments(결제 본체·decimal(12,2) amount·varchar(20) status 선례) · class_cancellations(DB-3 컨벤션)
--
-- 설계 요지:
--   - 청구 룰(정가·청구일)을 payment(할인·부분수금 반영)와 분리한 독립 소스.
--   - 멱등: last_generated_for_month(YYYY-MM-01) — 이번 달 이미 생성했는지 판별·중복청구 0·재실행 안전.
--   - anchor_day 1~31 허용 + 말일 클램프(생성 job 이 min(anchor_day, 해당월 일수)로 due_date 산정 — Backend 계약).
--   - 물리 FK 없음(현행 스키마 전체 앱 레벨 무결성). status varchar+CHECK(payments 선례).
--   - 영향: 신규 테이블 추가만 — 기존 데이터 영향 0(적용 직후 0행).

CREATE TABLE `billing_schedules` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `class_id` binary(16) DEFAULT NULL COMMENT '반 단위 청구 시 클래스. NULL=학생 단위 청구',
  `monthly_fee` decimal(12,2) NOT NULL COMMENT '월 청구액 (KRW 정수 권장·payments.amount 대응)',
  `anchor_day` tinyint NOT NULL COMMENT '매달 청구일 1~31. 말일 클램프: 해당월 일수보다 크면 말일 청구(Backend 계약)',
  `billing_item` varchar(255) NOT NULL COMMENT '청구 항목명 (payment.billing_item 대응)',
  `status` varchar(20) NOT NULL DEFAULT 'active' COMMENT '구독 상태: active/paused',
  `last_generated_for_month` date DEFAULT NULL COMMENT '멱등 키 — 마지막 생성 청구월(YYYY-MM-01)·중복청구 방지',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_billing_schedules_tenant_id_status_last_generated_for_month` (`tenant_id`,`status`,`last_generated_for_month`),
  KEY `idx_billing_schedules_tenant_id_student_id` (`tenant_id`,`student_id`),
  CONSTRAINT `chk_billing_schedules_monthly_fee` CHECK ((`monthly_fee` >= 0)),
  CONSTRAINT `chk_billing_schedules_anchor_day` CHECK ((`anchor_day` between 1 and 31)),
  CONSTRAINT `chk_billing_schedules_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='정기 결제(매달 자동 청구) 생성용 청구 소스 — 구독 단위 청구 룰+멱등 키 (BE daily_billing_generator 소비)';

-- migrate:down

DROP TABLE `billing_schedules`;
