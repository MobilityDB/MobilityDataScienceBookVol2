## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 6: In-memory Mobility Databases

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

### BerlinMOD Data Generator

These files create the BerlinMOD benchmark for the city of Hanoi, based on the hanoi.osm file that can be obtained from OpenStreetMap. To produce the database you shoul follow the step next.

--------------------------
Create the database hanoi_sf0.05 (or your database name)

CREATE EXTENSION MobilityDB Cascade;
create extension pgrouting;
create extension hstore;

osm2pgrouting -h localhost -p 5432 -U postgres -W postgres -f brussels.osm --dbname brussels_sf0.1 -c mapconfig.xml

osm2pgsql   -P 5432 -H localhost -d hanoi_sf0.05 -c -U postgres -W --proj=3857 hanoi.osm

psql -d hanoi_sf0.05 -p 5432 (or your port) -h localhost

 \i hanoi_preparedata.sql
 \i hanoi_datagenerator.sql
 
 select hanoi_datagenerator(0.05);

----------------------------------------

