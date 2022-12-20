with on_demand_availability as (-- a CTE that finds if changes happened  before shift or while in shift.
								with cs_availability_update as (-- a CTE that finds gap between chef availability updates
																select 
																	cs.starts_at at time zone 'utc' at time zone 'America/New_York' as cs_start_time, -- shift start time
																	aud.auditable_id as cs_id, -- shift id
																	concat(c.first_name, ' ', c.last_name, ' ','(', c.id, ')') as chef_name_and_id,
																	aud.audited_changes as status,-- available/unavailable
																	aud.created_at at time zone 'utc' at time zone 'America/New_York' as time_of_update,-- time of status update
																	lag(aud.created_at at time zone 'utc' at time zone 'America/New_York') 
																		over (partition by aud.auditable_id 
																				order by aud.created_at at time zone 'utc' at time zone 'America/New_York') as last_update, -- time of status update before current status update
																	extract(epoch from aud.created_at at time zone 'utc' at time zone 'America/New_York' -  
																			lag(aud.created_at at time zone 'utc' at time zone 'America/New_York') 
																				over (partition by aud.auditable_id 
																				order by aud.created_at at time zone 'utc' at time zone 'America/New_York')
																			) / 60 as gap_between_updates_min, -- measures the gap between availability updates in unix epoch
																	cs.ends_at at time zone 'utc' at time zone 'America/New_York' as cs_end_time -- shift end time
																from audits aud --status updates table
																left join cooking_slots cs on cs.id = aud.auditable_id --shifts table
																left join cooks c on c.id = cs.cook_id -- chefs table
																where auditable_id in ( -- subquery to filter only changes from inactive to active
																						select auditable_id 
																						from audits 
																						where audited_changes = '{"is_available": [false, true]}'
																					)
																  and cs.starts_at at time zone 'utc' at time zone 'America/New_York' 
																  		<= 
																  		current_timestamp at time zone 'utc' at time zone 'America/New_York' -- filtering future cahnges
														  		and aud.auditable_type = 'CookingSlot' -- filtering status changes: shifts only
																order by aud.auditable_id desc, aud.created_at at time zone 'utc' at time zone 'America/New_York'  desc
																)
								select 
									csau.cs_start_time, -- shift start time
									csau.cs_id, -- shift id
									csau.chef_name_and_id, 
									csau.status, 
									csau.time_of_update, -- time of status update
									csau.last_update, -- time of update before
									case
										when csau.status = '{"is_available": [false, true]}' -- changed from inactive to active
											and csau.time_of_update >= csau.cs_start_time -- checking if happened after shift start time
										then csau.gap_between_updates_min -- then calculate the time chef being inactive
										else 0
											end as on_demand_unavailable, -- availability changes that happened while in shift
									case 
										when csau.status = '{"is_available": [false, true]}' -- changed from inactive to active
											and csau.time_of_update < csau.cs_start_time -- checking if happened before shift
										then csau.gap_between_updates_min -- then calculate the time chef being inactive
										else 0
									end as in_advance_unavailable,-- availability before shift starts
									csau.cs_end_time -- shift end time
								from cs_availability_update csau
								)
select 
	date_trunc('day', oda.cs_start_time) as day,
	oda.chef_name_and_id,
	oda.cs_id, -- shift id
	extract(epoch from oda.cs_end_time - oda.cs_start_time) / 60 / 60 as gross_duration_hrs, -- shift gross duration in hours
	sum(oda.on_demand_unavailable) as on_demand_unavailable, -- time being inactive while in shift
	((extract(epoch from oda.cs_end_time - oda.cs_start_time) / 60) - 
		sum(oda.on_demand_unavailable)) / 60 as net_duration_hrs, -- shifts net duration: gross duration - time being inactive
	sum(oda.in_advance_unavailable) as in_advance_unavailable -- time being inactive before shift
from on_demand_availability oda
where oda.status = '{"is_available": [false, true]}'
group by oda.cs_start_time, oda.chef_name_and_id, oda.cs_id, oda.cs_end_time
order by day desc