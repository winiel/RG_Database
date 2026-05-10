-- ============================================================================
-- ProjectRG — Initial Schema (Phase 1)
--
-- Migration:  20260510000001_create_initial_schema
-- 작성일:     2026-05-10
-- 합의 근거:
--   - request: RG_Common/request/RG_Database/2026-05-10-backend-database-request.md
--   - 회신:   RG_Common/Document/RG_Database/2026-05-10-database-response-to-backend.md
--
-- 정책 요약:
--   * Engine:    MySQL 8.0+ (Aurora MySQL 3 호환)
--   * Charset:   utf8mb4 / Collation: utf8mb4_0900_ai_ci
--   * PK:        BINARY(16) UUID — 앱(백엔드) 측 생성 (UUIDv7 권장), DB DEFAULT 미설정
--   * FK:        100% 미사용 — 모든 무결성은 앱+CI 책임 (회신 §3-4)
--   * 시간:      DATETIME UTC 저장 — 인스턴스 time_zone='+00:00' 설정 별도 의무
--   * 멀티테넌시: 모든 도메인 테이블에 tenant_id NOT NULL + 인덱스 첫 컬럼
--   * created_at/updated_at: 모든 테이블 의무 (DatabaseGuide §3.6)
-- ============================================================================

-- migrate:up

CREATE DATABASE IF NOT EXISTS ProjectRG_Dev
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE ProjectRG_Dev;

-- ===========================================================================
-- §4.1 인증/테넌시
-- ===========================================================================

-- 1. academies (학원/테넌트 — 멀티테넌시 루트)
--    NOTE: 자기 자신이 테넌트이므로 tenant_id 컬럼 없음.
--          다른 테이블의 tenant_id는 academies.id를 가리키는 논리적 참조.
CREATE TABLE academies (
    id              BINARY(16)   NOT NULL,
    name            VARCHAR(100) NOT NULL,
    business_number VARCHAR(20)  NOT NULL,
    address         VARCHAR(255) NULL,
    phone           VARCHAR(20)  NULL,
    email           VARCHAR(255) NULL,
    logo_url        VARCHAR(500) NULL,
    operating_hours JSON         NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_academies                 PRIMARY KEY (id),
    CONSTRAINT uq_academies_business_number UNIQUE (business_number)
);

-- 2. user_accounts (학원장 로그인 계정)
CREATE TABLE user_accounts (
    id            BINARY(16)   NOT NULL,
    tenant_id     BINARY(16)   NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name          VARCHAR(100) NOT NULL,
    phone         VARCHAR(20)  NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'owner',
    last_login_at DATETIME     NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_accounts       PRIMARY KEY (id),
    CONSTRAINT uq_user_accounts_email UNIQUE (email),
    CONSTRAINT chk_user_accounts_role CHECK (role IN ('owner'))
);
CREATE INDEX idx_user_accounts_tenant_id ON user_accounts (tenant_id);

-- 3. refresh_tokens (JWT refresh token 폐기 추적)
CREATE TABLE refresh_tokens (
    id              BINARY(16)   NOT NULL,
    tenant_id       BINARY(16)   NOT NULL,
    user_account_id BINARY(16)   NOT NULL,
    token_hash      VARCHAR(255) NOT NULL,
    expires_at      DATETIME     NOT NULL,
    revoked_at      DATETIME     NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_refresh_tokens             PRIMARY KEY (id),
    CONSTRAINT uq_refresh_tokens_token_hash  UNIQUE (token_hash)
);
CREATE INDEX idx_refresh_tokens_tenant_id_user_account_id ON refresh_tokens (tenant_id, user_account_id);
CREATE INDEX idx_refresh_tokens_expires_at                ON refresh_tokens (expires_at);

-- ===========================================================================
-- §4.3 마스터 (subjects, rooms는 다른 테이블이 참조하므로 먼저 생성)
-- ===========================================================================

