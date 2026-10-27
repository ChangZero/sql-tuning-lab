# 테스트 DB 스키마·데이터 셋업

`sql-tuning-lab` 의 문제를 풀려면 Oracle 19c 에 `DEV` 스키마가 이 구성대로 들어 있어야 한다.
이 폴더의 스크립트를 번호 순서대로 돌리면 [../docs/SCHEMA.md](../docs/SCHEMA.md) 와 같은 상태가 된다.

## 실행 순서

| 파일 | 하는 일 | 계정 | 대략 소요 |
|---|---|---|---|
| `01_create_schema.sql` | `dev` 계정 생성 + 권한 | DBA | 즉시 |
| `02_tables.sql` | 테이블 18개 DDL (제약·인덱스 없이) | dev | 즉시 |
| `03_master_data.sql` | COM_CD 7 / ITEM 92 / SHOP 200 / UITEM 130 / UITEM_PRICE 130 | dev | 즉시 |
| `04_generate_ord.sql` | **ORD 15,000,000 / ORD_ITEM 약 37,200,000 생성** | dev | 20분~2시간 |
| `05_variants.sql` | RANDOM 쌍 + 파티션 테이블 6개 적재 | dev | 30분~3시간 |
| `06_indexes.sql` | PK·인덱스 생성, 병렬 속성 해제 | dev | 10~40분 |
| `07_gather_stats.sql` | 스키마 통계 수집 | dev | 10~30분 |
| `99_verify.sql` | 건수·CF·파티션 검증 | dev | 1~2분 |

```bash
# 컨테이너 안에서 돌리는 경우
docker exec -i oracle19c-ee bash -lc \
  'export NLS_LANG=AMERICAN_AMERICA.AL32UTF8; cat > /tmp/s.sql && sqlplus -S dev/1234@//localhost:1521/ORCLPDB1 @/tmp/s.sql' \
  < setup/03_master_data.sql
```

`04`, `05` 는 길게 돈다. `set serveroutput on` 상태로 돌리면 30일/1개월 단위로 진행상황이 찍힌다.

## 용량 요구사항

- `USERS` 테이블스페이스 **약 60GB** — ORD/ORD_ITEM 본체 9GB + RANDOM 복제 9GB + 파티션 3종 27GB + 인덱스
- `TEMP` **약 16GB** — `05` 의 무작위 적재 때 월별(약 62만 행) 정렬이 일어난다
- 둘 중 하나라도 부족하면 `ORA-01652` / `ORA-01653` 로 멈춘다. 그 단계만 다시 돌리면 된다

용량이 부족하면 `05` 를 건너뛰어도 된다. 클러스터링 팩터·파티션 주제 문제만 못 풀고
나머지(조인·분석함수·인덱스 무력화)는 전부 가능하다.

## 꼭 지켜야 하는 두 가지

이 스키마의 교보재 가치는 **적재 순서**에서 나온다. 순서를 어기면 테이블은 만들어지지만
문제의 성능 차이가 사라진다.

1. **`04` 는 하루씩 끊어 `(ORD_DT, ORD_HMS)` 오름차순으로 넣는다.**
   그래서 `ORD_X01` 의 클러스터링 팩터가 약 333,000 이 된다.
   한 번에 `ORDER BY` 없이 넣으면 CF 가 1,500만 쪽으로 올라가고 `ORD` 와 `ORD_RANDOM` 이 구분되지 않는다.
2. **`06` 마지막의 `NOPARALLEL` 을 빼먹지 않는다.**
   인덱스에 PARALLEL 속성이 남으면 이후 모든 문제에서 옵티마이저가 병렬 계획을 골라
   `bin/oplan` 실측치가 문제 파일의 기준값과 안 맞는다.

`99_verify.sql` 의 4번 항목이 이 두 가지를 바로 확인해 준다.

## 원본 DB 와 다른 점

이 스크립트는 **현재 돌아가는 DB 에서 떠낸 덤프가 아니라 `docs/SCHEMA.md` 기준으로 다시 작성한 것**이다.
구조(테이블·컬럼·타입·인덱스·파티션)와 건수·분포는 맞추었지만 아래는 원본과 다르다.

| 항목 | 원본 | 이 스크립트 |
|---|---|---|
| ITEM 상품명 | `데리버거`, `치킨버거세트` 같은 실제 상품명 | `버거01` ~ `음료25` 형태로 생성 |
| SHOP 매장명 | `강남점` 같은 실제 지점명 | `001호점` ~ `200호점` |
| ORD_ITEM 건수 | 37,096,485 | 약 37,200,000 (주문당 상세 분포로 생성) |
| 패딩 컬럼 값 | 임의 문자열 | 고정 문자열 (로우 길이만 맞춤) |

그래서 **결과 건수·실행계획·Buffers 는 재현되지만, 특정 상품명·매장명이 찍히는 문제의
정답 값 자체는 달라질 수 있다.** 기존 `answers/` 의 기준 Buffers 는 그대로 쓸 수 있고,
`problems/` 의 "정답 행 수" 도 유지된다.

원본 그대로를 떠내려면 살아 있는 DB 에서:

```sql
-- DDL 추출
select dbms_metadata.get_ddl('TABLE', table_name, 'DEV') from user_tables;
-- 마스터 데이터는 건수가 적으니 그대로 INSERT 문으로 뽑아 03 을 대체하면 된다
```

## 검증 기준값

`99_verify.sql` 이 아래와 맞으면 셋업 성공이다.

```
ORD                   15,000,000
ORD_ITEM              약 37,200,000
ORD_DT                20120101 ~ 20131231 (730일)
ITEM                  92  (버거18 세트17 치킨8 디저트12 아이스크림12 음료25)
SHOP                  200
COM_CD                7
ORD_X01               CF 약   333,000   / 리프블록 약 57,800
ORD_RANDOM_X01        CF 약 15,000,000  / 리프블록 약 57,600   ← 약 45배 차이
파티션 테이블          각 25개 파티션, 인덱스 전부 LOCAL
ORD_TEMP / ORD_TEMP2  NUM_ROWS 비어 있음 (통계 없음)
```
