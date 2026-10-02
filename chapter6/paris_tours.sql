/*****************************************************************************/

DROP TABLE IF EXISTS PoI CASCADE;
CREATE TABLE PoI(PoIId integer PRIMARY KEY, Name text NOT NULL,
  Geom geometry(Point, 2154) NOT NULL, Description jsonb NOT NULL);
INSERT INTO PoI VALUES
(1, 'Le Meurice', ST_Point(650759.721, 6863028.090, 2154),
  '{"Name": "Le Meurice", "Category": "Restaurant", "TypeOfFood": "French",
  "Price": "Expensive"}'),
(2, 'Hilton Paris Opera', ST_Point(650535.108, 6864130.888, 2154),
  '{"Name": "Hilton Paris Opera", "Category": "Hotel", "Stars": 5}'),
(3, 'Pathee Opera', ST_Point(651187.252530473, 6863616.056298946, 2154),
  '{"Name": "Pathee Opera", "Category": "Entertainment", "Type": "Movie"}'),
(4, 'Holiday Inn Paris Gare de l''Est', ST_Point(653017.785, 6864194.728, 2154),
  '{"Name": "Holiday Inn Paris Gare de l''Est", "Category": "Hotel", "Stars": 3}'),
(5, 'Cafe de Flore', ST_Point(650991.685, 6861829.618, 2154),
  '{"Name": "Cafe de Flore", "Category": "Amenity", "Type": "Coffee Shop"}'),
(6, 'Le Petit Italien', ST_Point(653501.802, 6862173.661, 2154),
  '{"Name": "Le Petit Italien", "Category": "Restaurant", "TypeOfFood": "Italian",
  "Price": "Moderate"}'),
(7, 'Musee d''Orsay', ST_Point(650596.165, 6862431.229),
  '{"Name": "Musee d''Orsay", "Category": "Museum"}'),
(8, 'Musee du Louvre', ST_Point(651418.262, 6862558.827, 2154),
  '{"Name": "Musee du Louvre", "Category": "Museum"}'),
(9, 'Indy Restaurant', ST_Point(652615.100,  6863746.535, 2154),
  '{"Name": "Indy Restaurant", "Category": "Restaurant", "TypeOfFood": "Indian", 
  "Price": "Moderate"}'),
(10, 'Eiffel Tower', ST_Point(648273.589, 6862226.878, 2154),
  '{"Name": "Eiffel Tower", "Category": "Landmark"}'),
(11, 'Bistro les Artizans', ST_Point(652094.296,  6862861.220, 2154),
  '{"Name": "Bistro les Artizans", "Category": "Restaurant", "TypeOfFood": "French", 
  "Price": "Moderate"}'),
(12, 'Centre Pompidou', ST_Point(652477.201,  6862495.556, 2154),
  '{"Name": "Centre Pompidou", "Category": "Museum"}');

/*****************************************************************************/

