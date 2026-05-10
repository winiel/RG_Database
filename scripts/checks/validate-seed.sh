#!/usr/bin/env bash
# ============================================================================
# validate-seed.sh — 더미 시드 정합성 검증 wrapper
#
# 동작:
#   1. validate-seed.sql 실행
#   2. 종합 결과의 PASS/FAIL 판정으로 exit code 반환 (0 = PASS, 1 = FAIL)
#
# 사용:
#   ./scripts/checks/validate-seed.sh
#
#   CI/통합 테스트 컨테이너 부트스트랩 후 실행 권장:
#     mysql ... < seeds/dummy/seoyugi_demo.sql
#     ./scripts/checks/validate-seed.sh   # 종료 코드로 PASS/FAIL 판정
#
# 환경 변수:
#   DB_NAME (기본: ProjectRG_Dev)
#   DB_USER (기본: root)
#   DB_HOST (기본: 127.0.0.1)
# ============================================================================

set -uo pipefail

DB_NAME="${DB_NAME:-ProjectRG_Dev}"
DB_USER="${DB_USER:-root}"
DB_HOST="${DB_HOST:-127.0.0.1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/validate-seed.sql"

if [[ ! -f "$SQL_FILE" ]]; then
    echo "ERROR: validate-seed.sql not found at $SQL_FILE" >&2
    exit 2
fi

OUTPUT="$(mysql -u "$DB_USER" -h "$DB_HOST" "$DB_NAME" < "$SQL_FILE" 2>&1)"
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
