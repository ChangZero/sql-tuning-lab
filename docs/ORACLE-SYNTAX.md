# 출제·채점 문법 규칙 — 오라클 전용

**모든 문제와 모범답안은 Oracle 19c 전용 문법으로 작성한다.** ANSI/표준 SQL 스타일이나
다른 DBMS 방언을 섞지 않는다. 문제를 낼 때 "오라클 문법으로 작성하시오"를 매번 적지 않아도
이 규칙이 기본값이다.

## 기본값으로 쓰는 오라클 문법
| 용도 | 쓸 것 (Oracle) | 쓰지 말 것 |
|---|---|---|
| 조인 | `FROM a, b WHERE a.k = b.k` | `INNER JOIN ... ON` |
| 아우터 조인 | `WHERE a.k = b.k(+)` | `LEFT OUTER JOIN` |
| 조건 분기 | `DECODE(x, 'A', 1, 'B', 2, 0)` | 단순 동등 비교에 `CASE` |
| NULL 처리 | `NVL`, `NVL2`, `NULLIF`, `COALESCE` | `IFNULL`, `ISNULL` |
| 행 제한 | `ROWNUM <= n`, `ROW_NUMBER() OVER()` 인라인뷰 | `LIMIT`, `TOP`, `FETCH FIRST`(※ 아래 예외) |
| 계층 질의 | `START WITH ... CONNECT BY PRIOR`, `LEVEL`, `SYS_CONNECT_BY_PATH`, `CONNECT_BY_ROOT` | 재귀 CTE(`WITH ... RECURSIVE`) |
| 날짜 | `SYSDATE`, `TO_DATE`, `TO_CHAR(d,'YYYYMMDD')`, `ADD_MONTHS`, `LAST_DAY`, `TRUNC(d,'MM')` | `NOW()`, `DATE_ADD`, `EXTRACT` 남용 |
| 문자열 | `SUBSTR`, `INSTR`, `LPAD`, `RPAD`, `||`, `TRANSLATE` | `CONCAT()` 중첩, `LEFT/RIGHT` |
| 집계 문자열 | `LISTAGG(x,',') WITHIN GROUP (ORDER BY y)` | `GROUP_CONCAT`, `STRING_AGG` |
| 더미 테이블 | `FROM DUAL` | `FROM (VALUES ...)` |
| UPSERT | `MERGE INTO ... USING ... ON` | `INSERT ... ON DUPLICATE KEY` |
| 시퀀스 | `seq.NEXTVAL`, `seq.CURRVAL` | `AUTO_INCREMENT` |

## 오라클 고유 기능은 적극적으로 출제 대상에 넣는다
- 분석함수: `RANK / DENSE_RANK / ROW_NUMBER / LAG / LEAD / SUM() OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN ...)`,
  `RATIO_TO_REPORT`, `NTILE`, `FIRST_VALUE / LAST_VALUE`, `KEEP (DENSE_RANK FIRST/LAST)`
- 집계 확장: `ROLLUP`, `CUBE`, `GROUPING SETS`, `GROUPING_ID`
- `MODEL` 절, `PIVOT` / `UNPIVOT`
- 계층 질의 전반
- 스칼라 서브쿼리, 인라인 뷰, `WITH` 절(서브쿼리 팩토링 — 재귀 아닌 일반 용법은 오라클 문법)
- 힌트: `/*+ INDEX(t idx) FULL(t) USE_NL(a b) USE_HASH(a b) LEADING(a b) NO_MERGE PARALLEL(4) GATHER_PLAN_STATISTICS */`

## 예외 — 허용하는 경우
- `FETCH FIRST n ROWS ONLY` 는 12c 이상 오라클 고유 구문이므로 **허용**하되,
  Top-N 튜닝을 주제로 한 문제에서는 `ROWNUM` / 분석함수 방식을 명시적으로 요구한다.
- `CASE` 는 범위 조건·복합 조건이 필요할 때 사용한다. 단순 동등 분기는 `DECODE` 를 우선한다.
- 사용자가 특정 문제에 대해 "ANSI 조인으로" 라고 지시하면 그 문제에 한해 따른다.

## 채점 시
- 제출 SQL이 ANSI 조인·타 DBMS 문법을 썼다면 **결과가 맞아도 지적**하고 오라클 문법으로 고친 버전을 함께 보여준다.
- 결과가 맞더라도 `bin/oplan` 의 Buffers 가 모범답안보다 크게 나쁘면 오답 처리하지 말고 "정답·비효율"로 구분해 피드백한다.
