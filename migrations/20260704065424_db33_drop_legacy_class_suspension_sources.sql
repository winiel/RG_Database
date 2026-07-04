-- migrate:up
-- DB33-DROP-LEGACY (DB-33 ③·파괴적) — 구 휴강 소스 제거 (BE-65 배포로 구 소비 제거 확인 후 실행)
--
-- 발의: request/RG_Database/2026-07-04-db33-class-suspensions-unified-table-request.md §2.3
-- 전제: ②(20260704065423) 이관 완료 → 이 시점 classes 에 status='paused' 행 0 (CHECK 재정의 안전).
--       BE-65 배포로 class_cancellations·status='paused' 소비지점이 완전히 제거된 뒤 prod 적용.
--       ★로컬 up/down 왕복 검증은 선수행하되, prod RDS 실행은 BE-65 배포 확인 게이트 후 별 사이클.
--
-- ★사전검증 반영: classes.status CHECK 는 실제 4종('active','paused','ended','archived') —
--   발의서엔 archived 누락. paused 만 제거하고 archived 는 반드시 보존.
--
-- 영향(파괴적): (1) chk_classes_status 에서 'paused' 제거 (2) class_cancellations DROP
--   (데이터는 ②에서 class_suspensions 로 이관 완료). down = 대칭 복원(paused 복원·테이블 재생성).

-- (1) classes.status CHECK 에서 'paused' 제거 (운영중/폐강/보관: active/ended/archived)
ALTER TABLE `classes`
  DROP CONSTRAINT `chk_classes_status`,
  ADD CONSTRAINT `chk_classes_status`
    CHECK ((`status` in (_utf8mb4'active',_utf8mb4'ended',_utf8mb4'archived')));

-- (2) class_cancellations 테이블 제거 (단일 소스 = class_suspensions)
DROP TABLE `class_cancellations`;

-- migrate:down
-- (2역) class_cancellations 재생성 (선례 20260610010000 스키마 byte-정합 복원)
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

-- (1역) classes.status CHECK 에 'paused' 복원 (원상 4종)
ALTER TABLE `classes`
  DROP CONSTRAINT `chk_classes_status`,
  ADD CONSTRAINT `chk_classes_status`
    CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused',_utf8mb4'ended',_utf8mb4'archived')));
