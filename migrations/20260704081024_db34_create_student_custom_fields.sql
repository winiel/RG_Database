-- migrate:up
-- DB34-STUDENT-CUSTOM-FIELDS (DB-34 ①) — 학원별 학생 커스텀 필드 정의 테이블 신설
--
-- 발의: request/RG_Database/2026-07-04-db34-student-custom-fields-request.md
-- 근거: 학원장 지시 — 학생 정보에 학원마다 다른 "커스텀 필드"를 설정에서 관리.
--       ① 5개 ② 각 필드 개별 사용여부(on/off·미사용 미표시) ③ 제목 학원별 상이
--       ④ 타입 3종(문자/숫자/선택박스·select 옵션은 배열 JSON) ⑤ 사용→미사용 전환 시 학생 값 초기화(BE-69).
-- cross-ref: subjects·ability_tracks(options json + CHECK) 정의 패턴 복제. 값 컬럼은 ②(students.custom_values).
--
-- 설계 요지:
--   - slot 1~5 고정(학원당 5슬롯)·UNIQUE(tenant_id, slot) 슬롯 중복 방지.
--   - enabled DEFAULT 0(기본 미사용) — 신규 슬롯 off 시작. 미사용 필드는 학생 정보 미표시(BE-69/DIR-109).
--   - field_type CHECK IN('text','number','select'). options=select 옵션 배열 JSON(json_valid CHECK).
--     select-options 정합(select만 options)·"|" split 파싱은 앱 레벨(BE-69/DIR-109·강건성).
--   - 물리 FK 없음(현행 컨벤션·앱 레벨 무결성). 검색 요구 없어 인덱스는 UNIQUE(tenant,slot)만.
--   - 5슬롯 seed(빈 5행)는 BE-69 upsert 관리 위임 — 본 마이그는 스키마만(seed 없음).
--
-- 영향: 신규 테이블 추가만(additive). 기존 쿼리 무영향(BE-69 라이브 전 미소비·적용 직후 0행).
--       트리거/SP 없음. 롤백 가능(down = DROP TABLE).

CREATE TABLE `student_custom_fields` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `tenant_id` binary(16) NOT NULL,
  `slot` tinyint NOT NULL COMMENT '슬롯 1~5',
  `enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT '사용여부(1=사용·0=미사용)',
  `title` varchar(60) DEFAULT NULL COMMENT '학원별 필드 제목',
  `field_type` varchar(16) NOT NULL COMMENT 'text|number|select',
  `options` json DEFAULT NULL COMMENT '선택박스 옵션 배열(select 타입만)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_student_custom_fields_tenant_id_slot` (`tenant_id`,`slot`),
  CONSTRAINT `chk_student_custom_fields_slot` CHECK ((`slot` between 1 and 5)),
  CONSTRAINT `chk_student_custom_fields_type` CHECK ((`field_type` in ('text','number','select'))),
  CONSTRAINT `chk_student_custom_fields_options` CHECK (((`options` is null) or json_valid(`options`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='학생 커스텀 필드 정의 — 학원(테넌트)별 5슬롯. 값은 students.custom_values(JSON). 미사용 필드 미표시·타입 text|number|select';

-- migrate:down

DROP TABLE `student_custom_fields`;
