-- ============================================================================
-- guardian_consents — 학부모 동의 audit 테이블 — Phase 5 v1 (B9 Y 채택)
--
-- 합의 근거:
--   user-add-process-supplement.md §2.1 + Backend v2 response (B9 Y audit 채택)
--
-- 결정 (B9 Y):
--   - audit 컬럼 6종: action / otp_verified_at / consented_at / revoked_at / ip_address / user_agent
--   - 개인정보보호법 시행령 §29 동의/철회 audit 요건 정합
--   - SMS OTP 검증 시각 보관 (B4' SMS 통일과 정합)
--   - 철회 시 revoked_at SET (row 삭제 X — 이력 보존)
--
-- action ENUM:
--   - claim_person       : 신규 person 연결 동의 (Type A' [A] / [B])
--   - link_to_academy    : 특정 학원 등록 동의 (Type B)
--   - revoke             : 기존 동의 철회 (학부모 명시 발화)
--   - reauth             : 재인증 (장기 미사용 후 재로그인 등)
-- ============================================================================

-- migrate:up

CREATE TABLE guardian_consents (
  id                BINARY(16)   NOT NULL,
  guardian_id       BINARY(16)   NOT NULL,
  person_id         BINARY(16)   NOT NULL,
  action            VARCHAR(30)  NOT NULL,
  otp_verified_at   DATETIME     NOT NULL COMMENT 'SMS OTP 검증 완료 시각 (B4'' SMS 통일)',
  consented_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at        DATETIME     DEFAULT NULL COMMENT 'NULL = 활성 / NOT NULL = 철회됨',
  ip_address        VARCHAR(45)  DEFAULT NULL COMMENT 'IPv4/IPv6 — audit 보강',
  user_agent        VARCHAR(255) DEFAULT NULL COMMENT 'client UA — audit 보강',
  PRIMARY KEY (id),
  KEY idx_consents_guardian (guardian_id, consented_at),
  KEY idx_consents_person (person_id, consented_at),
  CONSTRAINT chk_consent_action CHECK (action IN ('claim_person', 'link_to_academy', 'revoke', 'reauth'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='학부모 동의 audit (개인정보보호법 시행령 §29 정합)';

-- migrate:down

DROP TABLE guardian_consents;