DROP TABLE IF EXISTS Tour CASCADE;
CREATE TABLE Tour(TourId integer, StepNo integer, PoI text, AtTime tstzspan);
INSERT INTO Tour(TourId, StepNo, PoI, AtTime) VALUES
-- Trip 1
(1, 1, 'Le Meurice', '[2025-09-09 09:00, 2025-09-09 13:00)'),
(1, 2, 'Musee d''Orsay', '[2025-09-09 14:10, 2025-09-09 17:00)'),
(1, 3, 'Le Petit Italien', '[2025-09-09 18:00, 2025-09-09 19:30)'),
(1, 4, 'Pathee Opera', '[2025-09-09 20:30, 2025-09-09 22:30:00)'),
(1, 5, 'Hilton Paris Opera', '[2025-09-09 23:30, 2025-09-10 08:30)'),
-- Trip 2
(2, 1, 'Hilton Paris Opera', '[2025-09-09 08:10, 2025-09-09 10:00)'),
(2, 2, 'Musee du Louvre', '[2025-09-09 11:10, 2025-09-09 13:00)'),
(2, 3, 'Indy Restaurant', '[2025-09-09 13:30, 2025-09-09 15:30)'),
(2, 4, 'Pathee Opera', '[2025-09-09 17:30, 2025-09-09 20:00)'),
(2, 5, 'Hilton Paris Opera', '[2025-09-09 20:30, 2025-09-10 08:30)'),
-- Trip 3
(3, 1, 'Hilton Paris Opera', '[2025-09-09 09:00, 2025-09-09 10:00)'),
(3, 2, 'Pathee Opera', '[2025-09-09 17:00, 2025-09-09 19:00)'),
(3, 3, 'Indy Restaurant', '[2025-09-09 21:30, 2025-09-09 23:30)'),
-- Trip 4
(4, 1, 'Holiday Inn Paris Gare de l''Est', '[2025-09-11 10:10, 2025-09-11 11:00)'),
(4, 2, 'Cafe de Flore', '[2025-09-11 11:10, 2025-09-11 12:00)'),
(4, 3, 'Musee du Louvre', '[2025-09-11 12:10:00, 2025-09-11 14:00)'),
(4, 4, 'Le Meurice', '[2025-09-11 15:30, 2025-09-11 17:30)'),
-- Trip 5
(5, 1, 'Eiffel Tower', '[2025-09-11 10:30, 2025-09-11 15:30)'),
(5, 2, 'Cafe de Flore', '[2025-09-11 16:00, 2025-09-11 17:00)'),
(5, 3, 'Holiday Inn Paris Gare de l''Est', '[2025-09-11 19:30, 2025-09-12 08:30)'),
-- Trip 6
(6, 1, 'Hilton Paris Opera', '[2025-09-09 09:00, 2025-09-11 10:00)'),
(6, 2, 'Musee d''Orsay', '[2025-09-11 11:10, 2025-09-11 13:00)'),
(6, 3, 'Le Meurice', '[2025-09-11 13:10, 2025-09-11 15:30)'),
(6, 4, 'Eiffel Tower', '[2025-09-11 16:00, 2025-09-11 18:00)'),
(6, 5, 'Hilton Paris Opera', '[2025-09-11 20:00, 2025-09-12 08:30)'),
-- Trip 7
(7, 1, 'Holiday Inn Paris Gare de l''Est', '[2025-09-11 09:00, 2025-09-11 10:00)'),
(7, 2, 'Cafe de Flore', '[2025-09-11 10:30, 2025-09-11 11:00)'),
(7, 3, 'Indy Restaurant', '[2025-09-11 12:30, 2025-09-11 13:30)'),
(7, 4, 'Holiday Inn Paris Gare de l''Est', '[2025-09-11 21:00, 2025-09-12 10:00)'),
-- Trip 8
(8, 1, 'Bistro les Artizans', '[2025-09-12 09:00, 2025-09-12 10:30)'),
(8, 2, 'Eiffel Tower', '[2025-09-12 11:00, 2025-09-12 12:00)'),
(8, 3, 'Bistro les Artizans', '[2025-09-12 20:00, 2025-09-12 22:00)'),
-- Trip 9
(9, 1, 'Musee d''Orsay', '[2025-09-12 09:00, 2025-09-12 10:00)'),
(9, 2, 'Le Petit Italien', '[2025-09-12 10:30, 2025-09-12 11:00)'),
-- Trip 10
(10,	1,	'Musee d''Orsay',	'[2025-09-09 00:00:00+00, 2025-09-09 12:00:00+00)'),
(10,	2,	'Le Meurice',	'[2025-09-09 12:30:00+00, 2025-09-09 14:00:00+00)'),
(10,	3,	'Musee du Louvre', '[2025-09-09 14:30:00+00, 2025-09-09 18:30:00+00)'),
(10,	4,	'Le Petit Italien',	'[2025-09-09 19:30:00+00, 2025-09-09 21:30:00+00)'),
(10,	5,	'Musee d''Orsay',	'[2025-09-13 10:00:00+00, 2025-09-13 15:00:00+00)')
;
/*****************************************************************************/

