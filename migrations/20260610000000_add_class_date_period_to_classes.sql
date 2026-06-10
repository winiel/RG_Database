-- migrate:up
-- CLASS-DATE-PERIOD-SCHEMA — classes 운영 기간(start_date·end_date) 컬럼 추가 + days_of_week NOT NULL→NULL 완화
--
-- 발의: request/RG_Database/2026-06-10-class-date-period-schema-request.md
-- cross-ref: 직전 20260604053804 (days_of_week NOT NULL 강화) 정책을 본 마이그로 NULL 허용 전환
--
-- 변경 (사용자 확정 DDL, 6항목):
--   1) start_date DATE NULL 추가 (days_of_week 다음)
--   2) end_date   DATE NULL 추가 (start_date 다음)
--   3) days_of_week NOT NULL → NULL 완화
--   4) chk_classes_days_of_week_not_empty 재정의 (NULL 허용 + 비-NULL 시 최소 1개)
--   5) chk_classes_date_range 추가 (end_date >= start_date, NULL 관대)
--   6) 인덱스 2종 추가: idx_classes_tenant_status_end_date, idx_classes_tenant_start_date
--
-- 적용 순서 주의 (§2): days_of_week 를 MODIFY 하기 전 기존 CHECK 를 먼저 DROP 해야 안전
-- (json_length(days_of_week) 를 참조하는 CHECK 가 살아있는 상태에서 컬럼 정의를 바꾸면 MySQL 이 거부)
-- → CHECK DROP → 컬럼 MODIFY NULL → CHECK 재추가(NULL OR ...) 순서 (20260604053804 와 동일 검증 패턴)

-- §1 운영 기간 컬럼 2개 추가
ALTER TABLE classes
  ADD COLUMN start_date DATE NULL AFTER days_of_week,
  ADD COLUMN end_date   DATE NULL AFTER start_date;

-- §2 days_of_week NULL 허용 완화 (CHECK 선 DROP → MODIFY → CHECK 재추가)
ALTER TABLE classes
  DROP CONSTRAINT chk_classes_days_of_week_not_empty;

ALTER TABLE classes
  MODIFY COLUMN days_of_week JSON NULL;

ALTER TABLE classes
  ADD CONSTRAINT chk_classes_days_of_week_not_empty
    CHECK (days_of_week IS NULL OR JSON_LENGTH(days_of_week) >= 1);

-- §3 기간 범위 CHECK — end_date >= start_date (양측 NULL 관대)
ALTER TABLE classes
  ADD CONSTRAINT chk_classes_date_range
    CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date);

-- §4 인덱스 2종 (tenant 선두 복합 — 기존 idx_classes_tenant_id_* 명명 컨벤션 정합)
ALTER TABLE classes
  ADD INDEX idx_classes_tenant_status_end_date (tenant_id, status, end_date);

ALTER TABLE classes
  ADD INDEX idx_classes_tenant_start_date (tenant_id, start_date);


-- migrate:down
-- 역순 복원: §4 인덱스 DROP → §3 date_range CHECK DROP → §2 days_of_week NOT NULL 복원 → §1 컬럼 DROP
-- ⚠ 주의 1: start_date/end_date 에 데이터가 있으면 DROP COLUMN 으로 영구 소실됨.
-- ⚠ 주의 2: days_of_week 를 NOT NULL 로 되돌릴 때 NULL 행이 1건이라도 있으면 MODIFY 실패.
--           down 적용 전 days_of_week IS NULL 행을 backfill/정리해야 함.

-- §4↓ 인덱스 DROP
ALTER TABLE classes
  DROP INDEX idx_classes_tenant_start_date;

ALTER TABLE classes
  DROP INDEX idx_classes_tenant_status_end_date;

-- §3↓ date_range CHECK DROP
ALTER TABLE classes
  DROP CONSTRAINT chk_classes_date_range;

-- §2↓ days_of_week NOT NULL 복원 (CHECK 선 DROP → MODIFY → CHECK 재추가)
ALTER TABLE classes
  DROP CONSTRAINT chk_classes_days_of_week_not_empty;

ALTER TABLE classes
  MODIFY COLUMN days_of_week JSON NOT NULL;

ALTER TABLE classes
  ADD CONSTRAINT chk_classes_days_of_week_not_empty
    CHECK (JSON_LENGTH(days_of_week) >= 1);

-- §1↓ 운영 기간 컬럼 DROP
ALTER TABLE classes
  DROP COLUMN end_date,
  DROP COLUMN start_date;
