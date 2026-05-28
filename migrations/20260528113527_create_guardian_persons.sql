-- ============================================================================
-- guardian_persons — 보호자 ↔ 아이 매핑 (claimed 상태) — Phase 5 v1
--
-- 합의 근거:
--   user-add-process-supplement.md §2.1 + B10 Z (형제자매 자동 매칭 + confirm)
--
-- 결정:
--   - N:M (guardian 1명 → 자녀 N명, 자녀 1명 → 보호자 N명 = 부모 + 조부모 등)
--   - UNIQUE (guardian_id, person_id) — 중복 방지
--   - INDEX (person_id) — 학원장 fuzzy match 후 자녀 조회 패턴
--   - relationship 자유 (mother / father / guardian / grandparent 등) — 앱 레이어 검증
--
-- 영향:
--   - 신규 테이블 — 기존 데이터 영향 0
--   - FK 없음 (프로젝트 정책 정합, B8 X 의 person/guardian orphan-scan 별도 사이클)
-- ============================================================================

-- migrate:up

CREATE TABLE guardian_persons (
  id            BINARY(16)   NOT NULL,
  guardian_id   BINARY(16)   NOT NULL,
  person_id     BINARY(16)   NOT NULL,
  relationship  VARCHAR(20)  NOT NULL COMMENT 'mother | father | guardian | grandparent | other',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_guardian_persons (guardian_id, person_id),
  KEY idx_guardian_persons_person (person_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='보호자 ↔ 아이 매핑 (claimed 상태) — 형제자매 자동 그룹 매칭 SOURCE';

-- migrate:down

DROP TABLE guardian_persons;
