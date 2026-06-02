set search_path to public;

create schema if not exists safari_connect_clean;
set search_path to safari_connect_clean;

create table if not exists booking(
booking_id varchar(50)primary key,
passenger_name varchar(150),
passenger_phone varchar(20),
passenger_gender varchar(20),
passenger_city varchar(100),
route_code varchar(10),
route_from VARCHAR(100),
    route_to VARCHAR(100),
    vehicle_plate VARCHAR(50),
    vehicle_type VARCHAR(50),
    driver_name VARCHAR(150),
    driver_rating NUMERIC(2,1),
    departure_date DATE,
    departure_time TIME,
    seat_class VARCHAR(50),
    seats_booked INTEGER,
    fare_per_seat NUMERIC(10,2),
    total_fare NUMERIC(10,2),
    payment_method VARCHAR(50),
    booking_status VARCHAR(50),
    trip_rating NUMERIC(2,1),
    custom_phone VARCHAR(20)
);

-- Create indexes
CREATE INDEX idx_departure_date ON booking(departure_date);
CREATE INDEX idx_route_code ON booking(route_code);
CREATE INDEX idx_driver_name ON booking(driver_name);
CREATE INDEX idx_booking_status ON booking(booking_status);
CREATE INDEX idx_payment_method ON booking(payment_method);


select count(*) from safari_connect_clean.booking;
SELECT COUNT(*) FROM safari_connect_clean.safari_connect_clean;

set  search_path to safari_connect_clean; 
create or replace view v_clean_safari as select
booking_id,
passenger_name,
passenger_phone,
passenger_gender,
passenger_city,
route_code,
route_from,
route_to,
vehicle_plate,
vehicle_type,
driver_name,
driver_rating,
departure_date,
departure_time,
    seat_class,
    seats_booked,
    fare_per_seat,
    total_fare,
    payment_method,
    booking_status,
    trip_rating,
    TO_CHAR(departure_date::DATE,'Day') AS day_of_week,
    CASE 
        WHEN trip_rating >= 4.5 THEN 'Satisfied'
        WHEN trip_rating >= 3.5 THEN 'Neutral'
        WHEN trip_rating > 0 THEN 'Unsatisfied'
        ELSE 'No Rating'
    END AS satisfaction_level
FROM safari_connect_clean
WHERE booking_status = 'Completed'
ORDER BY departure_date DESC;

select count(*) from v_clean_safari;


========================================
===REVENUE & BOOKINGS - ROUTE

set search_path to safari_connect_clean;

select 
    route_code,
    route_from,
    route_to,
    count(*) as total_booking,
    sum(seats_booked::integer) as total_seats,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_revenue,
    round(avg(regexp_replace(fare_per_seat, '[^0-9.]', '', 'g')::numeric), 2) as avg_fare,
    round(avg(trip_rating::numeric), 1) as avg_trip_rating
from v_clean_safari
group by route_code, route_from, route_to
order by total_revenue desc;

---REVENUE PER SEAT BY ROUTE---
set search_path to safari_connect_clean;

select 
    route_code,
    route_from || ' - ' || route_to as route,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_revenue,
    sum(seats_booked::integer) as total_seats,
    round(
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) / 
        nullif(sum(seats_booked::integer), 0), 
        2
    ) as revenue_per_seat
from v_clean_safari
group by route_code, route_from, route_to
order by revenue_per_seat desc;


---ROUTE RANKING WITH WINDOW FUNCTION---
set search_path to safari_connect_clean;

with route_revenue as (
    select 
        route_code,
        route_from || ' - ' || route_to as route,
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as route_total_revenue,
        count(*) as bookings,
        rank() over (order by sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) desc) as revenue_rank
    from v_clean_safari
    group by route_code, route_from, route_to
),
total_company_revenue as (
    select sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as company_total from v_clean_safari
)
select 
    revenue_rank,
    route_code,
    route,
    route_total_revenue,
    bookings,
    round(100.0 * route_total_revenue / nullif((select company_total from total_company_revenue), 0), 2) as pct_of_total_revenue
from route_revenue
order by revenue_rank;


---VEHICLE TYPE PERFORMANCE---
set search_path to safari_connect_clean;

select
    vehicle_type,
    count(*) as total_bookings,
    sum(seats_booked::integer) as total_seats,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_revenue,
    round(avg(trip_rating::numeric), 2) as avg_rating
from v_clean_safari
group by vehicle_type
order by total_revenue desc;

---driver perfomance---
--driver summarry--
set search_path to safari_connect_clean;

select 
    driver_name,
    count(*) as total_trips,
    sum(seats_booked::integer) as total_seats_carried,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_revenue,
    round(avg(trip_rating::numeric), 2) as avg_passenger_rating,
    round(avg(driver_rating::numeric), 1) as driver_rating
from v_clean_safari
group by driver_name
order by total_revenue desc;

---driver by ranking---
set search_path to safari_connect_clean;

