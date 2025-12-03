## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 7: Large-Scale Mobility Databases

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.


## PROVISORIO  ##

To run Spark applications we assume that Java 21 (download the zip version which does not require any installation from https://www.azul.com/downloads) and Apache Spark 4.0.1 (download spark-4.0.1-bin-hadoop3.tgz file from https://spark.apache.org/downloads.html) files have been downloaded. Unzip the files (sudo unzip zulu21.46.19-ca-jdk21.0.9-linux_x64.zip and sudo tar xvfz spark-4.0.1-bin-hadoop3.tgz) and configure the following environment variables.


$ mkdir /software
$ cd /software
$ export JAVA_HOME=/software/zulu21.46.19-ca-jdk21.0.9-linux_x64
$ export SPARK_HOME=/software/spark-4.0.1-bin-hadoop3
$ export PATH=JAVA_HOME/bin:$SPARK_HOME/bin:$PATH


Verify that the applications are accessible:
$ javac  -version
$ java   -version
$ spark-submit



Apache Sedona is an external library that enables Spark with spatial funcionalities. 

To include an external Maven JAR in your Spark-SQL session, we can use the "--packages" parameter. 
The parameter format should be groupId:artifactId:version. The information of the library can be find out in Maven Repository. We use the last Apache Sedona version:
https://mvnrepository.com/artifact/org.apache.sedona/sedona-common/1.8.0


<img src="mvn.png" >


The package parameter should be: org.apache.sedona:sedona-spark-shaded-4.0_2.13:1.8.0

Finally, we can run sparq-sql with Sedona:

$ spark-sql --packages org.apache.sedona:sedona-spark-shaded-4.0_2.13:1.8.0   --conf spark.serializer=org.apache.spark.serializer.KryoSerializer   --conf spark.kryo.registrator=org.apache.sedona.viz.core.Serde.SedonaVizKryoRegistrator   --conf spark.sql.extensions=org.apache.sedona.viz.sql.SedonaVizExtensions,org.apache.sedona.sql.SedonaSqlExtensions

or optionally, for CRS transformations, ShapefileReader or GeoTiff reader the extra GeoTools library should be used.

$ spark-sql --packages org.apache.sedona:sedona-spark-shaded-4.0_2.13:1.8.0,org.datasyslab:geotools-wrapper:1.8.0-33.1    --conf spark.serializer=org.apache.spark.serializer.KryoSerializer   --conf spark.kryo.registrator=org.apache.sedona.viz.core.Serde.SedonaVizKryoRegistrator   --conf spark.sql.extensions=org.apache.sedona.viz.sql.SedonaVizExtensions,org.apache.sedona.sql.SedonaSqlExtensions



The application first looks for the files indicated by the "--packages" parameter in the local .m2 repository (typically within $HOME), If the files are not present, then they will be automatically downloaded into the $HOME/.ivy2.5.2/hjars/  directory.

Sparq-sql runs locally by default with as many workers as logical cores are available on the running computer, ideal in a single-machine environment. You can restrict to less workers, by indicating master[3] or local[3].
In a cluster environment, instead of local, we use extra parameters such as master and client. (https://spark.apache.org/docs/latest/submitting-applications.html)

 

Once in the interactive shell we can import csv data (in our case we import all the csv file from the indicated directory) and generate additional columns: duration_ms and also  origin and target geo referenced points.

CREATE TEMPORARY VIEW auxi_trip USING csv OPTIONS (path '/home/mapr/2023-citibike-tripdata', header 'true', inferSchema 'true');


CREATE TEMPORARY VIEW trip as 
SELECT  
st_setsrid( st_point( start_lng, start_lat), 4326) as origin,
st_setsrid( st_point( end_lng, end_lat), 4326) as target,
cast 
(date_part('DAY', ended_at - started_at ) * 24 * 60 * 60 * 1000+
 date_part('HOUR', ended_at - started_at ) * 60 * 1000 +
 date_part('MINUTE', ended_at - started_at ) * 60 * 1000 +
 date_part('SECOND', ended_at - started_at ) * 1000   as int) AS duration_ms, *

FROM
auxi_trip;















