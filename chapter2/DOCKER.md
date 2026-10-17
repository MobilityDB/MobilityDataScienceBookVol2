Generate docker container  (chapterJMEOS-1.0-jar-with-dependencies.jar and JMEOS-fat.jar  within Dockerfile directory)

docker build -t jmeos-examples:latest .

docker run -it --name jmeos-examples jmeos-examples:latest /bin/bash


Then,  run the examples. For instance
java -cp /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar:/usr/local/jmeos-examples/lib/jar/JMEOS-fat.jar   book.examples.JMEOS07

java -cp /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar:/usr/local/jmeos-examples/lib/jar/JMEOS-fat.jar   book.examples.JMEOS06

java -cp /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar:/usr/local/jmeos-examples/lib/jar/JMEOS-fat.jar   book.examples.JMEOS01

etc

