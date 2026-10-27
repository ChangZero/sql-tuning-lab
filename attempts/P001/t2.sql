-- P001 / t1 — 2012년 3월 매장별 주문 상위 10개
-- 문제: ../../problems/P001-shop-top10-tuning.md
--
-- 출력 컬럼: SHOP_NM, ORD_CNT   (이 순서)
-- 정렬     : ORD_CNT DESC, SHOP_NM ASC
-- 결과     : 10행
-- 제약     : 오라클 전용 문법(ANSI 조인 금지) / 인덱스 추가 금지 / 힌트 강제 금지
--            목표 Buffers 20,000 이하
--
-- 아래에 SQL 한 개만 쓴다. 끝에 세미콜론 없이, SQL 중간에 빈 줄을 넣지 않는다.
-- 다 썼으면  /grade P001     (다시 풀 때는 같은 폴더에 t2.sql 로 복사해서)

SELECT *  FROM (
SELECT shop_nm, count(1) as ord_cnt FROM ord o, shop s
WHERE o.shop_no = s.shop_no
  AND o.ord_dt LIKE '201203%'
 GROUP BY s.SHOP_NM
 ORDER BY count(1) desc, shop_nm asc
) WHERE rownum <= 10;


