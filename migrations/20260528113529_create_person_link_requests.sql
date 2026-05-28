-- ============================================================================
-- person_link_requests — 학원 ↔ 학생 ↔ person 매칭 요청 워크플로우 — Phase 5 v1
--
-- 합의 근거:
--   user-add-process-supplement.md §3 (Type A' / B / C 워크플로우)
--
-- 결정:
--   - initiator ENUM: 'academy' (Type A' 학원장 주도) | 'guardian' (Type B 학부모 주도)
--   - status ENUM: 'pending' / 'approved' / 'rejected' / 'expired'
--   - expires_at — B2 Z (30일 예비, 운영 정책)
--   - tenant 격리 — 학원장 inbox 조회 (D2 알림 dock)
--
-- 영향:
--   - 신규 테이블 — 기존 데이터 영향 0
--   - FK 없음 (프로젝트 정책 정합)
--   - student_id 컬럼 보유하지만 students.person_id ALTER (마이그 6) 와는 무관 — 별도 사이클
-- ============================================================================

-- migrate:up

CREATE TABLE person_link_requests (
  id            BINARY(16)   NOT NULL,
  tenant_id     BINARY(16)   NOT NULL,
  student_id    BINARY(16)   NOT NULL,
  person_id     BINARY(16)   NOT NULL,
  initiator     VARCHAR(20)  NOT NULL COMMENT 'academy (Type A'') | guardian (Type B)',
  status        VARCHAR(20)  NOT NULL DEFAULT 'pending',
  requested_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at   DATETIME     DEFAULT NULL,
  expires_at    DATETIME     NOT NULL COMMENT 'B2 Z — 30일 권장 (운영 정책)',
  PRIMARY KEY (id),
  KEY idx_plr_tenant_status (tenant_id, status),
  KEY idx_plr_person_status (person_id, status),
  CONSTRAINT chk_plr_initiator CHECK (initiator IN ('academy', 'guardian')),
  CONSTRAINT chk_plr_status    CHECK (status IN ('pending', 'approved', 'rejected', 'expired'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='학원 ↔ 학생 ↔ person 매칭 요청 워크플로우 (Type A''/B)';

-- migrate:down

DROP TABLE person_link_requests;