with driver_totals as (
    select 
        driver_name,
        vehicle_type,
        count(*) as trips,
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue,
        round(avg(trip_rating::numeric), 2) as avg_rating
    from v_clean_safari
    group by driver_name, vehicle_type
)
select 
    driver_name,
    vehicle_type,
    trips,
    revenue,
    avg_rating,
    rank() over (order by revenue desc) as overall_rank,
    rank() over (partition by vehicle_type order by revenue desc) as rank_within_vehicle_type
from driver_totals
order by overall_rank;

--does driver rating predict passenger satisfcation----
set search_path to safari_connect_clean;

with driver_satisfaction as (
    select 
        driver_name,
        case 
            when avg(driver_rating::numeric) >= 4.5 then 'High-Rated Driver'
            else 'Standard Driver'
        end as driver_category,
        round(avg(driver_rating::numeric), 2) as avg_driver_rating,
        round(avg(trip_rating::numeric), 2) as avg_passenger_rating,
        count(*) as trips
    from v_clean_safari
    group by driver_name
)
select 
    driver_category,
    count(*) as number_of_drivers,
    round(avg(avg_driver_rating), 2) as group_avg_driver_rating,
    round(avg(avg_passenger_rating), 2) as group_avg_passenger_rating,
    sum(trips) as total_trips
from driver_satisfaction
group by driver_category
order by group_avg_driver_rating desc;


---REVENUE TRENDS---
--monthly revenue with month over month change--
set search_path to safari_connect_clean;

with monthly_revenue as (
    select 
        date_trunc('month', departure_date::date)::date as month,
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as monthly_revenue
    from v_clean_safari
    group by date_trunc('month', departure_date::date)
)
select 
    month,
    monthly_revenue,
    lag(monthly_revenue) over (order by month) as prev_month_revenue,
    round(monthly_revenue - lag(monthly_revenue) over (order by month), 2) as mom_change,
    round(100.0 * (monthly_revenue - lag(monthly_revenue) over (order by month)) / lag(monthly_revenue) over (order by month), 2) as mom_pct_change
from monthly_revenue
order by month;

--running total of revenue--
set search_path to safari_connect_clean;

with monthly_revenue as (
    select 
        date_trunc('month', departure_date::date)::date as month,
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as monthly_revenue
    from v_clean_safari
    group by date_trunc('month', departure_date::date)
)
select 
    month,
    monthly_revenue,
    sum(monthly_revenue) over (order by month rows between unbounded preceding and current row) as running_total
from monthly_revenue
order by month;


--best and worst 3 months--
set search_path to safari_connect_clean;

with monthly_revenue as (
    select 
        date_trunc('month', departure_date::date)::date as month,
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as monthly_revenue,
        rank() over (order by sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) desc) as rank_desc,
        rank() over (order by sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) asc) as rank_asc
    from v_clean_safari
    group by date_trunc('month', departure_date::date)
)
select 
    month,
    monthly_revenue,
    case 
        when rank_desc <= 3 then 'Top 3'
        when rank_asc <= 3 then 'Bottom 3'
    end as month_category
from monthly_revenue
where rank_desc <= 3 or rank_asc <= 3
order by monthly_revenue desc;

--revenue by route per month--

set search_path to safari_connect_clean;

