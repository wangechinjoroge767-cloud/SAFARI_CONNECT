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

###BUSINESS ANALYSIS
 ===REVENUE AND BOOKINGS BY ROUTE===
     Business Objective
Identify which routes are the backbone of the business and which underperform. The Operations Director needs to see route performance ranked by revenue.
What the Query Does
Groups data by route (route_code, route_from, route_to)
Calculates:
total_bookings — number of completed trips on each route
total_seats — total passengers carried
total_revenue — sum of all fares collected
avg_fare — average fare per seat
avg_trip_rating — passenger satisfaction on each route
Orders by highest revenue first (most profitable routes first)
     Business Insights
RT001 is the revenue leader — high volume + high fares
RT004 has good volume but lower average fares
RT008 has low revenue — potential for route optimization or discontinuation
Routes with high passenger ratings are performing well and should be prioritized
Technical Notes
Data types must be cast because CSV import defaults all columns to VARCHAR
::integer for counts, ::numeric for calculations
ROUND() for readability in reporting
v_clean_trips filtered to completed bookings only (excluded cancelled/no-show)
      
