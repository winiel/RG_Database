-- migrate:up
-- DB31-SETTINGS-AUTO-ATTENDANCE-ENABLED (DB-31) — 학원(테넌트)별 자동 출결 on/off 플래그 신설
--
-- 발의: request/RG_Database/2026-06-29-db31-settings-auto-attendance-enabled-column-request.md
-- 근거: 학원장(위니엘) 지시 — 학원마다 자동 출결 기능을 켜고 끌 수 있어야 하나, 현재 그 상태를
--       담을 컬럼이 전무. 현행 settings(학원 1:1)는 payment_settings·notification_settings(JSON)만
--       보유(20260510000001_create_initial_schema.sql §17). BE-61(on/off 소비)의 DB 선행.
--
-- 설계 요지:
--   - auto_attendance_enabled = BOOLEAN(tinyint(1)) NOT NULL DEFAULT TRUE, notification_settings 뒤 배치.
--   - 의미: TRUE = 자동출결 활성(현행 동작), FALSE = 비활성.
--   - NOT NULL DEFAULT TRUE — ADD COLUMN 시 기존 행 전부 TRUE 자동 충전(별도 backfill UPDATE 불요)
--     + 신규 settings 행도 DEFAULT TRUE 로 자동 활성. → 현행 = 전 학원 자동출결 유지(회귀 0).
--
-- 영향: 컬럼 추가만(DDL only). 트리거/SP 없음. 테일 컬럼·DEFAULT 상수.
--       기존 settings INSERT/UPDATE 쿼리(Backend 현행)는 NOT NULL DEFAULT 라 미동봉해도 TRUE 자동 적용.
--       롤백 가능(down = DROP COLUMN).

ALTER TABLE settings
  ADD COLUMN auto_attendance_enabled BOOLEAN NOT NULL DEFAULT TRUE
    COMMENT '자동 출결 활성 여부 (TRUE=활성, FALSE=비활성)'
    AFTER notification_settings;

-- migrate:down

ALTER TABLE settings
  DROP COLUMN auto_attendance_enabled;
