-- migrate:up
-- DB-13 — academies 학원 승인 상태 컬럼(status) 추가 + 기존 행 전부 active backfill
--
-- 발의/정책: 학원장 정책 — 신규 학원 self-signup(BE-37)은 "관리자 승인 후 이용".
--   신규=pending, 기존 운영 학원=active. BE-38(승인 게이트)가 이 컬럼을 읽어 로그인 차단/허용.
-- 채택안: 옵션 A — status VARCHAR(16) NOT NULL DEFAULT 'pending' + CHECK(status IN ('pending','active')).
-- DDL 실행: production RDS 적용은 PM 배포 게이트 통과 후 — 본 마이그는 로컬限 적용.
--
-- ★CRITICAL 불변식: DDL+backfill 직후 기존 academies 에 pending 이 0건이어야 함.
--   DEFAULT 'pending' 이라 ADD COLUMN 시 기존 행이 일단 pending 으로 채워지므로,
--   같은 마이그레이션 안에서 즉시 UPDATE ... SET status='active' 로 기존 운영 학원 전부 승인됨 처리.
--   신규 INSERT(BE-37)는 default pending 유지.
-- BE-38 계약: 컬럼명 status · 타입 VARCHAR(16) · "승인됨"=status='active' · 기본 pending.

ALTER TABLE academies
  ADD COLUMN status varchar(16) NOT NULL DEFAULT 'pending',
  ADD CONSTRAINT chk_academies_status CHECK (status IN ('pending','active'));
-- ★기존 운영 학원 전부 승인됨으로 backfill (누락 금지·DDL 직후 pending 0 불변식)
UPDATE academies SET status = 'active';

-- migrate:down
ALTER TABLE academies DROP CONSTRAINT chk_academies_status;
ALTER TABLE academies DROP COLUMN status;
