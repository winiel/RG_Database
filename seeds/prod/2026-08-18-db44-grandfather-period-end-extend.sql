-- DB-44 grandfather Pro 2개 학원 이용기간 종료일 2026-12-31 연장 (prod RDS 데이터·1회성)
-- 오더: 위니엘님 직접 지시 (2026-08-18 "production 환경의 pro 플랜의 다른 계정들의 limit time을
--       2026년 12월 31일까지로 변경") — "다른 계정들" = DB-43(test@winielab.com) 제외 잔여 Pro 전량
--
-- 대상(2건·적용 시점 plan=pro·status=active·is_deleted=0 전량):
--   베테랑스에듀           academy_id = 0x019F20B555057B40B98A5A63AB9A1B8F
--   용인대천일태권도장(★실운영) academy_id = 0x019ECE3929DD7281AF56238014AD4D52
--   (둘 다 DB-39 grandfather seed·카드 0장·결제이력 0건·next_billing_date NULL)
--
-- 변경: current_period_end  2026-10-06 13:30:41 → 2026-12-31 23:59:59
--   ★값 근거 = `academy_subscriptions` 의 datetime 컬럼은 **KST 벽시계 naive** 저장 규약
--     (subscription_service `_kst_naive_now()` 저장·`_to_view` 무변환 통과) → KST 값 직접 기입.
--     23:59:59 = "12-31 까지(포함)" 를 datetime 레벨 비교에서도 보장(date 레벨 비교는 동일).
--   ★updated_at 명시 기입 = 컬럼이 ON UPDATE CURRENT_TIMESTAMP 인데 세션 TZ 가 UTC 라
--     자동 갱신 시 KST 규약과 9시간 어긋남 → NOW()+9h 로 KST 벽시계 유지.
--
-- 무변경(의도): next_billing_date = NULL 유지.
--   과금 크론(jobs/daily_subscription_charge.py)은 `next_billing_date <= today` 만 선정 →
--   NULL 은 영구 미선정 = 과금 0. 카드 미등록 상태라 값을 채우면 결제 실패가 발생하므로 유지.
--
-- ★한계 고지(기능 아님·표시 전용): resolver(`resolve_plan_from_row`)는 status in('trialing','active')
--   이면 current_period_end 를 **참조하지 않고** pro 를 반환한다(기간 판정은 status='canceled' 분기 전용).
--   따라서 본 변경은 화면 표기상의 이용기간만 연장하며, 2026-12-31 경과 후에도 자동 Basic 전환은
--   발생하지 않는다(무기한 Pro 유지). 실제 만료 집행은 별도 조치 필요 — PM 결정 대기.
--
-- 백업: backups/20260818-db44-preupdate-subscriptions.sql (mysqldump)
--       + RDS 스냅샷 winielab-dev-db-rds-db44-preupdate-20260818

-- migrate:up (수동 실행·prod 데이터·2026-08-18 적용완료·affected=2)
UPDATE academy_subscriptions
   SET current_period_end = '2026-12-31 23:59:59',
       updated_at = NOW() + INTERVAL 9 HOUR
 WHERE academy_id IN (UNHEX('019F20B555057B40B98A5A63AB9A1B8F'),
                      UNHEX('019ECE3929DD7281AF56238014AD4D52'))
   AND plan = 'pro'
   AND status = 'active'
   AND is_deleted = 0;
-- 기대 영향 행수: 2 (실측 2)

-- migrate:down (롤백 — 원본 종료일 복원)
-- UPDATE academy_subscriptions
--    SET current_period_end = '2026-10-06 13:30:41',
--        updated_at = NOW() + INTERVAL 9 HOUR
--  WHERE academy_id IN (UNHEX('019F20B555057B40B98A5A63AB9A1B8F'),
--                       UNHEX('019ECE3929DD7281AF56238014AD4D52'))
--    AND plan = 'pro' AND status = 'active' AND is_deleted = 0;
-- (또는 backups/20260818-db44-preupdate-subscriptions.sql / RDS 스냅샷 복원)
