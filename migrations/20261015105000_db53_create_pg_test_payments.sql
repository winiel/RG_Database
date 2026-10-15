-- migrate:up
-- DB53-PG-TEST-PAYMENTS — PG 단건 테스트 결제 기록 테이블 신설 (test3 전용 1,000원 위젯 단건결제)
--
-- 발의: request/RG_Database/2026-10-15-db53-pg-test-payments-table-order.md
-- 근거: 위니엘님 지시(2026-10-15) — 라이브 토스 PG 실결제 동작 확인용 단건 상품(결제위젯·카드 등록 아님).
--       소비(주문 생성·confirm 기록)는 BE-90(본 DDL 후). 트랙 DB-53 → BE-90 → DIR-138 (BE-89 rev3 대체).
-- ★도메인 분리(DB-38 원칙): 학생 청구(payments·billing_schedules)·구독(academy_subscriptions·subscription_payments)
--   어느 쪽과도 무관. 이 결제로 구독 상태/AI 게이팅 영향 0.
--
-- 설계 요지(RG_Database 컨벤션 우선):
--   - id BINARY(16) PK = UUID v7(앱 생성).
--   - order_id UNIQUE = 서버 생성 토스 orderId('pgtest-'+hex32)·★멱등 confirm 기준.
--   - status = VARCHAR + CHECK IN(...)(컨벤션·native ENUM 미사용). 값 = BE-90 API 계약 선회신 그대로
--     READY(주문 생성) | DONE(승인) | FAILED(승인 실패). 환불은 범위 외라 상태 없음.
--   - ★물리 FK 없음 — 전체 스키마 FOREIGN KEY 0건(현행 컨벤션). academy_id·user_id 정합은 앱(BE-90).
--     논리 참조 = academies.id·user_accounts.id.
--   - failure_code/failure_message = 토스 에러 원문(NOT_FOUND_MERCHANT 등 계약 범위 판단 근거).
--   - raw_response JSON = 토스 응답 원본(json_valid CHECK·subscription_payments 선례).
--   - 인덱스 = academy_id(학원별 조회·테넌트 격리)·status. 삭제 컬럼 없음(이력 보존).
--
-- 영향: 신규 테이블 추가만(additive). 기존 테이블 ALTER 0·데이터 0행. 트리거/SP 없음. 롤백 = DROP TABLE.

CREATE TABLE `pg_test_payments` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (논리 참조·테넌트 격리)',
  `user_id` binary(16) NOT NULL COMMENT 'user_accounts.id (논리 참조·결제 사용자)',
  `order_id` varchar(64) NOT NULL COMMENT '토스 orderId(서버 생성·멱등 키)',
  `order_name` varchar(100) NOT NULL COMMENT '상품명(예: PG 결제 테스트 상품)',
  `amount` int NOT NULL COMMENT '결제 금액(KRW·서버 고정값)',
  `status` varchar(16) NOT NULL DEFAULT 'READY' COMMENT 'READY | DONE | FAILED',
  `payment_key` varchar(255) DEFAULT NULL COMMENT '토스 paymentKey(confirm 요청 시)',
  `method` varchar(32) DEFAULT NULL COMMENT '결제수단(토스 method·예: 카드)',
  `approved_at` datetime DEFAULT NULL COMMENT '승인 시각',
  `failure_code` varchar(64) DEFAULT NULL COMMENT '실패 코드(토스 원문)',
  `failure_message` varchar(500) DEFAULT NULL COMMENT '실패 메시지(토스 원문)',
  `raw_response` json DEFAULT NULL COMMENT '토스 응답 원본(감사/디버깅)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pg_test_payments_order` (`order_id`),
  KEY `idx_pg_test_payments_academy` (`academy_id`),
  KEY `idx_pg_test_payments_status` (`status`),
  CONSTRAINT `chk_pg_test_payments_status` CHECK ((`status` in ('READY','DONE','FAILED'))),
  CONSTRAINT `chk_pg_test_payments_amount` CHECK ((`amount` > 0)),
  CONSTRAINT `chk_pg_test_payments_raw` CHECK (((`raw_response` is null) or json_valid(`raw_response`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='PG 단건 테스트 결제 기록(test3 전용·라이브 토스 결제위젯 검증) — order_id UNIQUE 멱등. 구독·학생청구와 별개 도메인';

-- migrate:down

DROP TABLE `pg_test_payments`;
