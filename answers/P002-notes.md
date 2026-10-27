# P002 해설 — 상품유형별 판매수량 상위 3개 상품

## 핵심 포인트
1. **집계 → 분석함수 → 필터 순서.** `RANK()` 는 `GROUP BY` 집계 결과 위에서 계산되므로
   `rank() over (partition by i.item_type_cd order by sum(oi.ord_item_qty) desc)` 처럼
   집계함수를 그대로 `ORDER BY` 에 넣을 수 있다.
   반면 분석함수는 `WHERE` 에서 참조할 수 없으므로 **인라인 뷰로 한 번 감싸고** 바깥에서 `rnk <= 3`.
2. **비중의 분모.** `RATIO_TO_REPORT(...) OVER (PARTITION BY item_type_cd)`
   (또는 `sum(...)/SUM(sum(...)) OVER (PARTITION BY ...)`) 를 **인라인 뷰 안쪽**에서 계산해야
   유형 전체 92개 상품 합계가 분모가 된다. 바깥에서 계산하면 상위 3개 합계가 분모가 되어 오답.
3. **정렬 컬럼을 출력하지 않기.** `ITEM_TYPE_CD` 를 인라인 뷰의 SELECT 리스트에는 올리고
   최종 SELECT 리스트에서는 뺀다.
4. `COM_CD` 조인은 `ITEM.ITEM_TYPE_CD = COM_CD.UNI_CD` 로 충분하다.
   `CL_UNI_CD='100'` 조건은 없어도 결과가 같다(루트 '100' 은 어떤 ITEM_TYPE_CD 와도 매칭 안 됨).

## 기준 실측 (2회차)
```
A-Rows  = 18
A-Time  = 00:00:00.61
Buffers = 43273
```
계획 요약:
- Id 12 `INDEX RANGE SCAN ORD_ITEM_X01` — ORD_DT 범위 (A-Rows 1,549K / Buffers 5,853)
- Id 11 `TABLE ACCESS BY INDEX ROWID BATCHED ORD_ITEM` — Buffers 43,265 (여기가 대부분)
- Id 5 `HASH JOIN` ORD_ITEM ↔ (ITEM ⋈ COM_CD 92건)
- Id 4 `HASH GROUP BY` → 91행, Id 3 `WINDOW SORT`, Id 2 `VIEW` filter RNK<=3

## 흔한 오답
| 오답 | 증상 | 원인 |
|---|---|---|
| 비중을 인라인 뷰 **바깥**에서 계산 | QTY_PCT 합이 유형별 100% 로 나옴 | 분모가 상위 3개 합계가 됨 |
| `ROW_NUMBER()` 사용 | 동순위 처리가 다름 | 이 데이터엔 동수량이 없어 결과는 같지만 요구사항 위반 |
| `DENSE_RANK()` 사용 | 동상동 | 위와 같음 |
| `ROWNUM <= 3` | 전체에서 3행만 | 유형별 Top-N 은 분석함수로 |
| `TO_DATE(ord_dt,'YYYYMMDD') between ...` | `ORD_ITEM_X01` 무력화 → 풀스캔, Buffers 800K+ | 문자열 컬럼에 함수 적용 |
| `ord_dt like '201203%'` | 결과는 동일 | 이 문제에선 허용 (범위가 한 달로 같음) |
| `GROUP BY i.item_id` 만 | ITEM_NM/TYPE_NM 참조 불가 에러 | 출력 컬럼을 GROUP BY 에 포함 |
| ANSI `JOIN ... ON` | 문법 위반 | 오라클 전용 규칙 |
| 정렬을 `TYPE_NM` 으로 | 유형 순서가 코드 순과 다름 | `ITEM_TYPE_CD` 로 정렬해야 버거→음료 순 |

## 채점 시
- `./bin/ocheck --ordered answers/P002.sql attempts/P002/tN.sql` (정렬까지 요구한 문제)
- 성능은 참고만. Buffers 가 100,000 을 넘으면 `ORD_ITEM` 풀스캔을 의심할 것
