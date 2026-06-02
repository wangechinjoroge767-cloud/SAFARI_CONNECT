# SAFARI_CONNECT
project 2
### data cleaning with power BI ###
  1) managed to remove duplicates (just 1) from 290 to 289 - booking_Id
  2) cleaned and standardized names by converting them to proper case and removing inconsistencies in capitalizations
  3) the raw dataset contained inconsistent phone number entries(2578297365, 07-3728-826, missing data(null values) - converted to text to remove the 0 and + , Next ,trim and clean (invisible spaces and characters that break text-matching rules).
     To fix the prefixes without creating step-by-step dependency errors, a single Custom Column was engineered using advanced M-code conditional logic:
     the Null Safe-Guard: The code first checks if a cell is null or completely empty (""). If it is, it leaves it alone. This successfully stopped the 4% error rate we initially encountered when trying to measure the length of non-existent text.
     The "+254" Pass: If the number already starts correctly with +254, the formula skips it and leaves it untouched.The "254" Fix: If a number starts with 254 but misses the plus sign, the formula concatenates a + to the front ("+" & CleanText).
     the Leading Zero "0" Strip: If a number starts with a local 0, the formula drops that single first character using Text.End() and seamlessly grafts +254 onto the remaining string.
     the Raw "7" or "1" Inject: For numbers starting directly with the provider prefix (like 7... or 1... for Safaricom/Airtel), the formula directly prepends +254 to standardise the length.
     perfectly standardized all phone records into a uniform and recognized string.

     4)Fare had a mix of plain numbers and text (ksh) . stripped the ksh(replace value) remained with plain numbers.
     Trimmed tto cutt out spaces at the beginning/end of the numbers..
     changed the data type from Text to decimal, currency - ksh

     5)Gender column -had mixed ways male,female,F,M,Male,Female
     capitalised each worf to fix the casing
     replaced value to change the single letters to full words ,advanced option -match entire cells content box so that power query only changes the single letter without breaking the existing words
     
=====================================================================================================================================

####DATABASE SET UP (POSTGRES + DBEAVER)
   ## SCHEMA CREATION
      created a schema to organize all safari connect data 
      Created table safari_connect_clean with proper data types:
        booking_id (VARCHAR) — primary key
        passenger_name, passenger_phone, passenger_gender, passenger_city (VARCHAR)
        route_code, route_from, route_to (VARCHAR)
        vehicle_plate, vehicle_type (VARCHAR)
        driver_name, driver_rating (NUMERIC)
        departure_date, departure_time (VARCHAR, cast to DATE/TIME for queries)
        seat_class, seats_booked (VARCHAR, INTEGER when cast)
        fare_per_seat, total_fare (VARCHAR, NUMERIC when cast)
        payment_method, booking_status, trip_rating (VARCHAR)
        custom_phone (VARCHAR)
Data Import
Imported 289 rows of cleaned CSV into PostgreSQL using DBeaver's Import Data tool.
select count(*) from safari_connect_clean.safari_connect_clean;
-- Result: 289 rows 

===========================================================================================================================================

##VIEW CREATION

  Created a filtered view containing only Completed bookings (254 out of 289 total).
What It Includes
All booking details (passenger, route, vehicle, driver, fare info)
Derived Columns:
day_of_week — extracted from departure_date using TO_CHAR()
satisfaction_level — categorized based on trip_rating:
≥4.5 = 'Satisfied'
≥3.5 = 'Neutral'
0 = 'Unsatisfied'
No rating = 'No Rating'

============================================================================================================================================

###BUSINESS ANALYSIS###

