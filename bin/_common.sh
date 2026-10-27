# 공통 설정 — 모든 러너가 source 함
ORA_CONTAINER="${ORA_CONTAINER:-oracle19c-ee}"
ORA_CONN="${ORA_CONN:-dev/1234@//localhost:1521/ORCLPDB1}"
OSQL_TIMEOUT="${OSQL_TIMEOUT:-180}"     # 초. 60GB 테이블에 풀스캔 날려도 여기서 끊김
LAB_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/osql.$$"

die() { echo "osql: $*" >&2; exit 2; }

# SQL 본문을 컨테이너로 흘려넣어 sqlplus 로 실행 (docker cp 불필요 = 권한 문제 없음)
run_in_container() {   # $1 = 로컬 sql 파일
  local local_sql="$1"
  local remote="/tmp/osql_$$.sql"
  docker exec -i "$ORA_CONTAINER" bash -lc \
    "export NLS_LANG=AMERICAN_AMERICA.AL32UTF8; cat > $remote && timeout ${OSQL_TIMEOUT}s sqlplus -S '$ORA_CONN' @$remote; rc=\$?; rm -f $remote; exit \$rc" \
    < "$local_sql"
  local rc=$?
  [ $rc -eq 124 ] && echo "!! ${OSQL_TIMEOUT}초 타임아웃으로 중단됨 (OSQL_TIMEOUT 조정 가능)" >&2
  return $rc
}

# 표준 sqlplus 헤더
sql_header() {
cat <<'HDR'
set linesize 200 pagesize 100 trimspool on tab off feedback on timing on
whenever sqlerror continue
HDR
}

# 인자(파일 | -c "sql" | -)를 하나의 sql 본문으로 정규화해 stdout 출력
read_sql_arg() {
  case "${1:-}" in
    -c) shift; printf '%s' "$*" ;;
    -)  cat ;;
    "") die "SQL 파일 또는 -c \"...\" 를 주세요" ;;
    *)  [ -f "$1" ] || die "파일 없음: $1"; cat "$1" ;;
  esac
}

# 끝에 종결자(; 또는 /)가 없으면 ; 붙임
ensure_terminator() {
  local body; body="$(cat)"
  local tail; tail="$(printf '%s' "$body" | sed -e 's/[[:space:]]*$//' | tail -c 1)"
  printf '%s' "$body"
  [ "$tail" = ";" ] || [ "$tail" = "/" ] || printf '\n;'
  printf '\n'
}
