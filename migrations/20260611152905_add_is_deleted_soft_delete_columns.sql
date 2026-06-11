-- migrate:up
-- DB-9 (is_deleted 논리삭제 스키마) Stage ① — students/teachers/classes 논리삭제 컬럼 추가
--
-- 발의: request/RG_Database/2026-06-12-is-deleted-soft-delete-schema-policy-request.md
-- 채택: PM 오더 DB9-APPROVAL-BE33-PROCEED (BE-33 person-centric 논리삭제 정책)
-- DDL 실행: production RDS 적용은 PM 배포 게이트 통과 후 — 본 마이그는 로컬限 적용.
--
-- 설계 요지:
--   - is_deleted tinyint(1) NOT NULL DEFAULT 0 — 논리삭제 플래그(0=활성·1=삭제). backfill 불요(전 행 DEFAULT 0).
--   - deleted_at datetime NULL — 삭제 시각. deleted_by binary(16) NULL — 삭제 주체(person/user uuid).
--   - 컬럼은 테이블 끝에 추가(AFTER 미지정) → MySQL 8.0 ALGORITHM=INSTANT 적용 가능·무락 무리빌드.
--   - 영향: 컬럼 추가만 — 기존 데이터 영향 0(전 행 is_deleted=0).

ALTER TABLE students
  ADD COLUMN is_deleted tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN deleted_at datetime DEFAULT NULL,
  ADD COLUMN deleted_by binary(16) DEFAULT NULL;
ALTER TABLE teachers
  ADD COLUMN is_deleted tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN deleted_at datetime DEFAULT NULL,
  ADD COLUMN deleted_by binary(16) DEFAULT NULL;
ALTER TABLE classes
  ADD COLUMN is_deleted tinyint(1) NOT NULL DEFAULT 0,
  ADD COLUMN deleted_at datetime DEFAULT NULL,
  ADD COLUMN deleted_by binary(16) DEFAULT NULL;

-- migrate:down
ALTER TABLE classes  DROP COLUMN deleted_by, DROP COLUMN deleted_at, DROP COLUMN is_deleted;
ALTER TABLE teachers DROP COLUMN deleted_by, DROP COLUMN deleted_at, DROP COLUMN is_deleted;
ALTER TABLE students DROP COLUMN deleted_by, DROP COLUMN deleted_at, DROP COLUMN is_deleted;
