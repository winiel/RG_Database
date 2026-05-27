-- ============================================================================
-- teachers.pay_type + base_pay 도입, hourly_rate DROP
--
-- 합의 근거:
--   request:  RG_Common/request/RG_Database/2026-05-27-teachers-pay-type-column-request.md (0460c17)
--   원 요청:  RG_Common/request/RG_Backend/2026-05-27-teacher-pay-type-request.md (4861a44)
--
-- 결정 (RG_Database 측 자체):
--   - pay_type ENUM('annual','monthly','hourly') 채택 — Backend 권장 그대로 (CHECK string 보다 enum 명시가 ERD/도구 친화)
--   - base_pay INT UNSIGNED NULL — 원 단위, pay_type 에 종속
--   - 데이터 이관: 기존 hourly_rate 값을 base_pay 로 옮김 (pay_type 은 DEFAULT 'hourly' 자연 유지)
--   - hourly_rate DROP — Backend 옵션 X 채택 (호환 부담 없음)
--   - down 시 annual/monthly 금액 손실은 의도 (스키마 표현력 한계 — 백업 책임은 백엔드)
--
-- 영향:
--   - 시드: `seeds/dummy/seoyugi_demo.sql` 의 teachers INSERT 에 hourly_rate 명시 컬럼 있다면
--     별도 갱신 필요 (본 마이그레이션은 시드 미수정 — 시드 재실행 시 분리 갱신 권장)
--   - schema-changes-log.md 항목 추가 (sync-schema.sh 자동 동기 외 수동)
-- ============================================================================

-- migrate:up

ALTER TABLE teachers
    ADD COLUMN pay_type ENUM('annual','monthly','hourly') NOT NULL DEFAULT 'hourly'
        COMMENT '급여 형태 (연봉/월급/시간당)' AFTER employment_type,
    ADD COLUMN base_pay INT UNSIGNED NULL
        COMMENT '급여 금액 (원 단위, pay_type 에 종속)' AFTER pay_type;

UPDATE teachers
SET base_pay = CAST(hourly_rate AS UNSIGNED)
WHERE hourly_rate IS NOT NULL;

ALTER TABLE teachers
    DROP COLUMN hourly_rate;

-- migrate:down

ALTER TABLE teachers
    ADD COLUMN hourly_rate DECIMAL(10,2) NULL
        COMMENT '시간당 급여 (원)' AFTER employment_type;

UPDATE teachers
SET hourly_rate = base_pay
WHERE pay_type = 'hourly' AND base_pay IS NOT NULL;

ALTER TABLE teachers
    DROP COLUMN base_pay,
    DROP COLUMN pay_type;
