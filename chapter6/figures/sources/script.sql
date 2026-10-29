 CREATE TABLE london_pois (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,             -- e.g., 'Restaurant', 'Hotel', 'Cathedral', 'Attraction', 'Landmark'
    cuisine_or_category TEXT,       -- e.g., 'Italian', 'French', 'Hotel', 'Cathedral', 'Zoo', 'Museum', 'Palace'
    price_range TEXT,               -- e.g., 'Cheap', 'Moderate', 'Expensive', '3-star', 'Luxury', NULL
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    geom geometry(Point, 4326)      -- PostGIS geometry column
);

-- Insert all entries
INSERT INTO london_pois (name, type, cuisine_or_category, price_range, latitude, longitude, notes) VALUES
-- Italian Restaurants
('Bocca di Lupo', 'Restaurant', 'Italian', 'Moderate', 51.51172, -0.13400, 'Popular trattoria in Soho, good regional Italian dishes.'),
('Padella', 'Restaurant', 'Italian', 'Cheap', 51.52338, -0.08177, 'Handmade pasta, budget-friendly in Shoreditch.'),
('Lina Stores Soho', 'Restaurant', 'Italian', 'Cheap', 51.5155, -0.1330, 'Cozy deli-style Italian pasta in Soho, good value.'),
-- French Restaurants
('Bob Bob Ricard Soho', 'Restaurant', 'French', 'Expensive', 51.5120, -0.1335, 'Fine dining French/British fusion in Soho.'),
('L''Escargot', 'Restaurant', 'French', 'Moderate', 51.51394, -0.13100, 'Historic French restaurant in Soho, lunch menu more affordable.'),
-- Cathedrals & Attractions
('St Paul''s Cathedral', 'Cathedral', 'Cathedral', NULL, 51.513611, -0.098056, 'Iconic London cathedral.'),
('ZSL London Zoo', 'Attraction', 'Zoo', 'Moderate', 51.5353, -0.1534, 'World-famous zoo in Regent''s Park, London.'),
('British Museum', 'Attraction', 'Museum', 'Free/Moderate', 51.5194, -0.1270, 'World-famous museum in Bloomsbury.'),
-- Landmarks
('Buckingham Palace', 'Landmark', 'Palace', NULL, 51.5014, -0.1419, 'Official London residence of the British monarch.'),
-- Hotels 3-star
('easyHotel London City Shoreditch', 'Hotel', 'Hotel', '3-star', 51.526, -0.079, 'Budget 3-star hotel in Shoreditch / City area.'),
('Royal National Hotel', 'Hotel', 'Hotel', '3-star', 51.52346, -0.12743, 'Large 3-star hotel in Bloomsbury / near Russell Square.'),
('The Z Hotel Leicester Square', 'Hotel', 'Hotel', '3-star', 51.5110, -0.1280, 'Compact central hotel near Leicester Square.'),
('Point A Hotel London Paddington', 'Hotel', 'Hotel', '3-star', 51.5155, -0.175, '3-star hotel near Paddington station.'),
-- Luxury Hotels
('The Ritz London', 'Hotel', 'Hotel', 'Luxury', 51.5073, -0.1419, 'Iconic 5-star hotel in Piccadilly.'),
('Savoy Hotel', 'Hotel', 'Hotel', 'Luxury', 51.5100, -0.1200, 'Historic 5-star hotel near Covent Garden.');

-- Populate the geometry column for all rows
UPDATE london_pois
SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

SELECT * from london_pois


SELECT * FROM (
  -- Itinerary 1
  SELECT
    1, ST_SetSRID(
      ST_MakeLine(ARRAY[
        (SELECT geom FROM london_pois WHERE name = 'The Ritz London'),
        (SELECT geom FROM london_pois WHERE name = 'Buckingham Palace'),
        (SELECT geom FROM london_pois WHERE name = 'Bocca di Lupo'),
        (SELECT geom FROM london_pois WHERE name = 'St Paul''s Cathedral'),
        (SELECT geom FROM london_pois WHERE name = 'L''Escargot'),
        (SELECT geom FROM london_pois WHERE name = 'The Ritz London')
      ]),
      4326
    ) AS geom,
    'Itinerary 1' AS route_name

  UNION ALL

  -- Itinerary 2
  SELECT
    2, ST_SetSRID(
      ST_MakeLine(ARRAY[
        (SELECT geom FROM london_pois WHERE name = 'Royal National Hotel'),
        (SELECT geom FROM london_pois WHERE name = 'British Museum'),
        (SELECT geom FROM london_pois WHERE name = 'Padella'),
        (SELECT geom FROM london_pois WHERE name = 'St Paul''s Cathedral'),
        (SELECT geom FROM london_pois WHERE name = 'Royal National Hotel')
      ]),
      4326
    ) AS geom,
    'Itinerary 2' AS route_name
) AS routes