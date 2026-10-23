/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

-- The five Flock examples of chapter 7 (Queries pipeline1 to pipeline5), on DuckDB v1.5.5 with
-- Flock from the community repository and two Ollama models: llama3 and gpt-oss:20b.
-- Run from this directory, after export_tables.sql has written the three Parquet files:
--
--   duckdb flock.duckdb -c ".read flock_pipelines.sql"
--
-- Both models answer one row per call ("max_batch_size": 1) and gpt-oss reasons at the low
-- level ("think": "low"), the setting of results/run.log, with Ollama 0.24.0 serving them.
-- The tables are the BerlinMOD-Hanoi data of scale factor 0.01 (hanoi_sf0.01.zip of
-- github.com/MobilityDB/MobilityDB-BerlinMOD-Hanoi), geometries as WKT in EPSG:3857.
-- Every result is written to results/ as Parquet and as CSV.
.timer on
INSTALL flock FROM community;
LOAD flock;
CREATE SECRET (TYPE OLLAMA, API_URL '127.0.0.1:11434');

CREATE OR REPLACE TABLE Points AS FROM 'points.parquet';
CREATE OR REPLACE TABLE Municipalities AS FROM 'municipalities.parquet';
CREATE OR REPLACE TABLE Vehicles AS FROM 'vehicles.parquet';

CREATE MODEL('flockmodel-llama',
  'llama3',
  'ollama',
  {"tuple_format": "json", "max_batch_size": 1, "model_parameters": {"temperature": 0.7}});
CREATE MODEL('flockmodel-gptoss',
  'gpt-oss:20b',
  'ollama',
  {"tuple_format": "json", "max_batch_size": 1, "model_parameters": {"temperature": 0.7, "think": "low"}});

-- pipeline1: the district and an attraction of selected points (gpt-oss)
CREATE PROMPT('PlacesDesc',
  'First, transform  the points, given in SRID=3857, to SRID=4326, and then, give me
  the district in Hanoi, Vietnam, where the points are located, together with a
  short description -in less than ten words- of the closest point of interest.');
CREATE OR REPLACE TABLE Pipeline1 AS
WITH PointsShort AS (
  SELECT *
  FROM Points
  WHERE PointId IN(8,51,56,94,33,85,78,39,90,80) ),
PointsExpanded AS (
  SELECT *,
    llm_complete(
      {'model_name': 'flockmodel-gptoss'},
      {'prompt_name': 'PlacesDesc', 'context_columns':
         [{'data': geom}]}) AS PlaceDesc
  FROM PointsShort )
SELECT *
FROM PointsExpanded;
COPY (FROM Pipeline1 ORDER BY PointId) TO 'results/pipeline1.parquet';
COPY (FROM Pipeline1 ORDER BY PointId) TO 'results/pipeline1.csv';

-- pipeline2: the top three attractions of fifteen districts (llama3)
CREATE PROMPT('DistrictAttraction',
  'You are a travel advisor. Give me the names of  the top three main attractions
  (cultural, religious, sports)  in the District, in Hanoi, Vietnam.
  Also give a ten-words description');
CREATE OR REPLACE TABLE DistrictsExpanded AS
WITH Districts AS (
  SELECT *
  FROM Municipalities
  ORDER BY MunicipalityId
  LIMIT 15),
DistrictsExp AS (
  SELECT *, llm_complete(
    {'model_name': 'flockmodel-llama'},
    {'prompt_name': 'DistrictAttraction',
    'context_columns': [{'data': municipalityname}]}) AS DistrictAttr
  FROM Districts )
SELECT *
FROM DistrictsExp;
COPY (SELECT MunicipalityId, MunicipalityName, DistrictAttr FROM DistrictsExpanded ORDER BY MunicipalityId) TO 'results/pipeline2.parquet';
COPY (SELECT MunicipalityId, MunicipalityName, DistrictAttr FROM DistrictsExpanded ORDER BY MunicipalityId) TO 'results/pipeline2.csv';

-- pipeline3: places of twelve points by llama3, kept when gpt-oss judges them cultural
CREATE PROMPT('CulturalAttractions',
  'You are a travel expert. Keep the places ONLY if they are cultural attractions
  (not leisure, sports, etc.), also give a description');
CREATE OR REPLACE TABLE PointsExpanded AS
WITH PointsShort AS (
  SELECT *
  FROM Points where PointId IN(8,45, 96, 51,56,94,33,85,78,39,90,80) ),
PointsExp AS (
  SELECT *, llm_complete(
  {'model_name': 'flockmodel-llama'},
  {'prompt_name': 'PlacesDesc', 'context_columns': [{'data': geom}]}) AS Place
  FROM PointsShort )
SELECT *
FROM PointsExp;
COPY (SELECT PointId, Place FROM PointsExpanded ORDER BY PointId) TO 'results/pipeline3_places.csv';
CREATE OR REPLACE TABLE Pipeline3 AS
SELECT pointid, Place
FROM PointsExpanded
WHERE llm_filter(
  {'model_name': 'flockmodel-gptoss'},
  {'prompt_name': 'CulturalAttractions',
  'context_columns': [{'data': Place}]});
COPY (FROM Pipeline3 ORDER BY PointId) TO 'results/pipeline3.parquet';
COPY (FROM Pipeline3 ORDER BY PointId) TO 'results/pipeline3.csv';

-- pipeline4: one summary of the models of each vehicle type (llama3)
CREATE OR REPLACE TABLE VehicleReduced AS
SELECT row_number() OVER (ORDER BY vehicletype) AS Id, vehicletype, categoryDesc
FROM (
  SELECT vehicletype,
    llm_reduce({'model_name': 'flockmodel-llama'},
      {'prompt' : 'Summarize the characteristics of each type of vehicles in the
        corresponding category', 'context_columns': [{'data': model}]}) AS categoryDesc
  FROM Vehicles
  GROUP BY vehicletype );
COPY (FROM VehicleReduced ORDER BY Id) TO 'results/pipeline4.parquet';
COPY (FROM VehicleReduced ORDER BY Id) TO 'results/pipeline4.csv';

-- pipeline5: the similarity of the summaries by their embeddings (llama3)
CREATE OR REPLACE TABLE VehicleEmbed AS
SELECT Id, vehicletype, categoryDesc,
  llm_embedding(
    {'model_name': 'flockmodel-llama'},
    {'context_columns': [{'data': categoryDesc}]}) AS VehEmbedding
FROM VehicleReduced;
SELECT Id, len(VehEmbedding) AS dimension FROM VehicleEmbed ORDER BY Id;
CREATE OR REPLACE TABLE Pipeline5All AS
SELECT v1.Id AS Id1, v2.Id AS Id2, v1.categoryDesc AS Description1,
  v2.categoryDesc AS Description2,
  array_cosine_similarity(v1.vehembedding::DOUBLE[4096],
  v2.vehembedding::DOUBLE[4096]) AS similarity
FROM VehicleEmbed v1 JOIN VehicleEmbed v2
  ON v1.id < v2.id AND v1.vehicletype != v2.vehicletype;
COPY (FROM Pipeline5All ORDER BY Id1, Id2) TO 'results/pipeline5_all.csv';
COPY (FROM Pipeline5All WHERE similarity > 0.8 ORDER BY Id1, Id2) TO 'results/pipeline5.csv';
