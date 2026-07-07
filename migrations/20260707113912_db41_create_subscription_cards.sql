-- migrate:up
-- DB41-SUBSCRIPTION-CARDS (DB-41 ①) — 구독 결제 카드 다중 저장 테이블 신설
--
-- 발의: request/RG_Database/2026-07-07-db41-subscription-cards-table-request.md
-- 설계 정본: RG_Common/docs/design/multi-card-subscription-proposal.md §1 데이터 모델
-- 근거: 위니엘님 지시 — 구독 결제 카드를 여러 장 등록·관리(기본 카드 지정·삭제 가드·결제 실패 시 다중 카드
--       폴백 + 재시도 후 자동 다운그레이드). 현재 as-is = 단일 카드(academy_subscriptions.billing_key 1장·교체뿐).
--       카드 CRUD·최대 5장 앱 가드·다중카드 폴백·재시도 개편은 BE-79(본 DDL 후). 본건은 트랙 최선행 DDL(테이블만).
-- cross-ref: academies(id=tenant_id) 테넌트. 이관 소스 = academy_subscriptions(toss_billing_key 단일 카드·DB-38).
--            ★도메인 분리 = payments·billing_schedules(학원→학생 수강료)와 별개. 접두 subscription_.
--
-- 설계 요지(RG_Database 컨벤션 우선):
--   - id BINARY(16) PK = UUID v7(앱 생성)·기존 테이블 패턴 정합(academy_subscriptions 등).
--   - academy_id = academies.id(=tenant_id) 논리 참조·테넌트 스코프. 카드는 테넌트당 여러 장(최대 5장 앱 가드 BE-79).
--   - ★물리 FK 없음 — 전체 스키마 FOREIGN KEY 0건(현행 무FK 컨벤션·앱 레벨 무결성·subscription_payments 선례).
--   - billing_key/customer_key = 발의서 명명 그대로(academy_subscriptions 는 toss_ 접두이나 본 테이블·BE-79 계약은
--     billing_key/customer_key 사용). billing_key = ★민감(정기결제 자격증명·카드별 고유)·BE 전용·응답/FE 노출 금지·NOT NULL.
--   - is_default TINYINT(1) DEFAULT 0 = 기본 결제 카드(테넌트당 정확히 1장 =1). 유니크성은 앱 레벨 보장(BE-79 트랜잭션·
--     기본 지정 시 기존 기본 해제)·MySQL8 부분 유니크 미지원. DB 는 조회 인덱스(academy_id, is_default)만 제공.
--   - 인덱스 = academy_id(테넌트 조회)·(academy_id, is_default)(기본 카드 조회)·billing_key(비유니크·이관 멱등/결제 조회).
--     ★billing_key 는 비유니크 KEY(논리삭제 후 동일 카드 재등록 허용·소프트삭제 정합).
--   - is_deleted/deleted_at/deleted_by = 논리삭제 3컬럼 패턴(academy_subscriptions 정합)·물리삭제 금지(감사 보존).
--   - created_at/updated_at = 생성·갱신(is_default 토글·논리삭제 시각 추적·ON UPDATE)·sibling 컨벤션 정합.
--
-- 영향: 신규 테이블 추가만(additive). 기존 쿼리 무영향(BE-79 라이브 전 미소비·적용 직후 0행). FK/트리거/SP 없음.
--       롤백 가능(down = DROP TABLE). 기존 payments·billing_schedules·academy_subscriptions 무접촉.

CREATE TABLE `subscription_cards` (
  `id` binary(16) NOT NULL COMMENT 'UUID v7 (앱 생성)',
  `academy_id` binary(16) NOT NULL COMMENT 'academies.id (=tenant_id)·테넌트 스코프 (논리 참조·무FK)',
  `billing_key` varchar(255) NOT NULL COMMENT '★민감 — 토스 빌링키(카드별 고유·정기결제). BE 전용·응답/FE 노출 금지',
  `customer_key` varchar(255) DEFAULT NULL COMMENT '토스 customerKey',
  `card_company` varchar(40) DEFAULT NULL COMMENT '카드사(표시용)',
  `card_number_masked` varchar(32) DEFAULT NULL COMMENT '마스킹 카드번호(표시용)',
  `is_default` tinyint(1) NOT NULL DEFAULT '0' COMMENT '기본 결제 카드 — 테넌트당 정확히 1장 =1(유니크성 앱 가드 BE-79)',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0' COMMENT '논리삭제(1=삭제·감사 보존)',
  `deleted_at` datetime DEFAULT NULL,
  `deleted_by` binary(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_subscription_cards_academy` (`academy_id`),
  KEY `idx_subscription_cards_academy_default` (`academy_id`,`is_default`),
  KEY `idx_subscription_cards_billing_key` (`billing_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='RGuardians→학원 구독 결제 카드 다중 저장 — 테넌트당 여러 장(최대 5장 앱 가드 BE-79)·is_default 기본 카드 1장·billing_key 민감(BE 전용)·논리삭제. 학생 청구(payments)와 별개 도메인';

-- migrate:down

DROP TABLE `subscription_cards`;
