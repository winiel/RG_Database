# RG_Database

ProjectRG의 **데이터베이스 개발/관리 영역**.

스키마 정의(DDL), 마이그레이션, 시드 스크립트, 권한 GRANT, ERD 산출물을 관리합니다.

## 합의 근거 문서

- 요청: `RG_Common/request/RG_Database/2026-05-10-backend-database-request.md`
- 회신: `RG_Common/Document/RG_Database/2026-05-10-database-response-to-backend.md`

## 핵심 정책 요약

| 항목 | 결정 |
|---|---|
| Engine | MySQL 8.0+ (Aurora MySQL 3 호환) |
| Charset / Collation | `utf8mb4` / `utf8mb4_0900_ai_ci` |
| PK | `BINARY(16)` UUID — **앱(백엔드) 측 생성** (UUIDv7 권장), DB DEFAULT 미설정 |
| FK | **100% 미사용** — 무결성은 앱+CI 책임 (회신 §3-4) |
| 시간 | DATETIME UTC 저장 — 인스턴스 `time_zone='+00:00'` 의무 |
| 멀티테넌시 | 모든 도메인 테이블 `tenant_id` NOT NULL + 인덱스 첫 컬럼 |
| 마이그레이션 도구 | dbmate (Phase 1 후반 도입 예정) |

## 디렉토리

```
RG_Database/
├── migrations/              # 마이그레이션 SQL (dbmate 호환 -- migrate:up / -- migrate:down)
├── schema/                  # 현재 dev 브랜치 스키마 스냅샷 (mysqldump 산출)
├── seeds/
│   ├── master/              # 마스터 시드 (필수, 멱등)
│   └── dummy/               # 더미 시드 (옵션, faker)
├── scripts/
│   ├── grants/              # 계정/권한 GRANT SQL
│   ├── backup/              # 백업/복구 헬퍼
│   └── ci/                  # CI 부트스트랩
├── docs/
│   ├── erd/                 # ERD (DBML 소스 + 자동 생성 이미지)
│   └── adr/                 # Architecture Decision Records (선택)
├── .env.example
├── .gitignore
└── README.md
```

## 환경

| 환경 | DB 이름 | 호스트 |
|---|---|---|
| 로컬 | `ProjectRG_Dev` | `127.0.0.1:3306` |
| AWS Dev | `ProjectRG_Dev` | RDS (Phase 1 후반) |
| AWS Stg | `ProjectRG_Stg` | RDS (Phase 3) |
| AWS Prod | `ProjectRG_Prod` | RDS → Aurora MySQL (Phase 4) |

## 빠른 시작 (로컬)

```bash
# 1. 로컬 MySQL 가동 확인
mysqladmin -u root ping

# 2. 마이그레이션 적용 (dbmate 도입 전 임시 방식 — up 섹션만 추출)
awk '/^-- migrate:down/{exit} {print}' migrations/20260510000001_create_initial_schema.sql | mysql -u root

# 3. 검증
mysql -u root -e "USE ProjectRG_Dev; SHOW TABLES;"

# 4. 스키마 스냅샷 갱신 (변경 후)
mysqldump -u root --no-data --skip-comments --skip-add-drop-table --skip-set-charset --skip-tz-utc --compact ProjectRG_Dev > schema/schema.sql
```

dbmate 도입 후에는 `dbmate up` / `dbmate dump` 한 줄로 대체 예정.

## 작업 흐름

1. 신규 마이그레이션 → `migrations/YYYYMMDDHHMMSS_<name>.sql` 추가 (`-- migrate:up` / `-- migrate:down` 섹션 의무)
2. dev 브랜치에서 적용·검증 → `schema/schema.sql` 갱신 (mysqldump)
3. **`schema/schema.sql` ↔ `RG_Common/Document/RG_Database/schema.sql` 동기**
   - 본 레포가 진실 원천. RG_Common 사본은 백엔드 공유용 스냅샷
   - byte-identical 복사 의무 (`cp schema/schema.sql ../RG_Common/Document/RG_Database/schema.sql && diff` 검증)
   - schema 변경 commit과 같은 시점에 RG_Common dev에도 push
4. `RG_Common/Document/RG_Database/schema-changes-log.md`에 변경 누적 기록 (회신 §6 컨벤션)
5. PR 생성 → 백엔드 측 합의 → main 머지

## 참고

- 명명 규칙: `CodingGuide/DatabaseGuide.md`
- 브랜치 전략: `CodingGuide/GithubBranchStrategyGuide.md`
- 모든 작업 시작 전 `cd ~/Documents/PythonProject/CodingGuide && git pull` 의무
