-- ============================================================================
-- teachers.memo 컬럼 추가 (학원장 자유 메모)
--
-- 합의 근거:
--   request: RG_Common/request/RG_Database/2026-05-16-teachers-memo-column-request.md
--   디렉터 결정: RG_Common/Document/RG_Director/2026-05-16-decisions-on-teacher-fields-response.md Q2
--
-- 결정:
--   타입: TEXT NULL (학생 메모 student_notes.content 와 통일)
--   멀티라인: 허용 (어플리케이션 UI textarea + pre-wrap)
--   길이 가드: 어플리케이션 단 (백엔드 재량, 권장 ~5,000자)
--
-- 영향:
--   - 기존 row: NULL 기본값으로 자연 추가 — 백필 불필요
--   - 백엔드 응답: 현재 항상 null → 컬럼 활성 후 실값 노출 (백엔드 후속 작업, 분량 ~30분)
--   - 시드: seoyugi_demo 의 2명 강사에 데모용 memo 예시 추가 (별도 시드 갱신)
-- ============================================================================

-- migrate:up

ALTER TABLE teachers
    ADD COLUMN memo TEXT NULL COMMENT '강사 내부 메모 (학원장 자유 입력, multi-line)';

-- migrate:down

ALTER TABLE teachers
    DROP COLUMN memo;
