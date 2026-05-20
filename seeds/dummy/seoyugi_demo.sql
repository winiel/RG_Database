-- ============================================================================
-- 서유기 학원 — 더미 데이터 시드
--
-- 위치:   seeds/dummy/seoyugi_demo.sql
-- 정책:   회신 §5.6 — 더미 시드는 비멱등 (재실행 전 truncate 가정)
-- 사용:   mysql -u root < seeds/dummy/seoyugi_demo.sql
--
-- 데이터 범위
--   * 학원 1개 (서유기학원), 학원장 계정 1개
--   * 과목 3개 (태권도/수학/영어), 강의실 2개, 강사 2명, 클래스 3개
--   * 학생 10명, 학생-클래스 등록 18건
--   * 결제 2026-01 ~ 2026-05 월간 (등록당 5건, 약 90건)
--     - 90% paid / 5% overdue / 5% cancelled
--   * 결제 이력 (payment_events): created 모두 + paid는 paid 이벤트
--   * 출석 2026-01-01 ~ 2026-05-10 클래스 운영 요일별
--     - 80% present / 10% late / 5% absent / 5% excused
--     - absence_category: sick/family/travel/school/other 5종 균등 분포 (CRC32 기반)
--   * 설정 (settings) 1행
--   * 학기 (semesters) 2건 — 2026-1학기 (현재) / 2026-2학기
-- ============================================================================

