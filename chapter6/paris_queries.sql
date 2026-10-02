/*****************************************************************************
 * Queries over the Paris tours of chapter 6, in the order of the chapter.
 * Each query is preceded by the pattern it expresses. When the chapter gives
 * both versions, the discrete query, over the view TourPoI, comes first and
 * the continuous query, over the table TempTour, second; the two return the
 * same rows. The tables are built by paris_tours.sql.
 *****************************************************************************/

SET TIMEZONE TO 'UTC';

-------------------------------------------------------------------------------

/* Pattern
  Tour[before([Category = 'Museum'],[Category = 'Restaurant'])]
*/

-- Discrete version
WITH Museum AS ( SELECT * FROM TourPoI
  WHERE PoI->>'Category' = 'Museum'),
Restaurant AS ( SELECT * FROM TourPoI
  WHERE PoI->>'Category' = 'Restaurant')
SELECT DISTINCT m.TourId, m.StepNo AS MuseumStep,
  r.StepNo AS RestStep, m.PoI->>'Name' AS MuseumName,
  r.PoI->>'Name' AS RestName
FROM Museum m, Restaurant r WHERE m.TourId = r.TourId
  AND m.StepNo < r.StepNo ORDER BY TourId, MuseumStep;
/* ...
  10 | 1 | 2 | Musee d'Orsay   | Le Meurice
  10 | 1 | 4 | Musee d'Orsay   | Le Petit Italien
  10 | 3 | 4 | Musee du Louvre | Le Petit Italien */

-- Continuous version
WITH Museum(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(getTime(atValue(Tour->>'Category',
    text 'Museum'))))) FROM TempTour ),
Restaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(getTime(atValue(Tour->>'Category',
    text 'Restaurant'))))) FROM TempTour )
SELECT DISTINCT m.TourId,
  startValue(m.Tour->>'StepNo')::integer AS MuseumStep,
  startValue(r.Tour->>'StepNo')::integer AS RestStep,
    startValue(m.Tour->>'Name') AS MuseumName,
  startValue(r.Tour->>'Name') AS RestName
FROM Museum m, Restaurant r WHERE m.TourId = r.TourId
  AND m.Tour <<# r.Tour ORDER BY TourId, MuseumStep;

-------------------------------------------------------------------------------

/* Pattern
  Tour[before([Category = 'Museum'],[Category = 'Restaurant'],
  [Category = 'Museum']) OR
  before([Category = 'Restaurant'],[Category = 'Museum'],
  [Category = 'Restaurant'])]
*/

-- Discrete version
WITH Steps(TourId, StepNo1, StepNo2, StepNo3, Cat1, Cat2,
  Cat3) AS (
  SELECT TourId, LAG(StepNo) OVER w, StepNo, LEAD(StepNo) OVER w,
    LAG(PoI->>'Category') OVER w, PoI->>'Category',
      LEAD(PoI->>'Category') OVER w
  FROM TourPoI WINDOW w AS (PARTITION BY TourId ORDER BY StepNo) )
SELECT TourId, StepNo1, StepNo2, StepNo3, Cat1, Cat2, Cat3
  FROM Steps
WHERE StepNo1 = StepNo2 - 1 AND StepNo2 = StepNo3 - 1 AND
  ((Cat1 = 'Museum' AND Cat2 = 'Restaurant' AND Cat3 = 'Museum')
    OR
   (Cat1 = 'Restaurant' AND Cat2 = 'Museum'
     AND Cat3 = 'Restaurant'))
ORDER BY TourId, StepNo1, StepNo2;
/* ...
   10 | 1 | 2 | 3 | Museum     | Restaurant | Museum
   10 | 2 | 3 | 4 | Restaurant | Museum     | Restaurant
   10 | 3 | 4 | 5 | Museum     | Restaurant | Museum */

-------------------------------------------------------------------------------

/* Pattern
  Tour[before([Category = 'Hotel'
  AND Name = 'Hilton Paris Opera'], [Category = 'Restaurant']*,
  [Category = 'Entertainment' AND Type = 'Movie'])]
*/

