-- migrate:up
-- DB33-CLASS-SUSPENSIONS-UNIFIED (DB-33) — 휴강(강의 중단) 단일/기간/무기한 통합 테이블 신설
--
-- 발의: request/RG_Database/2026-07-04-db33-class-suspensions-unified-table-request.md
-- 근거: "휴강"이 두 소스로 분리되어 판정·표시가 어긋남 —
--         ① classes.status='paused' = 무기한 휴강  ② class_cancellations = 특정 날짜 1회 취소.
--       학원장 지시로 휴강을 단일(하루)/기간(구간)/무기한 하나로 통합.
--       사용자 확정 = 데이터 완전 통합(단일 소스=class_suspensions)·휴강 중 청구 현행 유지(감액 제외)
--         ·용어 분리(상태 운영중/폐강 ↔ 휴강 단일/기간/무기한).
-- cross-ref: class_cancellations(20260610010000) 컨벤션 미러 · classes.status='paused' 이관 원천(②).
--
-- 설계 요지:
--   - 판정식: 날짜 D 휴강 = start_date <= D AND (end_date IS NULL OR end_date >= D).
--   - end_date NULL = 무기한. CHECK(end_date IS NULL OR end_date >= start_date) — 날짜 순서만 보장.
--   - 겹침(overlap) 검증은 앱 레벨(BE-65). DB는 교차 제약을 걸지 않음(강건성).
--   - is_deleted 논리삭제(휴강 해제 = is_deleted=1 + deleted_at/deleted_by). 모든 소비 EXISTS 에
--     is_deleted=0 필수(BE-65). [[project_soft_delete_is_deleted_policy]] 준수.
--   - 물리 FK 없음(현행 컨벤션·앱 레벨 무결성). tenant_id/class_id 정합은 앱 보장.
--   - 인덱스 2종: (tenant,class,start_date) 특정 클래스 휴강 조회 ·
--                 (tenant,start_date,end_date) 날짜 범위 스캔(대시보드/크론 range 매칭).
--
-- 영향: 신규 테이블 추가만(additive). 기존 쿼리 무영향(BE-65 라이브 전 미소비·적용 직후 0행).
--       트리거/SP 없음. 롤백 가능(down = DROP TABLE).

CREATE TABLE `class_suspensions` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `tenant_id` binary(16) NOT NULL,
  `class_id` binary(16) NOT NULL,
  `start_date` date NOT NULL COMMENT '휴강 시작일(포함)',
  `end_date` date DEFAULT NULL COMMENT '휴강 종료일(포함). NULL=무기한',
  `reason` varchar(255) DEFAULT NULL COMMENT '휴강 사유 — 선택',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '논리삭제(1=삭제=휴강 해제)',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` binary(16) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_class_suspensions_tenant_id_class_id_start_date` (`tenant_id`,`class_id`,`start_date`),
  KEY `idx_class_suspensions_tenant_id_start_date_end_date` (`tenant_id`,`start_date`,`end_date`),
  CONSTRAINT `chk_class_suspensions_date_order` CHECK (((`end_date` is null) or (`end_date` >= `start_date`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='휴강 통합 — 단일(start=end)/기간(start..end)/무기한(end NULL). 단일 소스(class_cancellations·status=paused 대체)';

-- migrate:down

DROP TABLE `class_suspensions`;
