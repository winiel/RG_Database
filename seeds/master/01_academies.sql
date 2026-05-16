-- ============================================================================
-- 01_academies — 마스터 시드 (학원)
--
-- 합의 근거: request §6 + response §5.6 (멱등 upsert)
-- 자연키:    business_number UNIQUE
-- 적용:      mysql ... < seeds/master/01_academies.sql
-- 운영:      재실행 안전 (ON DUPLICATE KEY UPDATE)
--
-- 의도:
--   - dev/test 환경 부트스트랩용 "ProjectRG 기본 학원" 1개
--   - 더미 시드(서유기학원, seoyugi_demo.sql)와 별도 학원이라 동거 가능
--   - production 부트스트랩에는 사용 안 함 (실 학원은 가입 플로우로 생성)
-- ============================================================================

USE ProjectRG_Dev;

INSERT INTO academies (id, name, business_number, address, phone, email, logo_url, operating_hours)
VALUES (
    UUID_TO_BIN('11111111-1111-1111-1111-111111111111', 1),
    'ProjectRG 기본 학원',
    '000-00-00000',
    NULL,
    NULL,
    'admin@projectrg.kr',
    NULL,
    JSON_OBJECT(
        'mon', '09:00-22:00', 'tue', '09:00-22:00', 'wed', '09:00-22:00',
        'thu', '09:00-22:00', 'fri', '09:00-22:00',
        'sat', '10:00-18:00', 'sun', 'closed'
    )
)
ON DUPLICATE KEY UPDATE
    name            = VALUES(name),
    address         = VALUES(address),
    phone           = VALUES(phone),
    email           = VALUES(email),
    operating_hours = VALUES(operating_hours);
