-- DINERS RANK BY MONTH C2B--
select 
	m.cal_month,
	m.eater_id,
	m.company_name,
	case 
		when 
				(
					num_orders > 0 -- ordered in current month 
					and month1 is null -- orders count doesn't exist in previous months
					and month2 is null 
					and month3 is null
				)
			or 
				(
					num_orders > 0 -- ordered in current month
					and month1 = 0 -- user created last month but didn't ordered
					and month2 is null -- orders count doesn't exist in previous months
					and month3 is null
				)
			or 
				(
					num_orders > 0 -- ordered in current month
					and month1 = 0 -- user created but didn't ordered
					and month2 = 0 -- user created but didn't ordered
					and month3 is null -- orders count doesn't exist
				)
			or 
				(
					num_orders > 0 -- ordered in current month
					and month1 = 0 -- user created but didn't ordered
					and month2 = 0 -- user created but didn't ordered
					and month3 = 0 -- user created but didn't ordered
					and month4 is null -- orders count doesn't exist
				)
					then 'new diner'
		when 
				(
					num_orders > 0 and num_orders < 4 -- current month orders count between 1-3
					and month1 > 0 -- did ordered last month
				)
			or 
				(
					num_orders > 0 and num_orders < 4 -- current month orders count between 1-3
					and month1 = 0 -- didnt ordered last month
					and month2 > 0 -- ordered 2 months ago
				)
			or 
				(
					num_orders > 0 and num_orders < 4 -- current month orders count between 1-3
					and month1 = 0 -- didnt ordered last month
					and month2 = 0 -- didnt ordered 2 months ago
					and month3 > 0 -- ordered 3 months ago
				)
			or 
				(
					num_orders > 0 and num_orders < 4  -- current month orders count between 1-3
					and month1 = 0 -- didnt ordered last month
					and month2 = 0 -- didnt ordered 2 months ago
					and month3 = 0 -- didnt ordered 3 months ago
					and month4 > 0 -- ordered 4 months ago
				)
					then 'regular diner'
		when 
				(
					num_orders >= 4 -- current month orders is 4 or higher
					and month1 > 0 -- oedered last month
				)
			or 
				(
					num_orders >= 4 -- current month orders is 4 or higher
					and month1 = 0 -- didnt order last month 
					and month2 > 0 -- ordered 2 months ago
				)
			or 
				(
					num_orders >= 4 -- current month orders is 4 or higher
					and month1 = 0 -- didnt order last month
				 	and month2 = 0 -- didnt order 2 months ago
				 	and month3 > 0 -- ordered 3 months ago
			 	)
			or 
				(
					num_orders >= 4 -- current month orders is 4 or higher
					and month1 = 0 -- didnt order last month
					and month2 = 0 -- didnt order 2 months ago
					and month3 = 0 -- didnt order 3 months ago
					and month4 > 0 -- ordered 4 months ago
				)
					then 'super diner'
		when 
				(
					num_orders = 0 -- no orders in current month
					and month1 > 0 -- did ordered last month
				)
			or 
				(
					num_orders = 0 -- user created in current month, didnt order
					and month1 is null  -- orders count doesn't exist in previous months
					and month2 is null 
					and month3 is null
				)
					then 'absent 1 month'
		when 
				(
					num_orders = 0 -- didnt order current month 
					and month1 = 0 -- didnt order last month
					and month2 > 0 -- ordered 2 months ago
				)
			or 
				(
					num_orders = 0 -- didnt order current month	 
					and month1 = 0 -- didnt order last month (user creatoin month)
					and month2 is null  -- orders count doesn't exist in previous months
					and month3 is null
				)
					then 'absent 2 months'
		when 
				(
					num_orders = 0 
					and month1 = 0 
					and month2 = 0 
					and month3 > 0
				)
			or 
				(
					num_orders = 0 
					and month1 = 0 
					and month2 = 0 
					and month3 is null
				)
			then 'absent 3 months'
		when 
			(
				num_orders = 0 -- user didnt order for whole 4 months
				and month1 = 0 
				and month2 = 0 
				and month3 = 0
			)
				then 'churned diner'
		when 
			(
				num_orders > 0 -- ordered current month
				and month1 = 0 -- didnt ordered 4 months before, basically got back from being churned
				and month2 = 0 
				and month3 = 0 
				and month4 = 0
			)
				then 'revived diner'
	else 'other' 
		end as diner_rank
from (with cal_month as ( -- generating months, we dont want to relay on user creation and delivery dates only
							select 
							generate_series(
											 DATE '2019-10-01',
									 current_timestamp,
									 interval '1 month'
									) as cal_month
				)
		select c.cal_month, -- calendar month
			   e.id as eater_id, 
			   e.company_name,
			   count(distinct o.id) as num_orders, -- orders count for current month
			   lag(count(distinct o.id)) over (partition by e.id order by c.cal_month) as month1, -- orders count month before 
			   lag(count(distinct o.id),2) over (partition by e.id order by c.cal_month) as month2, -- orders count 2 months before 
			   lag(count(distinct o.id),3) over (partition by e.id order by c.cal_month) as month3, -- orders count 3 months before
			   lag(count(distinct o.id),4) over (partition by e.id order by c.cal_month) as month4 -- orders count 4 months before
		from (
				cal_month c 
				left join eaters e on c.cal_month >= date_trunc('month', e.created_at) -- calndar month is equal or greater than user creation date, finds all eaters no matter if they ordered or not
				and e.account_status = 1 -- active accounts only
			)
		left join orders o on date_trunc('month', o.delivery_delivered_at) = c.cal_month -- matching calendar date with delivered order date truncated to month
			and o.eater_id = e.id  
				where e.id in (select distinct o.eater_id from orders o where o.delivery_status = 3) -- delivered orders only
				 	  and e.id not in (select * from vi_none_accountable_eater_id) -- not a staff order
				 	  and e.id in (select distinct o2.eater_id from orders o2 where o2.order_type = 'business') -- b2b orders only
				group by c.cal_month, e.id
	) as m