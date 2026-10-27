# SQL 튜닝 연습실

WSL2 도커의 Oracle 19c(`oracle19c-ee` / `dev@ORCLPDB1`)에 붙어서
**오라클 문법 기준 SQL 연습문제를 출제하고, 실제 실행해서 채점하는** Claude Code 워크스페이스.

## 처음 셋팅할 때
문제를 풀려면 Oracle 19c 에 `DEV` 스키마가 이 구성대로 들어 있어야 한다.
[setup/](setup/) 의 스크립트를 번호 순서대로 돌리면 된다 (`setup/README.md` 에 순서·소요시간·용량 요구사항).
`setup/99_verify.sql` 로 건수와 클러스터링 팩터가 기준값과 맞는지 확인하고 시작한다.

## 쓰는 법
```
/quiz                    # 이력을 보고 알아서 다음 문제
/quiz 분석함수 Lv3        # 주제·난이도 지정
/quiz 튜닝               # 튜닝 문제
/hint P001               # 힌트 한 단계
/grade P001              # 채점
/review "select ..."     # 문제와 무관하게 임의 SQL 리뷰
```
`/quiz` 를 돌리면 `problems/PNNN-slug.md` (문제) 와 `attempts/PNNN/t1.sql` (빈 제출 스텁) 이 같이 생긴다.
스텁에 SQL 을 쓰고 `/grade PNNN` → 채점 결과가 `attempts/PNNN/t1-grade.md` 로 남는다.
다시 풀 때는 같은 폴더에 `t2.sql`, `t3.sql` 로 복사해서 쓴다.

## 문제 카테고리

`/quiz` 뒤에 카테고리 이름을 붙이면 그 주제로 출제된다 (`/quiz 분석함수`, `/quiz 파티션 Lv4`).
비워두면 `progress.md` 이력을 보고 다음 주제를 자동으로 고른다.

### SQL 작성
| 카테고리 | Lv | 다루는 것 | 주 사용 테이블 |
|---|---|---|---|
| 기본 조회·집계 | 1 | `WHERE` / `ORDER BY` / `GROUP BY` / `HAVING`, `ROWNUM` | SHOP, ITEM |
| 조인 | 2 | 오라클 조인(`a.k = b.k`), 아우터 `(+)`, 셀프 조인 | ORD, ORD_ITEM, SHOP, ITEM |
| 서브쿼리·인라인뷰 | 2~3 | 스칼라 서브쿼리, `EXISTS`/`IN`, `WITH` 절(비재귀) | ORD, ORD_ITEM |
| 함수·조건 분기 | 2 | `DECODE`/`CASE`, `NVL`/`NVL2`, `SUBSTR`/`INSTR`/`LPAD`, `TO_CHAR`/`ADD_MONTHS`/`LAST_DAY`, `LISTAGG` | 전반 |
| 분석함수 | 3~4 | `RANK`/`DENSE_RANK`/`ROW_NUMBER`, `LAG`/`LEAD`, `SUM() OVER(...)` 누적·윈도우 프레임, `RATIO_TO_REPORT`, `NTILE`, `FIRST_VALUE`/`LAST_VALUE`, `KEEP (DENSE_RANK FIRST/LAST)` | ORD, ORD_ITEM |
| 집계 확장 | 3 | `ROLLUP`, `CUBE`, `GROUPING SETS`, `GROUPING_ID` | ORD_ITEM, ITEM |
| PIVOT / UNPIVOT | 4 | 행↔열 전환, 월별·유형별 교차표 | ORD_ITEM, ITEM |
| 계층 질의 | 4 | `START WITH ... CONNECT BY PRIOR`, `LEVEL`, `SYS_CONNECT_BY_PATH`, `CONNECT_BY_ROOT` | COM_CD (자기참조) |
| 이력 테이블 조회 | 4~5 | 적용일자 기준 시점 가격 찾기, 기간 겹침 | UITEM_PRICE, UITEM |
| DML·MERGE | 4 | `MERGE INTO ... USING`, `INSERT SELECT`, CTAS | ORD_TEMP, ORD_TEMP2 (요청 시에만) |

