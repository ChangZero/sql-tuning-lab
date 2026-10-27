# P001 / t1 채점 — 재제출

- 일자: 2026-09-20
- 제출: [t1.sql](t1.sql)
- 문제: [problems/P001-shop-top10-tuning.md](../../problems/P001-shop-top10-tuning.md)
- 판정: **재제출** (튜닝 목표 달성 / 출력 형식 불일치)

## 1. 문법 — 통과
오라클 전용 조인(`from ord o, shop s` + `where`). ANSI 조인·타 DBMS 방언 없음.
힌트 미사용, 인덱스 추가 없음 → 문제 제약 모두 준수.

## 2. 튜닝 — 목표 달성
`substr(ord_dt,1,6)='201203'` → `ord_dt like '201203%'` 로 컬럼 가공을 제거해 `ORD_X01` 이 살아남.

| | Buffers | A-Time | ORD 접근 |
|---|---|---|---|
| 원본 (문제의 느린 SQL) | 333,000 | 3.12초 | `TABLE ACCESS FULL ORD` |
| **제출 t1 (2회차)** | **16,283** | 0.22초 | `INDEX RANGE SCAN ORD_X01` → ROWID BATCHED |
| 모범답안 (2회차) | 16,284 | 0.16초 | 동일 |

목표 20,000 이하 대비 16,283, 기준의 1.00배.

실행계획 근거:
- `Id 8 INDEX RANGE SCAN ORD_X01` — Buffers 2,365 로 625K 건 ROWID 추출
- `Id 7 TABLE ACCESS BY INDEX ROWID BATCHED ORD` — 나머지 13,912 사용
- `ORD` 는 주문일자 순 정렬 적재라 CF 가 좋아 625K 건을 훑고도 16K 블록에 그침
  (같은 SQL을 `ORD_RANDOM` 에 던지면 이 지점이 수십만으로 뜀)

## 3. 결과셋 — FAIL
```
FAIL  결과셋 불일치 — 정답 10행 / 제출 10행
1c1
< SHOP_NM|ORD_CNT
---
> SHOP_NM|COUNT(1)
```
데이터 10행은 값·순서 모두 일치. 헤더 1행만 불일치.

### 고칠 점
1. **컬럼 별칭 누락** — 문제가 출력 컬럼을 `SHOP_NM`, `ORD_CNT` 로 지정했으나
   `count(1)` 에 별칭이 없어 컬럼명이 `COUNT(1)` 로 나감.
2. **동건수 정렬 기준 누락** — `order by count(1) desc` 만 있고 `SHOP_NM` 오름차순 tiebreak 가 없음.
   2012-03 데이터에 8·9위가 3,226건으로 실제 동률(2개 매장). 이번엔 우연히 순서가 맞았을 뿐,
   실행계획이 바뀌면 뒤집히고 `ocheck --ordered` 에서 FAIL 난다.

```
RNK   CNT    SHOPS
  7  3229      1
  8  3226      2   ← 동률
 10  3224      1
```

## 다음
`t2.sql` 로 복사해 위 두 가지만 수정. 튜닝 구조(LIKE + 인라인뷰 Top-N)는 이미 기준치이므로 그대로 둘 것.
