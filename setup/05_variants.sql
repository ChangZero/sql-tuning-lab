-- 05. 변형 테이블 적재 — dev 계정으로 실행 (04 가 끝난 뒤)
--
--   (1) ORD_RANDOM / ORD_ITEM_RANDOM — 같은 데이터를 무작위 순서로 적재해
--       클러스터링 팩터만 다르게 만든다 (ORD 333K vs ORD_RANDOM 15M)
--   (2) ORD_RANGE / ORD_LIST / ORD_LIST_HASH — ORD_YM 을 붙여 파티션 테이블로 복제
--
-- 월 단위로 끊어서 넣는다. 15,000,000행을 한 번에 정렬하면 TEMP 가 터진다(ORA-01652).

set serveroutput on size unlimited
set timing on

alter table ord_random         nologging;
alter table ord_item_random    nologging;
alter table ord_range          nologging;
alter table ord_item_range     nologging;
alter table ord_list           nologging;
alter table ord_item_list      nologging;
alter table ord_list_hash      nologging;
alter table ord_item_list_hash nologging;

truncate table ord_random;
truncate table ord_item_random;
truncate table ord_range;
truncate table ord_item_range;
truncate table ord_list;
truncate table ord_item_list;
truncate table ord_list_hash;
truncate table ord_item_list_hash;

declare
  -- 201201 ~ 201312, 24개월
  c_months constant pls_integer := 24;
  v_ym     varchar2(6);
begin
  for m in 0 .. c_months - 1 loop
    v_ym := to_char(add_months(date '2012-01-01', m), 'yyyymm');

    -- (1) 무작위 순서 적재. ORA_HASH 로 섞으면 재현 가능한 셔플이 된다.
    --     ORDER BY 를 빼면 ORD 와 같은 순서로 들어가 CF 차이가 안 생긴다.
    insert /*+ append */ into ord_random
    select * from ord
     where ord_dt like v_ym || '%'
     order by ora_hash(ord_no, 4294967295, 7);

    insert /*+ append */ into ord_item_random
    select * from ord_item
     where ord_dt like v_ym || '%'
     order by ora_hash(ord_no, 4294967295, 7), item_id;

    -- (2) 파티션 테이블. ORD_YM 은 ORD_DT 앞 6자리
    insert /*+ append */ into ord_range
    select ord_no, substr(ord_dt, 1, 6), ord_dt, ord_hms, shop_no, upper2,
           upper_case, lower_case, alphabet, alphabet_numeric
      from ord where ord_dt like v_ym || '%';

    insert /*+ append */ into ord_item_range
    select ord_no, substr(ord_dt, 1, 6), item_id, ord_item_qty, ord_dt, ord_hms,
           upper2, upper_case, lower_case, alphabet, alphabet_numeric
      from ord_item where ord_dt like v_ym || '%';

    insert /*+ append */ into ord_list
    select ord_no, substr(ord_dt, 1, 6), ord_dt, ord_hms, shop_no, upper2,
           upper_case, lower_case, alphabet, alphabet_numeric
      from ord where ord_dt like v_ym || '%';

    insert /*+ append */ into ord_item_list
    select ord_no, substr(ord_dt, 1, 6), item_id, ord_item_qty, ord_dt, ord_hms,
           upper2, upper_case, lower_case, alphabet, alphabet_numeric
      from ord_item where ord_dt like v_ym || '%';

    insert /*+ append */ into ord_list_hash
    select ord_no, substr(ord_dt, 1, 6), ord_dt, ord_hms, shop_no, upper2,
           upper_case, lower_case, alphabet, alphabet_numeric
      from ord where ord_dt like v_ym || '%';

    insert /*+ append */ into ord_item_list_hash
    select ord_no, substr(ord_dt, 1, 6), item_id, ord_item_qty, ord_dt, ord_hms,
           upper2, upper_case, lower_case, alphabet, alphabet_numeric
      from ord_item where ord_dt like v_ym || '%';

    commit;
    dbms_output.put_line(v_ym || ' 완료');
  end loop;
end;
/

alter table ord_random         logging;
alter table ord_item_random    logging;
alter table ord_range          logging;
alter table ord_item_range     logging;
alter table ord_list           logging;
alter table ord_item_list      logging;
alter table ord_list_hash      logging;
alter table ord_item_list_hash logging;

exit