DROP VIEW IF EXISTS TourPOI;
CREATE VIEW TourPOI(TourId, StepNo, PoI, Geom, AtTime) AS
SELECT t.TourId, t.StepNo, p.Description, p. Geom, t.AtTime
FROM Tour t, PoI p
WHERE t.PoI = p.Name;

/*****************************************************************************/

-- TEMPORAL TABLE

DROP TABLE IF EXISTS TempTour;
CREATE TABLE TempTour(TourId integer PRIMARY KEY, Tour tjsonb,
  Location tgeompoint);
INSERT INTO TempTour(TourId, Tour, Location)
SELECT TourId,
  merge(array_agg(tjsonb(jsonb_build_object(text 'StepNo', StepNo) || PoI, 
    AtTime) ORDER BY AtTime)),
  merge(array_agg(tgeompoint(Geom, AtTime) ORDER BY AtTime)) AS Location
FROM TourPoI
GROUP BY TourId
ORDER BY TourId;

/*****************************************************************************
 * QUERIES
 *****************************************************************************/

/*
Tours that go to the Hilton, then optionally go to a restaurant, and then go to the movies

Tour[before([Category = 'Hotel' AND Name = 'Hilton Paris Opera'],
  [Category = 'Restaurant']*, [Category = 'Entertainment' AND Type = 'Movie'])]
*/

WITH Hilton AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Hotel' AND PoI->>'Name' = 'Hilton Paris Opera' ),
Restaurant AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Restaurant' ),
Movie AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Entertainment' AND PoI->>'Type' = 'Movie' )
SELECT DISTINCT h.TourId, h.StepNo AS HiltonStep, h.PoI->>'Name' AS HiltonName,
  r.StepNo AS RestStep, r.PoI->>'Name' AS RestName,
  m.StepNo AS MovieStep, m.PoI->>'Name' AS MovieName
FROM Hilton h
JOIN Movie m ON m.TourId = h.TourId AND h.AtTime < m.AtTime
LEFT JOIN Restaurant r ON r.TourId = h.TourId AND h.AtTime < r.AtTime AND
  r.AtTime < m.AtTime
ORDER BY h.TourId, h.StepNo;

/* 
 tourid | hiltonstep |     hiltonname     | reststep |    restname     | moviestep |  moviename
--------+------------+--------------------+----------+-----------------+-----------+--------------
      2 |          1 | Hilton Paris Opera |        3 | Indy Restaurant |         4 | Pathee Opera
      3 |          1 | Hilton Paris Opera |          |                 |         2 | Pathee Opera
*/

-- TEMPORAL VERSION

WITH Hilton(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(
    getTime(atValue(Tour->>'Category', text 'Hotel')) *
    getTime(atValue(Tour->>'Name', text 'Hilton Paris Opera')))))
  FROM TempTour
  WHERE getTime(atValue(Tour->>'Name', text 'Hilton Paris Opera')) IS NOT NULL ),
Restaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(
    getTime(atValue(Tour->>'Category', text 'Restaurant')))))
  FROM TempTour
  WHERE getTime(atValue(Tour->>'Category', text 'Restaurant')) IS NOT NULL ),
Movie(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(
    getTime(atValue(Tour->>'Category', text 'Entertainment')) *
    getTime(atValue(Tour->>'Type', text 'Movie')))))
  FROM TempTour
  WHERE getTime(atValue(Tour->>'Category', text 'Entertainment')) IS NOT NULL AND
    getTime(atValue(Tour->>'Type', text 'Movie')) IS NOT NULL )
SELECT DISTINCT h.TourId, startValue(h.Tour->>'StepNo')::integer AS HiltonStep,
  startValue(h.Tour->>'Name') AS HiltonName,
  startValue(r.Tour->>'StepNo')::integer AS RestStep, 
  startValue(r.Tour->>'Name') AS RestName,
  startValue(m.Tour->>'StepNo')::integer AS MovieStep,
  startValue(m.Tour->>'Name') AS MovieName
