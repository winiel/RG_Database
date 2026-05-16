-- ============================================================================
-- 02_user_accounts — 마스터 시드 (학원장 계정)
--
-- 합의 근거: request §6 + response §5.6
-- 자연키:    email UNIQUE
-- 의존:      01_academies (tenant_id 조회)
--
-- 비밀번호: bcrypt('1111') — ⚠️ dev/test 한정. Stg/Prod 사용 금지.
-- ============================================================================

USE ProjectRG_Dev;

SET @academy_id := (SELECT id FROM academies WHERE business_number = '000-00-00000');

INSERT INTO user_accounts (id, tenant_id, email, password_hash, name, phone, role)
VALUES (
    UUID_TO_BIN('22222222-2222-2222-2222-222222222222', 1),
    @academy_id,
    'admin@projectrg.kr',
    '$2y$12$It3ax8hw2MDNNbB8VBshcOtipO422X4IdNYx0UpFLZ3JRe1XRZJDy',
    '관리자',
    NULL,
    'owner'
)
ON DUPLICATE KEY UPDATE
    tenant_id = VALUES(tenant_id),
    name      = VALUES(name),
    role      = VALUES(role);
