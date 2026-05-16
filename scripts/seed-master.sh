#!/usr/bin/env bash
# ============================================================================
# seed-master.sh — 마스터 시드 6 파일 순차 적용 (멱등)
#
# 동작:
#   seeds/master/01_*.sql 부터 06_*.sql 까지 자연 정렬 순서로 적용
#   모든 파일은 ON DUPLICATE KEY UPDATE 기반 멱등 — 재실행 안전
#
# 사용:
#   ./scripts/seed-master.sh                            # 로컬 (.env DATABASE_URL)
#   eval "$(./scripts/aws-dev/load-master-secret.sh)" \
#     && ./scripts/seed-master.sh                       # AWS Dev RDS
#
# 환경 변수:
#   DATABASE_URL    (.env에서 로드, 예: mysql://root@127.0.0.1:3306/ProjectRG_Dev)
#                   AWS Dev 사용 시 load-master-secret.sh 가 export
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MASTER_DIR="$REPO_ROOT/seeds/master"

# .env 로드 (DATABASE_URL 미설정 시)
if [[ -z "${DATABASE_URL:-}" && -f "$REPO_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    . "$REPO_ROOT/.env"
    set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "ERROR: DATABASE_URL 미설정. .env 확인 또는 load-master-secret.sh eval 후 실행" >&2
    exit 2
fi

# DATABASE_URL 파싱 (mysql://user[:pw]@host[:port]/db?params)
URL_NO_SCHEME="${DATABASE_URL#mysql://}"
URL_NO_PARAMS="${URL_NO_SCHEME%%\?*}"
USERINFO="${URL_NO_PARAMS%%@*}"
HOSTPATH="${URL_NO_PARAMS#*@}"
USER="${USERINFO%%:*}"
PASSWORD=""
if [[ "$USERINFO" == *:* ]]; then
    PASSWORD="${USERINFO#*:}"
fi
HOSTPORT="${HOSTPATH%%/*}"
DBNAME="${HOSTPATH#*/}"
HOST="${HOSTPORT%%:*}"
PORT="3306"
if [[ "$HOSTPORT" == *:* ]]; then
    PORT="${HOSTPORT##*:}"
fi

# mysql client 옵션 구성
MYSQL_ARGS=(-h "$HOST" -P "$PORT" -u "$USER")
if [[ -n "$PASSWORD" ]]; then
    MYSQL_ARGS+=(-p"$PASSWORD")
fi
# RDS 등 TLS 환경 자동 감지
if [[ "$DATABASE_URL" == *"tls=skip-verify"* ]]; then
    MYSQL_ARGS+=(--ssl-mode=REQUIRED)
elif [[ "$DATABASE_URL" == *"tls=true"* ]]; then
    MYSQL_ARGS+=(--ssl-mode=VERIFY_IDENTITY)
fi
MYSQL_ARGS+=("$DBNAME")

echo "→ 마스터 시드 적용 (대상 DB: $DBNAME @ $HOST:$PORT)"
echo ""

# 순차 적용 (정렬 보장)
for sql_file in "$MASTER_DIR"/[0-9][0-9]_*.sql; do
    [[ -e "$sql_file" ]] || continue
    base_name="$(basename "$sql_file")"
    echo "  [$base_name]"
    mysql "${MYSQL_ARGS[@]}" < "$sql_file"
done

echo ""
echo "✓ 마스터 시드 적용 완료. 재실행 안전 (ON DUPLICATE KEY UPDATE)."
echo ""
echo "검증:"
echo "  mysql -h $HOST -P $PORT -u $USER -p $DBNAME -e 'SELECT name, business_number FROM academies WHERE business_number=\"000-00-00000\"'"