FROM Hilton h
JOIN Movie m ON h.TourId = m.TourId AND h.Tour < m.Tour
LEFT JOIN Restaurant r ON r.TourId = h.TourId AND h.Tour < r.Tour AND
  r.Tour < m.Tour
ORDER BY TourId, HiltonStep;

/*
 tourid | hiltonstep |     hiltonname     | reststep |    restname     | stepno |  moviename
--------+------------+--------------------+----------+-----------------+--------+--------------
      2 |          1 | Hilton Paris Opera |        3 | Indy Restaurant |         4 | Pathee Opera
      3 |          1 | Hilton Paris Opera |          |                 |         2 | Pathee Opera
*/

/*****************************************************************************/

/*
 Tours that visit a museum and then a restaurant.

Tour[before([Category = 'Museum'],[Category = 'Restaurant'])]
*/


 WITH Museum AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Museum'),
Restaurant AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Restaurant')
SELECT DISTINCT m.TourId, m.StepNo AS MuseumStep, m.PoI->>'Name' AS MuseumName,
  r.StepNo AS RestStep, r.PoI->>'Name' AS RestName
FROM Museum m, Restaurant r
WHERE m.TourId = r.TourId AND m.StepNo < r.StepNo
ORDER BY TourId, MuseumStep;
 

-- TEMPORAL VERSION

WITH Museum(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(
    getTime(atValue(Tour->>'Category', text 'Museum')))))
  FROM TempTour
  WHERE getTime(atValue(Tour->>'Category', text 'Museum')) IS NOT NULL ),
Restaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(
    getTime(atValue(Tour->>'Category', text 'Restaurant')))))
  FROM TempTour
  WHERE getTime(atValue(Tour->>'Category', text 'Restaurant')) IS NOT NULL )
SELECT DISTINCT m.TourId, startValue(m.Tour->>'StepNo')::integer AS MuseumStep,
  startValue(m.Tour->>'Name') AS MuseumName,
  startValue(r.Tour->>'StepNo')::integer AS RestStep, 
  startValue(r.Tour->>'Name') AS RestName
FROM Museum m, Restaurant r 
WHERE m.TourId = r.TourId AND m.Tour < r.Tour
ORDER BY TourId, MuseumStep;

/*****************************************************************************/

/*
Tours where the first step is a French restaurant, and the next step is any museum

Tour[before(^[Category = 'Restaurant' AND TypeOfFood = 'French'],
  [Category = 'Hotel' AND StepNo = 2])]
*/

SELECT f.TourId, f.StepNo AS FirstStep, f.PoI->>'Name' AS FirstName,
  s.StepNo AS SecondStep, s.PoI->>'Name' AS SecondName 
FROM TourPoI f, TourPoI s
WHERE f.TourId = s.TourId AND f.StepNo = 1 AND s.StepNo = 2 AND
  f.PoI @? '$ ? ( @."Category" == "Restaurant" &&
    @."TypeOfFood" == "French" )' AND
  s.PoI @? '$ ? ( @."Category" == "Museum" )'
ORDER BY f.TourId;

/*
 tourid | firststep | firstname  | secondstep |  secondname
--------+-----------+------------+------------+---------------
      1 |         1 | Le Meurice |          2 | Musee d'Orsay
*/

-- TEMPORAL VERSION

WITH FrenchRestaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(Tour @? 
    '$ ? (@."StepNo" == 1 && @."Category" == "Restaurant" && 
      @."TypeOfFood" == "French" )')))) AS Tour
  FROM TempTour 
  WHERE Tour IS NOT NULL ),
Museum(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(Tour @? 
    '$ ? ( @."StepNo" == 2 && @."Category" == "Museum" )'))))
  FROM TempTour )
SELECT f.TourId, startValue(f.Tour->>'StepNo')::integer AS FirstStep, 
  startValue(f.Tour->>'Name') AS FirstName, 
  startValue(s.Tour->>'StepNo')::integer AS SecondStep, 
  startValue(s.Tour->>'Name') AS SecondName
