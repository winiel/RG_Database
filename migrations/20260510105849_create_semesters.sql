-- ============================================================================
-- semesters 테이블 신규
--
-- 합의 근거:
--   request: RG_Common/request/RG_Database/2026-05-10-director-database-request.md §1
--   회신:   RG_Common/Document/RG_Database/2026-05-10-response-to-director.md §2
--
-- 정책:
--   * BINARY(16) UUID PK (앱 측 생성, UUIDv7 권장)
--   * tenant_id 첫 컬럼 인덱스 (멀티테넌시)
--   * FK 미사용 (회신 §3-4 정책 일관)
--   * 학원당 is_current=TRUE 단일 보장: GENERATED column + UNIQUE
--     - MySQL 8.0이 partial unique index를 미지원하므로 우회 패턴
--     - is_current=TRUE 일 때만 tenant_id 값을 갖고, FALSE 면 NULL → UNIQUE는 NULL 중복 허용
-- ============================================================================

-- migrate:up

CREATE TABLE semesters (
    id           BINARY(16)   NOT NULL,
    tenant_id    BINARY(16)   NOT NULL,
    name         VARCHAR(40)  NOT NULL,
    starts_on    DATE         NOT NULL,
    ends_on      DATE         NOT NULL,
    is_current   BOOLEAN      NOT NULL DEFAULT FALSE,
    description  VARCHAR(200) NULL,
    -- 학원당 is_current=TRUE 단일 보장용 generated column
    current_flag BINARY(16)   GENERATED ALWAYS AS (IF(is_current = TRUE, tenant_id, NULL)) VIRTUAL,
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_semesters                 PRIMARY KEY (id),
    CONSTRAINT uq_semesters_tenant_current  UNIQUE (current_flag),
    CONSTRAINT chk_semesters_date_range     CHECK (ends_on >= starts_on)
);
CREATE INDEX idx_semesters_tenant_id_starts_on ON semesters (tenant_id, starts_on);

-- migrate:down

DROP TABLE IF EXISTS semesters;
