-- ============================================================================
-- 결제 조정 기능 (A 할인 / B 연기 / C 환급) v1 단계 — 장부 단계 DB 변경
--
-- 합의 근거:
--   request: RG_Common/request/RG_Database/2026-05-17-payment-adjustments-tables-request.md
--   회신:    RG_Common/Document/RG_Database/2026-05-16-payment-adjustments-response.md
--   디렉터: RG_Common/Document/RG_Director/2026-05-16-payment-adjustments-direction.md §1
--
-- v1 범위 (#1·#2·#3 동시 적용):
--   1. payment_adjustments 테이블 신설 — A/C 공통 도메인
--   2. payments.refunded_amount 컬럼 추가 — C 부분 환급 표현 (X 옵션)
--   3. payment_events.event_type CHECK 갱신 — 'adjusted', 'postponed' 추가
--
-- 보류 (v2):
--   - students.billing_anchor_day (B permanent 모드, auto-bill 잡과 동시 도입)
--   - students.next_billing_date_override (auto-bill 잡 도입 시점)
--
-- DDL 결정 사항 (회신 §2 권장안 채택):
--   - amount 정밀도: DECIMAL(12,2) — payments.amount 와 통일
--   - 인덱스 명명: idx_[table]_[col1]_[col2]_... 풀 컬럼명 (DatabaseGuide 일관)
--   - 추가 CHECK: chk_payment_adjustments_period — period_end >= period_start
--   - FK 미선언 (정책 §3-4) — 앱 측 검증
-- ============================================================================

-- migrate:up

-- 1. payment_adjustments 테이블 신설
CREATE TABLE payment_adjustments (
    id                  BINARY(16)    NOT NULL,
    tenant_id           BINARY(16)    NOT NULL,
    student_id          BINARY(16)    NOT NULL,
    type                VARCHAR(20)   NOT NULL                COMMENT '''discount'' = A안 (다음 청구서에서 차감) | ''refund'' = C안 (paid 결제 일부 환급 기록)',
    amount              DECIMAL(12,2) NOT NULL                COMMENT '학원장 입력값 (KRW 정수 권장. v1 정책상 자유 입력)',
    reason              VARCHAR(500)  DEFAULT NULL            COMMENT '사유 (자유 텍스트, v1)',
    period_start        DATE          DEFAULT NULL            COMMENT '부재/할인 시작일 (선택, audit 보조)',
    period_end          DATE          DEFAULT NULL            COMMENT '부재/할인 종료일 (선택)',
    target_payment_id   BINARY(16)    DEFAULT NULL            COMMENT '''discount'': 적용 대상 (NULL = 다음 미생성 청구서) / ''refund'': 원 결제 id (필수)',
    applied_payment_id  BINARY(16)    DEFAULT NULL            COMMENT '실제로 적용된 결제 id (pending → applied 전이 시 채워짐)',
    status              VARCHAR(20)   NOT NULL DEFAULT 'pending' COMMENT '''pending'' | ''applied'' | ''cancelled''',
    created_by          BINARY(16)    NOT NULL                COMMENT 'user_accounts.id (학원장)',
    created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_payment_adjustments_tenant_id_student_id        (tenant_id, student_id),
    KEY idx_payment_adjustments_tenant_id_target_payment_id (tenant_id, target_payment_id),
    KEY idx_payment_adjustments_tenant_id_status            (tenant_id, status),
    CONSTRAINT chk_payment_adjustments_type   CHECK (type   IN ('discount','refund')),
    CONSTRAINT chk_payment_adjustments_status CHECK (status IN ('pending','applied','cancelled')),
    CONSTRAINT chk_payment_adjustments_amount CHECK (amount >= 0),
    CONSTRAINT chk_payment_adjustments_period CHECK (period_end IS NULL OR period_start IS NULL OR period_end >= period_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2. payments.refunded_amount 컬럼 + CHECK 추가
ALTER TABLE payments
    ADD COLUMN refunded_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00
        COMMENT '누적 환급 금액 (v1 부분 환급 표현, X 옵션 — Director 채택)';

ALTER TABLE payments
    ADD CONSTRAINT chk_payments_refunded_amount
        CHECK (refunded_amount >= 0 AND refunded_amount <= amount);

-- 3. payment_events.event_type ENUM 확장 — 'adjusted', 'postponed' 추가
ALTER TABLE payment_events DROP CONSTRAINT chk_payment_events_type;
ALTER TABLE payment_events ADD CONSTRAINT chk_payment_events_type CHECK (
    event_type IN (
        'created', 'paid', 'overdue_marked', 'cancelled', 'refunded',
        'reminder_sent', 'note_added',
        'adjusted',   -- 신규: A안 할인 적용 이력
        'postponed'   -- 신규: B안 결제일 연기 이력
    )
);

-- migrate:down

-- 역순 적용
ALTER TABLE payment_events DROP CONSTRAINT chk_payment_events_type;
ALTER TABLE payment_events ADD CONSTRAINT chk_payment_events_type CHECK (
    event_type IN ('created', 'paid', 'overdue_marked', 'cancelled', 'refunded', 'reminder_sent', 'note_added')
);
-- ⚠️ down 적용 시 event_type='adjusted' 또는 'postponed' row 존재하면 CHECK 위반. 사전 정리 필요.

ALTER TABLE payments DROP CONSTRAINT chk_payments_refunded_amount;
ALTER TABLE payments DROP COLUMN refunded_amount;

DROP TABLE payment_adjustments;
