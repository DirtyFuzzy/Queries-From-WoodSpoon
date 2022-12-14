with total_sells_chef_month as (
select
 date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York') as month, -- chef shift start time truncated to months, using utc timezone because db located in EU
          c.id, -- chef id
          vcsac.city_name, -- chef city name
          concat(c.first_name, ' ', c.last_name) as chef_name,
          sum((o.subtotal + o.eater_service_fee + o.min_order_fee + o.delivery_fee)::numeric /100.0) as sales_per_chef, -- every chef monthly total salse
         sum(sum((o.subtotal + o.eater_service_fee + o.min_order_fee + o.delivery_fee)::numeric /100.0))
              over (PARTITION BY date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York')) as total_sales_month -- total sales of all the chefs in month
   from cooking_slots cs -- shifts table
            left join orders o on cs.id = o.cooking_slot_id and o.status = 2 -- Finalized
                --and o.eater_id not in (select * from vi_none_accountable_eater_id)
            left join cooks c on c.id = cs.cook_id
            left join vi_cooking_slots_and_cities as vcsac on vcsac.cooking_slot_id  = cs.id -- cities and chef shifts view 
   where cs.status in (0, 1, 2) -- not cancelled shift
   group by c.id, date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York'), vcsac.city_name
   order by date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York') desc, sales_per_chef desc
  ),
month_cs_duration_table as (	
select 
	date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York') as month,
	cs.cook_id, -- chef id
	sum(
		(EXTRACT(epoch FROM cs.ends_at at time zone 'utc' at time zone 'America/New_York') - 
		EXTRACT(epoch FROM cs.starts_at at time zone 'utc' at time zone 'America/New_York'))/3600
		) as month_cs_duration -- total chef working hrs in month (UNIX Epoch time)
from cooking_slots cs -- chefs shifts table
where cs.status in (0,1,2) -- not cancelled shift
group by date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York')/*month*/, cs.cook_id /*chef_id*/
),
 month_avg_rating as (
select 
	date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York') as month,
	cs.cook_id, -- chef id
	avg(or2.rating) as avg_rating_month --avg rating of chef in month
from cooking_slots as cs
left join orders as o on o.cooking_slot_id = cs.id
left join order_reviews as or2 on or2.order_id = o.id
where cs.status in (0,1,2) -- not cancelled shifts
and o.status = 2 -- finalized orders only
group by cs.cook_id, date_trunc('month', cs.starts_at at time zone 'utc' at time zone 'America/New_York')
)
select
   this_month.month as current_month,
   this_month.id as chef_id,
   this_month.chef_name as chef_name,
   this_month.city_name,
   coalesce(this_month_rating.avg_rating_month, 0) as current_month_avg_rating,
   coalesce(this_month.sales_per_chef, 0) as sales_this_month, -- chef sales this month
   coalesce(this_month.total_sales_month, 0) as total_this_month, -- total sales of all chefs
   coalesce(case
     	  	when this_month.total_sales_month = 0 then 0 --handles division by zero in case when chef didn't sold any food but has working hours
   			else this_month.sales_per_chef::numeric / this_month.total_sales_month::numeric -- chef total sales this month / total sales this month
   			end, 0) 
   					as chef_pct_in_this_month_sales, -- chef percentage from this month sales
	this_month_cs_duration.month_cs_duration as current_month_cs_duration, -- chef working hrs in current month
   prev_month.month as previous_month, --prev month date 
   coalesce(prev_month_rating.avg_rating_month, 0) as last_month_avg_rating, -- prev month chef avg rating
   coalesce(prev_month.sales_per_chef, 0) as sales_prev_month,
   coalesce(prev_month.total_sales_month, 0) as total_prev_month, -- total sales of all chefs previous month
   coalesce(case
       		when prev_month.total_sales_month = 0 then 0 --handles division by zero in case when chef didn't sold any food but has working hours
       		else prev_month.sales_per_chef::numeric / prev_month.total_sales_month::numeric -- chef total sales last month / total sales last month
   			end, 0) 
   					as chef_pct_in_prev_month_sales, -- chef percentage from last month sales
	prev_month_cs_duration.month_cs_duration as previous_month_cs_duration
from total_sells_chef_month as this_month
left join total_sells_chef_month as prev_month on
    (prev_month.month = this_month.month - interval '1 month') and -- matching on current date - 1 month
    this_month.id = prev_month.id
left join month_cs_duration_table as this_month_cs_duration on 
	(this_month_cs_duration.month = this_month.month) and 
	this_month_cs_duration.cook_id = this_month.id
left join month_cs_duration_table as prev_month_cs_duration on 
	(prev_month_cs_duration.month = this_month.month - interval '1 month') and -- matching on current date - 1 month
	prev_month_cs_duration.cook_id = prev_month.id
left join month_avg_rating as this_month_rating on 
	(this_month_rating.month = this_month.month) and
	this_month_rating.cook_id = this_month.id
left join month_avg_rating as prev_month_rating on 
	(prev_month_rating.month = this_month.month - interval '1 month') and-- matching on current date - 1 month
	prev_month_rating.cook_id = prev_month.id
order by this_month.month desc