/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
SET @MYSQLDUMP_TEMP_LOG_BIN = @@SESSION.SQL_LOG_BIN;
SET @@SESSION.SQL_LOG_BIN= 0;

--
-- GTID state at the beginning of the backup
--

SET @@GLOBAL.GTID_PURGED=/*!80000 '+'*/ '5626957a-4c39-11f1-a0d4-78f153c9f678:1-334153';

--
-- Table structure for table `ability_tracks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ability_tracks` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `subject_id` binary(16) DEFAULT NULL,
  `description` varchar(500) DEFAULT NULL,
  `level_thresholds` json DEFAULT NULL COMMENT '등급 임계값 정의 — [{label, min_score, max_score}, ...]. NULL = 등급 미설정',
  `default_score` int NOT NULL DEFAULT '0' COMMENT '학생 enroll cascade 시 student_abilities.score 초기값 (0~100)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ability_tracks_tenant_id_name` (`tenant_id`,`name`),
  KEY `idx_ability_tracks_tenant_id_subject_id` (`tenant_id`,`subject_id`),
  CONSTRAINT `chk_ability_tracks_default_score` CHECK (((`default_score` >= 0) and (`default_score` <= 100))),
  CONSTRAINT `chk_ability_tracks_level_thresholds_is_array` CHECK (((`level_thresholds` is null) or (json_type(`level_thresholds`) = _utf8mb4'ARRAY'))),
  CONSTRAINT `chk_ability_tracks_level_thresholds_valid` CHECK (((`level_thresholds` is null) or json_valid(`level_thresholds`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `academies`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `academies` (
  `id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `business_number` varchar(20) NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `logo_url` varchar(500) DEFAULT NULL,
  `operating_hours` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `status` varchar(16) NOT NULL DEFAULT 'pending',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_academies_business_number` (`business_number`),
  CONSTRAINT `chk_academies_status` CHECK ((`status` in (_utf8mb4'pending',_utf8mb4'active')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ai_assistant_audit_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_assistant_audit_log` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `user_id` binary(16) NOT NULL COMMENT 'user_accounts.id (학원장)',
  `session_id` binary(16) NOT NULL COMMENT 'ai_assistant_sessions.id',
  `utterance` text NOT NULL COMMENT '사용자 발화 원문',
  `tool_name` varchar(50) DEFAULT NULL COMMENT '호출된 tool 이름. read-only 발화는 NULL',
  `tool_args` json DEFAULT NULL COMMENT 'tool 인자 (학원장이 confirm한 최종 값)',
  `result_status` varchar(20) NOT NULL COMMENT '''proposed'' | ''confirmed'' | ''cancelled'' | ''failed'' | ''expired''',
  `result_data` json DEFAULT NULL COMMENT '응답 row brief 또는 에러 사유',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ai_assistant_audit_log_tenant_id_user_id_created_at` (`tenant_id`,`user_id`,`created_at`),
  KEY `idx_ai_assistant_audit_log_session_id` (`session_id`),
  CONSTRAINT `chk_ai_assistant_audit_log_result_status` CHECK ((`result_status` in (_utf8mb4'proposed',_utf8mb4'confirmed',_utf8mb4'cancelled',_utf8mb4'failed',_utf8mb4'expired')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ai_assistant_sessions`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_assistant_sessions` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `user_id` binary(16) NOT NULL COMMENT 'user_accounts.id (학원장)',
  `messages` json NOT NULL COMMENT 'Claude 메시지 이력 [{"role","content"},...]',
  `expires_at` datetime NOT NULL COMMENT 'TTL 만료 시각 (보통 created_at + 24h)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ai_assistant_sessions_tenant_id_user_id` (`tenant_id`,`user_id`),
  KEY `idx_ai_assistant_sessions_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ai_assistant_unmet_requests`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_assistant_unmet_requests` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL COMMENT '학원 테넌트 — 멀티테넌시 격리(NOT NULL·누락 INSERT 차단). 조회/집계 tenant 범위 한정',
  `utterance` text NOT NULL COMMENT '미충족 요청 발화 원문(사용자 입력 텍스트 그대로). 긴 발화 대비 TEXT',
  `captured_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '캡처 시각 — 집계의 시간 축',
  `category` varchar(100) DEFAULT NULL COMMENT 'NULL 허용. 미충족 요청 분류(캡처 시점 미분류 가능·추후 BE/집계 채움 여지)',
  `reason` varchar(255) DEFAULT NULL COMMENT 'NULL 허용. 미충족 사유',
  `session_id` binary(16) DEFAULT NULL COMMENT 'NULL 허용. 발생 세션 참조(반복 패턴 추적용). 물리 FK 없음(앱 레벨)',
  `user_id` binary(16) DEFAULT NULL COMMENT 'NULL 허용. 발화 사용자 참조. 물리 FK 없음(앱 레벨)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ai_assistant_unmet_requests_tenant_id_captured_at` (`tenant_id`,`captured_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI비서 미충족 요청 캡처 — 흡수 못한 틀 밖 요청 발화 저장소(append-only·신호 로그). 자유도 정책 ④ 백로그 캡처. BE-46 INSERT 대상';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `attendances`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendances` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `class_id` binary(16) NOT NULL,
  `date` date NOT NULL,
  `attendance_status` varchar(20) NOT NULL,
  `check_in_at` datetime DEFAULT NULL,
  `vision_verification_id` binary(16) DEFAULT NULL,
  `absence_reason` varchar(255) DEFAULT NULL,
  `memo` varchar(500) DEFAULT NULL COMMENT '수업 일지 (강사·원장이 매 수업 종료 후 학생 단위 기록)',
  `absence_category` varchar(20) DEFAULT NULL,
  `is_absence_notified_in_advance` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_via` varchar(20) NOT NULL DEFAULT 'manual',
  `confirmed_at` datetime DEFAULT NULL,
  `confirmed_by` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_attendances_tenant_id_student_id_class_id_date` (`tenant_id`,`student_id`,`class_id`,`date`),
  KEY `idx_attendances_tenant_id_class_id_date` (`tenant_id`,`class_id`,`date`),
  KEY `idx_attendances_tenant_id_student_id_date` (`tenant_id`,`student_id`,`date`),
  CONSTRAINT `chk_attendances_absence_category` CHECK (((`absence_category` is null) or (`absence_category` in (_utf8mb4'sick',_utf8mb4'family',_utf8mb4'travel',_utf8mb4'school',_utf8mb4'other')))),
  CONSTRAINT `chk_attendances_created_via` CHECK ((`created_via` in (_utf8mb4'manual',_utf8mb4'auto',_utf8mb4'vision',_utf8mb4'ai'))),
  CONSTRAINT `chk_attendances_status` CHECK ((`attendance_status` in (_utf8mb4'present',_utf8mb4'late',_utf8mb4'absent',_utf8mb4'excused')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `billing_schedules`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `billing_schedules` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `class_id` binary(16) DEFAULT NULL COMMENT '반 단위 청구 시 클래스. NULL=학생 단위 청구',
  `monthly_fee` decimal(12,2) NOT NULL COMMENT '월 청구액 (KRW 정수 권장·payments.amount 대응)',
  `anchor_day` tinyint NOT NULL COMMENT '매달 청구일 1~31. 말일 클램프: 해당월 일수보다 크면 말일 청구(Backend 계약)',
  `billing_item` varchar(255) NOT NULL COMMENT '청구 항목명 (payment.billing_item 대응)',
  `status` varchar(20) NOT NULL DEFAULT 'active' COMMENT '구독 상태: active/paused',
  `last_generated_for_month` date DEFAULT NULL COMMENT '멱등 키 — 마지막 생성 청구월(YYYY-MM-01)·중복청구 방지',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_billing_schedules_tenant_id_status_last_generated_for_month` (`tenant_id`,`status`,`last_generated_for_month`),
  KEY `idx_billing_schedules_tenant_id_student_id` (`tenant_id`,`student_id`),
  CONSTRAINT `chk_billing_schedules_anchor_day` CHECK ((`anchor_day` between 1 and 31)),
  CONSTRAINT `chk_billing_schedules_monthly_fee` CHECK ((`monthly_fee` >= 0)),
  CONSTRAINT `chk_billing_schedules_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='정기 결제(매달 자동 청구) 생성용 청구 소스 — 구독 단위 청구 룰+멱등 키 (BE daily_billing_generator 소비)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `class_ability_tracks`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `class_ability_tracks` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `class_id` binary(16) NOT NULL,
  `ability_track_id` binary(16) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_class_ability_tracks_tenant_class_track` (`tenant_id`,`class_id`,`ability_track_id`),
  KEY `idx_class_ability_tracks_tenant_class` (`tenant_id`,`class_id`),
  KEY `idx_class_ability_tracks_tenant_track` (`tenant_id`,`ability_track_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='클래스 ↔ 능력치 트랙 N:M 매핑 — 학생 enroll cascade 시 자동 평가 row 생성용';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `class_cancellations`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='클래스 휴강 — 반복 클래스의 특정 날짜 1회 수업 취소 기록 (폐강=classes.status ended 와 별개)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `classes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `classes` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `subject_id` binary(16) DEFAULT NULL,
  `teacher_id` binary(16) DEFAULT NULL,
  `room_id` binary(16) DEFAULT NULL,
  `days_of_week` json DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `capacity` int unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `started_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_classes_tenant_id_status` (`tenant_id`,`status`),
  KEY `idx_classes_tenant_id_subject_id` (`tenant_id`,`subject_id`),
  KEY `idx_classes_tenant_id_teacher_id` (`tenant_id`,`teacher_id`),
  KEY `idx_classes_tenant_id_room_id` (`tenant_id`,`room_id`),
  KEY `idx_classes_tenant_status_end_date` (`tenant_id`,`status`,`end_date`),
  KEY `idx_classes_tenant_start_date` (`tenant_id`,`start_date`),
  CONSTRAINT `chk_classes_date_range` CHECK (((`start_date` is null) or (`end_date` is null) or (`end_date` >= `start_date`))),
  CONSTRAINT `chk_classes_days_of_week_not_empty` CHECK (((`days_of_week` is null) or (json_length(`days_of_week`) >= 1))),
  CONSTRAINT `chk_classes_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused',_utf8mb4'ended',_utf8mb4'archived')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `guardian_consents`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `guardian_consents` (
  `id` binary(16) NOT NULL,
  `guardian_id` binary(16) NOT NULL,
  `person_id` binary(16) NOT NULL,
  `action` varchar(30) NOT NULL,
  `otp_verified_at` datetime NOT NULL COMMENT 'SMS OTP 검증 완료 시각 (B4'' SMS 통일)',
  `consented_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revoked_at` datetime DEFAULT NULL COMMENT 'NULL = 활성 / NOT NULL = 철회됨',
  `ip_address` varchar(45) DEFAULT NULL COMMENT 'IPv4/IPv6 — audit 보강',
  `user_agent` varchar(255) DEFAULT NULL COMMENT 'client UA — audit 보강',
  PRIMARY KEY (`id`),
  KEY `idx_consents_guardian` (`guardian_id`,`consented_at`),
  KEY `idx_consents_person` (`person_id`,`consented_at`),
  CONSTRAINT `chk_consent_action` CHECK ((`action` in (_utf8mb4'claim_person',_utf8mb4'link_to_academy',_utf8mb4'revoke',_utf8mb4'reauth')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='학부모 동의 audit (개인정보보호법 시행령 §29 정합)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `guardian_persons`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `guardian_persons` (
  `id` binary(16) NOT NULL,
  `guardian_id` binary(16) NOT NULL,
  `person_id` binary(16) NOT NULL,
  `relationship` varchar(20) NOT NULL COMMENT 'mother | father | guardian | grandparent | other',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_guardian_persons` (`guardian_id`,`person_id`),
  KEY `idx_guardian_persons_person` (`person_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='보호자 ↔ 아이 매핑 (claimed 상태) — 형제자매 자동 그룹 매칭 SOURCE';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `guardians`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `guardians` (
  `id` binary(16) NOT NULL,
  `phone` varchar(20) NOT NULL COMMENT 'B1'' 1차 lookup 키 — exact match',
  `name` varchar(100) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password_hash` varchar(255) DEFAULT NULL COMMENT 'B4'' SMS OTP 통일 — 비밀번호 인증 옵션',
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_guardians_phone` (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='글로벌 보호자 계정 (학부모 앱 로그인) — user_accounts 와 별도 인증 stack';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `holidays`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `holidays` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `date` date NOT NULL,
  `name` varchar(100) NOT NULL,
  `type` varchar(20) NOT NULL DEFAULT 'academy',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_holidays_tenant_id_date` (`tenant_id`,`date`),
  CONSTRAINT `chk_holidays_type` CHECK ((`type` in (_utf8mb4'public',_utf8mb4'academy',_utf8mb4'special')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_templates`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_templates` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `template_type` varchar(50) NOT NULL,
  `channel` varchar(20) NOT NULL,
  `title` varchar(200) DEFAULT NULL,
  `body` text NOT NULL,
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `timing_config` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_message_templates_tenant_id_type_channel` (`tenant_id`,`template_type`,`channel`),
  CONSTRAINT `chk_message_templates_channel` CHECK ((`channel` in (_utf8mb4'sms',_utf8mb4'email',_utf8mb4'push',_utf8mb4'kakao')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payment_adjustments`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_adjustments` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `type` varchar(20) NOT NULL COMMENT '''discount'' = A안 (다음 청구서에서 차감) | ''refund'' = C안 (paid 결제 일부 환급 기록)',
  `amount` decimal(12,2) NOT NULL COMMENT '학원장 입력값 (KRW 정수 권장. v1 정책상 자유 입력)',
  `reason` varchar(500) DEFAULT NULL COMMENT '사유 (자유 텍스트, v1)',
  `period_start` date DEFAULT NULL COMMENT '부재/할인 시작일 (선택, audit 보조)',
  `period_end` date DEFAULT NULL COMMENT '부재/할인 종료일 (선택)',
  `target_payment_id` binary(16) DEFAULT NULL COMMENT '''discount'': 적용 대상 (NULL = 다음 미생성 청구서) / ''refund'': 원 결제 id (필수)',
  `applied_payment_id` binary(16) DEFAULT NULL COMMENT '실제로 적용된 결제 id (pending → applied 전이 시 채워짐)',
  `status` varchar(20) NOT NULL DEFAULT 'pending' COMMENT '''pending'' | ''applied'' | ''cancelled''',
  `created_by` binary(16) NOT NULL COMMENT 'user_accounts.id (학원장)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payment_adjustments_tenant_id_student_id` (`tenant_id`,`student_id`),
  KEY `idx_payment_adjustments_tenant_id_target_payment_id` (`tenant_id`,`target_payment_id`),
  KEY `idx_payment_adjustments_tenant_id_status` (`tenant_id`,`status`),
  CONSTRAINT `chk_payment_adjustments_amount` CHECK ((`amount` >= 0)),
  CONSTRAINT `chk_payment_adjustments_period` CHECK (((`period_end` is null) or (`period_start` is null) or (`period_end` >= `period_start`))),
  CONSTRAINT `chk_payment_adjustments_status` CHECK ((`status` in (_utf8mb4'pending',_utf8mb4'applied',_utf8mb4'cancelled'))),
  CONSTRAINT `chk_payment_adjustments_type` CHECK ((`type` in (_utf8mb4'discount',_utf8mb4'refund')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payment_events`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_events` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `payment_id` binary(16) NOT NULL,
  `event_type` varchar(30) NOT NULL,
  `event_data` json DEFAULT NULL,
  `occurred_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payment_events_tenant_id_payment_id_occurred_at` (`tenant_id`,`payment_id`,`occurred_at`),
  CONSTRAINT `chk_payment_events_type` CHECK ((`event_type` in (_utf8mb4'created',_utf8mb4'paid',_utf8mb4'overdue_marked',_utf8mb4'cancelled',_utf8mb4'refunded',_utf8mb4'reminder_sent',_utf8mb4'note_added',_utf8mb4'adjusted',_utf8mb4'postponed')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payments`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payments` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `class_id` binary(16) DEFAULT NULL,
  `billing_item` varchar(100) NOT NULL,
  `billing_breakdown` json DEFAULT NULL,
  `amount` decimal(12,2) NOT NULL,
  `billing_date` date NOT NULL,
  `due_date` date DEFAULT NULL,
  `paid_date` date DEFAULT NULL,
  `payment_method` varchar(20) DEFAULT NULL,
  `payment_status` varchar(20) NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `refunded_amount` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT '누적 환급 금액 (v1 부분 환급 표현, X 옵션 — Director 채택)',
  PRIMARY KEY (`id`),
  KEY `idx_payments_tenant_id_billing_date` (`tenant_id`,`billing_date`),
  KEY `idx_payments_tenant_id_student_id` (`tenant_id`,`student_id`),
  KEY `idx_payments_tenant_id_status` (`tenant_id`,`payment_status`),
  KEY `idx_payments_tenant_id_due_date` (`tenant_id`,`due_date`),
  CONSTRAINT `chk_payments_amount` CHECK ((`amount` >= 0)),
  CONSTRAINT `chk_payments_method` CHECK (((`payment_method` is null) or (`payment_method` in (_utf8mb4'cash',_utf8mb4'card',_utf8mb4'transfer',_utf8mb4'auto_debit')))),
  CONSTRAINT `chk_payments_refunded_amount` CHECK (((`refunded_amount` >= 0) and (`refunded_amount` <= `amount`))),
  CONSTRAINT `chk_payments_status` CHECK ((`payment_status` in (_utf8mb4'pending',_utf8mb4'paid',_utf8mb4'overdue',_utf8mb4'cancelled',_utf8mb4'refunded')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `person_link_requests`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `person_link_requests` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `person_id` binary(16) NOT NULL,
  `initiator` varchar(20) NOT NULL COMMENT 'academy (Type A'') | guardian (Type B)',
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `requested_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` datetime DEFAULT NULL,
  `expires_at` datetime NOT NULL COMMENT 'B2 Z — 30일 권장 (운영 정책)',
  PRIMARY KEY (`id`),
  KEY `idx_plr_tenant_status` (`tenant_id`,`status`),
  KEY `idx_plr_person_status` (`person_id`,`status`),
  CONSTRAINT `chk_plr_initiator` CHECK ((`initiator` in (_utf8mb4'academy',_utf8mb4'guardian'))),
  CONSTRAINT `chk_plr_status` CHECK ((`status` in (_utf8mb4'pending',_utf8mb4'approved',_utf8mb4'rejected',_utf8mb4'expired')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='학원 ↔ 학생 ↔ person 매칭 요청 워크플로우 (Type A''/B)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `persons`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `persons` (
  `id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `birth_date` date DEFAULT NULL,
  `gender` varchar(10) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_persons_name_birth` (`name`,`birth_date`),
  CONSTRAINT `chk_persons_gender` CHECK (((`gender` is null) or (`gender` in (_utf8mb4'male',_utf8mb4'female',_utf8mb4'other'))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='글로벌 인물 (학생/아이) — 학부모 앱 통합 뷰 SOURCE';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `refresh_tokens`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `refresh_tokens` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `user_account_id` binary(16) NOT NULL,
  `token_hash` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_refresh_tokens_token_hash` (`token_hash`),
  KEY `idx_refresh_tokens_tenant_id_user_account_id` (`tenant_id`,`user_account_id`),
  KEY `idx_refresh_tokens_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rooms`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rooms` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rooms_tenant_id_name` (`tenant_id`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `schema_migrations`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `semesters`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `semesters` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(40) NOT NULL,
  `starts_on` date NOT NULL,
  `ends_on` date NOT NULL,
  `is_current` tinyint(1) NOT NULL DEFAULT '0',
  `description` varchar(200) DEFAULT NULL,
  `current_flag` binary(16) GENERATED ALWAYS AS (if((`is_current` = true),`tenant_id`,NULL)) VIRTUAL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_semesters_tenant_current` (`current_flag`),
  KEY `idx_semesters_tenant_id_starts_on` (`tenant_id`,`starts_on`),
  CONSTRAINT `chk_semesters_date_range` CHECK ((`ends_on` >= `starts_on`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `settings`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `payment_settings` json DEFAULT NULL,
  `notification_settings` json DEFAULT NULL,
  `auto_attendance_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '자동 출결 활성 여부 (TRUE=활성, FALSE=비활성)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_settings_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `student_abilities`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `student_abilities` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `ability_track_id` binary(16) NOT NULL,
  `score` int NOT NULL DEFAULT '0',
  `evaluated_at` datetime DEFAULT NULL COMMENT '학원장 명시 평가 시각. NULL = enroll cascade 자동 초기화 (미평가).',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_student_abilities_tenant_id_student_id_track_id` (`tenant_id`,`student_id`,`ability_track_id`),
  KEY `idx_student_abilities_tenant_id_student_id` (`tenant_id`,`student_id`),
  CONSTRAINT `chk_student_abilities_score` CHECK (((`score` >= 0) and (`score` <= 100)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `student_classes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `student_classes` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `class_id` binary(16) NOT NULL,
  `enrolled_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `unenrolled_at` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `attending_days_of_week` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_student_classes_tenant_id_student_id_class_id` (`tenant_id`,`student_id`,`class_id`),
  KEY `idx_student_classes_tenant_id_class_id` (`tenant_id`,`class_id`),
  CONSTRAINT `chk_student_classes_attending_days_not_empty` CHECK (((`attending_days_of_week` is null) or (json_length(`attending_days_of_week`) >= 1))),
  CONSTRAINT `chk_student_classes_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'unenrolled',_utf8mb4'completed')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `student_notes`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `student_notes` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `content` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_student_notes_tenant_id_student_id` (`tenant_id`,`student_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `students`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `students` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `person_id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `birth_date` date DEFAULT NULL,
  `school_name` varchar(100) DEFAULT NULL,
  `grade` varchar(20) DEFAULT NULL,
  `profile_image_url` varchar(500) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `registered_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `parent` json DEFAULT NULL,
  `parent_name` varchar(100) DEFAULT NULL,
  `parent_phone` varchar(20) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` binary(16) DEFAULT NULL,
  `active_uk_token` binary(16) GENERATED ALWAYS AS (if((`is_deleted` = 0),`tenant_id`,NULL)) VIRTUAL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_students_tenant_name_phone` (`name`,`phone`,`active_uk_token`),
  KEY `idx_students_tenant_id_status` (`tenant_id`,`status`),
  KEY `idx_students_tenant_id_parent_phone` (`tenant_id`,`parent_phone`),
  KEY `idx_students_tenant_id_name` (`tenant_id`,`name`),
  KEY `idx_students_person_id` (`person_id`),
  CONSTRAINT `chk_students_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused',_utf8mb4'withdrawn')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subjects`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subjects` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(50) NOT NULL,
  `color_token` varchar(30) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_subjects_tenant_id_name` (`tenant_id`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `teachers`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `teachers` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `subject_id` binary(16) DEFAULT NULL,
  `profile_image_url` varchar(500) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `employment_type` varchar(20) NOT NULL DEFAULT 'full_time',
  `pay_type` enum('annual','monthly','hourly') NOT NULL DEFAULT 'hourly' COMMENT '급여 형태 (연봉/월급/시간당)',
  `base_pay` int unsigned DEFAULT NULL COMMENT '급여 금액 (원 단위, pay_type 에 종속)',
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `memo` text COMMENT '강사 내부 메모 (학원장 자유 입력, multi-line)',
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_teachers_tenant_id_status` (`tenant_id`,`status`),
  KEY `idx_teachers_tenant_id_subject_id` (`tenant_id`,`subject_id`),
  CONSTRAINT `chk_teachers_employment_type` CHECK ((`employment_type` in (_utf8mb4'full_time',_utf8mb4'part_time',_utf8mb4'contract'))),
  CONSTRAINT `chk_teachers_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'inactive',_utf8mb4'resigned')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `uploads`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `uploads` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `purpose` varchar(50) NOT NULL,
  `object_key` varchar(500) NOT NULL,
  `original_filename` varchar(255) DEFAULT NULL,
  `content_type` varchar(100) DEFAULT NULL,
  `byte_size` bigint unsigned DEFAULT NULL,
  `upload_status` varchar(20) NOT NULL DEFAULT 'pending',
  `processed_url` varchar(500) DEFAULT NULL,
  `thumbnail_url` varchar(500) DEFAULT NULL,
  `created_by_user_account_id` binary(16) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_uploads_object_key` (`object_key`),
  KEY `idx_uploads_tenant_id_purpose` (`tenant_id`,`purpose`),
  KEY `idx_uploads_tenant_id_status` (`tenant_id`,`upload_status`),
  CONSTRAINT `chk_uploads_purpose` CHECK ((`purpose` in (_utf8mb4'student_profile',_utf8mb4'teacher_profile',_utf8mb4'academy_logo',_utf8mb4'vision_image',_utf8mb4'other'))),
  CONSTRAINT `chk_uploads_status` CHECK ((`upload_status` in (_utf8mb4'pending',_utf8mb4'uploading',_utf8mb4'processing',_utf8mb4'completed',_utf8mb4'failed')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_accounts`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_accounts` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `name` varchar(100) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `role` varchar(20) NOT NULL DEFAULT 'owner',
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_accounts_email` (`email`),
  KEY `idx_user_accounts_tenant_id` (`tenant_id`),
  CONSTRAINT `chk_user_accounts_role` CHECK ((`role` = _utf8mb4'owner'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vision_verifications`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vision_verifications` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `image_url` varchar(500) NOT NULL,
  `confidence` decimal(5,4) DEFAULT NULL,
  `verified_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_vision_verifications_tenant_id_student_id_verified_at` (`tenant_id`,`student_id`,`verified_at`),
  CONSTRAINT `chk_vision_verifications_confidence` CHECK (((`confidence` is null) or ((`confidence` >= 0) and (`confidence` <= 1))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'ProjectRG_Dev'
--
SET @@SESSION.SQL_LOG_BIN = @MYSQLDUMP_TEMP_LOG_BIN;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed

--
-- Dbmate schema migrations
--

LOCK TABLES `schema_migrations` WRITE;
INSERT INTO `schema_migrations` (version) VALUES
  ('20260510000001'),
  ('20260510105848'),
  ('20260510105849'),
  ('20260514074640'),
  ('20260516144831'),
  ('20260516151748'),
  ('20260520123408'),
  ('20260527064335'),
  ('20260527092031'),
  ('20260527092043'),
  ('20260527101754'),
  ('20260527102152'),
  ('20260528071913'),
  ('20260528113525'),
  ('20260528113526'),
  ('20260528113527'),
  ('20260528113528'),
  ('20260528113529'),
  ('20260528114510'),
  ('20260528123600'),
  ('20260528152603'),
  ('20260604053804'),
  ('20260604121944'),
  ('20260605042052'),
  ('20260610000000'),
  ('20260610010000'),
  ('20260611101124'),
  ('20260611152905'),
  ('20260611152906'),
  ('20260612091334'),
  ('20260613120125'),
  ('20260621082349'),
  ('20260629044913');
UNLOCK TABLES;
