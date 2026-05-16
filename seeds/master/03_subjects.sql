-- ============================================================================
-- 03_subjects — 마스터 시드 (과목 4건)
--
-- 합의 근거: request §6 (taekwondo, art, ballet, gym + color_token)
-- 자연키:    (tenant_id, name) UNIQUE
-- 의존:      01_academies
-- ============================================================================

USE ProjectRG_Dev;

SET @academy_id := (SELECT id FROM academies WHERE business_number = '000-00-00000');

INSERT INTO subjects (id, tenant_id, name, color_token) VALUES
    (UUID_TO_BIN('31111111-1111-1111-1111-111111111111', 1), @academy_id, '태권도', 'red-500'),
    (UUID_TO_BIN('32222222-2222-2222-2222-222222222222', 1), @academy_id, '미술',   'yellow-500'),
    (UUID_TO_BIN('33333333-3333-3333-3333-333333333333', 1), @academy_id, '발레',   'pink-500'),
    (UUID_TO_BIN('34444444-4444-4444-4444-444444444444', 1), @academy_id, '체조',   'blue-500')
ON DUPLICATE KEY UPDATE
    color_token = VALUES(color_token);