-- 9. subjects (종목 마스터)
CREATE TABLE subjects (
    id          BINARY(16)  NOT NULL,
    tenant_id   BINARY(16)  NOT NULL,
    name        VARCHAR(50) NOT NULL,
    color_token VARCHAR(30) NULL,
    created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_subjects                PRIMARY KEY (id),
    CONSTRAINT uq_subjects_tenant_id_name UNIQUE (tenant_id, name)
);

-- 10. rooms (강의실 마스터)
CREATE TABLE rooms (
    id          BINARY(16)   NOT NULL,
    tenant_id   BINARY(16)   NOT NULL,
    name        VARCHAR(50)  NOT NULL,
    description VARCHAR(255) NULL,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_rooms                PRIMARY KEY (id),
    CONSTRAINT uq_rooms_tenant_id_name UNIQUE (tenant_id, name)
);

-- ===========================================================================
-- §4.2 학생/메모
-- ===========================================================================

-- 4. students (학생)
CREATE TABLE students (
    id                BINARY(16)   NOT NULL,
    tenant_id         BINARY(16)   NOT NULL,
    name              VARCHAR(100) NOT NULL,
    birth_date        DATE         NULL,
    school_name       VARCHAR(100) NULL,
    grade             VARCHAR(20)  NULL,
    profile_image_url VARCHAR(500) NULL,
    address           VARCHAR(255) NULL,
    registered_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status            VARCHAR(20)  NOT NULL DEFAULT 'active',
    parent            JSON         NULL,
    parent_name       VARCHAR(100) NULL,
    parent_phone      VARCHAR(20)  NULL,
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_students        PRIMARY KEY (id),
    CONSTRAINT chk_students_status CHECK (status IN ('active', 'paused', 'withdrawn'))
);
CREATE INDEX idx_students_tenant_id_status       ON students (tenant_id, status);
CREATE INDEX idx_students_tenant_id_parent_phone ON students (tenant_id, parent_phone);
CREATE INDEX idx_students_tenant_id_name         ON students (tenant_id, name);

-- 5. student_notes (학원장 메모 — 학생 1:1)
CREATE TABLE student_notes (
    id         BINARY(16) NOT NULL,
    tenant_id  BINARY(16) NOT NULL,
    student_id BINARY(16) NOT NULL,
    content    TEXT       NULL,
    created_at DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_student_notes                       PRIMARY KEY (id),
    CONSTRAINT uq_student_notes_tenant_id_student_id  UNIQUE (tenant_id, student_id)
);

-- ===========================================================================
-- §4.3 클래스/강사
-- ===========================================================================

-- 8. teachers (강사)
CREATE TABLE teachers (
    id                BINARY(16)     NOT NULL,
    tenant_id         BINARY(16)     NOT NULL,
    name              VARCHAR(100)   NOT NULL,
    subject_id        BINARY(16)     NULL,
    profile_image_url VARCHAR(500)   NULL,
    phone             VARCHAR(20)    NULL,
    email             VARCHAR(255)   NULL,
    employment_type   VARCHAR(20)    NOT NULL DEFAULT 'full_time',
    hourly_rate       DECIMAL(10, 2) NULL,
    joined_at         DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status            VARCHAR(20)    NOT NULL DEFAULT 'active',
    created_at        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_teachers                  PRIMARY KEY (id),
    CONSTRAINT chk_teachers_employment_type CHECK (employment_type IN ('full_time', 'part_time', 'contract')),
    CONSTRAINT chk_teachers_status          CHECK (status IN ('active', 'inactive', 'resigned'))
);
CREATE INDEX idx_teachers_tenant_id_status     ON teachers (tenant_id, status);
CREATE INDEX idx_teachers_tenant_id_subject_id ON teachers (tenant_id, subject_id);

