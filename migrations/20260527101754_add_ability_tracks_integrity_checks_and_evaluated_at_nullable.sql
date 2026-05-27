-- migrate:up
-- 백엔드 요청서: RG_Common request/RG_Database/2026-05-27-ability-tracks-integrity-and-evaluated-at-request.md (47e2ff3)
-- DB 의견서 A1 X + A2 X 채택 후속 합의 묶음 적용:
-- (1) ability_tracks.level_thresholds JSON 무결성 CHECK 2건 (앱 레이어 우회 가드)
-- (2) student_abilities.evaluated_at NULL 허용 + 의미 재정의
--     (NULL = enroll cascade 자동 초기화, NOT NULL = 학원장 명시 평가)
ALTER TABLE ability_tracks
    ADD CONSTRAINT chk_ability_tracks_level_thresholds_valid
        CHECK (level_thresholds IS NULL OR JSON_VALID(level_thresholds)),
    ADD CONSTRAINT chk_ability_tracks_level_thresholds_is_array
        CHECK (level_thresholds IS NULL OR JSON_TYPE(level_thresholds) = 'ARRAY');

ALTER TABLE student_abilities
    MODIFY COLUMN evaluated_at DATETIME NULL
        COMMENT '학원장 명시 평가 시각. NULL = enroll cascade 자동 초기화 (미평가).';

-- migrate:down
-- B1 보강 — DB 측 추가 안 (acknowledgment 8d7fa45 §2 참조)
-- cascade 후 evaluated_at IS NULL row 가 발생한 상태에서 down 시 NOT NULL 환원이
-- 즉시 실패하는 것을 방지하기 위해 사전 UPDATE 보정.
-- 대체값으로 created_at 사용 (cascade INSERT 시점 ≈ enroll 시점 정합).
UPDATE student_abilities
    SET evaluated_at = created_at
    WHERE evaluated_at IS NULL;

ALTER TABLE student_abilities
    MODIFY COLUMN evaluated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE ability_tracks
    DROP CONSTRAINT chk_ability_tracks_level_thresholds_is_array,
    DROP CONSTRAINT chk_ability_tracks_level_thresholds_valid;
