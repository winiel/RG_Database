-- migrate:up
-- DB33-MIGRATE-DATA (DB-33 ②) — 구 두 소스를 class_suspensions 로 멱등 이관 + paused→active 복원
--
-- 발의: request/RG_Database/2026-07-04-db33-class-suspensions-unified-table-request.md §2.2
-- 전제: ①(20260704065422) 로 class_suspensions 생성 완료. ②는 BE-65 라이브 전 1회성 이관.
--
-- 멱등: up 재실행 시 NOT EXISTS 가드로 중복 0. 왕복(up→down→up) 후 데이터 원상.
-- 원천 ① class_cancellations → suspensions : cancelled_date 를 start=end(하루 휴강)로. reason 보존.
-- 원천 ② classes.status='paused' → 무기한 suspension : end_date NULL,
--         start_date = COALESCE(classes.start_date, DATE(classes.created_at)) — start_date NULL 폴백.
-- ②b paused → active 복원 : 휴강 정보를 suspensions 가 보유하므로 상태 축에서 paused 비움
--         (status enum/CHECK 에서 paused 제거는 파괴적 ③ 에서).
--
-- 영향: class_suspensions 행 추가 + classes.status paused→active UPDATE. 물리 삭제 없음.
--       cancellations 원본 유지(③ 에서 DROP). 트리거/SP 없음.

-- ① class_cancellations → suspensions (cancelled_date = start = end), 멱등
INSERT INTO `class_suspensions`
  (`id`, `tenant_id`, `class_id`, `start_date`, `end_date`, `reason`, `created_at`, `updated_at`)
SELECT UNHEX(REPLACE(UUID(), '-', '')), c.tenant_id, c.class_id,
       c.cancelled_date, c.cancelled_date, c.reason, NOW(), NOW()
FROM `class_cancellations` c
WHERE NOT EXISTS (
  SELECT 1 FROM `class_suspensions` s
  WHERE s.tenant_id = c.tenant_id AND s.class_id = c.class_id
    AND s.start_date = c.cancelled_date AND s.end_date = c.cancelled_date
    AND s.is_deleted = 0
);

-- ② classes.status='paused' → 무기한 suspension (end_date NULL), 멱등
INSERT INTO `class_suspensions`
  (`id`, `tenant_id`, `class_id`, `start_date`, `end_date`, `reason`, `created_at`, `updated_at`)
SELECT UNHEX(REPLACE(UUID(), '-', '')), cl.tenant_id, cl.id,
       COALESCE(cl.start_date, DATE(cl.created_at)), NULL, NULL, NOW(), NOW()
FROM `classes` cl
WHERE cl.status = 'paused'
  AND NOT EXISTS (
    SELECT 1 FROM `class_suspensions` s
    WHERE s.tenant_id = cl.tenant_id AND s.class_id = cl.id
      AND s.end_date IS NULL AND s.is_deleted = 0
  );

-- ②b paused → active 복원 (휴강 정보는 이제 suspensions 가 보유)
UPDATE `classes` SET `status` = 'active' WHERE `status` = 'paused';

-- migrate:down
-- 역이관 (BE-65 라이브 전·이관 직후 롤백 전제 — 앱 신규 생성분과 섞이기 전 원상복구 보장).
-- 순서 주의: (C역) status 복원 → (B역) 무기한 suspension 삭제 → (A역) 단일 suspension 삭제.

-- (C역) 무기한 suspension 보유 class → status='paused' 복원
UPDATE `classes` cl
SET cl.`status` = 'paused'
WHERE cl.`status` = 'active'
  AND EXISTS (
    SELECT 1 FROM `class_suspensions` s
    WHERE s.tenant_id = cl.tenant_id AND s.class_id = cl.id
      AND s.end_date IS NULL AND s.is_deleted = 0
  );

-- (B역) 이관으로 생성된 무기한 suspension 삭제
DELETE FROM `class_suspensions` WHERE `end_date` IS NULL;

-- (A역) cancellation 대응 단일(하루) suspension 삭제 (원본 cancellations 존재 → 참조 가능)
DELETE s FROM `class_suspensions` s
WHERE s.`start_date` = s.`end_date`
  AND EXISTS (
    SELECT 1 FROM `class_cancellations` c
    WHERE c.tenant_id = s.tenant_id AND c.class_id = s.class_id
      AND c.cancelled_date = s.start_date
  );