-- Discrete version
WITH Hilton AS ( SELECT * FROM TourPoI
  WHERE PoI->>'Category' = 'Hotel'
  AND PoI->>'Name' = 'Hilton Paris Opera' ),
Restaurant AS ( SELECT * FROM TourPoI
  WHERE PoI->>'Category' = 'Restaurant' ),
Movie AS ( SELECT * FROM TourPoI
  WHERE PoI->>'Category' = 'Entertainment'
  AND PoI->>'Type' = 'Movie' )
SELECT DISTINCT h.TourId, h.StepNo AS HiltonStep,
  h.PoI->>'Name' AS HiltonName, r.StepNo AS RestStep,
  r.PoI->>'Name' AS RestName, m.StepNo AS MovieStep,
    m.PoI->>'Name' AS MovieName
FROM Hilton h JOIN Movie m ON m.TourId = h.TourId
  AND h.AtTime < m.AtTime LEFT JOIN Restaurant r ON
  r.TourId = h.TourId AND h.AtTime < r.AtTime
    AND r.AtTime < m.AtTime ORDER BY h.TourId, h.StepNo;
/* 2 | 1 | Hilton Paris Opera | 3 | Indy Restaurant | 4 | Pathee
  Opera
  3 | 1 | Hilton Paris Opera | - | - | 2 | Pathee Opera */

-- Continuous version
WITH Hilton(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(getTime(atValue(Tour->>'Category',
    text 'Hotel')) *
    getTime(atValue(Tour->>'Name', text 'Hilton Paris Opera')))))
      FROM TempTour ),
Restaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(getTime(atValue(Tour->>'Category',
    text 'Restaurant'))))) FROM TempTour ),
Movie(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(getTime(atValue(Tour->>'Category',
    text 'Entertainment')) *
    getTime(atValue(Tour->>'Type', text 'Movie')))))
      FROM TempTour )
SELECT DISTINCT h.TourId,
  startValue(h.Tour->>'StepNo')::integer AS HiltonStep,
  startValue(h.Tour->>'Name') AS HiltonName,
  startValue(r.Tour->>'StepNo')::integer AS RestStep,
    startValue(r.Tour->>'Name') AS RestName,
  startValue(m.Tour->>'StepNo')::integer AS MovieStep,
    startValue(m.Tour->>'Name') AS MovieName
FROM Hilton h JOIN Movie m ON h.TourId = m.TourId
  AND h.Tour <<# m.Tour
  LEFT JOIN Restaurant r ON r.TourId = h.TourId
    AND h.Tour <<# r.Tour AND r.Tour <<# m.Tour
    ORDER BY TourId, HiltonStep;

-------------------------------------------------------------------------------

/* Pattern
  Tour[before(^[Category = 'Restaurant'
  AND TypeOfFood = 'French'], [Category = 'Museum'
  AND StepNo = 2],
  [Category = 'Hotel']$)]
*/

-- Discrete version
WITH LastStep(TourId, StepNo) AS (
  SELECT TourId, MAX(StepNo) FROM TourPoI GROUP BY TourId )
SELECT f.TourId, f.StepNo AS FirstStep, f.PoI->>'Name' AS FirstName,
  s.StepNo AS SecondStep, s.PoI->>'Name' AS SecondName,
  h.StepNo AS LastStep, h.PoI->>'Name' AS LastName
FROM TourPoI f, TourPoI s, TourPoI h, LastStep l
WHERE f.TourId = s.TourId AND s.TourId = h.TourId
  AND h.TourId = l.TourId AND f.StepNo = 1 AND s.StepNo = 2
  AND h.StepNo = l.StepNo AND s.AtTime < h.AtTime
  AND f.PoI @? '$ ? ( @."Category" == "Restaurant" &&
    @."TypeOfFood" == "French" )'
  AND s.PoI @? '$ ? ( @."Category" == "Museum" )'
  AND h.PoI @? '$ ? ( @."Category" == "Hotel" )'
ORDER BY f.TourId;