### 튜닝
| 카테고리 | Lv | 다루는 것 | 교보재 |
|---|---|---|---|
| 실행계획 읽기 | 1 | `A-Rows` vs `E-Rows`, `Starts`, `Buffers` 해석, 인덱스 탔는지 판별 | 아무 테이블 |
| 인덱스 무력화 | 2 | 컬럼 가공, 선행 컬럼 누락, 묵시적 형변환 (`ORD_DT` 는 `VARCHAR2(8)`) | ORD + ORD_X01 |
| 클러스터링 팩터 | 3 | 같은 SQL을 두 테이블에 날려 랜덤 액세스 비용 비교 (CF 333K vs 15M) | ORD ↔ ORD_RANDOM |
| 조인 방식·순서 | 3 | NL ↔ Hash ↔ Merge 교차점, `LEADING`, 소량 마스터 조인 | ORD + SHOP/ITEM |
| 스칼라 서브쿼리 | 3~4 | 캐싱 성공/실패, 조인 전환, 선집계 | ORD_ITEM + ITEM |
| Top-N·부분범위 처리 | 4 | `ROWNUM` vs 분석함수 vs `FETCH FIRST`, `COUNT STOPKEY` | ORD |
| 파티션 | 4 | 프루닝(`Pstart/Pstop`), RANGE/LIST/LIST-HASH 비교, 로컬 인덱스, 파티션 와이즈 조인 | ORD_RANGE, ORD_LIST, ORD_LIST_HASH |
| 인덱스 설계 | 5 | 커버링 인덱스, 컬럼 순서 (생성하지 않고 DDL 만 제시) | ORD, ORD_ITEM |
| 카디널리티·통계 | 5 | 오추정 진단, 통계 없는 테이블의 동적 샘플링 | ORD_TEMP 계열 |
| 병렬 | 5 | `PARALLEL` 힌트, DOP 별 비용 (기본은 병렬 끔) | ORD, ORD_ITEM |

난이도는 [.claude/skills/sql-lab/SKILL.md](.claude/skills/sql-lab/SKILL.md) 의 Lv1~5 기준,
문법 범위는 [docs/ORACLE-SYNTAX.md](docs/ORACLE-SYNTAX.md),
튜닝 진단 순서와 오답 패턴은 [docs/TUNING-PLAYBOOK.md](docs/TUNING-PLAYBOOK.md) 를 따른다.

## 직접 돌려보기
```bash
./bin/osql  -c "select count(*) from ord"          # 실행
./bin/oplan query.sql                              # 실측 실행계획 (A-Rows/Buffers)
./bin/ocheck answers/P001.sql attempts/P001/t1.sql # 결과셋 비교
```
`OSQL_TIMEOUT=600` 으로 타임아웃 조정. 접속 정보는 `bin/_common.sh`.

## 구조
```
CLAUDE.md                    에이전트 규칙 (오라클 문법 강제, 정답 비공개 등)
setup/                       테스트 DB 스키마·데이터 셋업 스크립트 (01~07, 99 검증)
docs/SCHEMA.md               스키마 레퍼런스
docs/ORACLE-SYNTAX.md        출제·채점 문법 규칙
docs/TUNING-PLAYBOOK.md      진단 순서와 이 스키마의 교보재
.claude/skills/sql-lab/      출제·채점 워크플로우
.claude/commands/            /quiz /grade /hint /review
problems/PNNN-slug.md        문제 (참고 정보 포함, 이것만 보고 풀 수 있게)
answers/PNNN.sql             모범답안 (비공개)
answers/PNNN-notes.md        해설·기준 성능치 (비공개)
attempts/PNNN/tN.sql         제출
attempts/PNNN/tN-grade.md    채점 결과·피드백
progress.md                  이력 인덱스
```

## 이 DB의 교보재
- `ORD` 1,500만 / `ORD_ITEM` 3,710만, 기간 **20120101~20131231**
- `ORD` ↔ `ORD_RANDOM`: 동일 구조인데 클러스터링 팩터 333K vs 15M (45배)
- `ORD_RANGE` / `ORD_LIST` / `ORD_LIST_HASH`: ORD_YM 기준 25파티션, 로컬 인덱스
- 스키마 통계 수집 완료 (2026-09-20)
