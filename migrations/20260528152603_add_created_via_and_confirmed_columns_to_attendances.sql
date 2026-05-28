-- migrate:up
-- B-1: 자동 출결 옵션 β 마이그 — N10 양쪽 ack 풀 합의 정합
-- spec: DB 통합 회신 570e27c §3.1 + Backend cron 정책 옵션 Y (dcf37fb) 정합
-- - created_via VARCHAR(20) NOT NULL DEFAULT 'manual' — D2 chip 정합
-- - confirmed_at DATETIME NULL — D4 (Y) v1 채택, cron INSERT 시 cron_run_at (Backend 옵션 Y)
-- - confirmed_by BINARY(16) NULL — 학원장 user_id (멀티 RBAC 미래 호환)
-- - CHECK chk_attendances_created_via — 4 enum 가드
-- 인덱스 v1 미도입 (1일 row 수십개 가정, EXPLAIN 검토 후 v2 추가)
-- 기존 row backfill: DEFAULT 'manual' 자동 적용 + confirmed_at/by NULL (학원장 미확인 의미)

ALTER TABLE attendances
  ADD COLUMN created_via VARCHAR(20) NOT NULL DEFAULT 'manual',
  ADD COLUMN confirmed_at DATETIME NULL,
  ADD COLUMN confirmed_by BINARY(16) NULL;

ALTER TABLE attendances
  ADD CONSTRAINT chk_attendances_created_via
    CHECK (created_via IN ('manual', 'auto', 'vision', 'ai'));


-- migrate:down

ALTER TABLE attendances
  DROP CONSTRAINT chk_attendances_created_via;

ALTER TABLE attendances
  DROP COLUMN confirmed_by,
  DROP COLUMN confirmed_at,
  DROP COLUMN created_via;
