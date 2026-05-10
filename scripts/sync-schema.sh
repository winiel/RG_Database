#!/usr/bin/env bash
# ============================================================================
# sync-schema.sh — dbmate wrapper + RG_Common schema.sql 동기 (회신 §4-D)
#
# 동작:
#   1. dbmate up | dump 실행 (default: up — pending 적용 + auto-dump)
#   2. RG_Common/Document/RG_Database/schema.sql 로 byte-identical 복사
#   3. diff -q 로 정합성 검증
#
# 사용:
#   ./scripts/sync-schema.sh              # = dbmate up + RG_Common 동기 (가장 흔한 케이스)
#   ./scripts/sync-schema.sh up           # 위와 동일
#   ./scripts/sync-schema.sh dump         # schema.sql만 재생성 (적용 없이)
#
# 새 마이그레이션 작성:
#   dbmate new add_some_column            # YYYYMMDDHHMMSS_add_some_column.sql 생성
#   ./scripts/sync-schema.sh              # 작성 후 적용 + 동기
#
# 기타 dbmate 명령은 직접 사용:
#   dbmate status / dbmate down / dbmate rollback
#
# 환경 변수:
#   DATABASE_URL    (.env에서 로드, 예: mysql://root@127.0.0.1:3306/ProjectRG_Dev)
#   RG_COMMON_REPO  (기본: <RG_Database 부모>/RG_Common)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RG_COMMON_REPO="${RG_COMMON_REPO:-$(cd "$REPO_ROOT/.." && pwd)/RG_Common}"

LOCAL_SCHEMA="$REPO_ROOT/schema/schema.sql"
COMMON_SCHEMA="$RG_COMMON_REPO/Document/RG_Database/schema.sql"

cd "$REPO_ROOT"

MODE="${1:-up}"
case "$MODE" in
    up)
        echo "→ dbmate up (apply pending + dump schema)"
        dbmate up
        ;;
    dump)
        echo "→ dbmate dump (regenerate schema.sql only)"
        dbmate dump
        ;;
    -h|--help)
        sed -n '2,28p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    *)
        echo "ERROR: unknown mode '$MODE'. Run with --help" >&2
        exit 2
        ;;
esac

# ----- Sync to RG_Common -----
COMMON_DIR="$(dirname "$COMMON_SCHEMA")"
if [[ ! -d "$COMMON_DIR" ]]; then
    echo "ERROR: RG_Common path not found: $COMMON_DIR" >&2
    echo "  Set RG_COMMON_REPO env var if RG_Common is not a sibling of RG_Database" >&2
    exit 1
fi

cp "$LOCAL_SCHEMA" "$COMMON_SCHEMA"
echo "→ Copied to: $COMMON_SCHEMA"

if diff -q "$LOCAL_SCHEMA" "$COMMON_SCHEMA" > /dev/null; then
    echo "✓ byte-identical verified"
else
    echo "✗ MISMATCH detected (this should not happen after cp)" >&2
    exit 1
fi

echo ""
echo "Done. Next: commit both repos."
echo "  (cd \"$REPO_ROOT\" && git add schema/schema.sql && git commit)"
echo "  (cd \"$RG_COMMON_REPO\" && git add Document/RG_Database/schema.sql && git commit)"