FROM FrenchRestaurant f, Museum s
WHERE f.TourId = s.TourId AND f.Tour < s.Tour
ORDER BY TourId, FirstStep;

/*
 tourid | firststep | firstname  | secondstep |  secondname
--------+-----------+------------+------------+---------------
      1 |         1 | Le Meurice |          2 | Musee d'Orsay
*/

/*****************************************************************************/

/*
Tours that go to the Hilton, then optionally go to various places, and finish at any hotel

Tour[before([Category = 'Hotel' AND Name = 'Hilton Paris Opera'], [Category = 'Hotel']$)]
*/

WITH Hilton AS (
  SELECT *
  FROM TourPoI 
  WHERE PoI->>'Name' = 'Hilton Paris Opera' AND PoI->>'Category' = 'Hotel' ),
AnyHotel AS (
  SELECT *
  FROM TourPoI t1
  WHERE PoI->>'Category' = 'Hotel' AND StepNo = 
    ( SELECT MAX(StepNo) FROM TourPoI t2 WHERE t1.TourId = t2.TourId ) )
SELECT h.TourId, h.StepNo AS StartStep, h.PoI->>'Name' AS StartName,
  a.StepNo AS EndStep, a.PoI->>'Name' AS EndName 
FROM Hilton h, AnyHotel a
WHERE h.TourId = a.TourId AND h.AtTime < a.AtTime 
ORDER BY h.TourId;

/*
 tourid | startstep |     startname      | endstep |      endname
--------+-----------+--------------------+---------+--------------------
      2 |         1 | Hilton Paris Opera |       5 | Hilton Paris Opera
      6 |         1 | Hilton Paris Opera |       5 | Hilton Paris Opera
*/

-- TEMPORAL VERSION

WITH Hilton(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(
    Tour @? '$ ? (@."Category" == "Hotel" && 
      @."Name" == "Hilton Paris Opera" )'))))
  FROM TempTour ),
LastStep(TourId, StepNo) AS (
  SELECT TourId, endValue(Tour->>'StepNo')
  FROM TempTour ),
AnyHotel(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(
    Tour @? '$ ? (@."Category" == "Hotel" )'))))
  FROM TempTour ),
LastHotel(TourId, Tour) AS (
  SELECT a.TourId, Tour
  FROM AnyHotel a, LastStep l 
  WHERE a.TourId = l.TourId AND 
    endValue(a.Tour->>'StepNo') = l.StepNo )
SELECT h.TourId, startValue(h.Tour->>'StepNo')::integer AS StartStep, 
  startValue(h.Tour->>'Name') AS StartName, 
  startValue(l.Tour->>'StepNo')::integer AS EndStep, 
  startValue(l.Tour->>'Name') AS EndName
FROM Hilton h, LastHotel l
WHERE h.TourId = l.TourId AND h.Tour < l.Tour
ORDER BY h.TourId;

/*
 tourid | startstep |     startname      | endstep |      endname
--------+-----------+--------------------+---------+--------------------
      2 |         1 | Hilton Paris Opera |       5 | Hilton Paris Opera
      6 |         1 | Hilton Paris Opera |       5 | Hilton Paris Opera
*/

/*****************************************************************************/
/* COMENTED OUT
/*****************************************************************************/

/*
Tours that go to a French restaurant, then optionally go wherever, and then go back to a hotel

Tour[before([Category = 'Restaurant' AND TypeOfFood = 'French'], [Category = 'Hotel'])]
*/

WITH FrenchRestaurant AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Restaurant' AND PoI->>'TypeOfFood' = 'French' ),
Hotel AS (
  SELECT *
  FROM TourPoI
  WHERE PoI->>'Category' = 'Hotel' )
SELECT DISTINCT f.TourId,
  f.StepNo AS FrenchRestStep, f.PoI->>'Name' AS FrenchRestName,
  h.StepNo AS HotelStep, h.PoI->>'Name' AS HotelName 
FROM FrenchRestaurant f, Hotel h
WHERE h.TourId = f.TourId AND f.AtTime < h.AtTime 
ORDER BY f.TourId;

