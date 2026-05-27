-- ============================================================================
-- ProjectRG — Seed/Data Validation Suite
--
-- 위치:    scripts/checks/validate-seed.sql
-- 사용:    mysql -u root ProjectRG_Dev < scripts/checks/validate-seed.sql
--          (또는 ./scripts/checks/validate-seed.sh)
--
-- 동작:
--   1. 모든 검증을 임시 테이블 rg_validation에 적재
--   2. 위반(violations > 0) 행만 출력
--   3. 마지막에 PASS/FAIL 종합 요약 출력
--
-- 검증 영역 (총 80+ checks):
--   * orphan        — 참조 무결성 (tenant_id + 도메인 간 참조)
--   * tenancy       — 교차 참조 시 tenant_id 일치 (멀티테넌시 핵심 invariant)
--   * business      — 운영 요일·결제 상태·UNIQUE 등 비즈니스 규칙
--   * plausibility  — 미래 일자·정원 초과·해시 형식 등 합리성
--   * schedule      — 강사·강의실 시간 충돌
--   * payment_calc  — 결제 누락(등록 후 발생해야 할 월별 결제)·금액 일치
--   * json_struct   — JSON 컬럼 타입·평탄화 일관성
--
-- 정책 근거: 회신 §3-4 (FK 미사용 → 무결성은 앱+CI 책임)
-- ============================================================================

USE ProjectRG_Dev;

-- ----------------------------------------------------------------------------
-- 검증 결과 임시 테이블
-- ----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS rg_validation;
CREATE TEMPORARY TABLE rg_validation (
    category    VARCHAR(20)  NOT NULL,
    check_name  VARCHAR(255) NOT NULL,
    violations  INT          NOT NULL,
    PRIMARY KEY (category, check_name)
) ENGINE=Memory;

