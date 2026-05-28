-- ============================================================================
-- trg_students_auto_person_id — students INSERT 시 person_id 자동 생성 trigger
--
-- 합의 근거:
--   request/RG_Database/2026-05-28-students-auto-person-id-trigger-request.md
--   (RG_Backend → RG_Database, 2026-05-28 21:08, P0)
--
-- 결정 (B8 X 정합):
--   - BEFORE INSERT 시 person_id IS NULL 이면 신규 persons row 생성 + 연결
--   - person_id 명시 시 (학원장 수동 통합 / merge-person endpoint) 그대로 통과
--   - persons 신규 row 의 name/birth_date 는 students 컬럼 복사 (B5 X — PII 사본 유지)
--   - persons.id 는 UUID v1 + swap_flag=1 (BINARY(16), 시간 부분 swap 으로 인덱스 최적화)
--
-- DB 권장 보강 (Backend 요청 대비):
--   - user variable (@new_pid) → local DECLARE (new_pid BINARY(16)) 로 변경
--     사유: user variable 은 session-scoped — 동일 connection 다중 INSERT 시 race 위험.
--           local variable 은 trigger 호출마다 고유 scope.
--   - 그 외 동작 사양은 Backend 요청 100% 동등
--
-- 영향:
--   - 신규 trigger 1건 — 기존 students/persons 데이터 영향 0
--   - Backend INSERT 통합 테스트 17건 자동 복원 (코드 변경 0)
--   - 시드 (seoyugi_demo.sql / master) — 기존 INSERT 가 person_id 명시 시 통과,
--     미명시 시 trigger 가 자동 생성 (정합)
--
-- 적용 주의:
--   - dbmate 2.x parser 는 BEGIN/END 블록 내 ';' 를 statement 분할자로 오인 →
--     multiStatements=true 옵션 필요:
--     DATABASE_URL="mysql://...?multiStatements=true" dbmate up
-- ============================================================================

-- migrate:up

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

-- migrate:down

DROP TRIGGER trg_students_auto_person_id;
