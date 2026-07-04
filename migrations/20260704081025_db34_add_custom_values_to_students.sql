-- migrate:up
-- DB34-STUDENT-CUSTOM-VALUES (DB-34 ②) — students 커스텀 필드 값 JSON 컬럼 신설
--
-- 발의: request/RG_Database/2026-07-04-db34-student-custom-fields-request.md §1.2
-- 근거: 학생별 커스텀 필드 값 저장처. 정의는 ①(student_custom_fields), 값은 본 컬럼.
-- cross-ref: students.parent json 선례(동일 테이블 JSON 컬럼 컨벤션).
--
-- 설계 요지:
--   - custom_values JSON NULL — 값 형태 {slot: value}(예: {"1":"지인추천","3":"010-1234-5678"}).
--   - 검색 요구 없어 JSON 최소 구현(인덱스 미부여). parent_phone 뒤(도메인 컬럼 뒤·감사 컬럼 앞) 배치.
--   - ★사용→미사용 전환 시 해당 slot 키 제거(재사용해도 옛 값 미표시) — 키 제거 트랜잭션은 BE-69.
--     본 마이그는 컬럼만 신설.
--
-- 영향: 컬럼 추가만(additive·JSON NULL). 기존 students 행 무영향·전 행 NULL(회귀 0).
--       트리거/SP 없음. 롤백 가능(down = DROP COLUMN).

ALTER TABLE `students`
  ADD COLUMN `custom_values` json DEFAULT NULL
    COMMENT '학생별 커스텀 필드 값 {slot: value}. 미사용 전환 시 해당 slot 키 제거(BE-69)'
    AFTER `parent_phone`;

-- migrate:down

ALTER TABLE `students`
  DROP COLUMN `custom_values`;
