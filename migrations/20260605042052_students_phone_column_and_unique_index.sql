-- migrate:up
-- T-AI-01-S4-BUNDLE-FOLLOWUP-Q2-STUDENT-PHONE-DB
-- Director 33회차 Q-2 cascade: 학생 본인 phone 컬럼 + (tenant_id, name, phone) 복합 unique
-- 사전 검증 (2026-06-05): row=28, 동명이인 충돌 0건, FK 차단 요인 없음

ALTER TABLE students
  ADD COLUMN phone VARCHAR(20) NULL AFTER address,
  ADD UNIQUE KEY uk_students_tenant_name_phone (tenant_id, name, phone);


-- migrate:down
ALTER TABLE students
  DROP INDEX uk_students_tenant_name_phone,
  DROP COLUMN phone;
