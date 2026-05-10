/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ability_tracks` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `subject_id` binary(16) DEFAULT NULL,
  `description` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ability_tracks_tenant_id_name` (`tenant_id`,`name`),
  KEY `idx_ability_tracks_tenant_id_subject_id` (`tenant_id`,`subject_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_academies_business_number` (`business_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  `absence_category` varchar(20) DEFAULT NULL,
  `is_absence_notified_in_advance` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_attendances_tenant_id_student_id_class_id_date` (`tenant_id`,`student_id`,`class_id`,`date`),
  KEY `idx_attendances_tenant_id_class_id_date` (`tenant_id`,`class_id`,`date`),
  KEY `idx_attendances_tenant_id_student_id_date` (`tenant_id`,`student_id`,`date`),
  CONSTRAINT `chk_attendances_absence_category` CHECK (((`absence_category` is null) or (`absence_category` in (_utf8mb4'sick',_utf8mb4'family',_utf8mb4'travel',_utf8mb4'other')))),
  CONSTRAINT `chk_attendances_status` CHECK ((`attendance_status` in (_utf8mb4'present',_utf8mb4'late',_utf8mb4'absent',_utf8mb4'excused')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `capacity` int unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `started_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_classes_tenant_id_status` (`tenant_id`,`status`),
  KEY `idx_classes_tenant_id_subject_id` (`tenant_id`,`subject_id`),
  KEY `idx_classes_tenant_id_teacher_id` (`tenant_id`,`teacher_id`),
  KEY `idx_classes_tenant_id_room_id` (`tenant_id`,`room_id`),
  CONSTRAINT `chk_classes_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused',_utf8mb4'ended')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  CONSTRAINT `chk_payment_events_type` CHECK ((`event_type` in (_utf8mb4'created',_utf8mb4'paid',_utf8mb4'overdue_marked',_utf8mb4'cancelled',_utf8mb4'refunded',_utf8mb4'reminder_sent',_utf8mb4'note_added')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  PRIMARY KEY (`id`),
  KEY `idx_payments_tenant_id_billing_date` (`tenant_id`,`billing_date`),
  KEY `idx_payments_tenant_id_student_id` (`tenant_id`,`student_id`),
  KEY `idx_payments_tenant_id_status` (`tenant_id`,`payment_status`),
  KEY `idx_payments_tenant_id_due_date` (`tenant_id`,`due_date`),
  CONSTRAINT `chk_payments_amount` CHECK ((`amount` >= 0)),
  CONSTRAINT `chk_payments_method` CHECK (((`payment_method` is null) or (`payment_method` in (_utf8mb4'cash',_utf8mb4'card',_utf8mb4'transfer',_utf8mb4'auto_debit')))),
  CONSTRAINT `chk_payments_status` CHECK ((`payment_status` in (_utf8mb4'pending',_utf8mb4'paid',_utf8mb4'overdue',_utf8mb4'cancelled',_utf8mb4'refunded')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `payment_settings` json DEFAULT NULL,
  `notification_settings` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_settings_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `student_abilities` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `student_id` binary(16) NOT NULL,
  `ability_track_id` binary(16) NOT NULL,
  `score` decimal(5,2) NOT NULL,
  `evaluated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_student_abilities_tenant_id_student_id_track_id` (`tenant_id`,`student_id`,`ability_track_id`),
  KEY `idx_student_abilities_tenant_id_student_id` (`tenant_id`,`student_id`),
  CONSTRAINT `chk_student_abilities_score` CHECK (((`score` >= 0) and (`score` <= 100)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_student_classes_tenant_id_student_id_class_id` (`tenant_id`,`student_id`,`class_id`),
  KEY `idx_student_classes_tenant_id_class_id` (`tenant_id`,`class_id`),
  CONSTRAINT `chk_student_classes_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'unenrolled',_utf8mb4'completed')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `students` (
  `id` binary(16) NOT NULL,
  `tenant_id` binary(16) NOT NULL,
  `name` varchar(100) NOT NULL,
  `birth_date` date DEFAULT NULL,
  `school_name` varchar(100) DEFAULT NULL,
  `grade` varchar(20) DEFAULT NULL,
  `profile_image_url` varchar(500) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `registered_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `parent` json DEFAULT NULL,
  `parent_name` varchar(100) DEFAULT NULL,
  `parent_phone` varchar(20) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_students_tenant_id_status` (`tenant_id`,`status`),
  KEY `idx_students_tenant_id_parent_phone` (`tenant_id`,`parent_phone`),
  KEY `idx_students_tenant_id_name` (`tenant_id`,`name`),
  CONSTRAINT `chk_students_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'paused',_utf8mb4'withdrawn')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
  `hourly_rate` decimal(10,2) DEFAULT NULL,
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_teachers_tenant_id_status` (`tenant_id`,`status`),
  KEY `idx_teachers_tenant_id_subject_id` (`tenant_id`,`subject_id`),
  CONSTRAINT `chk_teachers_employment_type` CHECK ((`employment_type` in (_utf8mb4'full_time',_utf8mb4'part_time',_utf8mb4'contract'))),
  CONSTRAINT `chk_teachers_status` CHECK ((`status` in (_utf8mb4'active',_utf8mb4'inactive',_utf8mb4'resigned')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
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