/*
 tourid | frenchreststep | frenchrestname | hotelstep |     hotelname
--------+----------------+----------------+-----------+--------------------
      1 |              1 | Le Meurice     |         5 | Hilton Paris Opera
      6 |              3 | Le Meurice     |         5 | Hilton Paris Opera
*/

-- TEMPORAL VERSION

WITH FrenchRestaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(
    Tour @? '$ ? ( @."Category" == "Restaurant" &&
      @."TypeOfFood" == "French" )'))))
  FROM TempTour ),
Hotel(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(
    Tour @? '$ ? ( @."Category" == "Hotel" )'))))
  FROM TempTour )
SELECT f.TourId, startValue(f.Tour->>'StepNo')::integer AS FrenchRestStep, 
  startValue(f.Tour->>'Name') AS FirstName, 
  startValue(h.Tour->>'StepNo')::integer AS HotelStep,
  startValue(h.Tour->>'Name') AS HotelName
FROM FrenchRestaurant f, Hotel h
WHERE f.TourId = h.TourId AND f.Tour < h.Tour
ORDER BY TourId, FrenchRestStep;

/*
 tourid | frenchreststep | firstname  | hotelstep |     hotelname
--------+----------------+------------+-----------+--------------------
      1 |              1 | Le Meurice |         5 | Hilton Paris Opera
      6 |              3 | Le Meurice |         5 | Hilton Paris Opera
*/
*/

/*****************************************************************************/

/*
Tours that start at a place that is characterized by an attribute \textsf{price}, then go to either the Eiffel tower or a restaurant, and finish at a place that serves French food and has the same price classification as the initial place.

Tour[before(^[Price = @x],
  ( [Category = 'Restaurant'] OR [Category = 'Landmark' AND Name = 'Eiffel Tower'] ),
  [Category = 'Restaurant' AND TypeOfFood = 'French' AND Price = @x]$)]
*/

WITH StartPlace AS (
  SELECT *, PoI->>'Price' AS StartPrice
  FROM TourPoI
  WHERE PoI ? 'Price' AND StepNo = 1 ),
IntermPlace AS (
  SELECT *
  FROM TourPoI
  WHERE (PoI->>'Category' = 'Landmark' AND PoI->>'Name' = 'Eiffel Tower') OR 
    PoI->>'Category' = 'Restaurant' ),
EndPlace AS (
  SELECT *, PoI->>'Price' AS EndPrice
  FROM TourPoI t1
  WHERE PoI->>'Category' = 'Restaurant' AND PoI->>'TypeOfFood' = 'French' AND
    StepNo = ( SELECT MAX(StepNo) FROM TourPoI t2 
      WHERE t1.TourId = t2.TourId ) )
SELECT DISTINCT s.TourId, s.StepNo AS StartStep, s.PoI->>'Name' AS StartName,
  i.StepNo AS IntermStep, i.PoI->>'Name' AS IntermName,
  e.StepNo AS EndStep, e.PoI->>'Name' AS EndName
FROM StartPlace s, IntermPlace i, EndPlace e
WHERE s.TourId = i.TourId AND s.AtTime < i.AtTime AND
  i.TourId = e.TourId AND i.AtTime < e.AtTime AND s.StartPrice = e.EndPrice
ORDER BY s.TourId;

/*
 tourid | startstep |      startname      | intermstep |  intermname  | endstep |       endname
--------+-----------+---------------------+------------+--------------+---------+---------------------
      8 |         1 | Bistro les Artizans |          2 | Eiffel Tower |       3 | Bistro les Artizans
*/

-- TEMPORAL VERSION

WITH StartPlace(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(getTime(Tour->>'Price'))))
  FROM TempTour 
  WHERE getTime(Tour->>'Price') IS NOT NULL ),
IntermediateStep(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(Tour @? '$ ? ( 
    (@."Category" == "Restaurant") ||
    (@."Category" == "Landmark" && @."Name" == "Eiffel Tower") )'))))
  FROM TempTour ),
