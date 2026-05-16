-- ============================================================================
-- 05_message_templates — 마스터 시드 (알림 템플릿 6건)
--
-- 합의 근거: request §6 (각 template_type 기본값 6건)
--           migration 20260514074640 (payment_paid 명명 정렬)
-- 자연키:    (tenant_id, template_type, channel) UNIQUE
-- 의존:      01_academies
--
-- template_type 6종 (백엔드 운영 알림 핵심 이벤트):
--   - payment_due_reminder   결제 예정 안내 (자정 배치)
--   - payment_paid           결제 완료 영수증
--   - payment_overdue        연체 발생 안내
--   - attendance_absent      결석 통보 (학부모)
--   - attendance_late        지각 통보 (학부모)
--   - enrollment_welcome     신규 등록 환영
--
-- 채널: 전 항목 'sms' (MVP). 향후 email/push/kakao 채널 추가는 별도 row 발급.
-- ============================================================================

USE ProjectRG_Dev;

SET @academy_id := (SELECT id FROM academies WHERE business_number = '000-00-00000');

INSERT INTO message_templates (id, tenant_id, template_type, channel, title, body, is_enabled, timing_config) VALUES
    (UUID_TO_BIN('51111111-1111-1111-1111-111111111111', 1), @academy_id, 'payment_due_reminder', 'sms', NULL,
     '[{academy_name}] {student_name} 학생의 {billing_item} {amount}원 결제 예정일이 {due_date}입니다.', 1,
     JSON_OBJECT('days_before_due', 3)),
    (UUID_TO_BIN('52222222-2222-2222-2222-222222222222', 1), @academy_id, 'payment_paid', 'sms', NULL,
     '[{academy_name}] {student_name} 학생의 {billing_item} {amount}원 결제가 완료되었습니다. 감사합니다.', 1,
     NULL),
    (UUID_TO_BIN('53333333-3333-3333-3333-333333333333', 1), @academy_id, 'payment_overdue', 'sms', NULL,
     '[{academy_name}] {student_name} 학생의 {billing_item} {amount}원이 연체되었습니다. 확인 부탁드립니다.', 1,
     JSON_OBJECT('days_after_due', 1)),
    (UUID_TO_BIN('54444444-4444-4444-4444-444444444444', 1), @academy_id, 'attendance_absent', 'sms', NULL,
     '[{academy_name}] {student_name} 학생이 오늘 {class_name} 수업에 결석했습니다.', 1,
     NULL),
    (UUID_TO_BIN('55555555-5555-5555-5555-555555555555', 1), @academy_id, 'attendance_late', 'sms', NULL,
     '[{academy_name}] {student_name} 학생이 오늘 {class_name} 수업에 지각했습니다.', 1,
     NULL),
    (UUID_TO_BIN('56666666-6666-6666-6666-666666666666', 1), @academy_id, 'enrollment_welcome', 'sms', NULL,
     '[{academy_name}] {student_name} 학생의 등록을 환영합니다. 첫 수업일은 {start_date}입니다.', 1,
     NULL)
ON DUPLICATE KEY UPDATE
    body          = VALUES(body),
    is_enabled    = VALUES(is_enabled),
    timing_config = VALUES(timing_config);
