#!/usr/bin/env bash
# ============================================================================
# load-master-secret.sh — RDS master 패스워드를 Secrets Manager에서 fetch
#
# 동작:
#   - .env.aws-dev 로드 + Secrets Manager에서 패스워드 가져오기
#   - 환경변수(DB_USER, DB_PASSWORD, RDS_HOST, RDS_PORT, RDS_DB_NAME,
#     DATABASE_URL, DATABASE_URL_TLS_SKIP_VERIFY)를 stdout으로 export 구문 출력
#   - 호출 셸(bash/zsh)에서 eval로 평가하여 환경에 반영
#
# 사용:
#   eval "$(./scripts/aws-dev/load-master-secret.sh)"
#   dbmate up
#   mysql -h "$RDS_HOST" -P "$RDS_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$RDS_DB_NAME"
#
# 왜 eval 패턴인가?
#   - bash/zsh 모두 호환 (source는 셸별 BASH_SOURCE 차이로 zsh에서 경로 깨짐)
#   - 자식 프로세스(bash 스크립트) 안에서 모든 IO/검증 수행, 결과만 export로 전달
#
# 필수 환경 (.env.aws-dev에 정의):
#   AWS_PROFILE / AWS_DEFAULT_REGION / RDS_HOST / RDS_PORT / RDS_DB_NAME / MASTER_SECRET_ARN
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.aws-dev"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found. Copy .env.aws-dev.example and fill values." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${AWS_PROFILE:?AWS_PROFILE required in .env.aws-dev}"
: "${AWS_DEFAULT_REGION:?AWS_DEFAULT_REGION required}"
: "${RDS_HOST:?RDS_HOST required}"
: "${MASTER_SECRET_ARN:?MASTER_SECRET_ARN required}"

RDS_PORT="${RDS_PORT:-3306}"
RDS_DB_NAME="${RDS_DB_NAME:-ProjectRG_Dev}"

SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$MASTER_SECRET_ARN" \
    --profile "$AWS_PROFILE" --region "$AWS_DEFAULT_REGION" \
    --query SecretString --output text)

DB_USER=$(echo "$SECRET_JSON" | jq -r '.username')
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.password')
DB_PASSWORD_ENC=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$DB_PASSWORD")

# Single-quote everything to survive special chars. Inner single-quotes
# are not expected in our generated values, but escape defensively.
esc() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }

cat <<EOF
export DB_USER='$(esc "$DB_USER")'
export DB_PASSWORD='$(esc "$DB_PASSWORD")'
export RDS_HOST='$(esc "$RDS_HOST")'
export RDS_PORT='$(esc "$RDS_PORT")'
export RDS_DB_NAME='$(esc "$RDS_DB_NAME")'
export DATABASE_URL='mysql://$(esc "$DB_USER"):$(esc "$DB_PASSWORD_ENC")@$(esc "$RDS_HOST"):$(esc "$RDS_PORT")/$(esc "$RDS_DB_NAME")?tls=skip-verify'
# Tip: dbmate respects DATABASE_URL. For mysql CLI use \$DB_PASSWORD via -p"\$DB_PASSWORD".
EOF
