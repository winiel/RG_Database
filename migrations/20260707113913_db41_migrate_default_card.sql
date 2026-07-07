-- migrate:up
-- DB41-MIGRATE-DEFAULT-CARD (DB-41 ②) — 기존 단일 카드 → subscription_cards 기본 카드 이관 (멱등)
--
-- 발의: request/RG_Database/2026-07-07-db41-subscription-cards-table-request.md §1.2
-- 근거: 기존 academy_subscriptions.toss_billing_key(단일 카드 1장) 보유 학원의 카드를 subscription_cards 에
--       기본 카드(is_default=1)로 이관. grandfather 학원(toss_billing_key NULL·카드 미등록 Pro)은 카드 행 없음.
--
-- 매핑: academy_subscriptions          → subscription_cards
--       toss_billing_key(NOT NULL)      → billing_key (is_default=1)
--       toss_customer_key               → customer_key
--       card_company / card_number_masked→ 동명 복사
--       academy_id                      → academy_id
--       (id = SQL UUID() 생성·DB-39 seed 선례. 앱 삽입은 UUID v7)
--
-- 멱등: (academy_id, billing_key) 이미 존재 시 skip(NOT EXISTS). 재실행 시 중복 0.
-- additive: academy_subscriptions 행은 읽기만·변경/삭제 0(billing_key 컬럼 처리는 §1.3 A안=유지·deprecated·별건 무변경).
-- ★prod 게이트: 이관은 prod 실데이터(billing_key 보유 학원)를 대상 → prod 적용은 로컬 검증 + 사용자 승인 후에만.
--   용인대천일태권도장(실운영)은 카드 미등록이면 0행·등록돼 있으면 그 학원 카드 1행 복사(읽기만·기존 행 무변경).

INSERT INTO `subscription_cards`
  (`id`, `academy_id`, `billing_key`, `customer_key`, `card_company`, `card_number_masked`,
   `is_default`, `created_at`, `is_deleted`)
SELECT
  UNHEX(REPLACE(UUID(), '-', '')), s.`academy_id`, s.`toss_billing_key`, s.`toss_customer_key`,
  s.`card_company`, s.`card_number_masked`,
  1, NOW(), 0
FROM `academy_subscriptions` s
WHERE s.`toss_billing_key` IS NOT NULL
  AND s.`is_deleted` = 0
  AND NOT EXISTS (
    SELECT 1 FROM `subscription_cards` c
    WHERE c.`academy_id` = s.`academy_id`
      AND c.`billing_key` = s.`toss_billing_key`
  );

-- migrate:down
-- 이관으로 생성한 기본 카드 행 롤백 — academy_subscriptions 의 (academy_id, toss_billing_key) 와 일치하는
-- is_default=1 이관 행만 물리 삭제(원상). 이관 이후 앱이 추가한 카드는 매칭되지 않아 보존.
DELETE c FROM `subscription_cards` c
JOIN `academy_subscriptions` s
  ON s.`academy_id` = c.`academy_id`
 AND s.`toss_billing_key` = c.`billing_key`
WHERE c.`is_default` = 1;