Question 1: Route Performance Analysis
Business Objective
Analyze route profitability, efficiency, and market concentration. Identify which routes drive revenue, which are most efficient, and how business is distributed across routes.
Technical Setup: Data Cleaning Functions
Why regexp_replace()?
CSV data stored currency values as TEXT (e.g., "KES 1200") instead of numbers. Cannot perform calculations on text with special characters.
regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric does:
Find all characters that match [^0-9.] (anything NOT a digit or period)
Delete them (replace with empty string '')
Convert result to numeric for calculations
Example: "KES 1200.50" → "1200.50" → 1200.50 (number)
Understanding [^0-9.]
[^...] = NOT/negate (match opposite)
0-9 = digits
. = decimal point
So [^0-9.] = "anything that is NOT a digit or decimal point"
Example:
Input: "KES 1200.50"
Matched characters (deleted): K, E, S, space
Kept characters: 1, 2, 0, 0, ., 5, 0
Output: "1200.50" 
The period is kept because fares have decimals. Without it, "1200.50" becomes "120050" (wrong!).
Why nullif()?
Prevents division by zero errors. If a route has 0 seats booked:
nullif(sum(seats_booked::integer), 0) returns NULL if seats = 0, otherwise returns the actual number.

===========================================================================================================================

1A: Revenue & Bookings by Route

What it shows: Total bookings, passengers, and revenue per route.

Key Results:
| Route | Bookings | Seats | Revenue | Avg Fare | Rating |
|---|---|---|---|---|---|
| RT001 (Nairobi → Mombasa) | 26 | 41 | KES 51,600 | 1,292 | 4.2 |
| RT004 (Nairobi → Eldoret) | 27 | 51 | KES 43,200 | 889 | 3.8 |
| RT008 (Kisumu → Kakamega) | 25 | 38 | KES 7,470 | 205 | 3.1 |
Business Insight: RT001 dominates revenue. Routes with high ratings (4+) are performing well.

===========================================================================================================================

1B: Revenue Per Seat (Efficiency)

What it shows: Which routes earn MOST per passenger (profit efficiency).

Key Results:
| Route | Revenue | Seats | Revenue/Seat | Type |
|---|---|---|---|---|
| RT001 | KES 51,600 | 41 | KES 1,258 | Premium |
| RT004 | KES 43,200 | 51 | KES 847 | Standard |
| RT008 | KES 7,470 | 38 | KES 197 | Budget |
Business Insight: Premium routes (KES 1,000+/seat) maintain quality. Budget routes (KES 100-300/seat) use volume strategy.

======================================================================================================================

1C: Route Ranking with Window Functions

What it shows: Route rankings by revenue + percentage of total company revenue.

Key Results:
| Rank | Route | Revenue | % of Total |
|---|---|---|---|
| 1 | RT001 | KES 51,600 | 18.45% |
| 2 | RT004 | KES 43,200 | 15.48% |
| 3 | RT002 | KES 15,120 | 5.41% |
Business Insight: Top 3 routes = 39% of revenue. High concentration = risk. Need to grow weaker routes.
Technical: Uses CTEs (WITH clauses) and RANK() window function for ranking without collapsing data.

=======================================================================================================================

1D: Vehicle Type Performance

What it shows: Bus vs Matatu vs Minibus — which vehicle type is most profitable?
Key Results:
| Vehicle Type | Bookings | Seats | Revenue | Rating |
|---|---|---|---|---|
| Matatu | 97 | 164 | KES 87,925 | 3.48 |
| Bus | 80 | 142 | KES 75,000 | 3.65 |
| Minibus | 77 | 140 | KES 68,200 | 3.52 |
Business Insight: Matatu highest volume + revenue. Bus highest passenger satisfaction. Consider expanding Matatu fleet.

====================================================================================================

###DRIVER PERFOMANCE###

  --DRIVER SUMMARY--

  The Operations Director wants to know: Which drivers bring in the most revenue? Do high-revenue drivers also satisfy passengers? Who should we promote?
The Data We Need:
How many trips each driver completed
Total passengers they carried
How much revenue they generated
What passengers thought of them (rating)
What the platform rated them

