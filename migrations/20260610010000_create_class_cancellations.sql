-- migrate:up
-- CLASS-SESSION-CANCELLATION-SCHEMA (DB-3) — 클래스 휴강 기록 전용 테이블 신설
--
-- 발의: request/RG_Database/2026-06-10-class-session-cancellation-schema-request.md
-- cross-ref: 같은 영역 DB-2 (20260610000000 class-date-period) · holidays(tenant_id+date 키 선례)
--
-- 휴강 = 반복 클래스의 특정 날짜 1회 수업만 취소 (폐강=classes.status 'ended' 와 별개).
-- 단수/복수 휴강은 모두 같은 테이블 행 N개로 저장.
--
-- 사용자 확정 설계:
--   - undo 정책 = 옵션 A (행 삭제) → status 컬럼 없음. 휴강 해제는 앱이 DELETE.
--   - unique(tenant_id, class_id, cancelled_date) — 같은 클래스 같은 날 중복 휴강 방지.
--   - 인덱스: ① unique 키가 클래스별 조회 커버 ② 날짜별 조회용 idx(tenant_id, cancelled_date).
--   - 물리 FK 없음 — 현행 스키마 전체가 앱 레벨 무결성(FK 미사용). DB-3도 동일.
--   - attendance 연계는 런타임 제외(Backend BE-21 책임) → attendances 무변경.
--
-- 영향: 신규 테이블 추가만 — 기존 데이터 영향 0 (적용 직후 0행). 트리거/SP 없음.

CREATE TABLE `class_cancellations` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `class_id` binary(16) NOT NULL,
  `cancelled_date` date NOT NULL,
  `reason` varchar(255) DEFAULT NULL COMMENT '휴강 사유 (예: 공휴일, 강사 사정) — 선택',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_class_cancellations_tenant_id_class_id_cancelled_date` (`tenant_id`,`class_id`,`cancelled_date`),
  KEY `idx_class_cancellations_tenant_id_cancelled_date` (`tenant_id`,`cancelled_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='클래스 휴강 — 반복 클래스의 특정 날짜 1회 수업 취소 기록 (폐강=classes.status ended 와 별개)';

-- migrate:down

DROP TABLE `class_cancellations`;
