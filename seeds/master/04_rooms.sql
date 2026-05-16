-- ============================================================================
-- 04_rooms — 마스터 시드 (강의실 2건)
--
-- 합의 근거: request §6 (2~3건, "1관"/"2관")
-- 자연키:    (tenant_id, name) UNIQUE
-- 의존:      01_academies
-- ============================================================================

USE ProjectRG_Dev;

SET @academy_id := (SELECT id FROM academies WHERE business_number = '000-00-00000');

INSERT INTO rooms (id, tenant_id, name, description) VALUES
    (UUID_TO_BIN('41111111-1111-1111-1111-111111111111', 1), @academy_id, '1관', '기본 강의실 A'),
    (UUID_TO_BIN('42222222-2222-2222-2222-222222222222', 1), @academy_id, '2관', '기본 강의실 B')
ON DUPLICATE KEY UPDATE
    description = VALUES(description);
