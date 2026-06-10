#!/usr/bin/env bash
# ============================================================================
# validate-seed.sh — 더미 시드 정합성 검증 wrapper
#
# 동작:
#   1. validate-seed.sql 실행
#   2. 종합 결과의 PASS/FAIL 판정으로 exit code 반환 (0 = PASS, 1 = FAIL)
#
# 사용:
#   # 로컬 (기본값 — root@127.0.0.1, no password)
#   ./scripts/checks/validate-seed.sh
#
#   # AWS production RDS (load-master-secret.sh 와 정합)
#   export PATH="/usr/local/opt/mysql-client@8.4/bin:$PATH"
#   eval "$(./scripts/aws-dev/load-master-secret.sh)"
#   DB_HOST="$RDS_HOST" DB_PORT="$RDS_PORT" DB_NAME="$RDS_DB_NAME" \
#     DB_SSL_MODE=REQUIRED \
#     ./scripts/checks/validate-seed.sh
#
#   CI/통합 테스트 컨테이너 부트스트랩 후 실행 권장:
#     mysql ... < seeds/dummy/seoyugi_demo.sql
#     ./scripts/checks/validate-seed.sh   # 종료 코드로 PASS/FAIL 판정
#
# 환경 변수:
#   DB_NAME     (기본: ProjectRG_Dev)
#   DB_USER     (기본: root)
#   DB_HOST     (기본: 127.0.0.1)
#   DB_PORT     (기본: 3306)
#   DB_PASSWORD (기본: 빈 값 — 미명시 시 -p 옵션 생략)
#   DB_SSL_MODE (기본: 빈 값 — 미명시 시 --ssl-mode 옵션 생략 / RDS 권장: REQUIRED 또는 VERIFY_CA)
# ============================================================================

set -uo pipefail

DB_NAME="${DB_NAME:-ProjectRG_Dev}"
DB_USER="${DB_USER:-root}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_SSL_MODE="${DB_SSL_MODE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/validate-seed.sql"

if [[ ! -f "$SQL_FILE" ]]; then
    echo "ERROR: validate-seed.sql not found at $SQL_FILE" >&2
    exit 2
fi

MYSQL_OPTS=(-u "$DB_USER" -h "$DB_HOST" -P "$DB_PORT")
[[ -n "$DB_PASSWORD" ]] && MYSQL_OPTS+=(-p"$DB_PASSWORD")
[[ -n "$DB_SSL_MODE" ]] && MYSQL_OPTS+=(--ssl-mode="$DB_SSL_MODE")

OUTPUT="$(mysql "${MYSQL_OPTS[@]}" "$DB_NAME" < "$SQL_FILE" 2>&1)"
EXIT_CODE=$?

echo "$OUTPUT"

if [[ $EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "✗ mysql execution failed (exit $EXIT_CODE)" >&2
    exit 2
fi

# 종합 결과 라인에서 PASS/FAIL 추출
if echo "$OUTPUT" | grep -q "PASS — 모든 검증 통과"; then
    echo ""
    echo "✓ validate-seed: PASS"
    exit 0
else
    echo ""
    echo "✗ validate-seed: FAIL — see violations above" >&2
    exit 1
fi
