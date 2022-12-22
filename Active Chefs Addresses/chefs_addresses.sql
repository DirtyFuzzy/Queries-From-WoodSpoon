/*
 I wrote this JS script to show the 'chef_id' & 'chef_name' in Superset's 'Java Script Tooltip Generator':
 d => `
<div>id: <srtong>${d.object.extraProps.chef_id}</strong></div>
<div>name: <srtong>${d.object.extraProps.chef_name}</strong></div>` 
 */
select 
	date_trunc('day', cs.starts_at) as day, -- day of shift
	c.id as chef_id,
	concat(c.first_name, ' ', c.last_name) as chef_name,
	a.lat as latitude, -- kitchen lat
	a.lng as longtitude -- kitchen lng
from cooks c -- chefs table
	left join cooking_slots cs on cs.cook_id = c.id	  -- shifts table
	left join addresses a on a.owner_id = c.id and a.owner_type = 'Cook' -- addresses table
where cs.status in (0,1,2) -- filtering cancelled shifts
	and date_trunc('week', cs.starts_at) <= date_trunc('week', current_timestamp) -- filtering future shifts
group by 1,2,4,5
order by 1 desc