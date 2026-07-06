-- migrate:up
-- DB38-ACADEMY-SUBSCRIPTIONS (DB-38 ①) — RGuardians→학원(테넌트) 서비스 구독 상태 테이블 신설
--
-- 발의: request/RG_Database/2026-07-06-db38-rg-subscription-toss-billing-schema-request.md
-- 근거: 위니엘님 지시 — RGuardians 서비스 이용료를 토스페이먼츠 빌링(정기결제·billingKey)으로 연동.
--       요금제 2종 = basic(무료·AI 비서 없음) / pro(20,000원/월·AI 비서 포함). 차이는 AI 비서 가부뿐.
--       학원 Pro 구독 시 토스 빌링으로 매월 자동 청구. 소비(빌링 API·게이팅)는 BE-76(본 DDL 후).
-- cross-ref: academies(id=tenant_id) 구독 대상. ★도메인 분리 = 기존 payments·billing_schedules 는
--            '학원→학생 수강료'. 본 신규는 'RGuardians→학원 서비스료' — 접두 academy_/subscription_ 로 분리.
--
-- 설계 요지(RG_Database 컨벤션 우선):
--   - id BINARY(16) PK = UUID v7(앱 생성)·기존 테이블 패턴 정합.
--   - academy_id UNIQUE — academies.id(=tenant_id) 참조·★학원당 정확히 1행. basic 은 행 없음 or plan='basic'.
--   - plan/status = VARCHAR + CHECK IN(...) 채택 — 코드베이스 컨벤션(classes.status·student_custom_fields.field_type
--     동일 표현·native ENUM 미사용). MySQL ENUM 아님.
--   - ★물리 FK 없음 — 전체 스키마 FOREIGN KEY 0건(현행 컨벤션·앱 레벨 무결성·db34 명시). academy_id 정합은 앱(BE-76).
--   - toss_billing_key = ★민감(정기결제 자격증명)·BE 전용·API 응답/FE 노출 절대 금지·NULL 허용.
--   - next_billing_date = 정기결제 배치 조회 키(인덱스 부여). status 도 인덱스(구독 상태 필터).
--   - is_deleted/deleted_at/deleted_by = 논리삭제 정책(class_suspensions 3컬럼 패턴)·물리삭제 금지(결제 이력 보존).
--   - cancel_at_period_end = ★기간 말 전환 예약 플래그(취소/환불 정책 SSOT §D·정책확정 3d84981). Pro→basic 다운그레이드
--     (첫결제 7일 초과·정기갱신)은 즉시 전환이 아니라 current_period_end 시 basic 전환 — 배치가 이 플래그+
--     current_period_end 도달 건 조회해 전환. A안(BOOLEAN) 채택: TINYINT(1) 플래그가 컨벤션(is_deleted·
--     settings.auto_attendance_enabled) 정합·B안(canceled_effective_at DATETIME)은 current_period_end 와 중복이라 미채택.
--
-- 영향: 신규 테이블 추가만(additive). 기존 쿼리 무영향(BE-76 라이브 전 미소비·적용 직후 0행).
--       트리거/SP 없음. 롤백 가능(down = DROP TABLE). 기존 payments·billing_schedules 무접촉.

CREATE TABLE `academy_subscriptions` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (=tenant_id)·학원당 1행',
  `plan` varchar(16) NOT NULL DEFAULT 'basic' COMMENT 'basic(무료·AI 없음) | pro(20000/월·AI 포함)',
  `status` varchar(16) NOT NULL DEFAULT 'active' COMMENT 'active | trialing | canceled | past_due',
  `toss_billing_key` varchar(255) DEFAULT NULL COMMENT '★민감 — 토스 빌링키(정기결제). BE 전용·응답 노출 금지',
  `toss_customer_key` varchar(255) DEFAULT NULL COMMENT '토스 customerKey',
  `card_company` varchar(40) DEFAULT NULL COMMENT '카드사(표시용)',
  `card_number_masked` varchar(32) DEFAULT NULL COMMENT '마스킹 카드번호(표시용)',
  `trial_end_at` datetime DEFAULT NULL COMMENT '무료체험 종료 시각',
  `current_period_start` datetime DEFAULT NULL COMMENT '현재 구독 주기 시작',
  `current_period_end` datetime DEFAULT NULL COMMENT '현재 구독 주기 종료',
  `next_billing_date` date DEFAULT NULL COMMENT '다음 정기결제 청구일(배치 조회 키)',
  `price_amount` int NOT NULL DEFAULT '20000' COMMENT '월 구독료(KRW·Pro=20000)',
  `cancel_at_period_end` tinyint(1) NOT NULL DEFAULT '0' COMMENT '★기간 말 전환 예약 — 1=current_period_end 시 basic 전환(다운그레이드·환불 없음). 배치 조회',
  `canceled_at` datetime DEFAULT NULL COMMENT '해지 시각',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '논리삭제(1=삭제)',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_academy_subscriptions_academy` (`academy_id`),
  KEY `idx_academy_subscriptions_status` (`status`),
  KEY `idx_academy_subscriptions_next_billing` (`next_billing_date`),
  CONSTRAINT `chk_academy_subscriptions_plan` CHECK ((`plan` in ('basic','pro'))),
  CONSTRAINT `chk_academy_subscriptions_status` CHECK ((`status` in ('active','trialing','canceled','past_due')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='RGuardians→학원 서비스 구독 상태 — 학원(테넌트)당 1행(academy_id UNIQUE). plan basic|pro·toss_billing_key 민감(BE 전용). 학생 청구(payments·billing_schedules)와 별개 도메인';

-- migrate:down

DROP TABLE `academy_subscriptions`;