EndPlace(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(Tour @?
    '$ ? (@."Category" == "Restaurant" && @."TypeOfFood" == "French")'))))
  FROM TempTour )
SELECT s.TourId, startValue(s.Tour->>'StepNo')::integer AS StartStep,
  startValue(s.Tour->>'Name') AS StartName,
  startValue(i.Tour->>'StepNo')::integer AS IntermStep, 
  startValue(i.Tour->>'Name') AS IntermName,
  startValue(e.Tour->>'StepNo')::integer AS EndStep, 
  startValue(e.Tour->>'Name') AS EndName
FROM StartPlace s, IntermediateStep i, EndPlace e
WHERE s.TourId = i.TourId AND s.Tour < i.Tour AND
  e.TourId = s.TourId AND i.Tour < e.Tour AND
  startValue(s.Tour)->>'Price' = startValue(e.Tour)->>'Price'
ORDER BY TourId, StartStep;

/*
 tourid | startstep |      startname      | intermstep |  intermname  | endstep |       endname
--------+-----------+---------------------+------------+--------------+---------+---------------------
      8 |         1 | Bistro les Artizans |          2 | Eiffel Tower |       3 | Bistro les Artizans
*/


/*****************************************************************************/

/*
Tours that go to a restaurant in the morning during the third quarter of any year

Tour[Category = 'Restaurant' AND lower(AtTime) = @t AND Hour(@t) < 12 AND
  Month(@t) >= 7 AND Month(@t) <= 12 ]
*/

SELECT TourId, StepNo AS RestStep, PoI->>'Name' AS RestName
FROM TourPoI
WHERE PoI->>'Category' = 'Restaurant' AND
  EXTRACT(HOUR FROM lower(AtTime)) < 12 AND
  EXTRACT(MONTH FROM lower(AtTime)) BETWEEN 7 AND 9
ORDER BY TourId, StepNo;

/*
 tourid | reststep |      restname
--------+----------+---------------------
      1 |        1 | Le Meurice
      8 |        1 | Bistro les Artizans
      9 |        2 | Le Petit Italien
*/

-- TEMPORAL VERSION

WITH Restaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour, unnest(spans(whenTrue(
    Tour @? '$ ? ( @."Category" == "Restaurant" )'))))
  FROM TempTour )
SELECT TourId, startValue(Tour->>'StepNo')::integer AS RestStep, 
  startValue(Tour->>'Name') AS RestName
FROM Restaurant
WHERE EXTRACT(HOUR FROM startTimestamp(Tour)) < 12 AND
  EXTRACT(MONTH FROM startTimestamp(Tour)) BETWEEN 7 AND 9;

/*
 tourid | reststep |      restname
--------+----------+---------------------
      1 |        1 | Le Meurice
      8 |        1 | Bistro les Artizans
      9 |        2 | Le Petit Italien
*/

/*****************************************************************************/

/*
Tours that go to two places, where the second one having moderate prices, at the same part of the day, e.g., both of them during the morning

Tour[before([lower(AtTime) = @t AND PartOfDay(@t) = @p], 
  [lower(AtTime) = @t AND Price = 'Moderate' AND PartOfDay(@t) = @p])]
*/

WITH DayPart AS (
 SELECT *,
    CASE
      WHEN EXTRACT(HOUR FROM lower(AtTime)) BETWEEN 8 AND 11
        THEN 'Morning'
      WHEN EXTRACT(HOUR FROM lower(AtTime)) BETWEEN 12 AND 17
        THEN 'Afternoon'
      WHEN EXTRACT(HOUR FROM lower(AtTime)) BETWEEN 18 AND 23
        THEN 'Evening'
      ELSE 'Night'
    END AS partOfDay
  FROM TourPoI )
SELECT DISTINCT f.TourId, f.StepNo AS FirstStep, f.Poi->>'Name' AS FirstName,
  s.StepNo AS SecondStep, s.Poi->>'Name' AS SecondName,
  f.partOfDay AS partOfDay
