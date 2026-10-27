-- 04. ORD / ORD_ITEM 대량 생성 — dev 계정으로 실행
--
--   ORD      : 15,000,000건 (20120101 ~ 20131231, 730일)
--   ORD_ITEM : 약 37,200,000건 (주문 1건당 1~5 상세, 평균 2.48)
--
-- ★ 적재 순서가 중요하다. 하루씩 끊어서 (ORD_DT, ORD_HMS) 오름차순으로 넣는다.
--   그래야 ORD_X01 의 클러스터링 팩터가 333,000 내외로 떨어진다.
--   한 방에 ORDER BY 없이 넣으면 CF 가 망가져 05 의 ORD_RANDOM 과 구분이 안 된다.
--
-- 소요시간: 장비에 따라 20분 ~ 2시간. 중간에 끊겨도 아래 "이어서 돌리기" 로 재개 가능.
-- 진행상황을 보려면 먼저  set serveroutput on

set serveroutput on size unlimited
set timing on

alter session enable parallel dml;
alter table ord      nologging;
alter table ord_item nologging;

truncate table ord_item;
truncate table ord;

declare
  c_total_ord   constant number      := 15000000;
  c_start_dt    constant date        := date '2012-01-01';
  c_days        constant pls_integer := 730;          -- 20120101 ~ 20131231
  c_per_day     constant pls_integer := 20548;        -- 730 * 20548 = 15,000,040 → 마지막 날 보정

  -- 패딩. 로우 길이를 약 173바이트로 맞춰 블록당 약 45행이 되게 한다
  -- (이 값이 곧 CF 를 결정한다. 20,548행/일 ÷ 45행/블록 ≈ 457블록/일 × 730일 ≈ 333,000)
  c_pad_a       constant varchar2(60) := rpad('A', 55, 'A');
  c_pad_n       constant varchar2(60) := rpad('A1B2C3D4E5', 55, 'A1B2C3D4E5');

  v_done        number := 0;
  v_rows        pls_integer;
  v_dt          varchar2(8);
begin
  for d in 0 .. c_days - 1 loop
    v_dt   := to_char(c_start_dt + d, 'yyyymmdd');
    v_rows := least(c_per_day, c_total_ord - v_done);
    exit when v_rows <= 0;

    -- ORD : 하루치를 ORD_HMS 오름차순으로 생성
    insert /*+ append */ into ord
      (ord_no, ord_dt, ord_hms, shop_no, upper2, upper_case, lower_case,
       alphabet, alphabet_numeric)
    select v_done + n                                                   ord_no
         , v_dt                                                         ord_dt
           -- 하루 86,400초를 v_rows 등분 → 하루 안에서 단조증가
         , lpad(trunc(trunc((n - 1) * 86400 / v_rows) / 3600), 2, '0')
        || lpad(trunc(mod(trunc((n - 1) * 86400 / v_rows), 3600) / 60), 2, '0')
        || lpad(mod(trunc((n - 1) * 86400 / v_rows), 60), 2, '0')       ord_hms
           -- 매장 분포는 일부러 치우치게 만든다 (Top-N 문제가 의미를 갖도록)
         , 'S' || lpad(
             least(200, trunc(200 * power(ora_hash(v_done + n, 999999) / 1000000, 1.6)) + 1)
             , 3, '0')                                                  shop_no
         , chr(65 + mod(ora_hash(v_done + n), 26))
        || chr(65 + mod(trunc(ora_hash(v_done + n) / 26), 26))          upper2
           -- 10자리 영대문자 (A~J). 함수기반인덱스·대소문자 검색 연습용
         , translate(to_char(1000000000 + ora_hash(v_done + n, 999999999))
                     , '0123456789', 'ABCDEFGHIJ')                      upper_case
         , lower(translate(to_char(1000000000 + ora_hash(v_done + n, 999999999, 42))
                           , '0123456789', 'ABCDEFGHIJ'))               lower_case
         , c_pad_a                                                      alphabet
         , c_pad_n                                                      alphabet_numeric
      from (select level n from dual connect by level <= v_rows);

    commit;
    v_done := v_done + v_rows;

    if mod(d + 1, 30) = 0 then
      dbms_output.put_line(to_char(d + 1) || '일 (' || v_dt || ') 까지 ORD '
                           || to_char(v_done, 'FM999,999,999') || '건');
    end if;
  end loop;

  dbms_output.put_line('ORD 완료: ' || to_char(v_done, 'FM999,999,999') || '건');
end;
/

-- ---------------------------------------------------------------------------
-- ORD_ITEM : ORD 를 하루씩 읽어 주문당 1~5건 생성
--   상세 건수 분포 = 1건 28% / 2건 25% / 3건 25% / 4건 15% / 5건 7% → 평균 2.48
--   ITEM_ID 는 한 주문 안에서 중복되지 않게 13씩 띄운다 (PK: ORD_NO + ITEM_ID)
-- ---------------------------------------------------------------------------
declare
  c_start_dt constant date        := date '2012-01-01';
  c_days     constant pls_integer := 730;
  c_pad_a    constant varchar2(60) := rpad('A', 55, 'A');
  c_pad_n    constant varchar2(60) := rpad('A1B2C3D4E5', 55, 'A1B2C3D4E5');
  v_dt       varchar2(8);
  v_total    number := 0;
begin
  for d in 0 .. c_days - 1 loop
    v_dt := to_char(c_start_dt + d, 'yyyymmdd');

    insert /*+ append */ into ord_item
      (ord_no, item_id, ord_item_qty, ord_dt, ord_hms, upper2,
       upper_case, lower_case, alphabet, alphabet_numeric)
    select o.ord_no
         , mod(ora_hash(o.ord_no, 91) + x.i * 13, 92) + 1   item_id
         , mod(o.ord_no + x.i, 3) + 1                       ord_item_qty
         , o.ord_dt
         , o.ord_hms
         , o.upper2
         , o.upper_case
         , o.lower_case
         , c_pad_a
         , c_pad_n
      from ord o
         , (select level i from dual connect by level <= 5) x
     where o.ord_dt = v_dt
       and x.i <= case
                    when mod(o.ord_no, 100) < 28 then 1
                    when mod(o.ord_no, 100) < 53 then 2
                    when mod(o.ord_no, 100) < 78 then 3
                    when mod(o.ord_no, 100) < 93 then 4
                    else 5
                  end
     order by o.ord_dt, o.ord_hms, o.ord_no;

    v_total := v_total + sql%rowcount;
    commit;

    if mod(d + 1, 30) = 0 then
      dbms_output.put_line(to_char(d + 1) || '일 (' || v_dt || ') 까지 ORD_ITEM '
                           || to_char(v_total, 'FM999,999,999') || '건');
    end if;
  end loop;

  dbms_output.put_line('ORD_ITEM 완료: ' || to_char(v_total, 'FM999,999,999') || '건');
end;
/

alter table ord      logging;
alter table ord_item logging;

-- ===========================================================================
-- 이어서 돌리기 (중간에 끊겼을 때)
--   ORD      : 위 첫 블록의  for d in 0 .. c_days - 1  를
--              이미 들어간 일수부터 시작하도록 바꾸고 v_done 초기값을
--              select nvl(max(ord_no), 0) from ord  으로 채운다
--   ORD_ITEM : 두 번째 블록만 다시 돌리면 된다. 단
--              delete from ord_item where ord_dt >= '<끊긴 날짜>'  로 그날 치를 지우고
--              for d 범위를 그 날부터로 바꾼다
-- ===========================================================================

exit
