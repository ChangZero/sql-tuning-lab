-- 02. 테이블 DDL — dev 계정으로 실행
-- 제약조건·인덱스는 여기서 만들지 않는다. 대량 적재(04·05) 를 끝낸 뒤 06 에서 한 번에 만든다.

whenever sqlerror continue
drop table ord_item_list_hash purge;
drop table ord_list_hash      purge;
drop table ord_item_list      purge;
drop table ord_list           purge;
drop table ord_item_range     purge;
drop table ord_range          purge;
drop table ord_item_random    purge;
drop table ord_random         purge;
drop table ord_temp2          purge;
drop table ord_temp           purge;
drop table ord_item           purge;
drop table ord                purge;
drop table uitem_price        purge;
drop table uitem              purge;
drop table item               purge;
drop table shop               purge;
drop table com_cd             purge;
whenever sqlerror exit failure

-- ===========================================================================
-- 1. 마스터 / 코드
-- ===========================================================================

-- 공통코드 7건. CL_UNI_CD 로 자기참조 → 계층질의(CONNECT BY) 교보재
create table com_cd (
  uni_cd      varchar2(6)   not null,
  uni_cd_nm   varchar2(100),
  cl_uni_cd   varchar2(6),
  seq         number,
  cd_desc     varchar2(500),
  reg_id      varchar2(20),
  reg_dts     date,
  mod_id      varchar2(20),
  mod_dts     date
);

-- 상품 92건
create table item (
  item_id       number       not null,
  item_nm       varchar2(100),
  item_type_cd  varchar2(6),          -- → com_cd.uni_cd
  sale_yn       varchar2(1),
  item_desc     varchar2(500),
  reg_id        varchar2(20),
  reg_dts       date,
  mod_id        varchar2(20),
  mod_dts       date
);

-- 매장 200건
create table shop (
  shop_no   varchar2(10)  not null,
  shop_nm   varchar2(100),
  addr      varchar2(300),
  tel       varchar2(20),
  reg_id    varchar2(20),
  reg_dts   date,
  mod_id    varchar2(20),
  mod_dts   date
);

-- 단위상품 130건
create table uitem (
  item_id    number        not null,
  uitem_id   number        not null,
  uitem_nm   varchar2(100),
  sale_yn    varchar2(1),
  reg_id     varchar2(20),
  reg_dts    date
);

-- 단위상품 가격이력 130건. APPLY_DT 기준 시점 조회 교보재
create table uitem_price (
  item_id    number        not null,
  uitem_id   number        not null,
  apply_dt   varchar2(8)   not null,   -- YYYYMMDD 문자열
  price      number,
  reg_id     varchar2(20),
  reg_dts    date
);

-- ===========================================================================
-- 2. 핵심 트랜잭션 테이블
--    ORD_DT / ORD_HMS 는 DATE 가 아니라 VARCHAR2 다 (묵시적 형변환 교보재)
--    ALPHABET / ALPHABET_NUMERIC 은 로우 길이를 늘려 블록당 행수를 줄이는 패딩 컬럼
-- ===========================================================================

-- 주문 15,000,000건 / 약 2.6GB. 주문일자 순으로 정렬 적재한다
create table ord (
  ord_no            number        not null,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  shop_no           varchar2(10),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
);

-- 주문상세 37,000,000건 내외 / 약 6.5GB. 주문 1건당 평균 약 2.5 상세
create table ord_item (
  ord_no            number        not null,
  item_id           number        not null,
  ord_item_qty      number,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
);

-- ===========================================================================
-- 3. 클러스터링 팩터 비교용 변형 테이블 (★ 이 스키마의 핵심 교보재)
--    ORD 와 컬럼·인덱스·건수가 완전히 동일하고 적재 순서만 무작위다.
--    ORD_X01 CF 333,388  vs  ORD_RANDOM_X01 CF 14,999,958 (45배)
-- ===========================================================================
create table ord_random      as select * from ord      where 1 = 0;
create table ord_item_random as select * from ord_item  where 1 = 0;

