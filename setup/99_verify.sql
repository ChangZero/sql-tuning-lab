-- 99. 셋업 검증 — dev 계정으로 실행
-- docs/SCHEMA.md 에 적힌 수치와 맞는지 확인한다. 안 맞으면 어느 단계가 틀렸는지 메모 참고.

set linesize 200 pagesize 200
col table_name format a24
col idx        format a24
col 판정       format a6

prompt ============ 1. 건수 (기대값과 비교) ============
prompt   ORD 15,000,000 / ORD_ITEM 약 37,200,000 / ITEM 92 / SHOP 200 / COM_CD 7
prompt   UITEM 130 / UITEM_PRICE 130
select 'COM_CD' t, count(*) cnt from com_cd      union all
select 'ITEM',      count(*)    from item        union all
select 'SHOP',      count(*)    from shop        union all
select 'UITEM',     count(*)    from uitem       union all
select 'UITEM_PRICE', count(*)  from uitem_price union all
select 'ORD',       count(*)    from ord         union all
select 'ORD_ITEM',  count(*)    from ord_item;

prompt ============ 2. 데이터 기간 (20120101 ~ 20131231 이어야 한다) ============
select min(ord_dt) min_dt, max(ord_dt) max_dt, count(distinct ord_dt) days from ord;

prompt ============ 3. ITEM 유형별 건수 ============
prompt   기대: 버거 18 / 세트 17 / 치킨 8 / 디저트 12 / 아이스크림 12 / 음료 25
select c.uni_cd, c.uni_cd_nm, count(*) cnt
  from item i, com_cd c
 where i.item_type_cd = c.uni_cd
 group by c.uni_cd, c.uni_cd_nm
 order by c.uni_cd;

prompt ============ 4. ★ 클러스터링 팩터 (이 스키마의 핵심) ============
prompt   기대: ORD_X01 약 333,000 / ORD_RANDOM_X01 약 15,000,000 (약 45배 차이)
prompt   둘이 비슷하게 나오면 04 의 "하루씩 ORD_HMS 순서로" 또는
prompt   05 의 ORDER BY ORA_HASH 가 빠진 것이다
select index_name idx, num_rows, leaf_blocks, clustering_factor
  from user_indexes
 where index_name in ('ORD_X01', 'ORD_RANDOM_X01', 'ORD_ITEM_X01', 'ORD_ITEM_RANDOM_X01')
 order by index_name;

prompt ============ 5. 파티션 구성 (테이블마다 25개여야 한다) ============
select table_name, partitioning_type, subpartitioning_type, partition_count
  from user_part_tables
 order by table_name;

prompt ============ 6. 로컬 인덱스 여부 (전부 LOCAL 이어야 한다) ============
select index_name idx, locality, status
  from user_part_indexes
 order by index_name;

prompt ============ 7. 통계 ============
prompt   ORD_TEMP / ORD_TEMP2 만 NUM_ROWS 가 비어 있어야 한다 (동적 샘플링 교보재)
select table_name, num_rows, blocks, nvl(to_char(last_analyzed,'YYYY-MM-DD'),'(없음)') analyzed
  from user_tables
 order by table_name;

prompt ============ 8. 파티션 프루닝 동작 확인 ============
explain plan for
select count(*) from ord_list where ord_ym = '201203';
select * from table(dbms_xplan.display(null, null, 'BASIC +PARTITION'));

prompt ============ 9. 인덱스를 타는지 확인 (ORD_X01 RANGE SCAN 이 보여야 한다) ============
explain plan for
select count(*) from ord where ord_dt between '20120301' and '20120331';
select * from table(dbms_xplan.display(null, null, 'BASIC'));

exit
