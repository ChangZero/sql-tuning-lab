-- 01. dev 스키마(계정) 생성 — 이미 dev 계정이 있으면 이 파일은 건너뛴다
-- 실행: DBA 권한 계정으로 대상 PDB 에 접속해서 돌린다

-- 기존 스키마 정리 (처음 설치면 에러 무시)
whenever sqlerror continue
drop user dev cascade;
whenever sqlerror exit failure

create user dev identified by "1234"
  default tablespace users
  temporary tablespace temp
  quota unlimited on users;

grant create session, create table, create view, create sequence to dev;

-- 실행계획 실측(DBMS_XPLAN.DISPLAY_CURSOR) 과 딕셔너리 조회에 필요
grant select any dictionary to dev;
grant select any table      to dev;
grant advisor               to dev;
grant alter session         to dev;

-- 용량 요구사항 (02~05 를 끝까지 돌리면)
--   USERS  : 약 60GB  (ORD/ORD_ITEM 과 RANDOM·파티션 복제본까지)
--   TEMP   : 약 16GB  (05 의 ORD_RANDOM 적재 때 15,000,000 행 정렬)
-- 둘 중 하나라도 부족하면 05 단계에서 ORA-01652 / ORA-01653 로 멈춘다

exit