-- ===========================================================================
-- 4. 파티션 테이블 — 모두 ORD_YM(YYYYMM) 기준 25개 파티션
--    파티션 테이블에만 ORD_YM 컬럼이 추가되고 PK 에도 포함된다
--    24개월(201201~201312) + 넘침 파티션 1개 = 25
-- ===========================================================================

-- 4-1. RANGE
create table ord_range (
  ord_no            number        not null,
  ord_ym            varchar2(6)   not null,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  shop_no           varchar2(10),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
)
partition by range (ord_ym) (
  partition p201201 values less than ('201202'),
  partition p201202 values less than ('201203'),
  partition p201203 values less than ('201204'),
  partition p201204 values less than ('201205'),
  partition p201205 values less than ('201206'),
  partition p201206 values less than ('201207'),
  partition p201207 values less than ('201208'),
  partition p201208 values less than ('201209'),
  partition p201209 values less than ('201210'),
  partition p201210 values less than ('201211'),
  partition p201211 values less than ('201212'),
  partition p201212 values less than ('201301'),
  partition p201301 values less than ('201302'),
  partition p201302 values less than ('201303'),
  partition p201303 values less than ('201304'),
  partition p201304 values less than ('201305'),
  partition p201305 values less than ('201306'),
  partition p201306 values less than ('201307'),
  partition p201307 values less than ('201308'),
  partition p201308 values less than ('201309'),
  partition p201309 values less than ('201310'),
  partition p201310 values less than ('201311'),
  partition p201311 values less than ('201312'),
  partition p201312 values less than ('201401'),
  partition pmax    values less than (maxvalue)
);

create table ord_item_range (
  ord_no            number        not null,
  ord_ym            varchar2(6)   not null,
  item_id           number        not null,
  ord_item_qty      number,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
)
partition by range (ord_ym) (
  partition p201201 values less than ('201202'),
  partition p201202 values less than ('201203'),
  partition p201203 values less than ('201204'),
  partition p201204 values less than ('201205'),
  partition p201205 values less than ('201206'),
  partition p201206 values less than ('201207'),
  partition p201207 values less than ('201208'),
  partition p201208 values less than ('201209'),
  partition p201209 values less than ('201210'),
  partition p201210 values less than ('201211'),
  partition p201211 values less than ('201212'),
  partition p201212 values less than ('201301'),
  partition p201301 values less than ('201302'),
  partition p201302 values less than ('201303'),
  partition p201303 values less than ('201304'),
  partition p201304 values less than ('201305'),
  partition p201305 values less than ('201306'),
  partition p201306 values less than ('201307'),
  partition p201307 values less than ('201308'),
  partition p201308 values less than ('201309'),
  partition p201309 values less than ('201310'),
  partition p201310 values less than ('201311'),
  partition p201311 values less than ('201312'),
  partition p201312 values less than ('201401'),
  partition pmax    values less than (maxvalue)
);

-- 4-2. LIST
create table ord_list (
  ord_no            number        not null,
  ord_ym            varchar2(6)   not null,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  shop_no           varchar2(10),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
)
partition by list (ord_ym) (
  partition p201201 values ('201201'),
  partition p201202 values ('201202'),
  partition p201203 values ('201203'),
  partition p201204 values ('201204'),
  partition p201205 values ('201205'),
  partition p201206 values ('201206'),
  partition p201207 values ('201207'),
  partition p201208 values ('201208'),
  partition p201209 values ('201209'),
  partition p201210 values ('201210'),
  partition p201211 values ('201211'),
  partition p201212 values ('201212'),
  partition p201301 values ('201301'),
  partition p201302 values ('201302'),
  partition p201303 values ('201303'),
  partition p201304 values ('201304'),
  partition p201305 values ('201305'),
  partition p201306 values ('201306'),
  partition p201307 values ('201307'),
  partition p201308 values ('201308'),
  partition p201309 values ('201309'),
  partition p201310 values ('201310'),
  partition p201311 values ('201311'),
  partition p201312 values ('201312'),
  partition pdefault values (default)
);

