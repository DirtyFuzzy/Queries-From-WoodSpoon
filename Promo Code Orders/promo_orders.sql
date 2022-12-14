with orders_with_rank_by_pickup as
(
   select *,
	   ROW_NUMBER() over (partition by o.eater_id order by o.pickup_at asc) as pickup_order -- numbering user's orders by date from 1 - n
   from orders o 
   where o.eater_id not in (select * from vi_none_accountable_eater_id vnaei)
   	   and delivery_status = 3  -- Delivered
),
promo_codes_to_check as 
(
	select id 
	from promo_codes pc
	where code in ('MOMLOVE', 'ATHOME', 'HUNGRY')
)
select 
	sum (
		case
			when orders_number_1.promo_code_id in (select * from promo_codes_to_check) -- subquery checking if promo code used in order
				and orders_number_1.total < 1000 -- it was basicly free (lower than 10$)
				and orders_number_2.id is null -- Making sure there isnt any second order
				then 1
				else 0
		end 
			) as count_first_with_promo_and_gone,
	sum (
		case
			when orders_number_2.promo_code_id is null or orders_number_1.total >= 1000 -- it was basicly free (lower than 10$)
				then 1
				else 0
		end
			) as count_first_with_money,
	sum (
		case
			when orders_number_1.promo_code_id in (select * from promo_codes_to_check)
				and orders_number_1.total < 1000 -- it was basicly free (lower than 10$)
				and orders_number_2.id is not null -- Making sure there is a second order 
				and (orders_number_2.promo_code_id is null
					 or orders_number_2.total >= 1000) -- but we got paid
				then 1
				else 0
		end
			) as count_first_orders_promo_and_second_money,
	sum (
			case
				when orders_number_1.promo_code_id in (select * from promo_codes_to_check)
					and orders_number_1.total < 1000 -- it was basicly free (lower than 10$)
					and orders_number_2.id is not null -- Making sure there is a second order 	
					and orders_number_2.promo_code_id in (select * from promo_codes_to_check)
					and orders_number_2.total < 1000 -- it was basicly free (lower than 10$)
					and orders_number_3.id is null -- Making sure there isnt any third order
					then 1
					else 0
			end
				) as count_first_orders_promo_and_second_promo_and_gone,
	sum (
			case
				when orders_number_1.promo_code_id in (select * from promo_codes_to_check)
					and orders_number_1.total < 1000 -- it was basicly free (lower than 10$)
					and orders_number_2.id is not null -- Making sure there is a second order 	
					and orders_number_2.promo_code_id in (select * from promo_codes_to_check)
					and orders_number_2.total < 1000 -- it was basicly free (lower than 10$)
					and orders_number_3.id is not null -- Making sure there is a third order
					and (orders_number_3.promo_code_id is null
						 or orders_number_3.total >= 1000)-- but we got paid
					then 1
					else 0
			end
				) as count_first_orders_promo_and_second_promo_and_third_money
from orders_with_rank_by_pickup as orders_number_1 -- a table for 1st orders
	left join orders_with_rank_by_pickup as orders_number_2 -- a table for 2nd orders
    	on orders_number_1.eater_id = orders_number_2.eater_id 
     	and orders_number_1.pickup_order = 1 
     	and orders_number_2.pickup_order = 2 -- validating pickup order
	left join orders_with_rank_by_pickup as orders_number_3 -- a table for 3rd orders
    	on orders_number_1.eater_id = orders_number_3.eater_id 
     	and orders_number_1.pickup_order = 1  
     	and orders_number_3.pickup_order = 3 -- validating pickup order
where orders_number_1.pickup_order = 1
	and orders_number_1.finalized_at > '2022-04-01 00:00:00.0'