FROM DayPart f, DayPart s
WHERE f.TourId = s.TourId AND f.AtTime < s.AtTime AND
  s.PoI->>'Price' = 'Moderate' AND f.partOfDay = s.partOfDay
ORDER BY f.TourId;

/*
 tourid | firststep |   firstname   | secondstep |    secondname    | partofday
--------+-----------+---------------+------------+------------------+-----------
      9 |         1 | Musee d'Orsay |          2 | Le Petit Italien | Morning
*/

-- TEMPORAL VERSION

WITH Step(TourId, Tour) AS (
  SELECT TourId, unnest(segments(Tour))
  FROM TempTour ),
DayPart AS (
  SELECT *,
    CASE
      WHEN EXTRACT(HOUR FROM startTimestamp(Tour)) BETWEEN 8 AND 11
        THEN 'Morning'
      WHEN EXTRACT(HOUR FROM startTimestamp(Tour)) BETWEEN 12 AND 17
        THEN 'Afternoon'
      WHEN EXTRACT(HOUR FROM startTimestamp(Tour)) BETWEEN 18 AND 23
        THEN 'Evening'
      ELSE 'Night'
    END AS PartOfDay
  FROM Step )
SELECT DISTINCT f.TourId, startValue(f.Tour->>'StepNo')::integer AS FirstStep,
  startValue(f.Tour->>'Name') AS FirstName,
  startValue(s.Tour->>'StepNo')::integer AS SecondStep,
  startValue(s.Tour->>'Name') AS SecondName, f.PartOfDay
FROM DayPart f, DayPart s
WHERE f.TourId = s.TourId AND startTimestamp(f.Tour) < startTimestamp(s.Tour) AND
  startValue(s.Tour->>'Price') = 'Moderate' AND f.PartOfDay = s.PartOfDay
ORDER BY f.TourId;

/*
 tourid | firststep |   firstname   | secondstep |    secondname    | partofday
--------+-----------+---------------+------------+------------------+-----------
      9 |         1 | Musee d'Orsay |          2 | Le Petit Italien | Morning
*/

/*****************************************************************************/

/*
Tours that go to a place with moderate prices within 1,000m of the `Centre Pompidou'

Tour[Price = 'Moderate' AND ST_DWithin(Geom, ST_Buffer('Centre Pompidou', 1000)]
*/

SELECT DISTINCT t.TourId, t.StepNo, t.PoI->>'Name' AS StepName,
  ST_Distance(t.Geom, p.Geom) AS Distance
FROM TourPoI t, PoI p
WHERE t.PoI->>'Price' = 'Moderate' AND p.Name = 'Centre Pompidou' AND
  ST_DWithin(t.Geom, p.Geom, 1000)
ORDER BY t.TourId;

/*
 tourid | stepno |      stepname       |     distance
--------+--------+---------------------+-------------------
      8 |      1 | Bistro les Artizans | 529.4585913198313
      8 |      3 | Bistro les Artizans | 529.4585913198313
*/

-- TEMPORAL VERSION

WITH ModeratePrices(TourId, Tour, Location) AS (
  SELECT TourId, atTime(Tour, unnest(spans(atValue(Tour->>'Price',
    text 'Moderate')))), Location
  FROM TempTour 
  WHERE atValue(Tour->>'Price', text 'Moderate') IS NOT NULL )
SELECT TourId, startValue(Tour->>'StepNo')::integer AS StepNo,
  startValue(Tour->>'Name') AS StepName, 
  ST_Distance(valueAtTimestamp(m.Location, startTimestamp(Tour)), p.Geom)
  AS Distance
FROM ModeratePrices m, PoI p
WHERE p.Name = 'Centre Pompidou' AND
  ST_DWithin(valueAtTimestamp(m.Location, startTimestamp(Tour)), p.Geom, 1000)
ORDER BY TourId, Tour;

/*
 tourid | stepno |      stepname       |     distance
--------+--------+---------------------+-------------------
      8 |      1 | Bistro les Artizans | 529.4585913198313
      8 |      3 | Bistro les Artizans | 529.4585913198313
*/

/*****************************************************************************/



