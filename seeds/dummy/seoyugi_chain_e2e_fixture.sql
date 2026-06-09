-- ─────────────────────────────────────────────────────────────────────────────
-- seoyugi_chain_e2e_fixture.sql
--   작업 코드: DB-1 / LOCAL-FIXTURE-CHAIN-E2E-DATA  (RG_Backend 발의)
--   목적: DIR-17 C40~C42 enroll/unenroll chain e2e 재검증용 fixture 추가.
--   대상: 로컬 dev DB 127.0.0.1 ProjectRG_Dev / 테넌트 = 서유기학원.
--
--   이 스크립트는 **추가(INSERT)만** 한다. 기존 행(토요 심화수학반, 초등 재원생 등)
--   삭제/변경 없음. DDL 없음(행 INSERT만).
--
--   멱등성: 고정 UUID 네임스페이스 + INSERT IGNORE.
--     - classes  : e2ec1a55-0000-... (수학반 13/15/17시 active 3건)
--     - persons  : e2e90000-... (중학생 person)
--     - students : e2e57000-... (중학생 grade 7~9)
--     - student_classes : e2e5c000-... (active enrollment)
--   재실행 시 UNIQUE 키 / PK 충돌은 IGNORE 로 흡수되어 안전.
--
--   UUID 바이트 오더: 이 프로젝트 규칙대로 UUID_TO_BIN(x, 1) / 스왑 플래그 1 사용.
-- ─────────────────────────────────────────────────────────────────────────────

-- 서유기학원 테넌트
SET @academy_id = UUID_TO_BIN('015da66a-5a66-11f1-9698-b05dc2b43f1d', 1);

-- 수학 과목 / 수학 강사(황포괴) / 강의실(2관) — 라이브 DB 실측 식별자
SET @subj_math   = UUID_TO_BIN('015e56c8-5a66-11f1-9698-b05dc2b43f1d', 1);
SET @teacher_hp  = UUID_TO_BIN('015f2c10-5a66-11f1-9698-b05dc2b43f1d', 1);  -- 황포괴 (수학)
SET @room_class  = UUID_TO_BIN('015e7874-5a66-11f1-9698-b05dc2b43f1d', 1);  -- 2관

-- ─────────────────────────────────────────────────────────────────────────────
-- §1. 13~18시 active 수학반 복수 (13:00 / 15:00 / 17:00 시작)
--     기존 "토요 심화수학반"(14:00·paused·요일 토)과 명/시간/요일/status 로 구분.
--     find_class("수학반") 이 비어있지 않고 시간대 narrowing 이 동작하도록.
-- ─────────────────────────────────────────────────────────────────────────────
SET @class_math_13 = UUID_TO_BIN('e2ec1a55-0000-0000-0000-000000001300', 1);
SET @class_math_15 = UUID_TO_BIN('e2ec1a55-0000-0000-0000-000000001500', 1);
SET @class_math_17 = UUID_TO_BIN('e2ec1a55-0000-0000-0000-000000001700', 1);

INSERT IGNORE INTO classes
  (id, tenant_id, name, subject_id, teacher_id, room_id, days_of_week, start_time, end_time, capacity, status, started_at)
VALUES
  (@class_math_13, @academy_id, '수학반 오후1시', @subj_math, @teacher_hp, @room_class, JSON_ARRAY(1,3,5), '13:00:00', '14:30:00', 12, 'active', '2026-03-02 13:00:00'),
  (@class_math_15, @academy_id, '수학반 오후3시', @subj_math, @teacher_hp, @room_class, JSON_ARRAY(1,3,5), '15:00:00', '16:30:00', 12, 'active', '2026-03-02 15:00:00'),
  (@class_math_17, @academy_id, '수학반 오후5시', @subj_math, @teacher_hp, @room_class, JSON_ARRAY(2,4),   '17:00:00', '18:30:00', 12, 'active', '2026-03-03 17:00:00');

-- ─────────────────────────────────────────────────────────────────────────────
-- §2. 중학생(grade 7~9) 재원생 다수
--     기존 재원생 전원 초등(grade 4~6)이라 중학생 필터가 공집합 → grade '7'/'8'/'9' 추가.
--     grade 컬럼은 VARCHAR; 기존 active 재원생 관례('6','5','4')대로 plain number 저장.
--     students.person_id 는 NOT NULL 이며 auto trigger 가 DROP 되었으므로 persons 를 명시 INSERT.
-- ─────────────────────────────────────────────────────────────────────────────
SET @p_m1 = UUID_TO_BIN('e2e90000-0000-0000-0000-000000000071', 1);
SET @p_m2 = UUID_TO_BIN('e2e90000-0000-0000-0000-000000000072', 1);
SET @p_m3 = UUID_TO_BIN('e2e90000-0000-0000-0000-000000000073', 1);
SET @p_m4 = UUID_TO_BIN('e2e90000-0000-0000-0000-000000000081', 1);
SET @p_m5 = UUID_TO_BIN('e2e90000-0000-0000-0000-000000000082', 1);
SET @p_m6 = UUID_TO_BIN('e2e90000-0000-0000-0000-000000000091', 1);

