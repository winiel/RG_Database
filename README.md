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
| 마이그레이션 도구 | **dbmate** (회신 §4-A 합의, 도입 완료) |

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
│   ├── checks/              # 데이터 정합성 검증 (validate-seed.sql/sh)
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
| AWS Dev | `ProjectRG_Dev` | `projectrg-dev-db-rds.cbya6us2qc5g.ap-northeast-2.rds.amazonaws.com:3306` (MySQL 8.4.9, 2026-05-15 업그레이드) |
| AWS Stg | `ProjectRG_Stg` | RDS (Phase 3) |
| AWS Prod | `ProjectRG_Prod` | RDS → Aurora MySQL (Phase 4) |

### AWS Dev RDS 접속

```bash
# 1회 준비
cp .env.aws-dev.example .env.aws-dev    # 실제 값으로 채움 (gitignored)
brew install mysql-client@8.4           # MySQL 9.x client 호환 이슈 회피
export PATH="/usr/local/opt/mysql-client@8.4/bin:$PATH"

# Master 계정 (DDL/dbmate)
eval "$(./scripts/aws-dev/load-master-secret.sh)"
dbmate status                            # DATABASE_URL은 자동 설정됨
mysql -h "$RDS_HOST" -P "$RDS_PORT" -u "$DB_USER" -p"$DB_PASSWORD" --ssl-mode=REQUIRED "$RDS_DB_NAME"

# App 계정 (DML만, 백엔드용) — Secret을 직접 fetch
APP_SECRET=$(aws secretsmanager get-secret-value --secret-id "$APP_USER_SECRET_ARN" \
  --profile projectrg --region ap-northeast-2 --query SecretString --output text)
APP_USER=$(echo "$APP_SECRET" | jq -r .username)
APP_PASSWORD=$(echo "$APP_SECRET" | jq -r .password)
mysql -h "$RDS_HOST" -P 3306 -u "$APP_USER" -p"$APP_PASSWORD" --ssl-mode=REQUIRED ProjectRG_Dev
```

> dev RDS는 퍼블릭 액세스 + Security Group IP whitelist 방식. 새 IP에서 접속하려면 `aws ec2 authorize-security-group-ingress`로 SG에 IP/32 추가. TLS 검증은 dev에서 `skip-verify` 사용 — 운영 시 [AWS RDS Combined CA](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem) 등록 권장.

## 빠른 시작 (로컬)

```bash
# 0. 사전 준비 (1회)
brew install dbmate
cp .env.example .env                    # 필요 시 DB 접속 정보 수정

# 1. 로컬 MySQL 가동 확인
mysqladmin -u root ping

# 2. 마이그레이션 적용 + schema.sql 갱신 + RG_Common 동기 (한 번에)
./scripts/sync-schema.sh                # = dbmate up + cp + verify

# 3. 새 마이그레이션 작성 (timestamp 자동)
dbmate new add_some_column              # → migrations/YYYYMMDDHHMMSS_add_some_column.sql 생성
# (-- migrate:up / -- migrate:down 섹션 작성 후)
./scripts/sync-schema.sh                # 적용 + 동기

# 기타 dbmate 명령
dbmate status                           # 적용 상태 확인 (Applied/Pending)
dbmate down                             # 가장 최근 마이그레이션 rollback
dbmate dump                             # schema.sql 재생성 (적용 없이)
```

`sync-schema.sh`가 자동으로:
1. `dbmate up`: pending 마이그레이션 적용 + `schema/schema.sql` 자동 갱신
2. `RG_Common/Document/RG_Database/schema.sql`로 byte-identical 복사
3. `diff -q`로 정합성 검증

### 시드 정합성 검증

```bash
# 시드 적용 후 (또는 CI 통합 테스트 부트스트랩 후) 실행
./scripts/checks/validate-seed.sh
# → 91 checks 실행: orphan / tenancy / business / plausibility / schedule / payment_calc / json_struct
# → exit 0 = PASS / exit 1 = FAIL (CI 친화)
```

검증 영역:
- **orphan** (38) — 참조 무결성 (FK 미사용 정책 하 앱 책임 보강)
- **tenancy** (18) — 멀티테넌시 cross-table tenant_id 일치
- **business** (15) — 운영 요일·결제 상태·UNIQUE 등
- **plausibility** (7) — 미래 일자·정원 초과·해시 형식
- **schedule** (2) — 강사·강의실 시간 충돌
- **payment_calc** (4) — 등록당 월별 결제 발생·금액 일치
- **json_struct** (7) — JSON 컬럼 타입·평탄화 일관성

## 작업 흐름

1. 신규 마이그레이션 → `dbmate new <name>` (timestamp 자동, `-- migrate:up` / `-- migrate:down` 템플릿 생성)
2. up/down 섹션 작성 → `./scripts/sync-schema.sh` (dbmate up + RG_Common 동기 한 번에)
3. **`schema/schema.sql` ↔ `RG_Common/Document/RG_Database/schema.sql` 동기**
   - 본 레포가 진실 원천. RG_Common 사본은 백엔드 공유용 스냅샷
   - byte-identical 복사 의무 — `sync-schema.sh`가 자동으로 cp + diff 검증
   - schema 변경 commit과 같은 시점에 RG_Common dev에도 push
4. `RG_Common/Document/RG_Database/schema-changes-log.md`에 변경 누적 기록 (회신 §6 컨벤션)
5. PR 생성 → 백엔드 측 합의 → main 머지

## 참고

- 명명 규칙: `CodingGuide/DatabaseGuide.md`
- 브랜치 전략: `CodingGuide/GithubBranchStrategyGuide.md`
- 모든 작업 시작 전 `cd ~/Documents/PythonProject/CodingGuide && git pull` 의무
