# Resume-Queries

BI queries I made along my time in WoodSpoon:

## Chef Shift Audits:

At some point, we found that we lacking chef availability in certain days and certain hours.
As a result, WoodSpoon stated to compensate chefs for availability in weekend and rush hours.
This query made to measure chef inactivity time during and before shift, to see if chef was available to an in advance orders and compensate chefs for their net availability duration and not gross.
This query saved WoodSpoon money, because we could measure the precise amount of availability time instead of gross duration of shift time.

## Chef Sales And Percentage From Total Sales

I was asked by my COO to make a monthly KPI table, for WoodSpoon's home chefs.

She wanted to know for every month:
1. chef's avg rating.
2. working hrs.
3. sales of chef in $.
4. % of chef sales from the total sales.
5. prev month working hrs.
6. prev month % of chef sales  from prev month sales.
7.prev month avg rating.

It was challenging to deal with bringing data from multiple dates (this / prev month) to the same row in a table.
I used - interval '1 month' when left joining dates, of the same CTE.
In retrospective, I could have used also 'lag' window function instead of joining the same table on table.date - 1 month.
