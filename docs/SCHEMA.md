# DEV 스키마 레퍼런스 (Oracle 19.3 EE / ORCLPDB1)

접속: `dev/1234@//172.30.38.250:1521/ORCLPDB1` (컨테이너 내부에서는 `//localhost:1521/ORCLPDB1`)
데이터 기간: **ORD_DT 20120101 ~ 20131231** (2년치). 2024년 등 범위 밖 날짜로 문제를 내면 0건이 나온다.

## 1. 핵심 트랜잭션 테이블

### ORD — 주문 (15,000,000 건 / 2.6GB)
| 컬럼 | 타입 | 설명 |
|---|---|---|
| ORD_NO | NUMBER | 주문번호 (PK) |
| ORD_DT | VARCHAR2(8) | 주문일자 `YYYYMMDD` — **DATE 아님, 문자열** |
| ORD_HMS | VARCHAR2(6) | 주문시각 `HH24MISS` |
| SHOP_NO | VARCHAR2(10) | 매장번호 → SHOP |
| UPPER2 | VARCHAR2(2) | 대문자 2자리 (임의 값, 필터 연습용) |
| UPPER_CASE / LOWER_CASE | VARCHAR2(10) | 대·소문자 문자열 (함수 기반 인덱스, 대소문자 검색 연습용) |
| ALPHABET / ALPHABET_NUMERIC | VARCHAR2(400) | 패딩 문자열 (로우 길이를 늘려 블록당 행수를 줄이는 용도) |

인덱스: `ORD_PK(ORD_NO)` UNIQUE, `ORD_X01(ORD_DT, ORD_HMS)`

### ORD_ITEM — 주문상세 (37,096,485 건 / 6.5GB)
| 컬럼 | 타입 | 설명 |
|---|---|---|
| ORD_NO, ITEM_ID | NUMBER | 복합 PK |
| ORD_ITEM_QTY | NUMBER | 수량 |
| ORD_DT, ORD_HMS | VARCHAR2 | ORD 에서 비정규화된 값 |
| UPPER2, UPPER_CASE, LOWER_CASE, ALPHABET, ALPHABET_NUMERIC | | ORD 와 동일 |

인덱스: `ORD_ITEM_PK(ORD_NO, ITEM_ID)` UNIQUE, `ORD_ITEM_X01(ORD_DT, ORD_HMS)`
주문 1건당 평균 약 2.5 상세.

## 2. 마스터 / 코드 테이블
| 테이블 | 건수 | 키 | 비고 |
|---|---|---|---|
| ITEM | 92 | ITEM_ID (PK) | ITEM_NM, ITEM_TYPE_CD, SALE_YN |
| SHOP | 200 | SHOP_NO (PK) | SHOP_NM, ADDR, TEL |
| COM_CD | 7 | UNI_CD (PK) | 공통코드. CL_UNI_CD 로 자기참조 → **계층질의(CONNECT BY) 연습용** |
| UITEM | 130 | ITEM_ID + UITEM_ID | 단위상품 |
| UITEM_PRICE | 130 | ITEM_ID + UITEM_ID + APPLY_DT | 단위상품 가격이력 → **이력 테이블 조회 패턴 연습용** |

COM_CD 값:
```
100      상품유형코드   (CL_UNI_CD='M', 루트)
100100 버거 / 100101 세트 / 100102 치킨 / 100103 디저트 / 100104 아이스크림 / 100105 음료  (CL_UNI_CD='100')
```
ITEM 분포: 버거18 세트17 치킨8 디저트12 아이스크림12 음료25

## 3. 튜닝 실험용 변형 테이블

### 클러스터링 팩터 비교 (★ 이 스키마의 핵심 교보재)
| 인덱스 | 클러스터링 팩터 | 리프블록 |
|---|---|---|
| ORD_X01 (ORD_DT, ORD_HMS) | **333,388** | 57,866 |
| ORD_RANDOM_X01 (동일 컬럼) | **14,999,958** | 57,637 |

`ORD` 는 주문일자 순으로 정렬 적재, `ORD_RANDOM` 은 무작위 적재. 컬럼·인덱스·건수가 완전히 동일한데
CF 가 45배 차이난다. 같은 SQL을 두 테이블에 던져 **테이블 랜덤 액세스 비용 차이**를 눈으로 확인하는 용도.
`ORD_ITEM` ↔ `ORD_ITEM_RANDOM` 도 같은 쌍.

### 파티션 테이블 (모두 ORD_YM 기준 25개 파티션)
| 테이블 | 파티션 방식 | 서브파티션 |
|---|---|---|
| ORD_RANGE / ORD_ITEM_RANGE | RANGE (P201201 high_value '201202' …) | 없음 |
| ORD_LIST / ORD_ITEM_LIST | LIST (P201201 = '201201' …) | 없음 |
| ORD_LIST_HASH / ORD_ITEM_LIST_HASH | LIST | HASH |

- 파티션 테이블에는 **ORD_YM 컬럼이 추가**되어 있고 PK 에도 포함된다 (`ORD_LIST_PK(ORD_NO, ORD_YM)`).
- 인덱스는 모두 **로컬 파티션 인덱스**.
- 파티션 프루닝(`Pstart/Pstop`), 로컬 인덱스 vs 글로벌 인덱스, 파티션 와이즈 조인 연습용.

### 기타
- `ORD_TEMP`, `ORD_TEMP2` — ORD_NO 없는 적재용 테이블 (INSERT/MERGE, CTAS, 통계 없는 상태 실험용)

## 4. 실행 환경 메모
- `dev` 보유 권한: `SELECT ANY DICTIONARY`, `ADVISOR`, `ALTER SESSION`, `CREATE TABLE`, `SELECT ANY TABLE`
  → `V$SQL`, `V$SQL_PLAN`, `DBMS_XPLAN.DISPLAY_CURSOR`, `DBMS_SQLTUNE` 사용 가능
- `PLAN_TABLE` 은 개인 스키마에 없고 공용 `PLAN_TABLE$` 를 사용 (EXPLAIN PLAN 그대로 동작)
- 통계: `DBMS_STATS.GATHER_SCHEMA_STATS(degree=>4, granularity=>'ALL')` 로 수집 완료
- 총 세그먼트 약 60GB. **풀스캔은 분 단위로 걸린다** — `bin/*` 러너의 기본 타임아웃 180초
