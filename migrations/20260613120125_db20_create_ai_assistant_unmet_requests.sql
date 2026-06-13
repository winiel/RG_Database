-- migrate:up
-- DB20-UNMET-REQUEST-CAPTURE-SCHEMA (DB-20) — AI비서 미충족 요청 캡처 테이블 신설
--
-- 발의: request/RG_Database/2026-06-13-db20-unmet-request-capture-schema-request.md
-- 근거: AI비서 자유도 정책 정본(2026-06-13) ④ Graceful capability gap 백로그 캡처
--       — AI비서가 흡수 못한 틀 밖 요청 발화를 저장해 제품 신호화(다음 도구 우선순위 근거).
-- cross-ref: class_cancellations(DB-3)·billing_schedules(DB-5) 컨벤션 — binary(16) PK·tenant_id binary(16) NOT NULL·datetime·물리 FK 없음(앱 레벨 무결성)
-- 소비자: BE-46 캡처 엔드포인트가 INSERT 대상으로 사용(DB 선행).
--
-- 설계 요지:
--   - PK/tenant_id = binary(16) (전 테이블 컨벤션). tenant_id NOT NULL — 멀티테넌시 격리(누락 INSERT 차단).
--   - utterance = TEXT (긴 발화 원문 대비, varchar 길이 한계 회피).
--   - captured_at = datetime NOT NULL DEFAULT CURRENT_TIMESTAMP (캡처 시각·집계 시간 축).
--   - category/reason/session_id/user_id = nullable (캡처 시점 미분류·세션/사용자 미상 허용).
--   - 집계용 인덱스 (tenant_id, captured_at) — 테넌트별·기간별 집계.
--   - 물리 FK 없음 — 현행 스키마 전체가 앱 레벨 무결성(FK 미사용). 본 테이블도 동일.
--
-- 논리삭제 정책(DB-9) 판단: 본 테이블은 운영 엔티티가 아니라 신호 로그(append-only) →
--   is_deleted/deleted_at/deleted_by 미적용. 캡처된 발화는 수정·삭제 없이 누적만 함.
--   (PM 발의 §2.4 — Database 판단·사유 receipt 명시 요구. append-only 채택.)
--
-- 영향: 신규 테이블 추가만 — 기존 데이터 영향 0(적용 직후 0행). 트리거/SP 없음.

CREATE TABLE `ai_assistant_unmet_requests` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL COMMENT '학원 테넌트 — 멀티테넌시 격리(NOT NULL·누락 INSERT 차단). 조회/집계 tenant 범위 한정',
  `utterance` text NOT NULL COMMENT '미충족 요청 발화 원문(사용자 입력 텍스트 그대로). 긴 발화 대비 TEXT',
  `captured_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '캡처 시각 — 집계의 시간 축',
  `category` varchar(100) DEFAULT NULL COMMENT 'NULL 허용. 미충족 요청 분류(캡처 시점 미분류 가능·추후 BE/집계 채움 여지)',
  `reason` varchar(255) DEFAULT NULL COMMENT 'NULL 허용. 미충족 사유',
  `session_id` binary(16) DEFAULT NULL COMMENT 'NULL 허용. 발생 세션 참조(반복 패턴 추적용). 물리 FK 없음(앱 레벨)',
  `user_id` binary(16) DEFAULT NULL COMMENT 'NULL 허용. 발화 사용자 참조. 물리 FK 없음(앱 레벨)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ai_assistant_unmet_requests_tenant_id_captured_at` (`tenant_id`,`captured_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='AI비서 미충족 요청 캡처 — 흡수 못한 틀 밖 요청 발화 저장소(append-only·신호 로그). 자유도 정책 ④ 백로그 캡처. BE-46 INSERT 대상';

-- migrate:down

DROP TABLE `ai_assistant_unmet_requests`;
