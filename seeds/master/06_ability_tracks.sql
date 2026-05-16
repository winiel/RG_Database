-- ============================================================================
-- 06_ability_tracks — 마스터 시드 (능력 트랙)
--
-- 합의 근거: request §6 ("N건, 종목별 트랙, RG_Director 시안 참조")
-- 자연키:    (tenant_id, name) UNIQUE
-- 의존:      01_academies, 03_subjects
--
-- 현 시점 디자인:
--   - 종목별 1개 기본 트랙 (총 4건). MVP 최소.
--   - RG_Director 시안 도착 시 종목별 다단계 트랙 (예: 태권도 띠 체계) 확장 마이그레이션
--   - subject_id 는 nullable 이지만 본 마스터 시드는 모두 연결
-- ============================================================================

USE ProjectRG_Dev;

SET @academy_id    := (SELECT id FROM academies WHERE business_number = '000-00-00000');
SET @subj_taekwondo := (SELECT id FROM subjects WHERE tenant_id = @academy_id AND name = '태권도');
SET @subj_art       := (SELECT id FROM subjects WHERE tenant_id = @academy_id AND name = '미술');
SET @subj_ballet    := (SELECT id FROM subjects WHERE tenant_id = @academy_id AND name = '발레');
SET @subj_gym       := (SELECT id FROM subjects WHERE tenant_id = @academy_id AND name = '체조');

INSERT INTO ability_tracks (id, tenant_id, name, subject_id, description) VALUES
    (UUID_TO_BIN('61111111-1111-1111-1111-111111111111', 1), @academy_id, '태권도 기본 트랙', @subj_taekwondo, '기본 동작·품새·겨루기 단계별 평가'),
    (UUID_TO_BIN('62222222-2222-2222-2222-222222222222', 1), @academy_id, '미술 기본 트랙',   @subj_art,       '데생·색채·작품 단계별 평가'),
    (UUID_TO_BIN('63333333-3333-3333-3333-333333333333', 1), @academy_id, '발레 기본 트랙',   @subj_ballet,    '자세·바 워크·센터 워크 단계별 평가'),
    (UUID_TO_BIN('64444444-4444-4444-4444-444444444444', 1), @academy_id, '체조 기본 트랙',   @subj_gym,       '유연성·근력·균형 단계별 평가')
ON DUPLICATE KEY UPDATE
    subject_id  = VALUES(subject_id),
    description = VALUES(description);