USE ProjectRG_Dev;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Cleanup (재실행 안전 — FK 미사용이라 순서 자유)
--    ⚠️ 이 시드는 단일 테넌트 dev DB 기준. 다른 데이터 혼재 시 주의.
-- ─────────────────────────────────────────────────────────────────────────────
DELETE FROM payment_events;
DELETE FROM payments;
DELETE FROM attendances;
DELETE FROM vision_verifications;
DELETE FROM student_abilities;
DELETE FROM ability_tracks;
DELETE FROM uploads;
DELETE FROM message_templates;
DELETE FROM settings;
DELETE FROM semesters;
DELETE FROM holidays;
DELETE FROM student_classes;
DELETE FROM student_notes;
DELETE FROM students;
DELETE FROM classes;
DELETE FROM teachers;
DELETE FROM rooms;
DELETE FROM subjects;
DELETE FROM refresh_tokens;
DELETE FROM user_accounts;
DELETE FROM academies;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 학원
-- ─────────────────────────────────────────────────────────────────────────────
SET @academy_id = UUID_TO_BIN(UUID(), 1);
INSERT INTO academies (id, name, business_number, address, phone, email, logo_url, operating_hours)
VALUES (@academy_id, '서유기학원', '123-45-67890',
  '서울특별시 강남구 테헤란로 100', '02-1234-5678', 'contact@seoyugi.kr', NULL,
  JSON_OBJECT(
    'mon', '10:00-22:00', 'tue', '10:00-22:00', 'wed', '10:00-22:00',
    'thu', '10:00-22:00', 'fri', '10:00-22:00',
    'sat', '10:00-18:00', 'sun', 'closed'
  ));

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 학원장 계정 (시스템 운영 필수)
-- ─────────────────────────────────────────────────────────────────────────────
SET @owner_id = UUID_TO_BIN(UUID(), 1);
-- 로컬 테스트 계정 — winiel@winielab.com / '1234' (bcrypt $2y$ cost=12, htpasswd 생성)
-- ⚠️ 실제 운영에서는 절대 사용 금지. Stg/Prod는 백엔드가 가입/관리자 등록 시 신규 해시 생성.
INSERT INTO user_accounts (id, tenant_id, email, password_hash, name, phone, role, last_login_at)
VALUES (@owner_id, @academy_id, 'winiel@winielab.com',
  '$2y$12$P8tiZVh1/SZQAVsS2orZye1Yt7455MafXAC38g69n5ITjiNmR1M.m',
  '손오공', '010-1111-1111', 'owner', '2026-05-10 09:00:00');

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 설정 (1:1)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO settings (id, tenant_id, payment_settings, notification_settings)
VALUES (UUID_TO_BIN(UUID(), 1), @academy_id,
  JSON_OBJECT('billing_day', 1, 'due_day', 10, 'overdue_grace_days', 3),
  JSON_OBJECT('sms_enabled', TRUE, 'kakao_enabled', TRUE, 'email_enabled', FALSE));

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.1 학기 (semesters) — 2026-1학기(현재) + 2026-2학기
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO semesters (id, tenant_id, name, starts_on, ends_on, is_current, description) VALUES
  (UUID_TO_BIN(UUID(), 1), @academy_id, '2026-1학기', '2026-03-01', '2026-08-31', TRUE,  '봄·여름학기'),
  (UUID_TO_BIN(UUID(), 1), @academy_id, '2026-2학기', '2026-09-01', '2027-02-28', FALSE, '가을·겨울학기');

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 과목 (3개)
-- ─────────────────────────────────────────────────────────────────────────────
SET @subj_taekwondo = UUID_TO_BIN(UUID(), 1);
SET @subj_math      = UUID_TO_BIN(UUID(), 1);
SET @subj_english   = UUID_TO_BIN(UUID(), 1);
INSERT INTO subjects (id, tenant_id, name, color_token) VALUES
  (@subj_taekwondo, @academy_id, '태권도', 'red-500'),
  (@subj_math,      @academy_id, '수학',   'blue-500'),
  (@subj_english,   @academy_id, '영어',   'green-500');

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. 강의실 (2개)
-- ─────────────────────────────────────────────────────────────────────────────
SET @room_dojang = UUID_TO_BIN(UUID(), 1);
SET @room_class  = UUID_TO_BIN(UUID(), 1);
INSERT INTO rooms (id, tenant_id, name, description) VALUES
  (@room_dojang, @academy_id, '1관', '태권도 도장 (매트 200평)'),
  (@room_class,  @academy_id, '2관', '학습실 (책상 20석)');

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. 강사 (2명) — 사오정(태권도), 저팔계(수학+영어)
-- ─────────────────────────────────────────────────────────────────────────────
SET @teacher_sa  = UUID_TO_BIN(UUID(), 1);
SET @teacher_jeo = UUID_TO_BIN(UUID(), 1);
INSERT INTO teachers (id, tenant_id, name, subject_id, phone, email, employment_type, hourly_rate, joined_at, status) VALUES
  (@teacher_sa,  @academy_id, '사오정', @subj_taekwondo, '010-2222-1111', 'sa@seoyugi.kr',  'full_time', 35000.00, '2025-03-01 09:00:00', 'active'),
  (@teacher_jeo, @academy_id, '저팔계', @subj_math,      '010-2222-2222', 'jeo@seoyugi.kr', 'full_time', 40000.00, '2025-06-01 09:00:00', 'active');

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. 클래스 (5개 — 운영 3 / 휴강 1 / 종료 1)
--    days_of_week: ISO 요일 (월=1, 화=2, 수=3, 목=4, 금=5, 토=6, 일=7)
--    백엔드 요청 (2026-05-20 questions-to-database §1.3) 반영
--    스케줄 충돌 회피: paused/ended 클래스는 토요일 시간대 사용 (운영 클래스는 평일)
-- ─────────────────────────────────────────────────────────────────────────────
SET @class_taekwondo        = UUID_TO_BIN(UUID(), 1);
SET @class_math             = UUID_TO_BIN(UUID(), 1);
SET @class_english          = UUID_TO_BIN(UUID(), 1);
SET @class_taekwondo_ended  = UUID_TO_BIN(UUID(), 1);
SET @class_math_paused      = UUID_TO_BIN(UUID(), 1);
INSERT INTO classes (id, tenant_id, name, subject_id, teacher_id, room_id, days_of_week, start_time, end_time, capacity, status, started_at) VALUES
  (@class_taekwondo,       @academy_id, '태권도반',        @subj_taekwondo, @teacher_sa,  @room_dojang, JSON_ARRAY(1,3,5), '17:00:00', '18:30:00', 15, 'active', '2026-01-02 17:00:00'),
  (@class_math,            @academy_id, '수학반',          @subj_math,      @teacher_jeo, @room_class,  JSON_ARRAY(2,4),   '18:00:00', '19:30:00', 12, 'active', '2026-01-06 18:00:00'),
  (@class_english,         @academy_id, '영어반',          @subj_english,   @teacher_jeo, @room_class,  JSON_ARRAY(1,3),   '19:30:00', '21:00:00', 12, 'active', '2026-01-05 19:30:00'),
  -- 종료 클래스 1건 — ended 필터 검증용 (예: 2025년 운영 후 종료된 토요 태권도반)
  (@class_taekwondo_ended, @academy_id, '토요 태권도반 (2025)', @subj_taekwondo, @teacher_sa,  @room_dojang, JSON_ARRAY(6), '09:00:00', '10:30:00', 10, 'ended',  '2025-03-01 09:00:00'),
  -- 휴강 클래스 1건 — paused 필터 / 휴강 카운트 검증용
  (@class_math_paused,     @academy_id, '토요 심화수학반',   @subj_math,      @teacher_jeo, @room_class,  JSON_ARRAY(6), '14:00:00', '15:30:00', 10, 'paused', '2026-02-01 14:00:00');

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. 학생 (13명 — 운영 10 / 휴원 1 / 퇴원 1 / parent NULL 1)
--    parent JSON: 캐노니컬 (relationship 영어 enum: father/mother/...)
--    백엔드 요청 (2026-05-20 questions-to-database §1.2, §1.3) 반영
-- ─────────────────────────────────────────────────────────────────────────────
SET @s1  = UUID_TO_BIN(UUID(), 1);
SET @s2  = UUID_TO_BIN(UUID(), 1);
SET @s3  = UUID_TO_BIN(UUID(), 1);
SET @s4  = UUID_TO_BIN(UUID(), 1);
SET @s5  = UUID_TO_BIN(UUID(), 1);
SET @s6  = UUID_TO_BIN(UUID(), 1);
SET @s7  = UUID_TO_BIN(UUID(), 1);
SET @s8  = UUID_TO_BIN(UUID(), 1);
SET @s9  = UUID_TO_BIN(UUID(), 1);
SET @s10 = UUID_TO_BIN(UUID(), 1);
SET @s11 = UUID_TO_BIN(UUID(), 1);
SET @s12 = UUID_TO_BIN(UUID(), 1);
SET @s13 = UUID_TO_BIN(UUID(), 1);
INSERT INTO students (id, tenant_id, name, birth_date, school_name, grade, address, registered_at, status, parent, parent_name, parent_phone) VALUES
  (@s1,  @academy_id, '김민준', '2014-03-15', '강남초등학교', '6', '서울 강남구 역삼동',  '2025-12-20 10:00:00', 'active', JSON_OBJECT('name','김아빠','phone','010-3001-0001','relationship','father','email',NULL), '김아빠', '010-3001-0001'),
  (@s2,  @academy_id, '이서윤', '2015-07-22', '강남초등학교', '5', '서울 강남구 역삼동',  '2025-12-22 11:00:00', 'active', JSON_OBJECT('name','이엄마','phone','010-3001-0002','relationship','mother','email',NULL), '이엄마', '010-3001-0002'),
  (@s3,  @academy_id, '박지호', '2013-11-08', '강남초등학교', '6', '서울 강남구 삼성동',  '2025-12-23 14:00:00', 'active', JSON_OBJECT('name','박아빠','phone','010-3001-0003','relationship','father','email',NULL), '박아빠', '010-3001-0003'),
  (@s4,  @academy_id, '최예린', '2016-02-19', '대치초등학교', '4', '서울 강남구 대치동',  '2025-12-26 16:00:00', 'active', JSON_OBJECT('name','최엄마','phone','010-3001-0004','relationship','mother','email',NULL), '최엄마', '010-3001-0004'),
  (@s5,  @academy_id, '정도현', '2014-08-30', '강남초등학교', '6', '서울 강남구 청담동',  '2025-12-27 10:00:00', 'active', JSON_OBJECT('name','정엄마','phone','010-3001-0005','relationship','mother','email',NULL), '정엄마', '010-3001-0005'),
  (@s6,  @academy_id, '강하은', '2015-05-12', '대치초등학교', '5', '서울 강남구 대치동',  '2025-12-28 11:00:00', 'active', JSON_OBJECT('name','강아빠','phone','010-3001-0006','relationship','father','email',NULL), '강아빠', '010-3001-0006'),
  (@s7,  @academy_id, '윤서준', '2014-12-01', '강남초등학교', '6', '서울 강남구 역삼동',  '2026-01-02 09:00:00', 'active', JSON_OBJECT('name','윤엄마','phone','010-3001-0007','relationship','mother','email',NULL), '윤엄마', '010-3001-0007'),
  (@s8,  @academy_id, '임채원', '2015-09-25', '대치초등학교', '5', '서울 강남구 도곡동',  '2026-01-03 10:00:00', 'active', JSON_OBJECT('name','임아빠','phone','010-3001-0008','relationship','father','email',NULL), '임아빠', '010-3001-0008'),
  (@s9,  @academy_id, '한지유', '2016-04-17', '강남초등학교', '4', '서울 강남구 삼성동',  '2026-01-05 14:00:00', 'active', JSON_OBJECT('name','한엄마','phone','010-3001-0009','relationship','mother','email',NULL), '한엄마', '010-3001-0009'),
  (@s10, @academy_id, '오민서', '2014-06-08', '강남초등학교', '6', '서울 강남구 청담동',  '2026-01-08 16:00:00', 'active', JSON_OBJECT('name','오아빠','phone','010-3001-0010','relationship','father','email',NULL), '오아빠', '010-3001-0010'),
  -- 휴원 학생 1명 — paused 상태 필터 검증용
  (@s11, @academy_id, '조하늘', '2015-01-10', '강남초등학교', '5', '서울 강남구 역삼동',  '2025-11-15 10:00:00', 'paused',    JSON_OBJECT('name','조엄마','phone','010-3001-0011','relationship','mother','email',NULL), '조엄마', '010-3001-0011'),
  -- 퇴원 학생 1명 — soft delete (withdrawn) 필터 검증용
  (@s12, @academy_id, '서민재', '2013-08-04', '강남초등학교', '6', '서울 강남구 청담동',  '2025-09-20 10:00:00', 'withdrawn', JSON_OBJECT('name','서아빠','phone','010-3001-0012','relationship','father','email',NULL), '서아빠', '010-3001-0012'),
  -- parent NULL 학생 1명 — 조부모 양육 등 학부모 미입력 케이스 안전성 검증용
  (@s13, @academy_id, '백지원', '2016-09-30', '대치초등학교', '4', '서울 강남구 대치동',  '2026-02-01 10:00:00', 'active',    NULL,                                                                                                              NULL,     NULL);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. 학생-클래스 등록 (총 18건)
