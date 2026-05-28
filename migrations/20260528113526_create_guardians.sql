-- ============================================================================
-- guardians — 글로벌 보호자 계정 (학부모 앱 로그인) — Phase 5 v1
--
-- 합의 근거:
--   user-add-process-supplement.md §2.1 + Backend v2 response (B6 X + B1' guardian-first)
--
-- 결정:
--   - B6 X: user_accounts 와 별도 stack (인증/JWT secret 분리)
--   - B1' guardian-first: phone UNIQUE 가 1차 lookup 키 (POST /persons/lookup-by-guardian-phone)
--   - B4' SMS OTP 통일: password_hash 는 OTP 인증 후 임시 token / refresh 패턴 (Backend 결정)
--
-- 영향:
--   - 신규 테이블 — 기존 데이터 영향 0
--   - Backend phase 진입 시 /auth/guardian/* endpoint set 신설
-- ============================================================================

-- migrate:up

CREATE TABLE guardians (
  id              BINARY(16)   NOT NULL,
  phone           VARCHAR(20)  NOT NULL COMMENT 'B1'' 1차 lookup 키 — exact match',
  name            VARCHAR(100) NOT NULL,
  email           VARCHAR(255) DEFAULT NULL,
  password_hash   VARCHAR(255) DEFAULT NULL COMMENT 'B4'' SMS OTP 통일 — 비밀번호 인증 옵션',
  last_login_at   DATETIME     DEFAULT NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_guardians_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='글로벌 보호자 계정 (학부모 앱 로그인) — user_accounts 와 별도 인증 stack';

-- migrate:down

DROP TABLE guardians;
