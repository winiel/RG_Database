-- migrate:up
-- 백엔드 요청서: RG_Common request/RG_Database/2026-05-27-student-abilities-score-int-alignment-request.md (410fcc4)
-- DB 의견서 A5 (default_score INT vs score DECIMAL 타입 불일치) 정합 + Director D1 F=X 채택.
-- 사전 점검 결과: 로컬 + AWS production RDS 모두 소수점 행 0건 → 옵션 1 (단순 ALTER) 적용.
-- CHECK 제약 (chk_student_abilities_score, 0~100) 은 그대로 유지.
ALTER TABLE student_abilities
    MODIFY COLUMN score INT NOT NULL DEFAULT 0;

-- migrate:down
-- INT → DECIMAL 무손실 변환. DEFAULT 0 도 down 대상에서 명시 제거 (원래 DEFAULT 없었음).
ALTER TABLE student_abilities
    MODIFY COLUMN score DECIMAL(5,2) NOT NULL;
