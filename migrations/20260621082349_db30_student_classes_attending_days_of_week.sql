-- migrate:up
-- DB30-STUDENT-CLASS-ATTENDING-DAYS (DB-30) — student_classes 학생별 부분 등원요일 컬럼 신설
--
-- 발의: request/RG_Database/2026-06-21-db30-student-class-attending-days-request.md
-- 근거: 부분 등원 기능 — 학생이 클래스 전 요일이 아닌 일부 요일만 등원하는 케이스 지원.
--       BE-53(런타임 요소 검증·등원요일 적용)·DIR-90 체인의 DB 선행(스키마 먼저 깔고 BE/DIR 진입).
-- cross-ref: classes.days_of_week CHECK 패턴(chk_classes_days_of_week_not_empty,
--       migrations/20260604053804_..._to_classes.sql §3.5)을 그대로 미러 —
--       JSON_LENGTH >= 1 빈배열 거부만, JSON_TYPE 검사·요소 0~6 범위 CHECK 없음.
--
-- 설계 요지:
--   - attending_days_of_week = JSON NULL DEFAULT NULL, status 컬럼 뒤(AFTER status) 배치.
--   - 의미: NULL = 클래스 전 요일 추종(현행·하위호환·기존 행 동작 무변경),
--           non-NULL = 클래스 요일의 부분집합(JSON 배열, 0=일 ~ 6=토).
--   - CHECK = (attending_days_of_week IS NULL) OR (JSON_LENGTH(attending_days_of_week) >= 1)
--           → NULL 허용 + 빈 배열만 거부. 요소 범위(0~6)는 BE-53 런타임 검증(발의서 지시).
--   - 교차 부분집합(⊆ classes.days_of_week) CHECK 절대 금지:
--           클래스 요일이 나중에 바뀌어도 student_classes 행이 깨지지 않도록 강건성 확보
--           (부분집합 정합은 BE 런타임 책임). DB는 빈배열만 막는다.
--
-- 영향: 컬럼 추가 + CHECK 제약만(DDL only). 백필 없음 — 기존 행 전부 NULL 유지(현행 동작 동일).
--       트리거/SP 없음. 롤백 가능(down = DROP CONSTRAINT + DROP COLUMN).

ALTER TABLE student_classes
  ADD COLUMN attending_days_of_week json DEFAULT NULL AFTER status,
  ADD CONSTRAINT chk_student_classes_attending_days_not_empty
    CHECK ((attending_days_of_week IS NULL) OR (JSON_LENGTH(attending_days_of_week) >= 1));

-- migrate:down

ALTER TABLE student_classes
  DROP CONSTRAINT chk_student_classes_attending_days_not_empty,
  DROP COLUMN attending_days_of_week;
