#!/bin/bash
# ============================================================================
# persons / students.person_id v1_swap → v7 backfill
#
# 근거: Database 발의 §5.2 / Backend 회신 ef57c5f §1 (A-ii + 단일 묶음)
# 영향: persons + students + guardian_persons + person_link_requests + guardian_consents (5 테이블)
#       dev RDS 시점 = persons 27 / students 27 / 의존 3 테이블 0 rows
#
# Dependency:
#   - Backend code 라이브 완료 (person_id 명시 bind, trigger 미호출 정합)
#   - migrations/20260604121944_drop_auto_person_id_trigger.sql 적용은 본 script 실행 후
#
# 사용:
#   DB_HOST=... DB_USER=... DB_PASSWORD=... DB_NAME=... \
#     scripts/backfill-persons-v7.sh [--dry-run]
#
# 의존: system mysql CLI (8.x) + python3 (stdlib only, RFC 9562 v7 generate)
# ============================================================================

set -euo pipefail

: "${DB_HOST:?DB_HOST 환경 변수 필요}"
: "${DB_USER:?DB_USER 환경 변수 필요}"
: "${DB_PASSWORD:?DB_PASSWORD 환경 변수 필요}"
: "${DB_NAME:?DB_NAME 환경 변수 필요}"
DB_PORT="${DB_PORT:-3306}"
DB_SSL_MODE="${DB_SSL_MODE:-REQUIRED}"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

MYSQL_OPTS=(-h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --ssl-mode="$DB_SSL_MODE" "$DB_NAME")

gen_v7_hex() {
    python3 -c '
import secrets, time
ts = int(time.time() * 1000).to_bytes(6, "big")
r = secrets.token_bytes(10)
ver = bytes([0x70 | (r[0] & 0x0F)])
var = bytes([0x80 | (r[1] & 0x3F)])
print((ts + ver + var + r[2:]).hex().upper())
'
}

# v1_swap row HEX 수집 (pos1 = '1')
OLD_IDS=$(MYSQL_PWD="$DB_PASSWORD" mysql "${MYSQL_OPTS[@]}" -N -B -e \
    "SELECT HEX(id) FROM persons WHERE SUBSTRING(HEX(id), 1, 1) = '1' ORDER BY id")

ROW_COUNT=$(echo "$OLD_IDS" | grep -c . || true)
echo "v1_swap persons rows: $ROW_COUNT"

if [ "$ROW_COUNT" = "0" ]; then
    echo "정정 대상 없음 — 종료"
    exit 0
fi

# v7 ID generate + sample 검증
SQL="START TRANSACTION;
CREATE TEMPORARY TABLE _person_v7_map (
    old_person_id BINARY(16) PRIMARY KEY,
    new_person_id BINARY(16) NOT NULL
);
"

while IFS= read -r old_hex; do
    [ -z "$old_hex" ] && continue
    new_hex=$(gen_v7_hex)
    # v7 정합 자체 검증 (pos 13 = '7')
    if [ "${new_hex:12:1}" != "7" ]; then
        echo "ERROR: v7 nibble 위반 — $new_hex" >&2
        exit 2
    fi
    SQL+="INSERT INTO _person_v7_map VALUES (UNHEX('$old_hex'), UNHEX('$new_hex'));
"
done <<< "$OLD_IDS"

SQL+="
UPDATE persons p JOIN _person_v7_map m ON m.old_person_id = p.id
    SET p.id = m.new_person_id;
UPDATE students s JOIN _person_v7_map m ON m.old_person_id = s.person_id
    SET s.person_id = m.new_person_id;
UPDATE guardian_persons g JOIN _person_v7_map m ON m.old_person_id = g.person_id
    SET g.person_id = m.new_person_id;
UPDATE person_link_requests r JOIN _person_v7_map m ON m.old_person_id = r.person_id
    SET r.person_id = m.new_person_id;
UPDATE guardian_consents c JOIN _person_v7_map m ON m.old_person_id = c.person_id
    SET c.person_id = m.new_person_id;

DROP TEMPORARY TABLE _person_v7_map;
COMMIT;

-- 검증 SELECT
SELECT 'persons_non_v7' AS chk, COUNT(*) AS cnt FROM persons WHERE SUBSTRING(HEX(id), 13, 1) <> '7'
UNION ALL SELECT 'students_non_v7', COUNT(*) FROM students WHERE SUBSTRING(HEX(person_id), 13, 1) <> '7';
"

if [ "$DRY_RUN" = "1" ]; then
    echo "--- DRY RUN — SQL preview (실행 X) ---"
    echo "$SQL"
    exit 0
fi

echo "--- 마이그 적용 (단일 트랜잭션 multi-table UPDATE) ---"
MYSQL_PWD="$DB_PASSWORD" mysql "${MYSQL_OPTS[@]}" -e "$SQL"
echo "--- 완료 ---"
