-- migrate:up
-- DB36-CLASS-ACTIVE-REQUIRES-TIME (DB-36) — active 클래스 시간 필수 조건부 CHECK (옵션 A 확정)
--
-- 발의: request/RG_Database/2026-07-04-db36-class-active-time-required-check-constraint-request.md
-- 부모: DB-35 진단 회신(62c805b) — 2안 중 옵션 A(조건부 CHECK) PM/사용자 확정.
-- 근거: 문제 본질 = status='active'(시간표 배치 대상)인데 start_time/end_time null 인 조합만 비정상
--       (FE ScheduleView 크래시). 무조건 NOT NULL 이 아니라 조건부 — active 만 시간 필수,
--       ended/paused/archived 는 시간 null 허용(폐강·초안 유연성·prod ended null 5건 정합 유지).
--
-- 설계 요지:
--   - CHECK: (status <> 'active') OR (start_time IS NOT NULL AND end_time IS NOT NULL).
--     ★CHECK 는 is_deleted 무관 전체 행에 적용 → 삭제 행 포함 active+null 위반 없어야 ADD 성공.
--   - ★선행 정합화(§2.2): active+null → status='archived'(데이터 보존·시간표 제외·복구 가능).
--     삭제(is_deleted) 아닌 archived 채택 — 백필은 임의 시간이라 부적절·삭제는 과함.
--     로컬 019f2d2e "휴무일반UNCHK" 1건 대상. prod 는 active+null 0건이라 UPDATE no-op(무영향).
--   - BE-73(자정 24:00:00 정규화) 정합: end_time=24:00:00 은 NOT NULL → CHECK 통과·충돌 없음
--     (본 CHECK 는 NULL 여부만 검사·time 범위 미검사).
--
-- 영향: 신규 CHECK 제약 1건 + active+null 정합화(로컬 1건 archived·prod 0건). 트리거/SP 없음.
--       기존 prod ended null 5건 무영향(active 아님·CHECK 통과). down = CHECK 제거(정합화는 일방향).
--       BE(cc): active 전환/생성 시 시간 필수 강제됨 — 재발방지 앱 검증은 별건 BE.

-- 선행 정합화: active + (시간 null) → archived (CHECK 위반 제거 · is_deleted 무관 전체 행)
UPDATE classes
SET status = 'archived'
WHERE status = 'active'
  AND (start_time IS NULL OR end_time IS NULL);

-- 조건부 CHECK: active 클래스는 start_time/end_time 필수
ALTER TABLE classes
  ADD CONSTRAINT chk_classes_active_requires_time
  CHECK ((status <> 'active') OR (start_time IS NOT NULL AND end_time IS NOT NULL));

-- migrate:down

-- CHECK 제거 (선행 정합화 archived 는 일방향 개선 → 원복 안 함:
--  원 active+null 은 비정상 상태였으므로 복원 시 재위반. 데이터 보존 상태 유지)
ALTER TABLE classes
  DROP CONSTRAINT chk_classes_active_requires_time;