Why We Built It This Way:
GROUP BY driver_name — Why?
One driver completes many trips across many routes
We need to collapse all their trips into ONE ROW per driver
Without GROUP BY, we'd have 254 rows (one per trip), not 30 rows (one per driver)
COUNT(*) as total_trips — Why COUNT and not SUM?
     We're counting TRIPS, not a numeric column
     Each row = one trip, so counting rows = counting trips
       If we used SUM(), we'd need a numeric column

SUM(seats_booked::integer) as total_seats_carried — Why SUM?
                 seats_booked is a NUMBER (how many passengers booked that trip)
                 We want TOTAL passengers across all trips
                 SUM() adds them up: Trip1 (2 seats) + Trip2 (3 seats) = 5 total
                 If we used AVG(), we'd get 2.5 (average per trip), not total
SUM(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_revenue — Why all these steps?
                Data comes in as "KES 1200" (TEXT with currency symbol)
                regexp_replace() removes "KES " → "1200"
                ::numeric converts TEXT "1200" to NUMBER 1200
                SUM() adds all revenue: 1200 + 800 + 500 = 2500
                Why not just SUM(total_fare)? Can't do math on TEXT with special characters
ROUND(AVG(trip_rating::numeric), 2) as avg_passenger_rating — Why AVG not SUM?
                  Ratings are 1-5 (e.g., 4.2, 3.8, 4.5)
                  We want AVERAGE rating (passenger satisfaction), not total
                  Summing would give 12.5 (meaningless)
                  Averaging gives 4.17/5 (meaningful satisfaction metric)
                  ROUND(..., 2) rounds to 2 decimals for readability
ORDER BY total_revenue DESC — Why DESC not ASC?
                    We want top earners FIRST (most profitable drivers on top)
                    DESC = descending (highest to lowest)
                    If we used ASC, lowest earners appear first (wrong for this question)

What We DON'T Do and Why:
                    Why no WHERE clause?
                    We want ALL drivers, not filtered ones
                    If we added WHERE total_revenue > 50000, we'd lose underperformers to coach

Why no LIMIT?
                  We want the complete picture of all 30 drivers
                  We'll analyze the top 5 separately if needed

Why no HAVING?
                We're not filtering aggregated results
                We want every driver regardless of metrics

=======================================================================

2B: Driver Ranking (Overall + by Vehicle Type)

What We're Looking For:

How do drivers rank against EACH OTHER (overall)? AND how do they rank within their vehicle type (fairness)?

The Data We Need:
          Driver name, vehicle type, trips, revenue, rating
          Rank #1 to #30 overall
          Rank #1 to #10 among Matatu drivers, #1 to #8 among Bus drivers, etc.
          
Why We Built It This Way:
          WITH driver_totals AS (...) — Why use a CTE?
          We need TWO different rankings on the same data
          CTE lets us calculate trips, revenue, avg_rating ONCE
          Then use that result twice (for overall + by vehicle type)
          Without CTE, we'd calculate the same metrics twice (slower, repetitive)
          
RANK() OVER (ORDER BY revenue DESC) as overall_rank — Why RANK and not ROW_NUMBER?
          RANK() assigns same rank to ties (if two drivers have same revenue = both #1)
          ROW_NUMBER() gives sequential numbers (first gets #1, second gets #2, even if tied)
          We chose RANK because revenue might have ties
          
RANK() OVER (PARTITION BY vehicle_type ORDER BY revenue DESC) as rank_within_vehicle_type — Why PARTITION?
            Without PARTITION BY, one RANK() ranking covers all 30 drivers (#1-#30)
            With PARTITION BY vehicle_type, ranking resets per vehicle:
            Matatu drivers: #1, #2, #3... (only against other Matatus)
            Bus drivers: #1, #2, #3... (only against other Buses)
            Minibus drivers: #1, #2, #3... (only against other Minibuses)
            
Why? Fair comparison. A KES 50k Matatu driver might be #1 among Matatus, not #1 overall.
GROUP BY driver_name, vehicle_type — Why both columns?
              Drivers stay in same vehicle type throughout dataset
              Grouping by both ensures we get vehicle type in results
              Can't use just GROUP BY driver_name — SQL would complain (vehicle_type not in GROUP BY)
ORDER BY overall_rank — Why order by rank, not revenue?
              Makes results easier to read (rank 1, 2, 3... in order)
              User can scan top-to-bottom to find their rank
              If we ordered by revenue, same information but not as clean visually
              
==========================================================================================================

2C: Does Driver Rating Predict Passenger Satisfaction?

What We're Looking For:

HR wants proof: Are highly-rated drivers (≥4.5) getting BETTER passenger satisfaction than standard drivers? Should we use driver rating as a hiring criteria?
The Data We Need:
            Categorize drivers into "High-Rated" (≥4.5) and "Standard" (<4.5)
            For each category: average driver rating, average passenger rating, number of trips
            Compare the two groups statistically
            
Why We Built It This Way:
          CASE WHEN avg(driver_rating::numeric) >= 4.5 THEN 'High-Rated Driver' ELSE 'Standard Driver' END — Why CASE WHEN?
          Driver ratings are continuous (4.2, 4.5, 4.8)
          We NEED to bucket them into 2 groups for comparison
          CASE WHEN is the SQL tool for conditional categorization
          Why not IF()? PostgreSQL doesn't have IF(), uses CASE WHEN
          Why not WHERE clauses? Would remove data; CASE keeps all rows with labels

WITH driver_satisfaction AS (...) — Why CTE?
          Calculation is complex: categorize, calculate avg ratings per driver
          CTE isolates this logic
          Main SELECT then groups by category
          Easier to read and debug
          
GROUP BY driver_category — Why this, not driver_name?
          We're comparing GROUPS (High-Rated vs Standard), not individual drivers
          GROUP BY driver_category collapses 30 drivers into 2 groups
          Then AVG(avg_passenger_rating) shows average satisfaction per group
          If we grouped by driver_name, we'd get 30 rows (back to individual level)
          
ROUND(AVG(avg_passenger_rating), 2) as group_avg_passenger_rating — Why AVG of an AVG?
          Inner query calculates avg_passenger_rating PER DRIVER (e.g., 3.92, 3.88, 4.05)
          Outer AVG() averages those per-driver averages across the group
          Why nested averages? Each driver's satisfaction is equally weighted (not biased toward drivers with many trips)
          
SUM(trips) as total_trips — Why SUM?
          Each driver's trips is a number
          We want TOTAL trips across all drivers in that category
          SUM() adds them: Driver1 (25 trips) + Driver2 (30 trips) = 55 total
          
ORDER BY group_avg_driver_rating DESC — Why this order?
          Shows High-Rated drivers first (naturally, since ≥4.5 > <4.5)
          Director can immediately see: "High-rated drivers get 4.2 avg satisfaction, standard get 3.5"
          Proves or disproves the hypothesis
          
=============================================================

###REVENUE TRENDS###

3A:monthly revenue with month-over-month change

what we are looking for:
finance whats to know :is revenue growing month-to-month? which months are weak? where's the growth/decline?

the data we need :
      revenue for each monh separately
      previous month's revenue(to compare)
      difference in KES and percenatage
why we built  it this way:
DATE_TRUNC('month', departure_date::date)::date as month — Why this complex expression?
      departure_date is stored as TEXT (from CSV)
      ::date converts TEXT to DATE type
      DATE_TRUNC('month', ...) extracts JUST the month part (zeroes out day)
      ::date converts back to DATE for clean display
      Why not just departure_date? Would group by exact date (2024-01-05, 2024-01-06 separate), not by month
SUM(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as monthly_revenue — Why SUM and regexp_replace?
      Multiple bookings per month, each with "KES xxxx" format
      regexp_replace() removes currency → number
      SUM() totals all bookings in that month
      Why not AVG? We want TOTAL revenue per month, not average
WITH monthly_revenue AS (...) — Why CTE?
            We need the monthly totals to reference TWICE:
            Main SELECT uses them directly
            LAG() window function references them
            CTE calculates once, uses twice
            Without CTE, would need subquery duplication
LAG(monthly_revenue) OVER (ORDER BY month) — Why LAG and not a JOIN?
        LAG() automatically looks at previous row's value
        Simpler than: LEFT JOIN table AS prev ON current.month = DATE_ADD(prev.month, INTERVAL 1 MONTH)
        Why window function over self-join? Cleaner, faster, one line of code
ROUND(monthly_revenue - LAG(...), 2) as mom_change — Why subtract?
        Shows absolute change in KES
        Positive = growth, negative = decline
        ROUND(..., 2) for currency (2 decimals)
ROUND(100.0 * (monthly_revenue - LAG(...)) / LAG(...), 2) as mom_pct_change — Why percentage too?
        KES change alone is hard to interpret (is +5,000 good?)
        Percentage normalizes it (13.64% growth vs -6.88% decline = clear)
        100.0 * converts to percentage
        Why divide by LAG result? Percentage is change relative to previous month
ORDER BY month — Why chronological?
        Easier to spot trends (January → December progression)
        Can see if decline is getting worse (Mar -5%, Apr -8%, May -12%)
        If sorted by revenue, would hide time pattern

================================================================

3B: Running Total of Revenue

What We're Looking For:
CFO wants: Are we on track to hit annual KES 600k target? Where are we YTD (year-to-date)?

The Data We Need:
    Monthly revenue each month
    Cumulative total from January through each month

Why We Built It This Way:
SUM(monthly_revenue) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) — Why this window function?
Normal SUM() would give grand total (all months = 600k) for EVERY row
     Window function with frame sums incrementally:
    Jan row: sums Jan only = 55k
    Feb row: sums Jan+Feb = 117.5k
    Mar row: sums Jan+Feb+Mar = 175.7k
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW = "from start up to THIS row"
ORDER BY month — Why order inside the window function?
Tells window function to process rows chronologically
Without it, order would be random (wouldn't know which is "previous")

===========================================================================

3C: Best and Worst 3 Months

What We're Looking For:
Operations wants: Which months succeeded (replicate them) and failed (avoid repeating)?

The Data We Need:
    Top 3 revenue months
    Bottom 3 revenue months
    Which is which (labeled)
Why We Built It This Way:
  RANK() OVER (ORDER BY monthly_revenue DESC) as rank_desc — Why DESC?
        Descending = highest revenue first
        Feb (62.5k) gets rank 1, Jan (55k) gets rank 2, etc.
        Used for filtering rank_desc <= 3 = top 3 months
RANK() OVER (ORDER BY monthly_revenue ASC) as rank_asc — Why ASC (and why TWO rankings)?
          Ascending = lowest revenue first
          Jun (28.2k) gets rank 1 (worst), May (38.9k) gets rank 2, etc.
          Can't filter top 3 AND bottom 3 with one ranking
          Need both directions
CASE WHEN rank_desc <= 3 THEN 'Top 3' WHEN rank_asc <= 3 THEN 'Bottom 3' END — Why CASE?
        Categorizes which months are good/bad
        Makes report self-explanatory
        Why not two separate queries? User needs both in one view for comparison
WHERE rank_desc <= 3 OR rank_asc <= 3 — Why OR not AND?
        OR = show rows in EITHER top 3 OR bottom 3
        AND = show only rows in BOTH top AND bottom (impossible, would be 0 rows)
        Gets us 6 rows: 3 best + 3 worst
ORDER BY monthly_revenue DESC — Why order final results?
    Shows best months first, worst months last
    Easy visual: strong months at top, weak at bottom

=======================================================================

3D: Revenue by Route Per Month (Pivot)

What We're Looking For:
Which routes drive each month? Is RT001 always strongest, or does it vary seasonally?

The Data We Need:
      Each month's row
      RT001 revenue in its own column
      RT002 revenue in its own column
      RT003 revenue in its own column
      Total for reference
Why We Built It This Way:
        SUM(CASE WHEN route_code = 'RT001' THEN regexp_replace(...) ELSE 0 END) as rt001_revenue — Why CASE inside SUM?
        Data is in ROWS (one row per booking)
        We need COLUMNS (RT001, RT002, RT003 side-by-side)
        CASE WHEN route_code = 'RT001' → checks each booking: is this RT001?
        YES: include its fare in sum
        NO: add 0 (don't count)
        SUM() then totals all RT001 fares for the month
Why not GROUP BY route_code?
        That would give 3 rows per month (RT001 row, RT002 row, RT003 row)
        User would have to scan vertically (harder to compare)
        CASE pivot gives 1 row per month with routes as columns (easier to scan horizontally)
Repeat for RT002, RT003 — Why separate CASE statements?
        One CASE for each route
        Each evaluates independently
        Creates 3 output columns
ORDER BY month — Why chronological?
        Easier to spot seasonal patterns
        See if RT001 peaks in Feb, RT002 in Apr, etc.

=====================================================================================

4A: Top Passenger Cities (3+ bookings minimum)

set search_path to safari_connect_clean;

          select 
              passenger_city,
              count(*) as total_bookings,
              sum(seats_booked::integer) as total_seats,
              sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_revenue,
              round(avg(regexp_replace(fare_per_seat, '[^0-9.]', '', 'g')::numeric), 2) as avg_fare
          from v_clean_safari
          group by passenger_city
          having count(*) >= 3
          order by total_bookings desc;

Shows: Which cities have most passengers.
What we wanted: Which cities have most passengers?
Why these functions:
GROUP BY passenger_city — Collapse multiple bookings per city into one row
COUNT(*) — Count bookings per city
SUM(seats_booked) — Total passengers from that city
HAVING COUNT(*) >= 3 — Filter to only cities with 3+ bookings (ignore tiny markets)
ORDER BY total_bookings DESC — Show busiest cities first

===================================================================================


4C: Satisfaction Breakdown

set search_path to safari_connect_clean;

        select 
            passenger_gender,
            sum(case when seat_class = 'Economy' then 1 else 0 end) as economy_bookings,
            sum(case when seat_class = 'Business' then 1 else 0 end) as business_bookings,
            round(sum(case when seat_class = 'Economy' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as economy_revenue,
            round(sum(case when seat_class = 'Business' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as business_revenue
        from v_clean_safari
        group by passenger_gender
        order by economy_bookings desc;
Shows: How many trips are Satisfied/Neutral/Unsatisfied/No Rating.
What we wanted: What % of trips are Satisfied vs Neutral vs Unsatisfied?
Why these functions:
CASE WHEN trip_rating >= 4.5 — Categorize ratings into satisfaction levels (not just raw 1-5 scores)
WHERE booking_status = 'Completed' — Only count finished trips (cancelled/no-show aren't real trips)
GROUP BY satisfaction_level — Count each category
SUM(count) OVER () — Grand total for percentage calculation (dividing by total = %)
Shows business health: % of happy passengers

=======================================================================================


4B: Gender Split and Seat Class Preference

set search_path to safari_connect_clean;

          select 
              passenger_gender,
              sum(case when seat_class = 'Economy' then 1 else 0 end) as economy_bookings,
              sum(case when seat_class = 'Business' then 1 else 0 end) as business_bookings,
              round(sum(case when seat_class = 'Economy' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as economy_revenue,
              round(sum(case when seat_class = 'Business' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as business_revenue
          from v_clean_safari
          group by passenger_gender
          order by economy_bookings desc;

Shows: Gender breakdown + Economy vs Business preference and revenue.
New Concept: CASE WHEN for pivot-style aggregation.. 
What we wanted: Do men prefer Business? Do women prefer Economy? Show both gender splits AND revenue.
Why these functions:
GROUP BY passenger_gender — One row per gender (Male, Female)
SUM(CASE WHEN seat_class = 'Economy' THEN 1 ELSE 0 END) — Count Economy bookings (pivot rows to columns)
Repeat CASE for Business class
Also count revenue per class
Why CASE instead of filtering? CASE keeps all data in one row (easy comparison)

==============================================================================

4D: Passenger Quartiles by Spend
What we wanted: Who are the top 25% spenders? VIP customers.
Why these functions:
NTILE(4) OVER (ORDER BY total_spent) — Divides ALL passengers into 4 equal groups (quartiles):
Quartile 1: Bottom 25% (low spenders)
Quartile 2-3: Middle 50%
Quartile 4: Top 25% (VIPs)
WHERE quartile = 4 — Show only VIPs
Helps identify customers worth targeting with loyalty programs

===========================================================================
Question 5: Cancellations & Lost Revenue (SHORT)

5A: Overall Status Breakdown

What we wanted: How many bookings are Completed vs Cancelled vs No Show? How much revenue was lost?
Why these functions:
GROUP BY booking_status — One row per status (Completed, Cancelled, No Show)
COUNT(*) — How many bookings per status
SUM(count(*)) OVER () — Grand total to calculate percentage
SUM(total_fare) — Revenue per status (lost revenue for non-completed)
Shows operational health: completion rate vs loss rate

========================================================================

5B: Cancellation Rate by Route

What we wanted: Which routes have highest cancellation problems? Focus improvements there.
Why these functions:
GROUP BY route_code, route_from, route_to — One row per route
SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) — Count completed trips per route (pivot)
Repeat for Cancelled and No Show
ROUND(100.0 * cancelled / COUNT(*), 2) — Cancellation % per route
Why CASE instead of WHERE? CASE keeps all statuses in one row (easy comparison)
ORDER BY cancellation_rate_pct DESC — Show problem routes first

===========================================================================
5C: Revenue Lost

What we wanted: How much KES did we lose to cancellations vs no-shows?
Why these functions:
WHERE booking_status IN ('Cancelled', 'No Show') — Filter to only lost bookings
GROUP BY booking_status — One row per type (Cancelled vs No Show)
SUM(total_fare) — Total lost revenue
AVG(total_fare) — Average value per lost booking (shows booking quality)
Shows financial impact of operational failures


========================================================================
Question 6: Operational Patterns 
6A: Revenue by Day of Week

What we wanted: Which days are busiest? Schedule drivers/vehicles accordingly.
Why these functions:
TO_CHAR(departure_date::date, 'Day') — Extract day name from date (Monday, Tuesday, etc.)
GROUP BY day_of_week — One row per day (7 rows total)
COUNT(*) — Trips per day
SUM(seats_booked) — Passengers per day
ORDER BY revenue DESC — Show busiest days first
Why not just day of week number (1-7)? Day names are readable

=======================================================

6B: Busiest Departure Times

What we wanted: Which time slots are most popular? 6 AM vs 9 AM vs 5 PM?
Why these functions:
GROUP BY departure_time — One row per time slot (6:00, 6:30, 7:00, etc.)
COUNT(*) — How many trips at that time
SUM(seats_booked) — Passenger volume per slot
LIMIT 10 — Show only top 10 busiest times (not all 24 hours)
ORDER BY revenue DESC — Most profitable times first
Helps plan vehicle/driver allocation by time

=======================================================================

6C: Seat Utilisation by Vehicle Type

What we wanted: Are Buses/Matatus/Minibuses full or empty? Which vehicle type runs most efficiently?
Why these functions:
GROUP BY vehicle_type — One row per vehicle type (3 rows: Bus, Matatu, Minibus)
AVG(seats_booked) — Average passengers per trip per vehicle type
CASE WHEN avg > 3 THEN 'High Load' — Categorize utilisation (not just raw numbers)
High Load (>3): Profitable, full vehicles
Medium Load (2-3): Decent utilisation
Low Load (<2): Inefficient, empty vehicles
ORDER BY avg_seats_booked DESC — Show fullest vehicles first
Shows which vehicle type to buy more of