-- ----------------------------------------------------------------------------
-- 1. ORPHAN — 참조 무결성 (tenant_id 32 + 도메인 간 16 = 48 checks)
-- ----------------------------------------------------------------------------
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('orphan', 'user_accounts.tenant_id',          (SELECT COUNT(*) FROM user_accounts t        LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'refresh_tokens.tenant_id',         (SELECT COUNT(*) FROM refresh_tokens t       LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'students.tenant_id',               (SELECT COUNT(*) FROM students t             LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'student_notes.tenant_id',          (SELECT COUNT(*) FROM student_notes t        LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'subjects.tenant_id',               (SELECT COUNT(*) FROM subjects t             LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'rooms.tenant_id',                  (SELECT COUNT(*) FROM rooms t                LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'teachers.tenant_id',               (SELECT COUNT(*) FROM teachers t             LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'classes.tenant_id',                (SELECT COUNT(*) FROM classes t              LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'student_classes.tenant_id',        (SELECT COUNT(*) FROM student_classes t      LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'holidays.tenant_id',               (SELECT COUNT(*) FROM holidays t             LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'attendances.tenant_id',            (SELECT COUNT(*) FROM attendances t          LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'vision_verifications.tenant_id',   (SELECT COUNT(*) FROM vision_verifications t LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'payments.tenant_id',               (SELECT COUNT(*) FROM payments t             LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'payment_events.tenant_id',         (SELECT COUNT(*) FROM payment_events t       LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'message_templates.tenant_id',      (SELECT COUNT(*) FROM message_templates t    LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'settings.tenant_id',               (SELECT COUNT(*) FROM settings t             LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'ability_tracks.tenant_id',         (SELECT COUNT(*) FROM ability_tracks t       LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'student_abilities.tenant_id',      (SELECT COUNT(*) FROM student_abilities t    LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'class_ability_tracks.tenant_id',   (SELECT COUNT(*) FROM class_ability_tracks t LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'uploads.tenant_id',                (SELECT COUNT(*) FROM uploads t              LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL)),
    ('orphan', 'semesters.tenant_id',              (SELECT COUNT(*) FROM semesters t            LEFT JOIN academies a ON a.id = t.tenant_id WHERE a.id IS NULL));

INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('orphan', 'refresh_tokens.user_account_id',       (SELECT COUNT(*) FROM refresh_tokens t LEFT JOIN user_accounts u ON u.id = t.user_account_id WHERE u.id IS NULL)),
    ('orphan', 'student_notes.student_id',             (SELECT COUNT(*) FROM student_notes t LEFT JOIN students s ON s.id = t.student_id WHERE s.id IS NULL)),
    ('orphan', 'student_classes.student_id',           (SELECT COUNT(*) FROM student_classes t LEFT JOIN students s ON s.id = t.student_id WHERE s.id IS NULL)),
    ('orphan', 'student_classes.class_id',             (SELECT COUNT(*) FROM student_classes t LEFT JOIN classes c ON c.id = t.class_id WHERE c.id IS NULL)),
    ('orphan', 'teachers.subject_id (non-null)',       (SELECT COUNT(*) FROM teachers t LEFT JOIN subjects s ON s.id = t.subject_id WHERE t.subject_id IS NOT NULL AND s.id IS NULL)),
    ('orphan', 'classes.subject_id (non-null)',        (SELECT COUNT(*) FROM classes t LEFT JOIN subjects s ON s.id = t.subject_id WHERE t.subject_id IS NOT NULL AND s.id IS NULL)),
    ('orphan', 'classes.teacher_id (non-null)',        (SELECT COUNT(*) FROM classes t LEFT JOIN teachers tc ON tc.id = t.teacher_id WHERE t.teacher_id IS NOT NULL AND tc.id IS NULL)),
    ('orphan', 'classes.room_id (non-null)',           (SELECT COUNT(*) FROM classes t LEFT JOIN rooms r ON r.id = t.room_id WHERE t.room_id IS NOT NULL AND r.id IS NULL)),
    ('orphan', 'attendances.student_id',               (SELECT COUNT(*) FROM attendances t LEFT JOIN students s ON s.id = t.student_id WHERE s.id IS NULL)),
    ('orphan', 'attendances.class_id',                 (SELECT COUNT(*) FROM attendances t LEFT JOIN classes c ON c.id = t.class_id WHERE c.id IS NULL)),
    ('orphan', 'attendances.vision_verif_id (n-null)', (SELECT COUNT(*) FROM attendances t LEFT JOIN vision_verifications v ON v.id = t.vision_verification_id WHERE t.vision_verification_id IS NOT NULL AND v.id IS NULL)),
    ('orphan', 'vision_verifications.student_id',      (SELECT COUNT(*) FROM vision_verifications t LEFT JOIN students s ON s.id = t.student_id WHERE s.id IS NULL)),
    ('orphan', 'payments.student_id',                  (SELECT COUNT(*) FROM payments t LEFT JOIN students s ON s.id = t.student_id WHERE s.id IS NULL)),
    ('orphan', 'payments.class_id (non-null)',         (SELECT COUNT(*) FROM payments t LEFT JOIN classes c ON c.id = t.class_id WHERE t.class_id IS NOT NULL AND c.id IS NULL)),
    ('orphan', 'payment_events.payment_id',            (SELECT COUNT(*) FROM payment_events t LEFT JOIN payments p ON p.id = t.payment_id WHERE p.id IS NULL)),
    ('orphan', 'ability_tracks.subject_id (n-null)',   (SELECT COUNT(*) FROM ability_tracks t LEFT JOIN subjects s ON s.id = t.subject_id WHERE t.subject_id IS NOT NULL AND s.id IS NULL)),
    ('orphan', 'student_abilities.student_id',         (SELECT COUNT(*) FROM student_abilities t LEFT JOIN students s ON s.id = t.student_id WHERE s.id IS NULL)),
    ('orphan', 'student_abilities.track_id',           (SELECT COUNT(*) FROM student_abilities t LEFT JOIN ability_tracks at ON at.id = t.ability_track_id WHERE at.id IS NULL)),
    ('orphan', 'class_ability_tracks.class_id',        (SELECT COUNT(*) FROM class_ability_tracks t LEFT JOIN classes c ON c.id = t.class_id WHERE c.id IS NULL)),
    ('orphan', 'class_ability_tracks.track_id',        (SELECT COUNT(*) FROM class_ability_tracks t LEFT JOIN ability_tracks at ON at.id = t.ability_track_id WHERE at.id IS NULL)),
    ('orphan', 'uploads.created_by (non-null)',        (SELECT COUNT(*) FROM uploads t LEFT JOIN user_accounts u ON u.id = t.created_by_user_account_id WHERE t.created_by_user_account_id IS NOT NULL AND u.id IS NULL));

-- ----------------------------------------------------------------------------
-- 2. TENANCY — 교차 참조 시 tenant_id 일치 (멀티테넌시 핵심 invariant)
-- ----------------------------------------------------------------------------
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('tenancy', 'student_classes vs students',     (SELECT COUNT(*) FROM student_classes sc JOIN students s ON s.id = sc.student_id WHERE sc.tenant_id != s.tenant_id)),
    ('tenancy', 'student_classes vs classes',      (SELECT COUNT(*) FROM student_classes sc JOIN classes c ON c.id = sc.class_id WHERE sc.tenant_id != c.tenant_id)),
    ('tenancy', 'attendances vs students',         (SELECT COUNT(*) FROM attendances a JOIN students s ON s.id = a.student_id WHERE a.tenant_id != s.tenant_id)),
    ('tenancy', 'attendances vs classes',          (SELECT COUNT(*) FROM attendances a JOIN classes c ON c.id = a.class_id WHERE a.tenant_id != c.tenant_id)),
    ('tenancy', 'payments vs students',            (SELECT COUNT(*) FROM payments p JOIN students s ON s.id = p.student_id WHERE p.tenant_id != s.tenant_id)),
    ('tenancy', 'payments vs classes',             (SELECT COUNT(*) FROM payments p JOIN classes c ON c.id = p.class_id WHERE p.class_id IS NOT NULL AND p.tenant_id != c.tenant_id)),
    ('tenancy', 'payment_events vs payments',      (SELECT COUNT(*) FROM payment_events pe JOIN payments p ON p.id = pe.payment_id WHERE pe.tenant_id != p.tenant_id)),
    ('tenancy', 'classes vs subjects',             (SELECT COUNT(*) FROM classes c JOIN subjects s ON s.id = c.subject_id WHERE c.subject_id IS NOT NULL AND c.tenant_id != s.tenant_id)),
    ('tenancy', 'classes vs teachers',             (SELECT COUNT(*) FROM classes c JOIN teachers t ON t.id = c.teacher_id WHERE c.teacher_id IS NOT NULL AND c.tenant_id != t.tenant_id)),
    ('tenancy', 'classes vs rooms',                (SELECT COUNT(*) FROM classes c JOIN rooms r ON r.id = c.room_id WHERE c.room_id IS NOT NULL AND c.tenant_id != r.tenant_id)),
    ('tenancy', 'teachers vs subjects',            (SELECT COUNT(*) FROM teachers t JOIN subjects s ON s.id = t.subject_id WHERE t.subject_id IS NOT NULL AND t.tenant_id != s.tenant_id)),
    ('tenancy', 'student_notes vs students',       (SELECT COUNT(*) FROM student_notes sn JOIN students s ON s.id = sn.student_id WHERE sn.tenant_id != s.tenant_id)),
    ('tenancy', 'refresh_tokens vs user_accounts', (SELECT COUNT(*) FROM refresh_tokens r JOIN user_accounts u ON u.id = r.user_account_id WHERE r.tenant_id != u.tenant_id)),
    ('tenancy', 'vision_verifications vs students',(SELECT COUNT(*) FROM vision_verifications v JOIN students s ON s.id = v.student_id WHERE v.tenant_id != s.tenant_id)),
    ('tenancy', 'student_abilities vs students',   (SELECT COUNT(*) FROM student_abilities sa JOIN students s ON s.id = sa.student_id WHERE sa.tenant_id != s.tenant_id)),
    ('tenancy', 'student_abilities vs ab_tracks',  (SELECT COUNT(*) FROM student_abilities sa JOIN ability_tracks at ON at.id = sa.ability_track_id WHERE sa.tenant_id != at.tenant_id)),
    ('tenancy', 'ability_tracks vs subjects',      (SELECT COUNT(*) FROM ability_tracks at JOIN subjects s ON s.id = at.subject_id WHERE at.subject_id IS NOT NULL AND at.tenant_id != s.tenant_id)),
    ('tenancy', 'class_ability_tracks vs classes', (SELECT COUNT(*) FROM class_ability_tracks cat JOIN classes c ON c.id = cat.class_id WHERE cat.tenant_id != c.tenant_id)),
    ('tenancy', 'class_ability_tracks vs tracks',  (SELECT COUNT(*) FROM class_ability_tracks cat JOIN ability_tracks at ON at.id = cat.ability_track_id WHERE cat.tenant_id != at.tenant_id)),
    ('tenancy', 'uploads vs user_accounts',        (SELECT COUNT(*) FROM uploads u JOIN user_accounts ua ON ua.id = u.created_by_user_account_id WHERE u.created_by_user_account_id IS NOT NULL AND u.tenant_id != ua.tenant_id));

-- ----------------------------------------------------------------------------
-- 3. BUSINESS — 비즈니스 규칙 (운영 요일·결제 상태·UNIQUE 등)
-- ----------------------------------------------------------------------------
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('business', 'attendance.date NOT in days_of_week',
        (SELECT COUNT(*) FROM attendances a JOIN classes c ON c.id = a.class_id
         WHERE NOT JSON_CONTAINS(c.days_of_week, CAST(WEEKDAY(a.`date`) + 1 AS JSON)))),
    ('business', 'attendance.date < enrolled_at',
        (SELECT COUNT(*) FROM attendances a JOIN student_classes sc
            ON sc.tenant_id = a.tenant_id AND sc.student_id = a.student_id AND sc.class_id = a.class_id
         WHERE a.`date` < DATE(sc.enrolled_at))),
    ('business', 'attendance.date > unenrolled_at',
        (SELECT COUNT(*) FROM attendances a JOIN student_classes sc
            ON sc.tenant_id = a.tenant_id AND sc.student_id = a.student_id AND sc.class_id = a.class_id
         WHERE sc.unenrolled_at IS NOT NULL AND a.`date` >= DATE(sc.unenrolled_at))),
    ('business', 'paid status without paid_date',
        (SELECT COUNT(*) FROM payments WHERE payment_status = 'paid' AND paid_date IS NULL)),
    ('business', 'paid_date set but not paid',
        (SELECT COUNT(*) FROM payments WHERE paid_date IS NOT NULL AND payment_status != 'paid')),
    ('business', 'due_date < billing_date',
        (SELECT COUNT(*) FROM payments WHERE due_date IS NOT NULL AND due_date < billing_date)),
    ('business', 'paid_date < billing_date',
        (SELECT COUNT(*) FROM payments WHERE paid_date IS NOT NULL AND paid_date < billing_date)),
    ('business', 'event paid w/o status=paid',
        (SELECT COUNT(*) FROM payment_events pe JOIN payments p ON p.id = pe.payment_id
         WHERE pe.event_type = 'paid' AND p.payment_status != 'paid')),
    ('business', 'payment without created event',
        (SELECT COUNT(*) FROM payments p WHERE NOT EXISTS (
            SELECT 1 FROM payment_events pe WHERE pe.payment_id = p.id AND pe.event_type = 'created'))),
    ('business', 'present/late without check_in_at',
        (SELECT COUNT(*) FROM attendances WHERE attendance_status IN ('present','late') AND check_in_at IS NULL)),
    ('business', 'absent/excused with check_in_at',
        (SELECT COUNT(*) FROM attendances WHERE attendance_status IN ('absent','excused') AND check_in_at IS NOT NULL)),
    ('business', 'absent/excused w/o reason',
        (SELECT COUNT(*) FROM attendances WHERE attendance_status IN ('absent','excused') AND absence_reason IS NULL)),
    ('business', 'absent/excused w/o category',
        (SELECT COUNT(*) FROM attendances WHERE attendance_status IN ('absent','excused') AND absence_category IS NULL)),
    ('business', 'duplicate student_classes',
        (SELECT COUNT(*) - COUNT(DISTINCT CONCAT(HEX(tenant_id),HEX(student_id),HEX(class_id))) FROM student_classes)),
    ('business', 'duplicate attendances',
        (SELECT COUNT(*) - COUNT(DISTINCT CONCAT(HEX(tenant_id),HEX(student_id),HEX(class_id),`date`)) FROM attendances)),
    -- semesters: 학원당 is_current=TRUE 가 최대 1개 (generated column UNIQUE로 보장. 명시적 검증)
    ('business', 'multiple is_current semesters per tenant',
        (SELECT COUNT(*) FROM (
            SELECT tenant_id FROM semesters WHERE is_current = TRUE
            GROUP BY tenant_id HAVING COUNT(*) > 1
        ) multi)),
    -- semesters: 학기가 있는 학원은 정확히 1개의 is_current=TRUE 학기를 가져야 함
    ('business', 'tenant with semesters but no current',
        (SELECT COUNT(*) FROM (
            SELECT tenant_id FROM semesters
            GROUP BY tenant_id
            HAVING SUM(CASE WHEN is_current = TRUE THEN 1 ELSE 0 END) = 0
        ) no_current)),
    -- semesters: starts_on > ends_on (CHECK가 잡지만 명시)
    ('business', 'semester starts_on > ends_on',
        (SELECT COUNT(*) FROM semesters WHERE starts_on > ends_on));

-- ----------------------------------------------------------------------------
-- 4. PLAUSIBILITY — 미래 일자, 정원, 해시 형식 등
-- ----------------------------------------------------------------------------
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('plausibility', 'students.registered_at in future',
        (SELECT COUNT(*) FROM students WHERE registered_at > NOW())),
    ('plausibility', 'students.birth_date in future',
        (SELECT COUNT(*) FROM students WHERE birth_date > CURDATE())),
    ('plausibility', 'teachers.joined_at in future',
        (SELECT COUNT(*) FROM teachers WHERE joined_at > NOW())),
    ('plausibility', 'class capacity exceeded',
        (SELECT COUNT(*) FROM (
            SELECT c.id FROM classes c
            LEFT JOIN student_classes sc ON sc.class_id = c.id AND sc.status = 'active'
            GROUP BY c.id, c.capacity HAVING COUNT(sc.id) > c.capacity
        ) over_cap)),
    ('plausibility', 'check_in_at >2h before class',
        (SELECT COUNT(*) FROM attendances a JOIN classes c ON c.id = a.class_id
         WHERE a.check_in_at IS NOT NULL
           AND TIMESTAMPDIFF(MINUTE, TIMESTAMP(a.`date`, c.start_time), a.check_in_at) < -120)),
    ('plausibility', 'check_in_at >2h after class',
        (SELECT COUNT(*) FROM attendances a JOIN classes c ON c.id = a.class_id
         WHERE a.check_in_at IS NOT NULL
           AND TIMESTAMPDIFF(MINUTE, TIMESTAMP(a.`date`, c.start_time), a.check_in_at) > 120)),
    ('plausibility', 'password_hash invalid bcrypt format',
        (SELECT COUNT(*) FROM user_accounts WHERE password_hash NOT REGEXP '^\\$2[ayb]\\$[0-9]{2}\\$.{53}$'));

-- ----------------------------------------------------------------------------
-- 5. SCHEDULE — 강사·강의실 시간 충돌
-- ----------------------------------------------------------------------------
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('schedule', 'teacher schedule conflict',
        (SELECT COUNT(*) FROM classes c1 JOIN classes c2 ON c1.teacher_id = c2.teacher_id AND c1.id < c2.id
         WHERE c1.teacher_id IS NOT NULL
           AND JSON_OVERLAPS(c1.days_of_week, c2.days_of_week)
           AND c1.start_time < c2.end_time AND c2.start_time < c1.end_time)),
    ('schedule', 'room schedule conflict',
        (SELECT COUNT(*) FROM classes c1 JOIN classes c2 ON c1.room_id = c2.room_id AND c1.id < c2.id
         WHERE c1.room_id IS NOT NULL
           AND JSON_OVERLAPS(c1.days_of_week, c2.days_of_week)
           AND c1.start_time < c2.end_time AND c2.start_time < c1.end_time));

-- ----------------------------------------------------------------------------
-- 6. PAYMENT_CALC — 결제 발생 누락·금액 일치
-- ----------------------------------------------------------------------------
-- 시드 로직: enrolled_at <= billing_month + 1 MONTH 인 월에 결제 발생
-- expected = 등록일이 속한 월(또는 이전)부터 2026-05까지의 월 수, 최대 5
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('payment_calc', 'missing monthly payments per enrollment',
        (SELECT COUNT(*) FROM (
            SELECT sc.id,
                   LEAST(5, GREATEST(0,
                       TIMESTAMPDIFF(MONTH, DATE_FORMAT(sc.enrolled_at, '%Y-%m-01'), '2026-05-01') + 1
                   )) AS expected,
                   (SELECT COUNT(*) FROM payments p
                    WHERE p.tenant_id = sc.tenant_id
                      AND p.student_id = sc.student_id
                      AND p.class_id = sc.class_id) AS actual
            FROM student_classes sc
        ) e WHERE actual != expected)),
    ('payment_calc', 'payment amount mismatch (taekwondo)',
        (SELECT COUNT(*) FROM payments p JOIN classes c ON c.id = p.class_id
         WHERE c.name = '태권도반' AND p.amount != 200000.00)),
    ('payment_calc', 'payment amount mismatch (math)',
        (SELECT COUNT(*) FROM payments p JOIN classes c ON c.id = p.class_id
         WHERE c.name = '수학반' AND p.amount != 250000.00)),
    ('payment_calc', 'payment amount mismatch (english)',
        (SELECT COUNT(*) FROM payments p JOIN classes c ON c.id = p.class_id
         WHERE c.name = '영어반' AND p.amount != 230000.00));

-- ----------------------------------------------------------------------------
-- 7. JSON_STRUCT — JSON 컬럼 타입·평탄화 일관성
-- ----------------------------------------------------------------------------
INSERT INTO rg_validation (category, check_name, violations) VALUES
    ('json_struct', 'academies.operating_hours not OBJECT',
        (SELECT COUNT(*) FROM academies WHERE operating_hours IS NOT NULL AND JSON_TYPE(operating_hours) != 'OBJECT')),
    ('json_struct', 'classes.days_of_week not ARRAY',
        (SELECT COUNT(*) FROM classes WHERE days_of_week IS NOT NULL AND JSON_TYPE(days_of_week) != 'ARRAY')),
    ('json_struct', 'students.parent not OBJECT',
        (SELECT COUNT(*) FROM students WHERE parent IS NOT NULL AND JSON_TYPE(parent) != 'OBJECT')),
    ('json_struct', 'payments.billing_breakdown not OBJECT',
        (SELECT COUNT(*) FROM payments WHERE billing_breakdown IS NOT NULL AND JSON_TYPE(billing_breakdown) != 'OBJECT')),
    ('json_struct', 'payment_events.event_data not OBJECT',
        (SELECT COUNT(*) FROM payment_events WHERE event_data IS NOT NULL AND JSON_TYPE(event_data) != 'OBJECT')),
    ('json_struct', 'students.parent_name flatten mismatch',
        (SELECT COUNT(*) FROM students
         WHERE parent IS NOT NULL
           AND parent_name != JSON_UNQUOTE(JSON_EXTRACT(parent, '$.name')))),
    ('json_struct', 'students.parent_phone flatten mismatch',
        (SELECT COUNT(*) FROM students
         WHERE parent IS NOT NULL
           AND parent_phone != JSON_UNQUOTE(JSON_EXTRACT(parent, '$.phone'))));

-- ============================================================================
-- 결과 출력
-- ============================================================================

SELECT '=== 위반 (violations > 0) — 비어있으면 모두 PASS ===' AS info;
SELECT category, check_name, violations
FROM rg_validation
WHERE violations > 0
ORDER BY category, check_name;

SELECT '=== 카테고리별 요약 ===' AS info;
SELECT
    category,
    COUNT(*)                                          AS total_checks,
    SUM(CASE WHEN violations > 0 THEN 1 ELSE 0 END)   AS failed_checks,
    SUM(violations)                                   AS total_violations
FROM rg_validation
GROUP BY category
ORDER BY category;

SELECT '=== 종합 결과 ===' AS info;
SELECT
    COUNT(*)                                          AS total_checks,
    SUM(CASE WHEN violations > 0 THEN 1 ELSE 0 END)   AS failed_checks,
    SUM(violations)                                   AS total_violations,
    IF(SUM(violations) = 0,
       'PASS — 모든 검증 통과',
       CONCAT('FAIL — ', SUM(violations), ' violations across ',
              SUM(CASE WHEN violations > 0 THEN 1 ELSE 0 END), ' checks')) AS result
FROM rg_validation;
