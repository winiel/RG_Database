-- ============================================================================
-- message_templates.template_type 값 정렬: 'payment_completed' → 'payment_paid'
--
-- 합의 근거:
--   request: RG_Common/request/RG_Database/2026-05-14-template-type-rename-request.md
--   배경:    백엔드 TemplateType Literal 정렬 + payment_status='paid' 와 단어 통일
--
-- 영향:
--   - message_templates.template_type 은 VARCHAR(50) 자유 문자열 (CHECK 없음)
--   - UNIQUE (tenant_id, template_type, channel) 제약은 채널 단위 충돌 시에만 위반
--   - 현재 적재 row: 0건 예상 (master seed 미작성 — Phase 2 Week 3). no-op 안전.
--   - 'absent_pending' 은 정렬 대상 아님 (출결 상태 vs 알림 키 도메인 분리, request §6)
-- ============================================================================

-- migrate:up

UPDATE message_templates
SET template_type = 'payment_paid'
WHERE template_type = 'payment_completed';

-- migrate:down

UPDATE message_templates
SET template_type = 'payment_completed'
WHERE template_type = 'payment_paid';
