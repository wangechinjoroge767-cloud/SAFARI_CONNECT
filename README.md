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
      creeated a schema to organize all safari connect data 
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