INSERT IGNORE INTO persons (id, name, birth_date, gender) VALUES
  (@p_m1, '한중학', '2012-04-11', 'male'),
  (@p_m2, '서중학', '2012-09-23', 'female'),
  (@p_m3, '오중학', '2012-12-05', 'male'),
  (@p_m4, '임중학', '2011-03-17', 'female'),
  (@p_m5, '강중학', '2011-08-29', 'male'),
  (@p_m6, '윤중학', '2010-06-14', 'female');

SET @s_m1 = UUID_TO_BIN('e2e57000-0000-0000-0000-000000000071', 1);
SET @s_m2 = UUID_TO_BIN('e2e57000-0000-0000-0000-000000000072', 1);
SET @s_m3 = UUID_TO_BIN('e2e57000-0000-0000-0000-000000000073', 1);
SET @s_m4 = UUID_TO_BIN('e2e57000-0000-0000-0000-000000000081', 1);
SET @s_m5 = UUID_TO_BIN('e2e57000-0000-0000-0000-000000000082', 1);
SET @s_m6 = UUID_TO_BIN('e2e57000-0000-0000-0000-000000000091', 1);

INSERT IGNORE INTO students
  (id, tenant_id, person_id, name, birth_date, school_name, grade, address, phone, registered_at, status, parent, parent_name, parent_phone)
VALUES
  (@s_m1, @academy_id, @p_m1, '한중학', '2012-04-11', '강남중학교', '7', '서울 강남구 역삼동', '010-3007-0071', '2026-03-01 10:00:00', 'active', JSON_OBJECT('name','한중부','phone','010-3007-1071','relationship','father','email',NULL), '한중부', '010-3007-1071'),
  (@s_m2, @academy_id, @p_m2, '서중학', '2012-09-23', '강남중학교', '7', '서울 강남구 삼성동', '010-3007-0072', '2026-03-01 11:00:00', 'active', JSON_OBJECT('name','서중모','phone','010-3007-1072','relationship','mother','email',NULL), '서중모', '010-3007-1072'),
  (@s_m3, @academy_id, @p_m3, '오중학', '2012-12-05', '대치중학교', '7', '서울 강남구 대치동', '010-3007-0073', '2026-03-02 10:00:00', 'active', JSON_OBJECT('name','오중부','phone','010-3007-1073','relationship','father','email',NULL), '오중부', '010-3007-1073'),
  (@s_m4, @academy_id, @p_m4, '임중학', '2011-03-17', '대치중학교', '8', '서울 강남구 도곡동', '010-3008-0081', '2026-03-02 11:00:00', 'active', JSON_OBJECT('name','임중모','phone','010-3008-1081','relationship','mother','email',NULL), '임중모', '010-3008-1081'),
  (@s_m5, @academy_id, @p_m5, '강중학', '2011-08-29', '강남중학교', '8', '서울 강남구 청담동', '010-3008-0082', '2026-03-03 10:00:00', 'active', JSON_OBJECT('name','강중부','phone','010-3008-1082','relationship','father','email',NULL), '강중부', '010-3008-1082'),
  (@s_m6, @academy_id, @p_m6, '윤중학', '2010-06-14', '강남중학교', '9', '서울 강남구 역삼동', '010-3009-0091', '2026-03-03 11:00:00', 'active', JSON_OBJECT('name','윤중모','phone','010-3009-1091','relationship','mother','email',NULL), '윤중모', '010-3009-1091');

-- ─────────────────────────────────────────────────────────────────────────────
-- §3. §1 수학반에 §2 중학생을 active enrollment 로 연결
--     enrollment affected > 0 → 실제 unenroll 경로(C40~C42)가 검증되게.
--     수학반 오후1시: m1,m2,m3 / 오후3시: m4,m5 / 오후5시: m6
-- ─────────────────────────────────────────────────────────────────────────────
INSERT IGNORE INTO student_classes
  (id, tenant_id, student_id, class_id, enrolled_at, status)
VALUES
  (UUID_TO_BIN('e2e5c000-0000-0000-0000-000000130071', 1), @academy_id, @s_m1, @class_math_13, '2026-03-02 13:00:00', 'active'),
  (UUID_TO_BIN('e2e5c000-0000-0000-0000-000000130072', 1), @academy_id, @s_m2, @class_math_13, '2026-03-02 13:00:00', 'active'),
  (UUID_TO_BIN('e2e5c000-0000-0000-0000-000000130073', 1), @academy_id, @s_m3, @class_math_13, '2026-03-02 13:00:00', 'active'),
  (UUID_TO_BIN('e2e5c000-0000-0000-0000-000000150081', 1), @academy_id, @s_m4, @class_math_15, '2026-03-02 15:00:00', 'active'),
  (UUID_TO_BIN('e2e5c000-0000-0000-0000-000000150082', 1), @academy_id, @s_m5, @class_math_15, '2026-03-02 15:00:00', 'active'),
  (UUID_TO_BIN('e2e5c000-0000-0000-0000-000000170091', 1), @academy_id, @s_m6, @class_math_17, '2026-03-03 17:00:00', 'active');
