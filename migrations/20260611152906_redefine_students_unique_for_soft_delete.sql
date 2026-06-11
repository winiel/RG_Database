-- migrate:up
-- DB-9 (is_deleted 논리삭제 스키마) Stage ③ — students 유니크를 active 행 한정으로 재정의
--
-- 발의: request/RG_Database/2026-06-12-is-deleted-soft-delete-schema-policy-request.md
-- 채택: PM 오더 DB9-APPROVAL-BE33-PROCEED. DDL 실행: production RDS는 PM 배포 게이트 — 본 마이그는 로컬限 적용.
-- 의존: 마이그 20260611152905 (is_deleted 컬럼) 이후에만 적용 가능.
--
-- VIRTUAL NULL-token 패턴 (semesters.current_flag 선례) — active(is_deleted=0) 행만 (tenant_id,name,phone)
-- 유니크·삭제 행 면제·동명/동번호 재등록 허용.
--   - active 행: token=tenant_id → (name,phone,tenant_id) 유니크 = 기존과 동치.
--   - 삭제 행: token=NULL → NULL distinct 로 유니크 면제 → 동일 (name,phone) 재등록 허용.
-- ⚠ production 은 인덱스 재정의가 테이블 재구성(INSTANT 불가) → 저트래픽 시간대 PM/사용자 협의 게이트.

ALTER TABLE students
  ADD COLUMN active_uk_token binary(16) GENERATED ALWAYS AS (IF(is_deleted = 0, tenant_id, NULL)) VIRTUAL;
ALTER TABLE students DROP INDEX uk_students_tenant_name_phone;
ALTER TABLE students ADD UNIQUE KEY uk_students_tenant_name_phone (name, phone, active_uk_token);

-- migrate:down
ALTER TABLE students DROP INDEX uk_students_tenant_name_phone;
ALTER TABLE students ADD UNIQUE KEY uk_students_tenant_name_phone (tenant_id, name, phone);
ALTER TABLE students DROP COLUMN active_uk_token;
