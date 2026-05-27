-- migrate:up
-- 백엔드 요청서: RG_Common request/RG_Database/2026-05-27-class-ability-tracks-cascade-request.md
-- (1) ability_tracks 에 default_score INT 컬럼 추가 — 학생 enroll cascade 시 student_abilities.score 초기값
-- (2) class_ability_tracks N:M join 테이블 신설 — 클래스 ↔ 능력치 트랙 매핑
ALTER TABLE ability_tracks
    ADD COLUMN default_score INT NOT NULL DEFAULT 0
        COMMENT '학생 enroll cascade 시 student_abilities.score 초기값 (0~100)'
        AFTER level_thresholds,
    ADD CONSTRAINT chk_ability_tracks_default_score
        CHECK (default_score >= 0 AND default_score <= 100);

CREATE TABLE class_ability_tracks (
    id BINARY(16) NOT NULL,
    tenant_id BINARY(16) NOT NULL,
    class_id BINARY(16) NOT NULL,
    ability_track_id BINARY(16) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_class_ability_tracks_tenant_class_track
        (tenant_id, class_id, ability_track_id),
    KEY idx_class_ability_tracks_tenant_class (tenant_id, class_id),
    KEY idx_class_ability_tracks_tenant_track (tenant_id, ability_track_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='클래스 ↔ 능력치 트랙 N:M 매핑 — 학생 enroll cascade 시 자동 평가 row 생성용';

-- migrate:down
DROP TABLE class_ability_tracks;

ALTER TABLE ability_tracks
    DROP CONSTRAINT chk_ability_tracks_default_score,
    DROP COLUMN default_score;
