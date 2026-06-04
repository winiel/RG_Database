#!/usr/bin/env bash
# ============================================================================
# check-uuid-pattern.sh — UUID byte order CI 가드
#
# RG_Backend 발의 (2026-06-04, request/RG_Database/uuid-ci-guard-...) δ scope:
#   - 검사 대상: migrations/, schema/, seeds/  (단 seeds/dummy/ 제외)
#   - 금지 패턴: UUID_TO_BIN(UUID()  → v1_swap 결함 (uuid-byte-order-guide §4.1)
#   - 인라인 예외: 같은 라인에 `ci-uuid-guard:allow` 마커 + 사유 코멘트 의무
#   - default = --diff <base_ref> (신규 변경 라인만 검사 — 기존 hybrid 잔존 보존)
#   - --full = 전체 grep (수동 진단용)
#
# 사용:
#   ./scripts/checks/check-uuid-pattern.sh --diff origin/main
#   ./scripts/checks/check-uuid-pattern.sh --full
#
# 종료 코드: 0 = clean, 1 = violation, 2 = invocation error
# ============================================================================

set -uo pipefail

PATTERN='UUID_TO_BIN[[:space:]]*\([[:space:]]*UUID[[:space:]]*\('
ALLOW_MARKER='ci-uuid-guard:allow'
TARGETS=(migrations schema seeds)
EXCLUDE_GLOB=':!seeds/dummy/**'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
    cat >&2 <<EOF
usage:
  $0 --diff <base_ref>     # base..HEAD 추가 라인만 검사 (CI 기본)
  $0 --full                # 전체 폴더 grep (수동 진단)
EOF
    exit 2
}

[[ $# -ge 1 ]] || usage
mode="$1"; shift || true

check_file_excluded() {
    # path 가 seeds/dummy/ 하위인지
    [[ "$1" == seeds/dummy/* ]]
}

violations=0

case "$mode" in
    --full)
        # 전체 grep — `:!seeds/dummy/**` 제외, allow 마커 제외
        # `git ls-files` 사용 시 worktree 비추적 파일 누락 → find 기반
        while IFS= read -r -d '' file; do
            check_file_excluded "$file" && continue
            while IFS=: read -r lineno content; do
                # allow 마커 같은 라인 → 통과
                if [[ "$content" == *"$ALLOW_MARKER"* ]]; then
                    continue
                fi
                echo "✗ $file:$lineno: $content"
                violations=$((violations + 1))
            done < <(grep -nE "$PATTERN" "$file" 2>/dev/null || true)
        done < <(find "${TARGETS[@]}" -type f \( -name '*.sql' -o -name '*.py' \) -print0 2>/dev/null)
        ;;

    --diff)
        base_ref="${1:-}"
        if [[ -z "$base_ref" ]]; then
            echo "ERROR: --diff requires <base_ref>" >&2
            usage
        fi

        # 새 브랜치 push 등 zeros SHA → diff 대상 없음 → skip
        if [[ "$base_ref" == "0000000000000000000000000000000000000000" ]]; then
            echo "[uuid-guard] base_ref = zeros SHA (new branch) → skip diff mode"
            exit 0
        fi

        # base_ref 가 fetch 안 된 경우 (얕은 clone) → resolve 실패 → CI 단계 책임
        if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
            echo "ERROR: base_ref '$base_ref' not resolvable. fetch-depth 부족?" >&2
            exit 2
        fi

        # 추가 라인 (+) 만 검사. seeds/dummy/ 제외.
        # `git diff --unified=0` 은 hunk 헤더 (@@) 노출 → 파일/라인 추적
        current_file=""
        current_lineno=0
        while IFS= read -r line; do
            if [[ "$line" == "+++ b/"* ]]; then
                current_file="${line#+++ b/}"
                continue
            fi
            if [[ "$line" == "@@"* ]]; then
                # @@ -a,b +c,d @@ 형식 → c 추출
                tmp="${line#*+}"
                start="${tmp%%,*}"
                start="${start%% *}"
                current_lineno="$start"
                continue
            fi
            if [[ "$line" == "+"* && "$line" != "+++"* ]]; then
                added="${line#+}"
                if [[ -n "$current_file" ]] && ! check_file_excluded "$current_file"; then
                    if [[ "$added" =~ $PATTERN ]] && [[ "$added" != *"$ALLOW_MARKER"* ]]; then
                        echo "✗ $current_file:$current_lineno: $added"
                        violations=$((violations + 1))
                    fi
                fi
                current_lineno=$((current_lineno + 1))
            elif [[ "$line" != "-"* && "$line" != "diff "* && "$line" != "index "* && "$line" != "---"* ]]; then
                # context 라인 (공백 prefix) → lineno 증가
                current_lineno=$((current_lineno + 1))
            fi
        done < <(git diff --unified=0 "$base_ref"...HEAD -- "${TARGETS[@]}" "$EXCLUDE_GLOB" 2>/dev/null)
        ;;

    -h|--help)
        usage
        ;;
    *)
        echo "ERROR: unknown mode '$mode'" >&2
        usage
        ;;
esac

if [[ $violations -gt 0 ]]; then
    cat >&2 <<EOF

✗ uuid-guard: $violations violation(s) — UUID_TO_BIN(UUID(), ...) 패턴 금지.
  → uuid-byte-order-guide §4.1 (RG_Common/Document/RG_Database/uuid-byte-order-guide.md)
  → Python 측 new_uuid7() + to_bin() bind param 사용 권장 (§4.2)
  → 의도된 잔존은 같은 라인에 \`-- ci-uuid-guard:allow: <사유>\` 마커 동봉
EOF
    exit 1
fi

echo "✓ uuid-guard: clean (mode=$mode)"
exit 0
