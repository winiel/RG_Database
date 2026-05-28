-- ============================================================================
-- attendances.memo 컬럼 추가 (수업 일지 — 학생 × 클래스 × 날짜별 메모)
--
-- 합의 근거:
--   Director request: RG_Common/request/RG_Backend/2026-05-28-class-session-memo-request.md (265ff1a)
--   Backend response: RG_Common/Document/RG_Backend/2026-05-28-class-session-memo-response.md (16cb8cd)
--   Backend → DB request: RG_Common/request/RG_Database/2026-05-28-attendances-memo-column-request.md
--
-- 결정 (Q1~Q5 + Q-A~Q-E 정합):
--   타입:     VARCHAR(500) NULL — 평균 일지 분량 (한글 ~250자) + 여유
--   위치:     AFTER absence_reason — 관련 운영 메타 그룹
--   인덱스:   불요 — 검색 키 아님 (v2 full-text 별도 사이클)
--   디폴트:   NULL — 미기록 attendance row 자연
--   빈 문자열: Backend Q-B 회신 — 그대로 저장 (clear 분기 없음)
--
-- 도메인 구분:
--   학생 메모 (student_notes 또는 students.memo)  — 알레르기/특이사항 등 영구 정보
--   수업 일지 (attendances.memo, 본 컬럼)          — 그날 컨디션/진도/통보 등 시계열 기록
--   두 메모는 별개 도메인, 공존
--
-- 영향:
--   기존 row:    NULL 기본값으로 자연 추가 — 백필 불필요
--   백엔드:      Attendance schema 에 memo: str | None 필드 추가 (별도 사이클)
--   더미 시드:   seoyugi_demo.sql 일부 attendance row 에 시연용 memo UPDATE 동봉 (Q-D Y)
-- ============================================================================

-- migrate:up

ALTER TABLE attendances
    ADD COLUMN memo VARCHAR(500) NULL COMMENT '수업 일지 (강사·원장이 매 수업 종료 후 학생 단위 기록)'
    AFTER absence_reason;

-- migrate:down

ALTER TABLE attendances
    DROP COLUMN memo;