--   태권도반(월수금): s1, s2, s3, s5, s6, s9         (6명)
--   수학반(화목):     s1, s4, s5, s7, s8, s10        (6명)
--   영어반(월수):     s2, s3, s4, s7, s9, s10        (6명)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO student_classes (id, tenant_id, student_id, class_id, enrolled_at, status) VALUES
  -- 태권도반
  (UUID_TO_BIN(UUID(),1), @academy_id, @s1, @class_taekwondo, '2025-12-20 10:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s2, @class_taekwondo, '2025-12-22 11:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s3, @class_taekwondo, '2025-12-23 14:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s5, @class_taekwondo, '2025-12-27 10:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s6, @class_taekwondo, '2025-12-28 11:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s9, @class_taekwondo, '2026-01-05 14:00:00', 'active'),
  -- 수학반
  (UUID_TO_BIN(UUID(),1), @academy_id, @s1,  @class_math, '2025-12-20 10:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s4,  @class_math, '2025-12-26 16:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s5,  @class_math, '2025-12-27 10:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s7,  @class_math, '2026-01-02 09:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s8,  @class_math, '2026-01-03 10:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s10, @class_math, '2026-01-08 16:00:00', 'active'),
  -- 영어반
  (UUID_TO_BIN(UUID(),1), @academy_id, @s2,  @class_english, '2025-12-22 11:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s3,  @class_english, '2025-12-23 14:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s4,  @class_english, '2025-12-26 16:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s7,  @class_english, '2026-01-02 09:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s9,  @class_english, '2026-01-05 14:00:00', 'active'),
  (UUID_TO_BIN(UUID(),1), @academy_id, @s10, @class_english, '2026-01-08 16:00:00', 'active');

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. 결제 (payments) — 2026-01 ~ 2026-05 월간
--     amount: 태권도 200,000 / 수학 250,000 / 영어 230,000
--     billing_date: 매월 1일 / due_date: 매월 10일
--     90% paid / 5% overdue / 5% cancelled (CRC32 해시 기반 결정적 분포)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO payments (id, tenant_id, student_id, class_id, billing_item, billing_breakdown,
                      amount, billing_date, due_date, paid_date, payment_method, payment_status)
WITH RECURSIVE months AS (
    SELECT DATE('2026-01-01') AS billing_month
    UNION ALL
    SELECT DATE_ADD(billing_month, INTERVAL 1 MONTH) FROM months
    WHERE billing_month < DATE('2026-05-01')
),
class_amount AS (
    SELECT @class_taekwondo AS cid, '태권도반 월 수강료' AS item, 200000.00 AS amt
    UNION ALL SELECT @class_math,    '수학반 월 수강료',   250000.00
    UNION ALL SELECT @class_english, '영어반 월 수강료',   230000.00
)
SELECT
    UUID_TO_BIN(UUID(), 1) AS id,
    @academy_id            AS tenant_id,
    sc.student_id,
    sc.class_id,
    ca.item                AS billing_item,
    JSON_OBJECT('tuition', ca.amt, 'discount', 0, 'extra', 0) AS billing_breakdown,
    ca.amt                 AS amount,
    m.billing_month        AS billing_date,
    DATE_ADD(m.billing_month, INTERVAL 9 DAY) AS due_date,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id, 1), BIN_TO_UUID(sc.class_id, 1), m.billing_month)), 100) < 90
            THEN DATE_ADD(m.billing_month,
                INTERVAL MOD(CRC32(CONCAT('paid_offset', BIN_TO_UUID(sc.student_id, 1), m.billing_month)), 9) DAY)
        ELSE NULL
    END AS paid_date,
    ELT(MOD(CRC32(CONCAT('method', BIN_TO_UUID(sc.student_id, 1), m.billing_month)), 4) + 1,
        'cash', 'card', 'transfer', 'auto_debit') AS payment_method,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id, 1), BIN_TO_UUID(sc.class_id, 1), m.billing_month)), 100) < 90 THEN 'paid'
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id, 1), BIN_TO_UUID(sc.class_id, 1), m.billing_month)), 100) < 95 THEN 'overdue'
        ELSE 'cancelled'
    END AS payment_status
