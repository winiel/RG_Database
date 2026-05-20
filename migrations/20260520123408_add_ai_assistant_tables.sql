-- ============================================================================
-- AI 비서 (Claude tool use 기반 mutation) v1 — DB 변경
--
-- 합의 근거:
--   제안:    RG_Common/Document/RG_Backend/2026-05-20-ai-assistant-crud-proposal.md
--   회신:    RG_Common/Document/RG_Database/2026-05-20-response-ai-assistant-crud-to-backend.md
--   채택:    RG_Common/Document/RG_Backend/2026-05-20-followup-to-database-class-color-and-ai-assistant.md
--            (백엔드 §2 — 4가지 보정 모두 채택 + 추가 인덱스 채택)
--
-- v1 범위:
--   1. ai_assistant_audit_log — AI 발화로 인한 mutation 추적 (회계·분쟁 대응, 보존 2년)
--   2. ai_assistant_sessions  — Claude 멀티턴 컨텍스트 보관 (TTL 24h)
--
-- DDL 결정 사항 (회신 §5 최종 안 그대로):
--   - 명명 규칙: idx_<table>_<columns>, chk_<table>_<column>, pk_<table>
--   - result_status enum: 'proposed','confirmed','cancelled','failed','expired' (5종)
--     ('expired'는 v2 cleanup 잡에서 활성. v1은 컬럼/CHECK만 준비)
--   - messages: JSON 유지 (회신 Q6)
--   - audit log 보존: 2년 운영 정책 (활성 1년 + 아카이브 1년) — DDL 자체엔 미반영, cron 잡(v2)
--   - 추가 인덱스: idx_ai_assistant_audit_log_session_id (회신 §Q5, session 묶음 조회)
--   - FK 미선언 (정책 §3-4) — 앱 측 검증
-- ============================================================================

-- migrate:up

-- 1. ai_assistant_audit_log — AI 비서 발화·tool 호출·결과 audit
CREATE TABLE ai_assistant_audit_log (
    id            BINARY(16)   NOT NULL,
    tenant_id     BINARY(16)   NOT NULL,
    user_id       BINARY(16)   NOT NULL                COMMENT 'user_accounts.id (학원장)',
    session_id    BINARY(16)   NOT NULL                COMMENT 'ai_assistant_sessions.id',
    utterance     TEXT         NOT NULL                COMMENT '사용자 발화 원문',
    tool_name     VARCHAR(50)  DEFAULT NULL            COMMENT '호출된 tool 이름. read-only 발화는 NULL',
    tool_args     JSON         DEFAULT NULL            COMMENT 'tool 인자 (학원장이 confirm한 최종 값)',
    result_status VARCHAR(20)  NOT NULL                COMMENT '''proposed'' | ''confirmed'' | ''cancelled'' | ''failed'' | ''expired''',
    result_data   JSON         DEFAULT NULL            COMMENT '응답 row brief 또는 에러 사유',
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ai_assistant_audit_log PRIMARY KEY (id),
    CONSTRAINT chk_ai_assistant_audit_log_result_status CHECK (
        result_status IN ('proposed','confirmed','cancelled','failed','expired')
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX idx_ai_assistant_audit_log_tenant_id_user_id_created_at
    ON ai_assistant_audit_log (tenant_id, user_id, created_at);
CREATE INDEX idx_ai_assistant_audit_log_session_id
    ON ai_assistant_audit_log (session_id);

-- 2. ai_assistant_sessions — Claude 멀티턴 메시지 이력 (TTL 24h)
CREATE TABLE ai_assistant_sessions (
    id          BINARY(16) NOT NULL,
    tenant_id   BINARY(16) NOT NULL,
    user_id     BINARY(16) NOT NULL                    COMMENT 'user_accounts.id (학원장)',
    messages    JSON       NOT NULL                    COMMENT 'Claude 메시지 이력 [{"role","content"},...]',
    expires_at  DATETIME   NOT NULL                    COMMENT 'TTL 만료 시각 (보통 created_at + 24h)',
    created_at  DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_ai_assistant_sessions PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX idx_ai_assistant_sessions_tenant_id_user_id
    ON ai_assistant_sessions (tenant_id, user_id);
CREATE INDEX idx_ai_assistant_sessions_expires_at
    ON ai_assistant_sessions (expires_at);

-- migrate:down

DROP TABLE IF EXISTS ai_assistant_sessions;
DROP TABLE IF EXISTS ai_assistant_audit_log;
