-- ============================================================================
-- trg_students_auto_person_id 제거 — students.person_id v1_swap 정정 cycle
--
-- 근거:
--   request/RG_Backend/2026-06-04-students-person-id-v1-swap-correction-request.md (05363d1)
--   Document/RG_Backend/2026-06-04-students-person-id-v1-swap-correction-response.md (ef57c5f, A-ii 채택)
--   Document/RG_Database/2026-06-04-students-person-id-v1-swap-impact-diagnosis.md (4b183c0)
--
-- 결정 (옵션 A-ii):
--   - trigger 제거 — Backend application 레이어 (new_uuid7() + to_bin()) 로 person 생성 이전
--   - 가이드 §6.1 정합 + RFC 9562 v7
--
-- Dependency:
--   - Backend code 라이브 완료 후 적용 (student_repo.py + students.sql + 회귀 가드)
--   - 라이브 전 적용 시 students.person_id NOT NULL 위반
--
-- Backfill:
--   - 기존 row (persons + students.person_id 각 27 v1_swap) = scripts/backfill-persons-v7.sh 별 실행
--   - 본 마이그 = schema-only (trigger DROP)
--
-- 적용 주의: down 본문 BEGIN/END 블록 → multiStatements=true 필요
-- ============================================================================

-- migrate:up

DROP TRIGGER trg_students_auto_person_id;

-- migrate:down

CREATE TRIGGER trg_students_auto_person_id
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    DECLARE new_pid BINARY(16);
    IF NEW.person_id IS NULL THEN
        SET new_pid = UUID_TO_BIN(UUID(), 1);
        INSERT INTO persons (id, name, birth_date)
            VALUES (new_pid, NEW.name, NEW.birth_date);
        SET NEW.person_id = new_pid;
    END IF;
END;
