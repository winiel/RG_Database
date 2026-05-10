-- ============================================================================
-- attendances.absence_category 에 'school' 카테고리 추가
--
-- 합의 근거:
--   request: RG_Common/request/RG_Database/2026-05-10-director-database-request.md §2
--   회신:   RG_Common/Document/RG_Database/2026-05-10-response-to-director.md §3
--
-- 변경: CHECK 제약 4종 → 5종 (sick | family | travel | school | other)
-- 데이터 영향: 신규 값 추가만, 기존 데이터 백필 불필요
-- ============================================================================

-- migrate:up

ALTER TABLE attendances DROP CONSTRAINT chk_attendances_absence_category;
ALTER TABLE attendances ADD CONSTRAINT chk_attendances_absence_category
    CHECK (absence_category IS NULL OR absence_category IN ('sick', 'family', 'travel', 'school', 'other'));

-- migrate:down

ALTER TABLE attendances DROP CONSTRAINT chk_attendances_absence_category;
ALTER TABLE attendances ADD CONSTRAINT chk_attendances_absence_category
    CHECK (absence_category IS NULL OR absence_category IN ('sick', 'family', 'travel', 'other'));
-- ⚠️ down 적용 시 'school'로 분류된 기존 행이 있으면 CHECK 위반. 사전 정리 필요.
