-- migrate:up
-- B-X lockstep §3.3 ~ §3.5 + 옵션 α + 옵션 A — classes.days_of_week NOT NULL 강제 + production 잔여 2건 archive backfill + DELETE + chk_classes_status enum 확장 (archived 추가)
--
-- 발의 chain:
-- - request/RG_Database/2026-06-02-classes-days-of-week-not-null-migration-request.md (B-X 원 발의)
-- - request/RG_Backend/2026-06-04-B-X-backfill-sql-correction-request.md (B-X-correction 정정)
-- - Document/RG_Backend/2026-06-04-B-X-backfill-sql-correction-response.md (Backend §1.4 합의 + §3.3 진입 합의)
-- - Document/RG_Database/2026-06-04-B-X-student-classes-archive-impact-verification.md (archive 영향 0 정량 확정)
--
-- 옵션 α (chk_classes_status enum 확장) 트리거: 적용 시 enum ('active','paused','ended') 가 'archived' 미허용
-- 옵션 A (UPDATE+DELETE) 트리거: status='archived' UPDATE 만으로는 days_of_week 가 NULL 유지 → NOT NULL DDL 실패. archive 의도 표시 후 DELETE 동봉
-- archive 영향 0 정량 보강: student_classes 0건 (active/status 무관 모두 0) → cascade FK 영향 0
--
-- Backend A-X 진입점 가드 (route + AI tool) 라이브: 2026-06-02 EC2 dev (commit 7e8e5a1) — 신규 NULL INSERT 차단 가동

-- §0 chk_classes_status enum 확장 ('archived' 추가) — backfill UPDATE 선결 조건
ALTER TABLE classes
  DROP CONSTRAINT chk_classes_status;

ALTER TABLE classes
  ADD CONSTRAINT chk_classes_status
    CHECK (status IN ('active', 'paused', 'ended', 'archived'));

-- §3.3 production backfill — NULL days_of_week row 일괄 archive 의도 표시 후 DELETE
-- 운영 의도: archive 의도 표시 (audit log 효과) → 즉시 DELETE
-- production RDS 대상 row (specific id 추적): 019e8870-e10b-7c53-9637-c1a77cb3dce4, 019e8870-e128-7a50-be2a-1c70ce649ca2 (수학반, tenant 2f201078-...)
-- local dev 대상 row (dummy id): 019e6e74-... (V21todayreflect반), 019e7144-... (V21수동입력반)
-- 양 환경 모두 student_classes 등록 0건 + 메타 미지정 → cascade 영향 0

UPDATE classes
SET status = 'archived'
WHERE days_of_week IS NULL;

DELETE FROM classes
WHERE days_of_week IS NULL
  AND status = 'archived';
-- 기대 affected rows (양 환경) = 2

-- §3.5 DDL NOT NULL 강제
ALTER TABLE classes
  MODIFY COLUMN days_of_week JSON NOT NULL;

-- §3.5 (선택, 채택) CHECK 제약 — array 1개 이상 보장 (Backend B-X-correction 응답 §4 권장 + 사용자 합의)
ALTER TABLE classes
  ADD CONSTRAINT chk_classes_days_of_week_not_empty
    CHECK (JSON_LENGTH(days_of_week) >= 1);


-- migrate:down
-- DDL 역순 복원. DELETE 된 row 의 복원은 불가 (audit log 손실 인지) — migration 내 자동 복원 안 함
-- chk_classes_status 복원 시 archived row 존재하면 실패 가능 — 필요 시 별 사이클에서 archived → ended 매핑 후 down 적용

ALTER TABLE classes
  DROP CONSTRAINT chk_classes_days_of_week_not_empty;

ALTER TABLE classes
  MODIFY COLUMN days_of_week JSON NULL;

ALTER TABLE classes
  DROP CONSTRAINT chk_classes_status;

ALTER TABLE classes
  ADD CONSTRAINT chk_classes_status
    CHECK (status IN ('active', 'paused', 'ended'));
