# P001 — 2012년 3월 매장별 주문 상위 10개

- 난이도: Lv2
- 주제: 인덱스 무력화 (컬럼 가공) / Top-N
- 유형: 튜닝

## 요구사항
2012년 3월 한 달 동안 주문 건수가 많은 **매장 상위 10곳**을 구한다.

출력 컬럼: `SHOP_NM`, `ORD_CNT`
정렬: `ORD_CNT` 내림차순, 동건수면 `SHOP_NM` 오름차순
결과 행 수: 10행

## 참고 정보
**ORD** — 주문, 15,000,000 건 / 2.6GB
| 컬럼 | 타입 | 설명 |
|---|---|---|
| ORD_NO | NUMBER | PK |
| ORD_DT | VARCHAR2(8) | 주문일자 `YYYYMMDD` — **DATE 아니라 문자열** |
| ORD_HMS | VARCHAR2(6) | 주문시각 `HH24MISS` |
| SHOP_NO | VARCHAR2(10) | → SHOP.SHOP_NO |

인덱스: `ORD_PK(ORD_NO)` UNIQUE, `ORD_X01(ORD_DT, ORD_HMS)` (클러스터링 팩터 333,388 / 리프블록 57,866)

**SHOP** — 매장, 200 건. `SHOP_NO`(PK), `SHOP_NM`, `ADDR`, `TEL`

조인: `ORD.SHOP_NO = SHOP.SHOP_NO`
데이터 기간: `ORD_DT` 20120101 ~ 20131231

## 제약
- 오라클 전용 문법으로 작성한다 (ANSI 조인 금지)
- **인덱스를 새로 만들지 않는다.** SQL 만 고쳐서 해결할 것
- 힌트(`/*+ ... */`)로 강제하지 말고, 옵티마이저가 스스로 좋은 계획을 고르게 만들 것
- 결과는 아래 현재 SQL과 완전히 동일해야 한다

## 현재 SQL
```sql
select s.shop_nm, count(*) ord_cnt
  from ord o, shop s
 where substr(o.ord_dt, 1, 6) = '201203'
   and o.shop_no = s.shop_no
 group by s.shop_nm
 order by count(*) desc, s.shop_nm
 fetch first 10 rows only
```

현재 실측: **Buffers 333,000 / A-Time 3.12초** — `TABLE ACCESS FULL ORD` (1,500만 건 전수 스캔)

→ **목표: Buffers 20,000 이하**

## 생각해볼 것
1. `ORD_X01(ORD_DT, ORD_HMS)` 인덱스가 있는데 왜 안 타는가?
2. `ORD_DT` 는 `DATE` 가 아니라 `VARCHAR2(8)` 이다. 이게 해법에 어떻게 쓰이는가?

## 제출
`attempts/P001/t1.sql` 에 SQL 을 쓴 뒤 `/grade P001`
채점 결과는 같은 폴더에 `t1-grade.md` 로 남는다. 다시 풀 때는 `t2.sql` 로 복사해서.