-- Continuous version
WITH FrenchRestaurant(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(whenTrue(Tour @?
    '$ ? (@."StepNo" == 1 && @."Category" == "Restaurant" &&
    @."TypeOfFood" == "French" )')))) FROM TempTour ),
Museum(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(whenTrue(Tour @?
    '$ ? ( @."StepNo" == 2 && @."Category" == "Museum" )'))))
  FROM TempTour ),
Hotel(TourId, Tour) AS (
  SELECT TourId, atTime(Tour,
    unnest(spans(whenTrue(Tour @?
    '$ ? ( @."Category" == "Hotel" )')))) FROM TempTour ),
LastHotel(TourId, Tour) AS (
  SELECT h.TourId, h.Tour FROM Hotel h, TempTour t
  WHERE h.TourId = t.TourId
    AND endValue(h.Tour->>'StepNo') = endValue(t.Tour->>'StepNo')
    )
SELECT f.TourId,
  startValue(f.Tour->>'StepNo')::integer AS FirstStep,
  startValue(f.Tour->>'Name') AS FirstName,
  startValue(s.Tour->>'StepNo')::integer AS SecondStep,
    startValue(s.Tour->>'Name') AS SecondName,
  startValue(l.Tour->>'StepNo')::integer AS LastStep,
    startValue(l.Tour->>'Name') AS LastName
FROM FrenchRestaurant f, Museum s, LastHotel l
WHERE f.TourId = s.TourId AND s.TourId = l.TourId
  AND f.Tour <<# s.Tour AND s.Tour <<# l.Tour
  ORDER BY TourId, FirstStep;

-------------------------------------------------------------------------------

/* Pattern
  StartPlace: Tour[^has(Price)]; Price = @p1
  MiddlePlace: Tour[Category = 'Museum' OR (Category = 'Landmark'
  AND Name = 'Eiffel Tower')]
  EndPlace: Tour[Category = 'Restaurant' AND TypeOfFood = 'French'
  AND has(Price)$]; Price = @p2
  Tour[before(StartPlace, MiddlePlace, EndPlace)] AND @p1 = @p2
*/

-- Discrete version
WITH StartPlace AS ( SELECT *, PoI->>'Price' AS StartPrice
  FROM TourPoI WHERE PoI ? 'Price' AND StepNo = 1 ),
IntermPlace AS (
  SELECT * FROM TourPoI WHERE (PoI->>'Category' = 'Landmark'
    AND PoI->>'Name' = 'Eiffel Tower') OR
    PoI->>'Category' = 'Museum' ),
EndPlace AS (
  SELECT *, PoI->>'Price' AS EndPrice FROM TourPoI t1
    WHERE PoI->>'Category' = 'Restaurant' AND
    PoI->>'TypeOfFood' = 'French' AND StepNo = (
      SELECT MAX(StepNo) FROM TourPoI t2
      WHERE t1.TourId = t2.TourId ) )
SELECT DISTINCT s.TourId, s.StepNo AS StartStep,
  s.PoI->>'Name' AS StartName, i.StepNo AS IntermStep,
  i.PoI->>'Name' AS IntermName, e.StepNo AS EndStep,
    e.PoI->>'Name' AS EndName
FROM StartPlace s, IntermPlace i, EndPlace e
  WHERE s.TourId = i.TourId AND s.AtTime < i.AtTime AND
  i.TourId = e.TourId AND i.AtTime < e.AtTime
    AND s.StartPrice = e.EndPrice ORDER BY s.TourId;

-------------------------------------------------------------------------------

/* Pattern
  Tour[Category = 'Restaurant']; lower(AtTime) = @t
  AND Hour(@t) < 12 AND Month(@t) >= 7 AND Month(@t) <= 9
*/

-- Discrete version
SELECT TourId, StepNo AS RestStep, PoI->>'Name' AS RestName
  FROM TourPoI
WHERE PoI->>'Category' = 'Restaurant' AND EXTRACT(HOUR
  FROM lower(AtTime)) < 12 AND
  EXTRACT(MONTH FROM lower(AtTime)) BETWEEN 7 AND 9
    ORDER BY TourId, StepNo;

-------------------------------------------------------------------------------

