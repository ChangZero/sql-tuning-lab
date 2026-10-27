select x.type_nm, x.item_nm, x.qty, x.rnk, x.qty_pct
  from (select c.uni_cd_nm type_nm
             , i.item_nm
             , i.item_type_cd
             , sum(oi.ord_item_qty) qty
             , rank() over (partition by i.item_type_cd order by sum(oi.ord_item_qty) desc) rnk
             , round(ratio_to_report(sum(oi.ord_item_qty)) over (partition by i.item_type_cd) * 100, 1) qty_pct
          from ord_item oi, item i, com_cd c
         where oi.ord_dt between '20120301' and '20120331'
           and oi.item_id = i.item_id
           and i.item_type_cd = c.uni_cd
         group by i.item_type_cd, c.uni_cd_nm, i.item_nm) x
 where x.rnk <= 3
 order by x.item_type_cd, x.rnk, x.item_nm
