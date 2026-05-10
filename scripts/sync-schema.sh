#!/usr/bin/env bash
# ============================================================================
# sync-schema.sh — schema.sql 동기 헬퍼 (회신 §4-D + 운영 컨벤션)
#
# 동작:
#   1. (선택) --apply <file>: 마이그레이션 파일의 up 섹션을 로컬 DB에 적용
#   2. 로컬 DB에서 mysqldump → schema/schema.sql 갱신
#   3. RG_Common/Document/RG_Database/schema.sql 로 byte-identical 복사
#   4. diff -q 로 정합성 검증
#
# 사용:
#   ./scripts/sync-schema.sh                                # 현재 DB 상태만 dump + 동기
#   ./scripts/sync-schema.sh --apply migrations/20260601000001_add_x.sql
#
# 환경 변수 (기본값 override 가능):
#   DB_NAME         (기본: ProjectRG_Dev)
#   DB_USER         (기본: root)
#   DB_HOST         (기본: 127.0.0.1)
#   RG_COMMON_REPO  (기본: <RG_Database 부모>/RG_Common)
# ============================================================================

set -euo pipefail

# ----- Defaults -----
DB_NAME="${DB_NAME:-ProjectRG_Dev}"
DB_USER="${DB_USER:-root}"
DB_HOST="${DB_HOST:-127.0.0.1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RG_COMMON_REPO="${RG_COMMON_REPO:-$(cd "$REPO_ROOT/.." && pwd)/RG_Common}"

LOCAL_SCHEMA="$REPO_ROOT/schema/schema.sql"
COMMON_SCHEMA="$RG_COMMON_REPO/Document/RG_Database/schema.sql"

# ----- Argument parsing -----
APPLY_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            APPLY_FILE="${2:-}"
            if [[ -z "$APPLY_FILE" ]]; then
                echo "ERROR: --apply requires a migration file path" >&2
                exit 2
            fi
            shift 2
            ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            echo "Run with --help for usage" >&2
            exit 2
            ;;
    esac
done

# ----- Step 1: Apply migration (optional) -----
if [[ -n "$APPLY_FILE" ]]; then
    if [[ ! -f "$APPLY_FILE" ]]; then
        echo "ERROR: migration file not found: $APPLY_FILE" >&2
        exit 1
    fi
    echo "→ Applying migration (up section only): $APPLY_FILE"
    awk '/^-- migrate:down/{exit} {print}' "$APPLY_FILE" | mysql -u "$DB_USER" -h "$DB_HOST"
    echo "  done."
fi

# ----- Step 2: Dump schema -----
echo "→ Dumping schema: $DB_USER@$DB_HOST/$DB_NAME"
mysqldump -u "$DB_USER" -h "$DB_HOST" \
    --no-data --skip-comments --skip-add-drop-table \
    --skip-set-charset --skip-tz-utc --compact \
    --set-gtid-purged=OFF --single-transaction \
    "$DB_NAME" > "$LOCAL_SCHEMA"
echo "  written: $LOCAL_SCHEMA ($(wc -l < "$LOCAL_SCHEMA" | tr -d ' ') lines)"

# ----- Step 3: Sync to RG_Common -----
COMMON_DIR="$(dirname "$COMMON_SCHEMA")"
if [[ ! -d "$COMMON_DIR" ]]; then
    echo "ERROR: RG_Common Document path not found: $COMMON_DIR" >&2
    echo "  Set RG_COMMON_REPO env var if RG_Common is not a sibling of RG_Database" >&2
    exit 1
fi
cp "$LOCAL_SCHEMA" "$COMMON_SCHEMA"
echo "→ Copied to: $COMMON_SCHEMA"

# ----- Step 4: Verify byte-identical -----
if diff -q "$LOCAL_SCHEMA" "$COMMON_SCHEMA" > /dev/null; then
    echo "✓ byte-identical verified"
else
    echo "✗ MISMATCH detected (this should not happen after cp)" >&2
    exit 1
fi

# ----- Step 5: Hint commit steps -----
echo ""
echo "Done. Next: commit both repos."
echo "  (cd \"$REPO_ROOT\" && git add schema/schema.sql && git commit)"
echo "  (cd \"$RG_COMMON_REPO\" && git add Document/RG_Database/schema.sql && git commit)"
