-- 06. 제약조건·인덱스 생성 — dev 계정으로 실행 (04·05 적재가 끝난 뒤)
--
-- ★ 마지막에 반드시 NOPARALLEL 로 되돌린다.
--   인덱스를 PARALLEL 속성이 남은 채로 두면 이후 모든 문제에서 옵티마이저가
--   제멋대로 병렬 계획을 고른다 (docs/TUNING-PLAYBOOK.md "병렬은 기본적으로 끈다")

set timing on

-- ===========================================================================
-- 마스터
-- ===========================================================================
alter table com_cd      add constraint com_cd_pk      primary key (uni_cd);
alter table item        add constraint item_pk        primary key (item_id);
alter table shop        add constraint shop_pk        primary key (shop_no);
alter table uitem       add constraint uitem_pk       primary key (item_id, uitem_id);
alter table uitem_price add constraint uitem_price_pk primary key (item_id, uitem_id, apply_dt);

-- ===========================================================================
-- ORD / ORD_ITEM
-- ===========================================================================
create unique index ord_pk on ord (ord_no) parallel 4 nologging;
alter table ord add constraint ord_pk primary key (ord_no) using index ord_pk;
create index ord_x01 on ord (ord_dt, ord_hms) parallel 4 nologging;

create unique index ord_item_pk on ord_item (ord_no, item_id) parallel 4 nologging;
alter table ord_item add constraint ord_item_pk primary key (ord_no, item_id) using index ord_item_pk;
create index ord_item_x01 on ord_item (ord_dt, ord_hms) parallel 4 nologging;

-- ===========================================================================
-- RANDOM 쌍 — 컬럼 구성이 ORD 쪽과 완전히 동일해야 CF 비교가 성립한다
-- ===========================================================================
create unique index ord_random_pk on ord_random (ord_no) parallel 4 nologging;
alter table ord_random add constraint ord_random_pk primary key (ord_no) using index ord_random_pk;
create index ord_random_x01 on ord_random (ord_dt, ord_hms) parallel 4 nologging;

create unique index ord_item_random_pk on ord_item_random (ord_no, item_id) parallel 4 nologging;
alter table ord_item_random add constraint ord_item_random_pk primary key (ord_no, item_id) using index ord_item_random_pk;
create index ord_item_random_x01 on ord_item_random (ord_dt, ord_hms) parallel 4 nologging;

-- ===========================================================================
-- 파티션 테이블 — 전부 로컬 파티션 인덱스
--   PK 에 파티션 키(ORD_YM)가 들어가야 UNIQUE 로컬 인덱스를 만들 수 있다
-- ===========================================================================
alter table ord_range add constraint ord_range_pk primary key (ord_no, ord_ym)
  using index local;
create index ord_range_x01 on ord_range (ord_dt, ord_hms) local parallel 4 nologging;

alter table ord_item_range add constraint ord_item_range_pk primary key (ord_no, ord_ym, item_id)
  using index local;
create index ord_item_range_x01 on ord_item_range (ord_dt, ord_hms) local parallel 4 nologging;

alter table ord_list add constraint ord_list_pk primary key (ord_no, ord_ym)
  using index local;
create index ord_list_x01 on ord_list (ord_dt, ord_hms) local parallel 4 nologging;

alter table ord_item_list add constraint ord_item_list_pk primary key (ord_no, ord_ym, item_id)
  using index local;
create index ord_item_list_x01 on ord_item_list (ord_dt, ord_hms) local parallel 4 nologging;

alter table ord_list_hash add constraint ord_list_hash_pk primary key (ord_no, ord_ym)
  using index local;
create index ord_list_hash_x01 on ord_list_hash (ord_dt, ord_hms) local parallel 4 nologging;

alter table ord_item_list_hash add constraint ord_item_list_hash_pk primary key (ord_no, ord_ym, item_id)
  using index local;
create index ord_item_list_hash_x01 on ord_item_list_hash (ord_dt, ord_hms) local parallel 4 nologging;

-- ===========================================================================
-- ★ 병렬 속성 해제 (이거 빼먹으면 이후 실행계획이 전부 틀어진다)
-- ===========================================================================
alter index ord_pk                 noparallel;
alter index ord_x01                noparallel;
alter index ord_item_pk            noparallel;
alter index ord_item_x01           noparallel;
alter index ord_random_pk          noparallel;
alter index ord_random_x01         noparallel;
alter index ord_item_random_pk     noparallel;
alter index ord_item_random_x01    noparallel;
alter index ord_range_x01          noparallel;
alter index ord_item_range_x01     noparallel;
alter index ord_list_x01           noparallel;
alter index ord_item_list_x01      noparallel;
alter index ord_list_hash_x01      noparallel;
alter index ord_item_list_hash_x01 noparallel;

alter table ord                noparallel;
alter table ord_item           noparallel;
alter table ord_random         noparallel;
alter table ord_item_random    noparallel;
alter table ord_range          noparallel;
alter table ord_item_range     noparallel;
alter table ord_list           noparallel;
alter table ord_item_list      noparallel;
alter table ord_list_hash      noparallel;
alter table ord_item_list_hash noparallel;

exit
