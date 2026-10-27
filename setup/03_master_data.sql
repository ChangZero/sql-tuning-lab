-- 03. 마스터 데이터 적재 — dev 계정으로 실행
-- COM_CD 7 / ITEM 92 / SHOP 200 / UITEM 130 / UITEM_PRICE 130

set define off
alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS';

truncate table uitem_price;
truncate table uitem;
truncate table item;
truncate table shop;
truncate table com_cd;

-- ===========================================================================
-- COM_CD — 7건. '100' 이 루트, 그 아래 상품유형 6개. CL_UNI_CD 자기참조
-- ===========================================================================
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100',    '상품유형코드', 'M',   null, '상품유형 분류 루트', 'SETUP', sysdate);
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100100', '버거',       '100', 1,    null, 'SETUP', sysdate);
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100101', '세트',       '100', 2,    null, 'SETUP', sysdate);
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100102', '치킨',       '100', 3,    null, 'SETUP', sysdate);
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100103', '디저트',     '100', 4,    null, 'SETUP', sysdate);
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100104', '아이스크림', '100', 5,    null, 'SETUP', sysdate);
insert into com_cd (uni_cd, uni_cd_nm, cl_uni_cd, seq, cd_desc, reg_id, reg_dts)
values ('100105', '음료',       '100', 6,    null, 'SETUP', sysdate);
commit;

-- ===========================================================================
-- ITEM — 92건. 유형별 건수를 원본과 똑같이 맞춘다
--   버거 18 / 세트 17 / 치킨 8 / 디저트 12 / 아이스크림 12 / 음료 25 = 92
--   ITEM_ID 는 유형 순서대로 1~92
-- ===========================================================================
insert into item (item_id, item_nm, item_type_cd, sale_yn, item_desc, reg_id, reg_dts)
with spec as (
  select '100100' type_cd, '버거'       type_nm,  1 from_id, 18 cnt from dual union all
  select '100101',         '세트',                19,          17       from dual union all
  select '100102',         '치킨',                36,           8       from dual union all
  select '100103',         '디저트',              44,          12       from dual union all
  select '100104',         '아이스크림',          56,          12       from dual union all
  select '100105',         '음료',                68,          25       from dual
), gen as (
  select level n from dual connect by level <= 25
)
select s.from_id + g.n - 1                         item_id
     , s.type_nm || lpad(g.n, 2, '0')              item_nm
     , s.type_cd                                   item_type_cd
     , 'Y'                                         sale_yn
     , s.type_nm || ' 상품'                        item_desc
     , 'SETUP'                                     reg_id
     , date '2012-01-01'                           reg_dts
  from spec s, gen g
 where g.n <= s.cnt;
commit;

-- ===========================================================================
-- SHOP — 200건
-- ===========================================================================
insert into shop (shop_no, shop_nm, addr, tel, reg_id, reg_dts)
select 'S' || lpad(level, 3, '0')                            shop_no
     , lpad(level, 3, '0') || '호점'                         shop_nm
     , '서울특별시 테스트구 테스트로 ' || level              addr
     , '02-' || lpad(mod(level, 1000), 4, '0') || '-'
              || lpad(mod(level * 7, 10000), 4, '0')         tel
     , 'SETUP'                                               reg_id
     , date '2012-01-01'                                     reg_dts
  from dual
connect by level <= 200;
commit;

-- ===========================================================================
-- UITEM — 130건. 92개 상품 중 앞쪽 38개는 단위상품 2개, 나머지는 1개 (92 + 38 = 130)
-- ===========================================================================
insert into uitem (item_id, uitem_id, uitem_nm, sale_yn, reg_id, reg_dts)
select i.item_id
     , u.uitem_id
     , i.item_nm || '-' || u.uitem_id
     , 'Y'
     , 'SETUP'
     , date '2012-01-01'
  from item i, (select 1 uitem_id from dual union all select 2 from dual) u
 where u.uitem_id = 1
    or i.item_id <= 38;
commit;

-- ===========================================================================
-- UITEM_PRICE — 130건. 단위상품마다 적용일자 1건 (원본 건수에 맞춤)
--   ※ 적용일자 이력을 여러 건 두고 연습하려면 아래 "이력 확장" 블록을 쓴다
-- ===========================================================================
insert into uitem_price (item_id, uitem_id, apply_dt, price, reg_id, reg_dts)
select u.item_id
     , u.uitem_id
     , '20120101'                                        apply_dt
     , 1000 + mod(u.item_id * 137 + u.uitem_id * 31, 60) * 100  price
     , 'SETUP'
     , date '2012-01-01'
  from uitem u;
commit;

-- --- 이력 확장 (선택) --------------------------------------------------------
-- 단위상품마다 20120101 / 20120701 / 20130101 3개 시점을 두면
-- "특정일자 기준 유효 가격 찾기" 문제를 낼 수 있다. 쓰려면 주석을 풀 것.
-- (건수가 130 → 390 으로 바뀌므로 docs/SCHEMA.md 도 같이 고친다)
--
-- insert into uitem_price (item_id, uitem_id, apply_dt, price, reg_id, reg_dts)
-- select u.item_id, u.uitem_id, d.apply_dt
--      , (1000 + mod(u.item_id * 137 + u.uitem_id * 31, 60) * 100) + d.bump
--      , 'SETUP', date '2012-01-01'
--   from uitem u
--      , (select '20120701' apply_dt, 200 bump from dual union all
--         select '20130101',          500      from dual) d;
-- commit;

exit