select 
    date_trunc('month', departure_date::date)::date as month,
    round(sum(case when route_code = 'RT001' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as rt001_revenue,
    round(sum(case when route_code = 'RT002' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as rt002_revenue,
    round(sum(case when route_code = 'RT003' then regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric else 0 end), 2) as rt003_revenue,
    round(sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric), 2) as total_monthly_revenue
from v_clean_safari
group by date_trunc('month', departure_date::date)
order by month;


---PASSENGER INSIGHT---
--Top passenger cities--

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

--gender split and seat class preference--

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

--satisfaction breakdown--
set search_path to safari_connect_clean;

with satisfaction_counts as (
    select 
        case 
            when trip_rating::numeric >= 4.5 then 'Satisfied'
            when trip_rating::numeric >= 3.5 then 'Neutral'
            when trip_rating::numeric > 0 then 'Unsatisfied'
            else 'No Rating'
        end as satisfaction_level,
        count(*) as count
    from v_clean_safari
    where booking_status = 'Completed'
    group by 1
  )
select 
    satisfaction_level,
    count as trip_count,
    round(100.0 * count / sum(count) over (), 2) as pct_of_total
from satisfaction_counts
order by count desc;

--passenger quartiles by spend--
set search_path to safari_connect_clean;

with passenger_spend as (
    select 
        passenger_name,
        sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as total_spent,
        ntile(4) over (order by sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric)) as quartile
    from v_clean_safari
    group by passenger_name
)
select 
    passenger_name,
    total_spent,
    case 
        when quartile = 4 then 'Top Spender'
        when quartile = 3 then 'High Spender'
        when quartile = 2 then 'Medium Spender'
        else 'Low Spender'
    end as spender_category
from passenger_spend
where quartile = 4
order by total_spent desc;

---CANCELLATION & LOST REVENUE---
--overall status breakdown--

set search_path to safari_connect_clean;

select 
    booking_status,
    count(*) as bookings,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_of_total,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue
from safari_connect_clean
group by booking_status
order by bookings desc;

--cancellation rate--
set search_path to safari_connect_clean;

select 
    route_code,
    route_from || ' - ' || route_to as route,
    count(*) as total_bookings,
    sum(case when booking_status = 'Completed' then 1 else 0 end) as completed,
    sum(case when booking_status = 'Cancelled' then 1 else 0 end) as cancelled,
    sum(case when booking_status = 'No Show' then 1 else 0 end) as no_show,
    round(100.0 * sum(case when booking_status = 'Cancelled' then 1 else 0 end) / count(*), 2) as cancellation_rate_pct
from safari_connect_clean
group by route_code, route_from, route_to
order by cancellation_rate_pct desc;

--revenue lost from cancellations and no shows--
set search_path to safari_connect_clean;

select 
    booking_status,
    count(*) as bookings,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as lost_revenue,
    round(avg(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric), 2) as avg_booking_value
from safari_connect_clean
where booking_status in ('Cancelled', 'No Show')
group by booking_status
order by lost_revenue desc;

---Operational patterns---
--revenue by day of week--
set search_path to safari_connect_clean;

select 
    to_char(departure_date::date, 'Day') as day_of_week,
    count(*) as trips,
    sum(seats_booked::integer) as total_seats,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue
from v_clean_safari
group by to_char(departure_date::date, 'Day')
order by revenue desc;

--busiest departure times--
set search_path to safari_connect_clean;

select 
    departure_time,
    count(*) as trips,
    sum(seats_booked::integer) as passengers,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue
from v_clean_safari
group by departure_time
order by revenue desc
limit 10;

--seat utilisattion by vehicle type--
set search_path to safari_connect_clean;

select 
    vehicle_type,
    round(avg(seats_booked::integer), 2) as avg_seats_booked,
    round(avg(seats_booked::integer), 1) as utilisation,
    case 
        when round(avg(seats_booked::integer), 2) > 3 then 'High Load'
        when round(avg(seats_booked::integer), 2) >= 2 then 'Medium Load'
        else 'Low Load'
    end as utilisation_category
from v_clean_safari
group by vehicle_type
order by avg_seats_booked desc;


---view 1---
--route perfomance--
set search_path to safari_connect_clean;

create or replace view route_performance as
select 
    route_code,
    route_from,
    route_to,
    route_from || ' - ' || route_to as route,
    count(*) as bookings,
    sum(seats_booked::integer) as passengers,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue,
    round(sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) / nullif(sum(seats_booked::integer), 0), 2) as revenue_per_seat,
    round(avg(trip_rating::numeric), 2) as avg_rating
from v_clean_safari
group by route_code, route_from, route_to;



--view 2 : driver perfomance--
set search_path to safari_connect_clean;

create or replace view driver_performance as
select 
    driver_name,
    vehicle_type,
    count(*) as trips,
    sum(seats_booked::integer) as passengers,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue,
    round(avg(driver_rating::numeric), 1) as driver_rating,
    round(avg(trip_rating::numeric), 2) as passenger_satisfaction
from v_clean_safari
group by driver_name, vehicle_type;


---view 3: revenue_trends---
set search_path to safari_connect_clean;

create or replace view revenue_trends as
select 
    date_trunc('month', departure_date::date)::date as month,
    route_code,
    route_from || ' - ' || route_to as route,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as monthly_revenue,
    count(*) as bookings
from v_clean_safari
group by date_trunc('month', departure_date::date), route_code, route_from, route_to;


---view 4:passenger insights---

set search_path to safari_connect_clean;

create or replace view passenger_insights as
select 
    passenger_city,
    passenger_gender,
    seat_class,
    count(*) as bookings,
    sum(regexp_replace(total_fare, '[^0-9.]', '', 'g')::numeric) as revenue,
    round(avg(trip_rating::numeric), 2) as avg_rating
from v_clean_safari
group by passenger_city, passenger_gender, seat_class;


set search_path to safari_connect_clean;

select table_name 
from information_schema.tables 
where table_schema = 'safari_connect_clean' 
and table_type = 'VIEW'
order by table_name;

---indexes--
set search_path to safari_connect_clean;

-- Create indexes for faster queries
create index idx_departure_date on safari_connect_clean(departure_date);
create index idx_route_code on safari_connect_clean(route_code);
create index idx_driver_name on safari_connect_clean(driver_name);
create index idx_booking_status on safari_connect_clean(booking_status);
create index idx_payment_method on safari_connect_clean(payment_method);
create index idx_vehicle_type on safari_connect_clean(vehicle_type);

-- Verify indexes created
select indexname 
from pg_indexes 
where schemaname = 'safari_connect_clean'
order by indexname;