FROM student_classes sc
CROSS JOIN months m
JOIN class_amount ca ON ca.cid = sc.class_id
WHERE sc.tenant_id = @academy_id
  AND sc.enrolled_at <= DATE_ADD(m.billing_month, INTERVAL 1 MONTH);

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. 결제 이력 (payment_events)
--     모든 결제: 'created' 이벤트 (billing_date 09:00)
--     paid 결제: 'paid' 이벤트 (paid_date 14:00)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO payment_events (id, tenant_id, payment_id, event_type, event_data, occurred_at)
SELECT UUID_TO_BIN(UUID(), 1), p.tenant_id, p.id, 'created',
       JSON_OBJECT('amount', p.amount, 'channel', 'system'),
       TIMESTAMP(p.billing_date, '09:00:00')
FROM payments p WHERE p.tenant_id = @academy_id;

INSERT INTO payment_events (id, tenant_id, payment_id, event_type, event_data, occurred_at)
SELECT UUID_TO_BIN(UUID(), 1), p.tenant_id, p.id, 'paid',
       JSON_OBJECT('method', p.payment_method, 'amount', p.amount),
       TIMESTAMP(p.paid_date, '14:00:00')
FROM payments p WHERE p.tenant_id = @academy_id AND p.payment_status = 'paid';

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. 출석 (attendances) — 2026-01-01 ~ 2026-05-10 클래스 운영 요일
--     80% present / 10% late / 5% absent / 5% excused (CRC32 해시 결정적)
--     check_in_at: present/late이면 클래스 시작 ±15분 범위
--     날짜 매핑: WEEKDAY(date) (월=0..일=6) + 1 → ISO (월=1..일=7)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO attendances (id, tenant_id, student_id, class_id, `date`, attendance_status,
                         check_in_at, vision_verification_id, absence_reason, absence_category,
                         is_absence_notified_in_advance)
