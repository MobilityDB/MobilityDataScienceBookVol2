CREATE TABLE Weather(id  serial, WeatherData jsonb);
INSERT INTO Weather (WeatherData) VALUES (
'{
  "latitude": 41.23023,
  "longitude": -8.638977,
  "generationtime_ms": 0.4216432571411133,
  "utc_offset_seconds": 0,
  "timezone": "Europe/Lisbon",
  "timezone_abbreviation": "GMT",
  "elevation": 48.0,
  "hourly_units": {
    "time": "iso8601",
    "temperature_2m": "C",
    "wind_speed_10m": "km/h",
    "precipitation": "mm",
    "pressure_msl": "hPa"
    },
  "hourly": {
    "time": ["2013-07-01T00:00", "2013-07-01T01:00", "2013-07-01T02:00",
      "2013-07-01T03:00", "2013-07-01T04:00"],
    "temperature_2m": [21.5, 20.0, 18.6, 19.0],
    "wind_speed_10m": [10.0, 10.8, 11.7, 10.1],
    "precipitation": [0.0, 0.0, 0.0, 0.0],
    "pressure_msl": [1015.0, 1014.7, 1014.2, 1013.7]
    }
}
')

SELECT WeatherData  ->  'latitude', WeatherData ->  'longitude'
FROM Weather;
--"41.23023"	"-8.638977"

SELECT WeatherData  ->> 'latitude', WeatherData ->> 'longitude'
FROM Weather;
--"41.23023"	"-8.638977"

-- Returns as JSON

SELECT WeatherData #> '{hourly_units, time}' 
FROM Weather; 
--"iso8601" 

-- RETURNS AS TEXT

SELECT
    WeatherData->'hourly_units'->>'time'    AS time_unit,
    WeatherData->'hourly_units'->>'temperature_2m' AS temperature_unit,
    WeatherData->'hourly_units'->>'wind_speed_10m' AS wind_speed_unit
FROM Weather;

-- "iso8601"	"C"	"km/h"

SELECT
    WeatherData #> '{hourly_units,time}'   AS time_unit,
    WeatherData #> '{hourly_units,temperature_2m}' AS temperature_unit,
    WeatherData #> '{hourly_units,wind_speed_10m}' AS wind_speed_unit
FROM Weather;
--"""iso8601"""	"""C"""	"""km/h"""

-- RETURNS JSON

SELECT  WeatherData -> 'hourly' -> 'time', 
        WeatherData ->'hourly' -> 'temperature_2m' 
FROM Weather;
/*"[""2013-07-01T00:00"", ""2013-07-01T01:00"",
""2013-07-01T02:00"", ""2013-07-01T03:00"",
""2013-07-01T04:00""]"	"[21.5, 20.0, 18.6, 19.0]"*/

--Extract JSON field as text
 
SELECT WeatherData -> 'hourly' ->> 'time', 
       WeatherData -> 'hourly' ->> 'temperature_2m' 
FROM Weather;
/* "[""2013-07-01T00:00"", ""2013-07-01T01:00"", 
   ""2013-07-01T02:00"", ""2013-07-01T03:00"", 
   ""2013-07-01T04:00""]" "[21.5, 20.0, 18.6, 19.0]"*/
 
-- We can extract an item from array,
SELECT WeatherData  -> 'hourly' -> 'temperature_2m'->> 0 
FROM Weather;
-- 21.5
-- temperature_2m
--JSON A contains JSON B, for example whether it contains a field with key \textsf{id} and value \textsf{778}, as follows.

SELECT WeatherData @> '{"latitude": 41.23023}'::jsonb
FROM Weather;
-- true

--JSON A contains Item B, for example, whether it
--contains a field \textsf{shop}, as follows.

SELECT WeatherData ? 'hourly'
FROM Weather;
-- true
 
--JSON A contains any item in B, for example, whether it contains any of the fields \textsf{shop} and \textsf{cookies} as follows.

SELECT WeatherData ?| ARRAY['hourly','time']
FROM Weather;
-- true

--Does JSON path return any item, for example,
--whether the name of the second pizza is
--equal to \textsf{"Salami"}.

SELECT WeatherData @? '$.wind_speed_10m[1] ? (@ == 156.0)' 
FROM Weather;

SELECT jsonb_path_query(WeatherData, '$.wind_speed_10m[1]')
FROM Weather;

SELECT jsonb_path_query(WeatherData, '$.hourly.temperature_2m[*]') AS temperature
FROM Weather; -- Returns all elements matching the JSON path.

/*"21.5"
"20.0"
"18.6"
"19.0"*/

SELECT jsonb_path_query(WeatherData, '$.hourly.temperature_2m[*] ? (@ > 20)') AS temperature
FROM Weather;
--"21.5"
 


-- TRANSFORM INTO TABLE, Convert array elements to JSON rows
-- Convert array elements to text rows

SELECT
    times.value::text::timestamp AS time,
    temps.value::text::numeric AS temperature_c,
    winds.value::text::numeric AS wind_kmh
FROM Weather,
     jsonb_array_elements(WeatherData->'hourly'->'time') WITH ORDINALITY AS times(value, idx)  
-- ORDINALITY because we want to keep track of the original position (index) of each element in that array.
JOIN LATERAL
     jsonb_array_elements(WeatherData->'hourly'->'temperature_2m') WITH ORDINALITY AS temps(value, tidx)
       ON times.idx = temps.tidx
JOIN LATERAL
     jsonb_array_elements(WeatherData->'hourly'->'wind_speed_10m') WITH ORDINALITY AS winds(value, widx)
       ON times.idx = winds.widx
ORDER BY times.idx;
/*"2013-07-01 00:00:00"	21.5	10.0
"2013-07-01 01:00:00"	20.0	10.8
"2013-07-01 02:00:00"	18.6	11.7
"2013-07-01 03:00:00"	19.0	10.1*/
 