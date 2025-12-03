## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

### Chapter 7: Large-Scale Mobility Databases

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.


## PROVISORIO  ##

To run Spark applications we assume that Java 21 (can be downloaded the zip version which does not require any installation from \footnote{\url{https://www.azul.com/downloads/}} and spark-4.0.1-bin-hadoop3.tgz file from \footnote{\url{https://spark.apache.org/downloads.html}} and the following environment variables are configured.

$ mkdir /software
$ cd /software  
$ export JAVA_HOME=/software/zulu21.46.19-ca-jdk21.0.9-linux_x64
$ export SPARK_HOME=/software/spark-4.0.1-bin-hadoop3
$ export PATH=JAVA_HOME/bin:$SPARK_HOME/bin:$PATH

Apache Sedona is an external library that enables Spark with spatial funcionalities. 
The 