WITH RECURSIVE dates AS (
    SELECT DATE('2026-01-01') AS d
    UNION ALL
    SELECT DATE_ADD(d, INTERVAL 1 DAY) FROM dates WHERE d < DATE('2026-05-10')
),
class_schedule AS (
    SELECT @class_taekwondo AS cid, JSON_ARRAY(1,3,5) AS dow, TIME('17:00:00') AS start_t
    UNION ALL SELECT @class_math,    JSON_ARRAY(2,4),   TIME('18:00:00')
    UNION ALL SELECT @class_english, JSON_ARRAY(1,3),   TIME('19:30:00')
)
SELECT
    UUID_TO_BIN(UUID(), 1) AS id,
    @academy_id            AS tenant_id,
    sc.student_id,
    sc.class_id,
    dt.d                   AS `date`,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) < 80 THEN 'present'
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) < 90 THEN 'late'
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) < 95 THEN 'absent'
        ELSE 'excused'
    END AS attendance_status,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) < 90
            THEN TIMESTAMP(dt.d,
                ADDTIME(cs.start_t,
                    SEC_TO_TIME(CAST(MOD(CRC32(CONCAT('checkin', BIN_TO_UUID(sc.student_id,1), dt.d)), 1500) AS SIGNED) - 600)))
        ELSE NULL
    END AS check_in_at,
    NULL AS vision_verification_id,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) >= 90
            THEN ELT(MOD(CRC32(CONCAT('reason', BIN_TO_UUID(sc.student_id,1), dt.d)), 4) + 1,
                     '몸살감기', '가족 행사', '여행', '기타 사유')
        ELSE NULL
    END AS absence_reason,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) >= 90
            THEN ELT(MOD(CRC32(CONCAT('cat', BIN_TO_UUID(sc.student_id,1), dt.d)), 5) + 1,
                     'sick', 'family', 'travel', 'school', 'other')
        ELSE NULL
    END AS absence_category,
    CASE
        WHEN MOD(CRC32(CONCAT(BIN_TO_UUID(sc.student_id,1), BIN_TO_UUID(sc.class_id,1), dt.d)), 100) >= 95 THEN TRUE
        ELSE FALSE
    END AS is_absence_notified_in_advance
