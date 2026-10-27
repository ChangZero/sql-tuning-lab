-- 07. 통계 수집 — dev 계정으로 실행 (06 이 끝난 뒤)
--
-- ORD_TEMP / ORD_TEMP2 는 일부러 통계를 남기지 않는다.
-- "통계 없는 테이블의 동적 샘플링" 문제의 교보재이기 때문이다.

set timing on
set serveroutput on

begin
  dbms_stats.gather_schema_stats(
      ownname          => 'DEV'
    , estimate_percent => dbms_stats.auto_sample_size
    , method_opt       => 'FOR ALL COLUMNS SIZE AUTO'
    , degree           => 4
    , granularity      => 'ALL'          -- 파티션·서브파티션 통계까지
    , cascade          => true           -- 인덱스 통계 포함
  );
end;
/

-- 통계 없는 상태로 되돌린다
begin
  dbms_stats.delete_table_stats('DEV', 'ORD_TEMP');
  dbms_stats.delete_table_stats('DEV', 'ORD_TEMP2');
end;
/

-- 수집 결과 확인
set linesize 200 pagesize 100
col table_name format a24
select table_name, num_rows, blocks, last_analyzed
  from user_tables
 order by table_name;

exit
