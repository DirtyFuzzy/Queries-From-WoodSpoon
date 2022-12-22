# Resume-Queries

BI queries I made along my time in WoodSpoon.
Sensitive data (ie chefs names, sales, etc) was blanked out. 

## Active Chefs Addresses
 Our chef operations manager asked the BE engineers if they can build her a tool that will show active chef addresses on a map.
I was tagged in the thread by the BE tech lead, he asked if it could be done in Superset, to save some develop time.
Gladly, I stood up the challenge and found out it will be pretty easy, deck.gl maps pack for Superset will do most of the job.
This query saved lots of dev time and also time for the chef operations manager, that until then updated the addresses manually.
To present the chef id and name in the tooltip, I used This JS code:
<pre><code> d => `
 <div>id: <srtong>${d.object.extraProps.chef_id}</strong></div>
<div>name: <srtong>${d.object.extraProps.chef_name}</strong></div>`</code></pre>

#### The result on Superset:

<img width="1439" alt="Screen Shot 2022-12-22 at 15 28 24" src="https://user-images.githubusercontent.com/105126311/209160974-7e9cc62d-726a-4cae-8d61-0b6d240700d1.png">

## Chef Shift Audits

At some point, we found that we lacking chef availability in certain days and certain hours.
As a result, WoodSpoon stated to compensate chefs for availability in weekend and rush hours.
This query made to measure chef inactivity time during and before shift, to see if chef was available to an in advance orders and compensate chefs for their net availability duration and not gross.
This query saved WoodSpoon money, because we could measure the precise amount of availability time instead of gross duration of shift time.

#### The result on Superset:

<img width="1387" alt="Screen Shot 2022-12-22 at 15 25 03" src="https://user-images.githubusercontent.com/105126311/209171045-c60817ad-98e3-4c5b-bf99-2657f818369e.png">

## Chef Sales And Percentage From Total Sales

I was asked by my COO to make a monthly KPI table, for WoodSpoon's home chefs.

She wanted to know for every month:
- chef's avg rating.
- working hrs.
- sales of chef in $.
- % of chef sales from the total sales.
- prev month working hrs.
- prev month % of chef sales  from prev month sales.
- prev month avg rating.

It was challenging to deal with bringing data from multiple dates (this / prev month) to the same row in a table.
I used - interval '1 month' when left joining dates, of the same CTE.
In retrospective, I could have used also 'lag' window function instead of joining the same table on table.date - 1 month.

#### The result on Superset:

<img width="1386" alt="Screen Shot 2022-12-22 at 15 23 41" src="https://user-images.githubusercontent.com/105126311/209166613-c2d90b6f-811e-4155-baef-a16206c81f05.png">
<img width="1383" alt="Screen Shot 2022-12-22 at 15 22 28" src="https://user-images.githubusercontent.com/105126311/209170076-ff0d5f5f-cd97-4d66-90eb-e044e093f261.png">
<img width="1379" alt="Screen Shot 2022-12-22 at 15 23 07" src="https://user-images.githubusercontent.com/105126311/209170145-161efa57-29c5-4778-8d09-b894b20af767.png">


## Onboarding Chefs Grades
In a meeting with my COO i was told that we don't have enough data on chefs that starting their way in WoodSpoon.
She would like to keep track on new chefs KPIs in their first 6 months in WoodSpoon.
Therefore I designed this table to show chefs grades (good/bad/absent) by their onboarding date.
every column next to chef name showing its grade in the following month.
In this case i used left join +1/2/3/4/5/6 month interval.
In retrospective, I  think using a 'LEAD' window function will be more efficient than joining the same CTE with + month intervals.

#### The result on Superset:

<img width="1382" alt="Screen Shot 2022-12-22 at 15 18 26" src="https://user-images.githubusercontent.com/105126311/209168359-80893105-abba-43a5-9c1d-f5a9f64cc3d8.png">

## Promo Code Orders
In one of my first months in WoodSpoon, we had a massive user growth due to new promotional code that was given free to new users on their first couple of orders.

My CTO asked me to build a simple, All Time 'Big Number' chart for every count:

- users that ordered 1st order with pc (promo code) and then gone.
- users that their 1st order is without  any pc.
- users that used pc in 1st order and then ordered without any pc.
- users that ordered 1st&2nd order with pc and then gone.
- users that ordered 1st&2nd order with pc and then placed 3rd order with real money.

It was my first query using window functions and multiple joins and CTEs. In this case ROW_NUMBER, for numbering user's orders by date in ascending numbers from 1-n.

In the end every column in this table was visualized as a 'Big Number' chart on WoodSpoons Apache SuperSet.

#### The result on Superset:

<img width="1166" alt="Screen Shot 2022-12-21 at 16 17 45" src="https://user-images.githubusercontent.com/105126311/209169497-d647ff8f-2819-41b1-bfd7-3b0321c629f1.png">
