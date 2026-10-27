select *
  from (select s.shop_nm, count(*) ord_cnt
          from ord o, shop s
         where o.ord_dt between '20120301' and '20120331'
           and o.shop_no = s.shop_no
         group by s.shop_nm
         order by count(*) desc, s.shop_nm)
 where rownum <= 10
