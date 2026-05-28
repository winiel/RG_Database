-- ============================================================================
-- students.person_id 추가 + 1:1 backfill — Phase 5 v1 마이그 6 (B8 X 채택)
--
-- 합의 근거:
--   user-add-process-supplement.md §2.1 + Backend v2 response (B8 X — 1:1 신규 person + 후보 노출)
--
-- 결정 (B8 X):
--   - 기존 students 마다 신규 person 1:1 생성 (자연키 매칭 안 함 — orphan/오매칭 risk 차단)
--   - 학원장 통합은 별도 endpoint POST /students/{id}/merge-person (Backend phase 진입 시)
--   - persons 사양 정합 (B5 X) — name + birth_date 복사
--   - gender 는 NULL (학생 PII 에 없음 — 추후 별도 입력)
--
-- 단계 (단일 트랜잭션):
--   1. students.person_id NULLABLE 컬럼 추가
--   2. 임시 매핑 테이블 _person_backfill_map 생성
--   3. 각 student 마다 신규 person UUID 매핑
--   4. persons 일괄 INSERT (name/birth_date 복사)
--   5. students.person_id UPDATE
--   6. NOT NULL 전환
--   7. INDEX 추가
--   8. 임시 테이블 DROP
--
-- 영향:
--   - 기존 students row: person_id 채워짐 (1:1 신규 person)
--   - persons row: students 수만큼 신규 생성 (로컬 13, RDS 18 예상)
--   - 운영 중지 불요 (DDL + DML — 짧은 락만)
--   - Backend `/students` 응답 schema 변경 없음 (Backend SELECT person_id 미참조)
-- ============================================================================

-- migrate:up

-- Step 1: NULLABLE 컬럼 추가
ALTER TABLE students
    ADD COLUMN person_id BINARY(16) DEFAULT NULL AFTER tenant_id;

-- Step 2: 임시 매핑 테이블
CREATE TEMPORARY TABLE _person_backfill_map (
    student_id    BINARY(16) PRIMARY KEY,
    new_person_id BINARY(16) NOT NULL
);

-- Step 3: 각 student 별 신규 person UUID 매핑
INSERT INTO _person_backfill_map (student_id, new_person_id)
SELECT id, UUID_TO_BIN(UUID(), 1) FROM students;

-- Step 4: persons 일괄 INSERT (PII 사본 — B5 X)
INSERT INTO persons (id, name, birth_date, gender)
SELECT m.new_person_id, s.name, s.birth_date, NULL
FROM students s
JOIN _person_backfill_map m ON m.student_id = s.id;

-- Step 5: students.person_id 채우기
UPDATE students s
JOIN _person_backfill_map m ON m.student_id = s.id
SET s.person_id = m.new_person_id;

-- Step 6: NOT NULL 전환
ALTER TABLE students MODIFY person_id BINARY(16) NOT NULL;

-- Step 7: INDEX 추가
ALTER TABLE students ADD INDEX idx_students_person_id (person_id);

-- Step 8: 임시 테이블 명시 DROP (세션 종료 시 자동 drop 이지만 명시)
DROP TEMPORARY TABLE _person_backfill_map;

-- migrate:down

-- 역순 — INDEX 제거 → 컬럼 제거 → persons 의 backfill row 는 그대로 두기 (수동 정리)
-- 주의: persons row 자체는 정리 안 함 (다른 데이터와 연결됐을 수 있음 — guardian_persons 등)
-- 운영에서 down 권장 X (데이터 손실)
ALTER TABLE students DROP INDEX idx_students_person_id;
ALTER TABLE students DROP COLUMN person_id;
