-- ============================================================================
-- persons — 글로벌 인물 (학생/아이) — Phase 5 person-centric 모델 v1
--
-- 합의 근거:
--   user-add-process-supplement.md §2.1 + Backend v2 response (B5 X)
--
-- 결정 (B5 X):
--   - persons 는 최소 식별자만 (name + birth_date + gender)
--   - PII 사본은 students 에 유지 (학원별 격리 원칙)
--   - 자연키 UNIQUE 없음 — 동명이인 허용, fuzzy match 로 후보 노출 (fallback)
--   - 1차 lookup 은 guardians.phone (B1' guardian-first)
--
-- 영향:
--   - 신규 테이블 — 기존 데이터 영향 0
--   - students.person_id ALTER + backfill 은 별도 사이클 (마이그 6, 사용자 발화 후)
-- ============================================================================

-- migrate:up

CREATE TABLE persons (
  id          BINARY(16)   NOT NULL,
  name        VARCHAR(100) NOT NULL,
  birth_date  DATE         DEFAULT NULL,
  gender      VARCHAR(10)  DEFAULT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_persons_name_birth (name, birth_date),
  CONSTRAINT chk_persons_gender CHECK ((gender IS NULL) OR (gender IN ('male', 'female', 'other')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='글로벌 인물 (학생/아이) — 학부모 앱 통합 뷰 SOURCE';

-- migrate:down

DROP TABLE persons;
