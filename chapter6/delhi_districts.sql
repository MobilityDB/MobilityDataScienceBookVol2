/*****************************************************************************/

SET TIMEZONE TO 'Asia/Kolkata';
SET DATESTYLE TO 'ISO, YMD';

-------------------------------------------------------------------------------

/*

DROP TABLE IF EXISTS Districts;
CREATE TABLE Districts(OsmId bigint PRIMARY KEY, Name text, AdminLevel text, 
  Geom geometry, Boundary geometry);
INSERT INTO Districts(OsmId, Name, AdminLevel, Geom, Boundary)
SELECT osm_id, name, admin_level, ST_Transform(way, 7760),
  ST_boundary(ST_Transform(way, 7760))
FROM planet_osm_polygon
WHERE boundary = 'administrative' AND admin_level = '6' AND name IS NOT NULL;

-- INSERT 0 33
-- Time: 88.099 ms

When using administrative level 6 a trip traverses many subdistricts

delhi=# select distinct array_length(DistrictSeq, 1) from tripdistrictsseq order by 1 desc limit 10;
 array_length
--------------
          155
          153
          129
          127
          123
          121
          119
          117
          115
          113

The next level is district

delhi=# select osm_id, name from planet_osm_line where boundary = 'administrative' AND admin_level = '5' AND name IS NOT
 NULL order by 2;
  osm_id  |        name
----------+---------------------
 -1958008 | Baghpat
 -1942443 | Central Delhi
 -1942588 | East Delhi
 -1943060 | Faridabad
 -1958053 | Gautam Buddha Nagar
 -1958054 | Ghaziabad
 -3577685 | Gurugram
 -1942946 | Jhajjar
 -2763541 | New Delhi
 -1942605 | North Delhi
 -1942605 | North Delhi
 -1942602 | North East Delhi
 -1942609 | North West Delhi
 -1942609 | North West Delhi
 -3560206 | Shahdara
 -1942904 | Sonipat
 -1942663 | South Delhi
 -3588253 | South East Delhi
 -1942625 | South West Delhi
 -1942625 | South West Delhi
 -1942620 | West Delhi
(21 rows)

*/

DROP TABLE IF EXISTS Districts;
CREATE TABLE Districts(OsmId bigint PRIMARY KEY, Name text, AdminLevel text, 
  Geom geometry, Boundary geometry);
INSERT INTO Districts(OsmId, Name, AdminLevel, Geom, Boundary)
WITH DistrictsInput(OsmId, Name, AdminLevel, Geom) AS (
  SELECT osm_id, name, admin_level, ST_Transform(way, 7760)
  FROM planet_osm_polygon
  WHERE boundary = 'administrative' AND admin_level = '5' AND name IS NOT NULL ),
DistrictsAgg(OsmId, Name, AdminLevel, Geom) AS (
  SELECT OsmId, name, AdminLevel, ST_Collect(Geom)
  FROM DistrictsInput
  GROUP BY OsmId, Name, AdminLevel )
SELECT OsmId, Name, AdminLevel, Geom, ST_Boundary(Geom)
FROM DistrictsAgg
ORDER BY OsmId;

-- INSERT 0 11
-- Time: 87.969 ms

CREATE INDEX Districts_Geom_Quadtree_Idx ON Districts USING SPGIST(Geom);

-------------------------------------------------------------------------------

DROP TABLE IF EXISTS TripDistricts;
CREATE TABLE TripDistricts(TripId integer, StepNo integer, StartTime timestamptz,
  EndTime timestamptz, Name text, Pm25 float, Weather jsonb,
  PRIMARY KEY (TripId, Name, StartTime));
INSERT INTO TripDistricts
WITH PointDistricts(TripId, T, Pm25, Geom, Weather, Name, PrevDistr) AS (
  SELECT p.TripId, p.T, p.Pm25, p.Geom, p.Weather, d.Name, 
    LAG(Name) OVER (PARTITION BY TripId ORDER BY T )
  FROM TripPoints p, Districts d
  WHERE ST_Contains(d.Geom, p.Geom) ),
StepStarts(TripId, T, Pm25, Geom, Weather, Name, PrevDistr, NewStep) AS (
  SELECT *, 
    CASE WHEN PrevDistr IS NULL OR Name <> PrevDistr THEN 1 ELSE 0 END
  FROM PointDistricts ),
TripSteps(TripId, StepNo, T, Pm25, Geom, Weather, Name, PrevDistr) AS (
  SELECT TripId, SUM(NewStep) OVER (PARTITION BY TripId ORDER BY T
    ROWS UNBOUNDED PRECEDING), T, Pm25, Geom, Weather, Name, PrevDistr
  FROM StepStarts )
SELECT TripId, StepNo, MIN(T), MAX(T), MIN(Name), /* Name is unique in a group */
  AVG(Pm25), jsonb_build_object(
    'Temperature', AVG((Weather->>'Temperature')::float),
    'Humidity', AVG((Weather->>'Humidity')::float),
    'CloudCover', AVG((Weather->>'CloudCover')::float),
    'Rain', AVG((Weather->>'Rain')::float),
    'Wind', AVG((Weather->>'Wind')::float)) AS Weather
