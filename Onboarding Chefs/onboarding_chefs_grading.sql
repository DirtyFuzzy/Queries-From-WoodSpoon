with cs_first_cs as ( -- cte that finds first shift date for every chef
                  select cook_id, -- chef id
                  min(starts_at at time zone 'utc' at time zone 'America/New_York') as first_cs -- first shift date
    from cooking_slots cs -- shifts table
    where cs.status in (0,1,2) -- not a cancelled shift
    group by 1
),
cook_month_agg as (-- a cte that finds monthly shift duration, avg monthly menu items and monthly sales for every chef
    select 
    	date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York') as month, -- shift start date truncated to month
    	cs.cook_id, -- chef id
        sum((EXTRACT(epoch FROM cs.ends_at at time zone 'utc' at time zone 'America/New_York') -
            EXTRACT(epoch FROM cs.starts_at at time zone 'utc' at time zone 'America/New_York'))/3600) as duration, -- shift duration in unix time
        avg(cs.menu_items_count) as avg_menu_items,--avg items count on menu
        sum(cs_sales.sales_per_cs) as sales --total sales per chef in month
    from cooking_slots cs -- shifts table
    left join (-- making this subquerry in left join to find sales per shift, more eficient in runtime than join all orders table
		        select sum((o.subtotal + o.eater_service_fee
		                        + o.min_order_fee + o.delivery_fee)::numeric /100.0) as sales_per_cs, -- sales per shift in $
		            o.cooking_slot_id -- shift id
		        from orders o
		        where o.status = 2 -- finalized orders only
		        group by 2
    		) cs_sales 
    			on cs_sales.cooking_slot_id = cs.id
    where cs.status in (0,1,2) -- filtering cancelled shifts
    group by 1,2
)
select 
	cfc.first_cs as onboarding_date,
	c.id, -- chef_id
	concat(c.first_name, ' ', c.last_name) as chef_name,
	vc."name" as city,
	case
        when
            (cma1.sales >=
             (2000 *
              (1 - (date_part('days', first_cs) /
                    date_part('days', date_trunc('month', now()) + '1 mon' - '1 day'::interval)))) -- concedering that not al cefs started working in 1st of the month (sales > 200$)
             or
             (cma1.duration >=
              ((60.0 * (1 - (date_part('days', first_cs) /
                           date_part('days', date_trunc('month', now()) + '1 mon' - '1 day'::interval))))) -- concedering that not al cefs started working in 1st of the month (monthly hrs > 60)
                   and 
                   	cma1.avg_menu_items >= 8)) -- and monthly avg menu items >= 8
                   	then 'Good'  
        when
            ((cma1.sales < 2000 or cma1.sales is null) -- chef sales is null or < 200$
        and 
        	(cma1.duration < 60 or cma1.avg_menu_items < 8)) -- monthly working hours < 60 hrs or avg menu items in shift < 8
        	then 'Bad'
        else 'Absent'
    end as month_1_grade, -- onboarding month grade
    case
        when -- full 1st month of work, no need to conceder starting date.
            (cma2.sales >= 2000  -- chef sales >= 200$
            or
             (cma2.duration >= 60 and cma2.avg_menu_items >= 8) -- monthly duration >= 60 and avg menu items per shift >=8 
             ) 
             	then 'Good'
        when
            ((cma2.sales < 20000 or cma2.sales is null) -- sales is null or lower than 200$
        and
             (cma2.duration < 60 or cma2.avg_menu_items < 8)) -- monthly working hours < 60 hrs or avg menu items in shift < 8
             	then 'Bad'
        else 'Absent'
    end as month_2_grade, -- 2nd month of chef in the system
    case
        when
            (cma3.sales >= 2000 -- chef sales >= 200$
            or
             (cma3.duration >= 60 and cma3.avg_menu_items >= 8) -- monthly duration >= 60 and avg menu items per shift >=8
             ) 
             	then 'Good'
        when
            ((cma3.sales < 2000 or cma3.sales is null)  -- sales is null or lower than 200$
            and
             (cma3.duration < 60 or cma3.avg_menu_items < 8)) -- monthly working hours < 60 hrs or avg menu items in shift < 8
             	then 'Bad'
        else 'Absent'
    end as month_3_grade, -- 3rd month in system
        case
        when
            (cma4.sales >= 2000  -- chef sales >= 200$
            or
             (cma4.duration >= 60 and cma4.avg_menu_items >= 8) -- monthly duration >= 60 and avg menu items per shift >=8
             ) 
             	then 'Good'
        when
            ((cma4.sales < 2000 or cma4.sales is null)  -- sales is null or lower than 200$
            and
             (cma4.duration < 60 or cma4.avg_menu_items < 8)) -- monthly working hours < 60 hrs or avg menu items in shift < 8
             	then 'Bad'
        else 'Absent'
    end as month_4_rank, -- 4th month in system
     case
        when
            (cma5.sales >= 2000 
            or
             (cma5.duration >= 60 and cma5.avg_menu_items >= 8)
             ) 
             	then 'Good'
        when
            ((cma5.sales < 2000 or cma5.sales is null)  
            and
             (cma5.duration < 60 or cma5.avg_menu_items < 8)) 
             	then 'Bad'
        else 'Absent'
    end as month_5_grade, -- 5th month in system
     case
        when
            (cma6.sales >= 2000 
            or
             (cma6.duration >= 60 and cma6.avg_menu_items >= 8)
             )
             	then 'Good'
        when
            ((cma6.sales < 2000 or cma6.sales is null)  
            and
             (cma6.duration < 60 or cma6.avg_menu_items < 8)) 
             	then 'Bad'
        else 'Absent'
    end as month_6_grade -- 6th month in system
from cs_first_cs cfc
    left join cooks c on c.id = cfc.cook_id -- chefs table
    left join addresses a on a.owner_id = c.id and a.owner_type = 'Cook' -- addresses table
    left join vi_cities vc on vc.id = a.city_id -- cities table
	left join cook_month_agg cma1 on date_trunc('month', cfc.first_cs) = cma1.month
                and cfc.cook_id = cma1.cook_id
    left join cook_month_agg cma2 on date_trunc('month', cfc.first_cs + interval '1 month') = cma2.month -- joining the same aggregation CTE with a +1/2/3/4/5/6 month interval in matching aliases
                and cfc.cook_id = cma2.cook_id
    left join cook_month_agg cma3 on date_trunc('month', cfc.first_cs + interval '2 month') = cma3.month
                and cfc.cook_id = cma3.cook_id
    left join cook_month_agg cma4 on date_trunc('month', cfc.first_cs + interval '3 month') = cma4.month
                and cfc.cook_id = cma4.cook_id
    left join cook_month_agg cma5 on date_trunc('month', cfc.first_cs + interval '4 month') = cma5.month
                and cfc.cook_id = cma5.cook_id
    left join cook_month_agg cma6 on date_trunc('month', cfc.first_cs + interval '5 month') = cma6.month
                and cfc.cook_id = cma6.cook_id
where cfc.first_cs <= current_timestamp at time zone 'utc' at time zone 'America/New_York' -- filtering data for chefs that already made their 1st shift
order by cfc.first_cs desc -- ordering by first shift date