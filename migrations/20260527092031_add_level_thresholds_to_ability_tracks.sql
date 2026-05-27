-- migrate:up
-- 백엔드 요청서: RG_Common request/RG_Database/2026-05-27-ability-tracks-level-thresholds-request.md (옵션 C 하이브리드)
-- ability_tracks 에 등급 임계값 JSON 컬럼 추가 — score(0~100) 와 함께 자동 라벨 derive 용
ALTER TABLE ability_tracks
    ADD COLUMN level_thresholds JSON DEFAULT NULL
        COMMENT '등급 임계값 정의 — [{label, min_score, max_score}, ...]. NULL = 등급 미설정'
        AFTER description;

-- migrate:down
ALTER TABLE ability_tracks
    DROP COLUMN level_thresholds;