FROM TripSteps
GROUP BY TripId, StepNo
ORDER BY TripId, StepNo;

-- INSERT 0 41644
-- Time: 70620.539 ms (01:10.621)

DROP TABLE IF EXISTS TripDistrictsSeq;
CREATE TABLE TripDistrictsSeq(TripId integer PRIMARY KEY, DistrictSeq text[]);
INSERT INTO TripDistrictsSeq
SELECT TripId, array_agg(Name ORDER BY EndTime)
FROM TripDistricts
GROUP BY TripId
ORDER BY TripId;

-- INSERT 0 27114
-- Time: 184.656 ms

/*

delhi=# select distinct array_length(DistrictSeq, 1) from tripdistrictsseq order by 1 desc limit 10;
 array_length
--------------
           79
           75
           72
           71
           69
           65
           63
           59
           51
           47
(10 rows)

*/

-- TEMPORAL VERSION

DROP TABLE IF EXISTS TripDistricts;
CREATE TABLE TripDistricts(TripId integer, StepNo integer, AtTime tstzspanset,
  Name text, Trip tgeompoint, Trajectory geometry, Pm25 tfloat,
  Weather tjsonb, PRIMARY KEY (TripId, StepNo) );
INSERT INTO TripDistricts
WITH TripDistricts(TripId, Name, Trip, Pm25, Weather) AS (
  SELECT TripId, Name, atGeometry(t.Trip, d.Geom), Pm25, Weather
  FROM Trips t, Districts d
  WHERE eIntersects(t.Trip, d.Geom) )
SELECT TripId, ROW_NUMBER() OVER (PARTITION BY TripId ORDER BY getTime(Trip)),
  getTime(Trip), Name, Trip, trajectory(Trip), atTime(Pm25, getTime(Trip)),
  atTime(Weather, getTime(Trip))
FROM TripDistricts
ORDER BY TripId, getTime(Trip);

-- INSERT 0 31756
-- Time: 119488.270 ms (01:59.488)

/* 
  The following query is more elaborated than the corresponding TripTilesSeq
  since there atGeometry does not have a parameter borderInc as in atStbox
  and thus we need to convert the spans into open to the right and and The
  last instant
*/

DROP TABLE IF EXISTS TripDistrictsSeq;
CREATE TABLE TripDistrictsSeq(TripId integer PRIMARY KEY, Districts ttext, DistrictSeq text[]);
INSERT INTO TripDistrictsSeq
WITH Spans(TripId, Name, Span) AS (
  SELECT TripId, Name, unnest(spans(AtTime))
  FROM TripDistricts ),
DistrNames(TripId, NameSeq) AS (
  SELECT TripId, array_agg(Name ORDER BY Seq)
  FROM (
    SELECT TripId, Name, ROW_NUMBER() OVER w AS Seq, LAG(Name) OVER w AS PrevVal
    FROM Spans
    WINDOW w AS (PARTITION BY TripId ORDER BY Span) ) d
  WHERE Name IS DISTINCT FROM PrevVal
  GROUP BY TripId ),
DistrPeriods(TripId, Name) AS (
  SELECT TripId, ttext(Name, span(lower(Span), upper(Span), true, 
    CASE WHEN lower(Span) = upper(Span) THEN true ELSE false END))
  FROM Spans ),
EndDistrict(TripId, Inst) AS (
  SELECT DISTINCT ON (TripId) TripId, ttext(Name, upper(Span))
  FROM Spans
  ORDER BY TripId, Span DESC ),
TripDistricts(TripId, Name) AS (
  SELECT d.TripId, merge(array_agg(Name ORDER BY Name)) Name
  FROM DistrPeriods d
  GROUP BY TripId )
SELECT d.TripId, merge(Name, Inst), NameSeq
FROM TripDistricts d, EndDistrict e, DistrNames n
WHERE d.TripId = e.TripId AND d.TripId = n.TripId
ORDER BY TripId, Name;

-- INSERT 0 27114
-- Time: 631.475 ms

/*

delhi=# select TripId, Districts from TripDistrictsSeq WHERE numInstants(Districts) > 2 order by numInstants(Districts) limit 3;
 tripid |                                                           districts                                           
--------+-------------------------------------------------------------------------------------------------------------------------------
     12 | [South Delhi@2020-11-04 18:51:20+05:30, New Delhi@2020-11-04 18:51:36.189174+05:30, New Delhi@2020-11-04 19:05:45+05:30]
     35 | [West Delhi@2020-11-05 07:15:56+05:30, New Delhi@2020-11-05 07:16:47.318143+05:30, New Delhi@2020-11-05 07:16:48+05:30]
     65 | [South East Delhi@2020-11-06 05:42:16+05:30, New Delhi@2020-11-06 05:42:21.771428+05:30, New Delhi@2020-11-06 05:44:21+05:30]
(3 rows)

delhi=# select TripId, numInstants(Districts) from TripDistrictsSeq order by numInstants(Districts) DESC limit 10;
 tripid | numinstants
 tripid | numinstants
--------+-------------
   3876 |          80
   3871 |          76
   2769 |          75
   3874 |          74
   3849 |          70
   3869 |          70
   6711 |          66
  25447 |          66
   2768 |          62
   3860 |          52
(10 rows)
*/