-- 6. classes (클래스)
CREATE TABLE classes (
    id         BINARY(16)   NOT NULL,
    tenant_id  BINARY(16)   NOT NULL,
    name       VARCHAR(100) NOT NULL,
    subject_id BINARY(16)   NULL,
    teacher_id BINARY(16)   NULL,
    room_id    BINARY(16)   NULL,
    days_of_week JSON       NULL,
    start_time TIME         NULL,
    end_time   TIME         NULL,
    capacity   INT UNSIGNED NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'active',
    started_at DATETIME     NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_classes        PRIMARY KEY (id),
    CONSTRAINT chk_classes_status CHECK (status IN ('active', 'paused', 'ended'))
);
CREATE INDEX idx_classes_tenant_id_status     ON classes (tenant_id, status);
CREATE INDEX idx_classes_tenant_id_subject_id ON classes (tenant_id, subject_id);
CREATE INDEX idx_classes_tenant_id_teacher_id ON classes (tenant_id, teacher_id);
CREATE INDEX idx_classes_tenant_id_room_id    ON classes (tenant_id, room_id);

-- 7. student_classes (학생-클래스 등록 N:M)
CREATE TABLE student_classes (
    id            BINARY(16)  NOT NULL,
    tenant_id     BINARY(16)  NOT NULL,
    student_id    BINARY(16)  NOT NULL,
    class_id      BINARY(16)  NOT NULL,
    enrolled_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unenrolled_at DATETIME    NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_student_classes                                  PRIMARY KEY (id),
    CONSTRAINT uq_student_classes_tenant_id_student_id_class_id    UNIQUE (tenant_id, student_id, class_id),
    CONSTRAINT chk_student_classes_status                          CHECK (status IN ('active', 'unenrolled', 'completed'))
);
CREATE INDEX idx_student_classes_tenant_id_class_id ON student_classes (tenant_id, class_id);

-- 11. holidays (휴무일)
CREATE TABLE holidays (
    id         BINARY(16)   NOT NULL,
    tenant_id  BINARY(16)   NOT NULL,
    `date`     DATE         NOT NULL,
    name       VARCHAR(100) NOT NULL,
    type       VARCHAR(20)  NOT NULL DEFAULT 'academy',
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_holidays              PRIMARY KEY (id),
    CONSTRAINT uq_holidays_tenant_id_date UNIQUE (tenant_id, `date`),
    CONSTRAINT chk_holidays_type        CHECK (type IN ('public', 'academy', 'special'))
);

-- ===========================================================================
-- §4.4 출결/Vision (vision_verifications가 attendances보다 먼저 생성)
-- ===========================================================================

-- 13. vision_verifications (Vision AI 인증 결과)
CREATE TABLE vision_verifications (
    id          BINARY(16)    NOT NULL,
    tenant_id   BINARY(16)    NOT NULL,
    student_id  BINARY(16)    NOT NULL,
    image_url   VARCHAR(500)  NOT NULL,
    confidence  DECIMAL(5, 4) NULL,
    verified_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_vision_verifications             PRIMARY KEY (id),
    CONSTRAINT chk_vision_verifications_confidence CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))
);
CREATE INDEX idx_vision_verifications_tenant_id_student_id_verified_at
    ON vision_verifications (tenant_id, student_id, verified_at);

-- 12. attendances (출결)
CREATE TABLE attendances (
    id                              BINARY(16)   NOT NULL,
    tenant_id                       BINARY(16)   NOT NULL,
    student_id                      BINARY(16)   NOT NULL,
    class_id                        BINARY(16)   NOT NULL,
    `date`                          DATE         NOT NULL,
    attendance_status               VARCHAR(20)  NOT NULL,
    check_in_at                     DATETIME     NULL,
    vision_verification_id          BINARY(16)   NULL,
    absence_reason                  VARCHAR(255) NULL,
    absence_category                VARCHAR(20)  NULL,
    is_absence_notified_in_advance  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at                      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_attendances                                       PRIMARY KEY (id),
    CONSTRAINT uq_attendances_tenant_id_student_id_class_id_date    UNIQUE (tenant_id, student_id, class_id, `date`),
    CONSTRAINT chk_attendances_status                               CHECK (attendance_status IN ('present', 'late', 'absent', 'excused')),
    CONSTRAINT chk_attendances_absence_category                     CHECK (absence_category IS NULL OR absence_category IN ('sick', 'family', 'travel', 'other'))
);
CREATE INDEX idx_attendances_tenant_id_class_id_date   ON attendances (tenant_id, class_id, `date`);
CREATE INDEX idx_attendances_tenant_id_student_id_date ON attendances (tenant_id, student_id, `date`);