/* Pattern
  FirstPlace: Tour[StepNo >=1]; lower(AtTime) = @t1
  AND PartOfDay(@t1) = @p1,
  SecondPlace: Tour[Price = 'Moderate']; lower(AtTime) = @t2
  AND PartOfDay(@t2) = @p2,
  Tour[before(FirstPlace,SecondPlace)]; @p1 = @p2
*/

-- Discrete version
WITH DayPart AS (
  SELECT *,
    CASE WHEN EXTRACT(HOUR FROM lower(AtTime)) BETWEEN 8 AND 11
      THEN 'Morning'
    WHEN EXTRACT(HOUR FROM lower(AtTime)) BETWEEN 12 AND 17
      THEN 'Afternoon'
    WHEN EXTRACT(HOUR FROM lower(AtTime)) BETWEEN 18 AND 23
      THEN 'Evening'
    ELSE 'Night' END AS PartOfDay
  FROM TourPoI )
SELECT DISTINCT f.TourId, f.StepNo AS FirstStep,
  f.PoI->>'Name' AS FirstName, s.StepNo AS SecondStep,
  s.PoI->>'Name' AS SecondName, f.PartOfDay
    FROM DayPart f, DayPart s
WHERE f.TourId = s.TourId AND f.AtTime < s.AtTime
  AND s.PoI->>'Price' = 'Moderate' AND f.PartOfDay = s.PartOfDay
ORDER BY f.TourId;

-- Continuous version
WITH Step(TourId, Tour) AS (SELECT TourId, unnest(segments(Tour))
  FROM TempTour ),
DayPart(TourId, Tour, PartOfDay) AS (
  SELECT TourId, Tour,
    CASE WHEN EXTRACT(HOUR FROM startTimestamp(Tour))
      BETWEEN 8 AND 11 THEN 'Morning'
    WHEN EXTRACT(HOUR FROM startTimestamp(Tour))
      BETWEEN 12 AND 17 THEN 'Afternoon'
    WHEN EXTRACT(HOUR FROM startTimestamp(Tour))
      BETWEEN 18 AND 23 THEN 'Evening'
    ELSE 'Night' END
  FROM Step )
SELECT DISTINCT f.TourId,
  startValue(f.Tour->>'StepNo')::integer AS FirstStep,
  startValue(f.Tour->>'Name') AS FirstName,
 startValue(s.Tour->>'StepNo')::integer AS SecondStep,
   startValue(s.Tour->>'Name') AS SecondName, f.PartOfDay
FROM DayPart f, DayPart s
WHERE f.TourId = s.TourId AND f.Tour <<# s.Tour
  AND startValue(s.Tour->>'Price') = 'Moderate'
  AND f.PartOfDay = s.PartOfDay
ORDER BY f.TourId;

-------------------------------------------------------------------------------

/* Pattern
  Tour[Price = 'Moderate' AND ST_DWithin(Geom,
  ST_Buffer('Centre Pompidou', 1000))]
*/

-- Discrete version
SELECT DISTINCT t.TourId, t.StepNo, t.PoI->>'Name' AS StepName,
  ST_Distance(t.Geom, p.Geom) AS Distance
FROM TourPoI t, PoI p WHERE t.PoI->>'Price' = 'Moderate'
  AND p.Name = 'Centre Pompidou' AND
  ST_DWithin(t.Geom, p.Geom, 1000) ORDER BY t.TourId;

-- Continuous version
WITH ModeratePrices(TourId, Tour, Location) AS (
  SELECT TourId, atTime(Tour, unnest(spans(atValue(Tour->>'Price',
    text 'Moderate')))), Location FROM TempTour )
SELECT TourId, startValue(Tour->>'StepNo')::integer AS StepNo,
  startValue(Tour->>'Name') AS StepName,
  ST_Distance(valueAtTimestamp(m.Location, startTimestamp(Tour)),
    p.Geom) AS Distance
FROM ModeratePrices m, PoI p WHERE p.Name = 'Centre Pompidou' AND
  ST_DWithin(valueAtTimestamp(m.Location, startTimestamp(Tour)),
    p.Geom, 1000) ORDER BY TourId, Tour;