create table ord_item_list (
  ord_no            number        not null,
  ord_ym            varchar2(6)   not null,
  item_id           number        not null,
  ord_item_qty      number,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
)
partition by list (ord_ym) (
  partition p201201 values ('201201'),
  partition p201202 values ('201202'),
  partition p201203 values ('201203'),
  partition p201204 values ('201204'),
  partition p201205 values ('201205'),
  partition p201206 values ('201206'),
  partition p201207 values ('201207'),
  partition p201208 values ('201208'),
  partition p201209 values ('201209'),
  partition p201210 values ('201210'),
  partition p201211 values ('201211'),
  partition p201212 values ('201212'),
  partition p201301 values ('201301'),
  partition p201302 values ('201302'),
  partition p201303 values ('201303'),
  partition p201304 values ('201304'),
  partition p201305 values ('201305'),
  partition p201306 values ('201306'),
  partition p201307 values ('201307'),
  partition p201308 values ('201308'),
  partition p201309 values ('201309'),
  partition p201310 values ('201310'),
  partition p201311 values ('201311'),
  partition p201312 values ('201312'),
  partition pdefault values (default)
);

-- 4-3. LIST + HASH 서브파티션 (파티션 와이즈 조인 교보재)
create table ord_list_hash (
  ord_no            number        not null,
  ord_ym            varchar2(6)   not null,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  shop_no           varchar2(10),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
)
partition by list (ord_ym)
subpartition by hash (ord_no) subpartitions 4 (
  partition p201201 values ('201201'),
  partition p201202 values ('201202'),
  partition p201203 values ('201203'),
  partition p201204 values ('201204'),
  partition p201205 values ('201205'),
  partition p201206 values ('201206'),
  partition p201207 values ('201207'),
  partition p201208 values ('201208'),
  partition p201209 values ('201209'),
  partition p201210 values ('201210'),
  partition p201211 values ('201211'),
  partition p201212 values ('201212'),
  partition p201301 values ('201301'),
  partition p201302 values ('201302'),
  partition p201303 values ('201303'),
  partition p201304 values ('201304'),
  partition p201305 values ('201305'),
  partition p201306 values ('201306'),
  partition p201307 values ('201307'),
  partition p201308 values ('201308'),
  partition p201309 values ('201309'),
  partition p201310 values ('201310'),
  partition p201311 values ('201311'),
  partition p201312 values ('201312'),
  partition pdefault values (default)
);

create table ord_item_list_hash (
  ord_no            number        not null,
  ord_ym            varchar2(6)   not null,
  item_id           number        not null,
  ord_item_qty      number,
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
)
partition by list (ord_ym)
subpartition by hash (ord_no) subpartitions 4 (
  partition p201201 values ('201201'),
  partition p201202 values ('201202'),
  partition p201203 values ('201203'),
  partition p201204 values ('201204'),
  partition p201205 values ('201205'),
  partition p201206 values ('201206'),
  partition p201207 values ('201207'),
  partition p201208 values ('201208'),
  partition p201209 values ('201209'),
  partition p201210 values ('201210'),
  partition p201211 values ('201211'),
  partition p201212 values ('201212'),
  partition p201301 values ('201301'),
  partition p201302 values ('201302'),
  partition p201303 values ('201303'),
  partition p201304 values ('201304'),
  partition p201305 values ('201305'),
  partition p201306 values ('201306'),
  partition p201307 values ('201307'),
  partition p201308 values ('201308'),
  partition p201309 values ('201309'),
  partition p201310 values ('201310'),
  partition p201311 values ('201311'),
  partition p201312 values ('201312'),
  partition pdefault values (default)
);

-- ===========================================================================
-- 5. 통계 없는 상태 실험용 (동적 샘플링 관찰). ORD_NO 가 없고, 비워 둔다.
--    07 의 통계수집에서 제외한다
-- ===========================================================================
create table ord_temp (
  ord_dt            varchar2(8),
  ord_hms           varchar2(6),
  shop_no           varchar2(10),
  upper2            varchar2(2),
  upper_case        varchar2(10),
  lower_case        varchar2(10),
  alphabet          varchar2(400),
  alphabet_numeric  varchar2(400)
);

create table ord_temp2 as select * from ord_temp where 1 = 0;

exit