-- ===========================================================================
-- §4.5 결제/이력
-- ===========================================================================

-- 14. payments (결제)
CREATE TABLE payments (
    id                BINARY(16)     NOT NULL,
    tenant_id         BINARY(16)     NOT NULL,
    student_id        BINARY(16)     NOT NULL,
    class_id          BINARY(16)     NULL,
    billing_item      VARCHAR(100)   NOT NULL,
    billing_breakdown JSON           NULL,
    amount            DECIMAL(12, 2) NOT NULL,
    billing_date      DATE           NOT NULL,
    due_date          DATE           NULL,
    paid_date         DATE           NULL,
    payment_method    VARCHAR(20)    NULL,
    payment_status    VARCHAR(20)    NOT NULL DEFAULT 'pending',
    created_at        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_payments         PRIMARY KEY (id),
    CONSTRAINT chk_payments_status CHECK (payment_status IN ('pending', 'paid', 'overdue', 'cancelled', 'refunded')),
    CONSTRAINT chk_payments_method CHECK (payment_method IS NULL OR payment_method IN ('cash', 'card', 'transfer', 'auto_debit')),
    CONSTRAINT chk_payments_amount CHECK (amount >= 0)
);
CREATE INDEX idx_payments_tenant_id_billing_date ON payments (tenant_id, billing_date);
CREATE INDEX idx_payments_tenant_id_student_id   ON payments (tenant_id, student_id);
CREATE INDEX idx_payments_tenant_id_status       ON payments (tenant_id, payment_status);
CREATE INDEX idx_payments_tenant_id_due_date     ON payments (tenant_id, due_date);

-- 15. payment_events (결제 이력 타임라인)
CREATE TABLE payment_events (
    id          BINARY(16)  NOT NULL,
    tenant_id   BINARY(16)  NOT NULL,
    payment_id  BINARY(16)  NOT NULL,
    event_type  VARCHAR(30) NOT NULL,
    event_data  JSON        NULL,
    occurred_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_payment_events       PRIMARY KEY (id),
    CONSTRAINT chk_payment_events_type CHECK (event_type IN ('created', 'paid', 'overdue_marked', 'cancelled', 'refunded', 'reminder_sent', 'note_added'))
);
CREATE INDEX idx_payment_events_tenant_id_payment_id_occurred_at
    ON payment_events (tenant_id, payment_id, occurred_at);

-- ===========================================================================
-- §4.6 알림/설정
-- ===========================================================================

-- 16. message_templates (알림 템플릿)
CREATE TABLE message_templates (
    id            BINARY(16)   NOT NULL,
    tenant_id     BINARY(16)   NOT NULL,
    template_type VARCHAR(50)  NOT NULL,
    channel       VARCHAR(20)  NOT NULL,
    title         VARCHAR(200) NULL,
    body          TEXT         NOT NULL,
    is_enabled    BOOLEAN      NOT NULL DEFAULT TRUE,
    timing_config JSON         NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_message_templates                          PRIMARY KEY (id),
    CONSTRAINT uq_message_templates_tenant_id_type_channel   UNIQUE (tenant_id, template_type, channel),
    CONSTRAINT chk_message_templates_channel                 CHECK (channel IN ('sms', 'email', 'push', 'kakao'))
);