FROM student_classes sc
CROSS JOIN dates dt
JOIN class_schedule cs ON cs.cid = sc.class_id
WHERE sc.tenant_id = @academy_id
  AND JSON_CONTAINS(cs.dow, CAST(WEEKDAY(dt.d) + 1 AS JSON))
  AND sc.enrolled_at <= dt.d
  AND (sc.unenrolled_at IS NULL OR sc.unenrolled_at > dt.d);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. 검증
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'academies'        AS t, COUNT(*) AS n FROM academies        WHERE id        = @academy_id
UNION ALL SELECT 'user_accounts',     COUNT(*) FROM user_accounts     WHERE tenant_id = @academy_id
UNION ALL SELECT 'settings',          COUNT(*) FROM settings          WHERE tenant_id = @academy_id
UNION ALL SELECT 'subjects',          COUNT(*) FROM subjects          WHERE tenant_id = @academy_id
UNION ALL SELECT 'rooms',             COUNT(*) FROM rooms             WHERE tenant_id = @academy_id
UNION ALL SELECT 'teachers',          COUNT(*) FROM teachers          WHERE tenant_id = @academy_id
UNION ALL SELECT 'classes',           COUNT(*) FROM classes           WHERE tenant_id = @academy_id
UNION ALL SELECT 'students',          COUNT(*) FROM students          WHERE tenant_id = @academy_id
UNION ALL SELECT 'student_classes',   COUNT(*) FROM student_classes   WHERE tenant_id = @academy_id
UNION ALL SELECT 'payments',          COUNT(*) FROM payments          WHERE tenant_id = @academy_id
UNION ALL SELECT 'payment_events',    COUNT(*) FROM payment_events    WHERE tenant_id = @academy_id
UNION ALL SELECT 'attendances',       COUNT(*) FROM attendances       WHERE tenant_id = @academy_id
UNION ALL SELECT 'semesters',         COUNT(*) FROM semesters         WHERE tenant_id = @academy_id;