-------------------------------------------------------------------------------
/*
Query 5.15. Trips that traversed at least twice the same district with exactly
one different district in between.
*/

-- Overlapping patterns
DROP TABLE IF EXISTS Q5_15_Over;
CREATE TABLE Q5_15_Over AS
SELECT s.TripId, d.Pos, s.DistrictSeq[d.Pos : d.Pos + 2] AS MatchSeq
FROM TripDistrictsSeq s
CROSS JOIN LATERAL generate_series(1, array_length(s.DistrictSeq, 1) - 2) AS d(Pos)
WHERE s.DistrictSeq[d.Pos] = s.DistrictSeq[d.Pos + 2] AND
  s.DistrictSeq[d.Pos] <> s.DistrictSeq[d.Pos + 1]
ORDER BY s.TripId;

-- SELECT 9262
-- Time: 70.657 ms

-- Disjoint patterns
DROP TABLE IF EXISTS Q5_15_Disj;
CREATE TABLE Q5_15_Disj AS
WITH AllMatches AS (
  SELECT s.TripId, d.Pos, s.DistrictSeq[d.Pos:d.Pos + 2] AS MatchSeq
  FROM TripDistrictsSeq s
  CROSS JOIN LATERAL generate_series(1, array_length(s.DistrictSeq, 1) - 2) AS d(Pos)
  WHERE s.DistrictSeq[d.Pos] = s.DistrictSeq[d.Pos + 2] AND
    s.DistrictSeq[d.Pos] <> s.DistrictSeq[d.Pos + 1] ),
Ranked AS (
  SELECT *, LAG(Pos) OVER (PARTITION BY TripId ORDER BY Pos) AS PrevPos
  FROM AllMatches )
SELECT TripId, Pos, MatchSeq
FROM Ranked
WHERE PrevPos IS NULL OR Pos >= PrevPos + 3
ORDER BY TripId, Pos;

-- SELECT 1906
-- Time: 71.043 ms

-- Overlapping patterns of A.*A
DROP TABLE IF EXISTS Q5_15_AnyLen;
CREATE TABLE Q5_15_AnyLen AS
SELECT s.TripId, g1.StartPos, g2.EndPos,
  s.DistrictSeq[g1.StartPos : g2.EndPos] AS MatchSeq
FROM TripDistrictsSeq s
  CROSS JOIN LATERAL generate_series(1, array_length(s.DistrictSeq, 1) - 1) AS g1(StartPos)
  CROSS JOIN LATERAL generate_series(g1.StartPos + 2, array_length(s.DistrictSeq, 1)) AS g2(EndPos)
WHERE s.DistrictSeq[g1.StartPos] = s.DistrictSeq[g2.EndPos]
AND NOT EXISTS (
  SELECT 1
  FROM generate_series(g1.StartPos + 1, g2.EndPos - 1) AS d(MidPos)
  WHERE s.DistrictSeq[d.MidPos] = s.DistrictSeq[g1.StartPos] )
ORDER BY s.TripId, g1.StartPos;

-- SELECT 10201
-- Time: 251.100 ms

-------------------------------------------------------------------------------
/*
Query 5.16. Trips that traversed one district with the following development of
spatiotemporal predicates: Disjoint -> Meets -> Inside -> Meets -> Disjoint
*/

-- Overlapping patterns
DROP TABLE IF EXISTS Q5_16_Over;
CREATE TABLE Q5_16_Over AS
WITH Meets(TripId, Name, AtTimestamp) AS (
  SELECT t.TripId, d.Name, 
    lower(unnest(spans(whenTrue(tIntersects(t.Trip, d.Boundary)))))
  FROM Trips t, Districts d
  WHERE eIntersects(t.Trip, d.Boundary)
  ORDER BY t.TripId, d.Name ),
ContainedBy(TripId, Name, AtTime) AS (
  SELECT t.TripId, d.Name, 
    unnest(spans(whenTrue(tContains(d.Geom, t.Trip))))
  FROM Trips t, Districts d
  WHERE eIntersects(t.Trip, d.Geom)
  ORDER BY t.TripId, d.Name )
SELECT m1.TripId, m1.Name, m1.AtTimestamp, c.AtTime, m2.AtTimestamp
FROM Meets m1, ContainedBy c, Meets m2
WHERE m1.TripId = c.TripId AND m1.Name = c.Name AND
  m2.TripId = c.TripId AND m2.Name = c.Name AND
  m2.AtTimestamp = upper(c.AtTime)
ORDER BY m1.TripId, m1.Name;

/*****************************************************************************/