-- 17. settings (학원 설정 1:1)
CREATE TABLE settings (
    id                    BINARY(16) NOT NULL,
    tenant_id             BINARY(16) NOT NULL,
    payment_settings      JSON       NULL,
    notification_settings JSON       NULL,
    created_at            DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_settings           PRIMARY KEY (id),
    CONSTRAINT uq_settings_tenant_id UNIQUE (tenant_id)
);

-- ===========================================================================
-- §4.7 능력치
-- ===========================================================================

-- 18. ability_tracks (능력치 트랙 마스터)
CREATE TABLE ability_tracks (
    id          BINARY(16)   NOT NULL,
    tenant_id   BINARY(16)   NOT NULL,
    name        VARCHAR(100) NOT NULL,
    subject_id  BINARY(16)   NULL,
    description VARCHAR(500) NULL,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_ability_tracks                PRIMARY KEY (id),
    CONSTRAINT uq_ability_tracks_tenant_id_name UNIQUE (tenant_id, name)
);
CREATE INDEX idx_ability_tracks_tenant_id_subject_id ON ability_tracks (tenant_id, subject_id);

-- 19. student_abilities (학생별 능력치 평가)
CREATE TABLE student_abilities (
    id               BINARY(16)    NOT NULL,
    tenant_id        BINARY(16)    NOT NULL,
    student_id       BINARY(16)    NOT NULL,
    ability_track_id BINARY(16)    NOT NULL,
    score            DECIMAL(5, 2) NOT NULL,
    evaluated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_student_abilities                                       PRIMARY KEY (id),
    CONSTRAINT uq_student_abilities_tenant_id_student_id_track_id         UNIQUE (tenant_id, student_id, ability_track_id),
    CONSTRAINT chk_student_abilities_score                                CHECK (score >= 0 AND score <= 100)
);
CREATE INDEX idx_student_abilities_tenant_id_student_id ON student_abilities (tenant_id, student_id);

-- ===========================================================================
-- §4.8 업로드 메타
-- ===========================================================================

-- 20. uploads (업로드 메타 — presigned URL 추적)
CREATE TABLE uploads (
    id                         BINARY(16)         NOT NULL,
    tenant_id                  BINARY(16)         NOT NULL,
    purpose                    VARCHAR(50)        NOT NULL,
    object_key                 VARCHAR(500)       NOT NULL,
    original_filename          VARCHAR(255)       NULL,
    content_type               VARCHAR(100)       NULL,
    byte_size                  BIGINT UNSIGNED    NULL,
    upload_status              VARCHAR(20)        NOT NULL DEFAULT 'pending',
    processed_url              VARCHAR(500)       NULL,
    thumbnail_url              VARCHAR(500)       NULL,
    created_by_user_account_id BINARY(16)         NULL,
    created_at                 DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                 DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_uploads             PRIMARY KEY (id),
    CONSTRAINT uq_uploads_object_key  UNIQUE (object_key),
    CONSTRAINT chk_uploads_status     CHECK (upload_status IN ('pending', 'uploading', 'processing', 'completed', 'failed')),
    CONSTRAINT chk_uploads_purpose    CHECK (purpose IN ('student_profile', 'teacher_profile', 'academy_logo', 'vision_image', 'other'))
);
CREATE INDEX idx_uploads_tenant_id_purpose ON uploads (tenant_id, purpose);
CREATE INDEX idx_uploads_tenant_id_status  ON uploads (tenant_id, upload_status);

-- migrate:down

DROP TABLE IF EXISTS uploads;
DROP TABLE IF EXISTS student_abilities;
DROP TABLE IF EXISTS ability_tracks;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS message_templates;
DROP TABLE IF EXISTS payment_events;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS attendances;
DROP TABLE IF EXISTS vision_verifications;
DROP TABLE IF EXISTS holidays;
DROP TABLE IF EXISTS student_classes;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS teachers;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS subjects;
DROP TABLE IF EXISTS student_notes;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS user_accounts;
DROP TABLE IF EXISTS academies;
-- DROP DATABASE는 안전을 위해 자동화하지 않음 (수동 실행 필요)
