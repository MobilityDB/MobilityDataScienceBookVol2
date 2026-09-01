FROM debian:bookworm-slim

# Install dependencies + Amazon Corretto JDK 21
RUN apt-get update \
  && apt-get install -y git curl gnupg build-essential cmake \
     libgeos-dev libproj-dev libjson-c-dev libgsl-dev \
  && export GNUPGHOME="$(mktemp -d)" \
  && curl -fL https://apt.corretto.aws/corretto.key | gpg --batch --import \
  && gpg --batch --export '6DC3636DAE534049C8B94623A122542AB04F24E3' > /usr/share/keyrings/corretto.gpg \
  && rm -r "$GNUPGHOME" \
  && unset GNUPGHOME \
  && echo "deb [signed-by=/usr/share/keyrings/corretto.gpg] https://apt.corretto.aws stable main" > /etc/apt/sources.list.d/corretto.list \
  && apt-get update \
  && apt-get install -y java-21-amazon-corretto-jdk \
  && apt-get install -y unzip

# Build MobilityDB with MEOS enabled
RUN git clone --depth 1 https://github.com/MobilityDB/MobilityDB.git -b master /usr/local/src/MobilityDB
RUN mkdir -p /usr/local/src/MobilityDB/build
RUN cd /usr/local/src/MobilityDB/build && \
    cmake -DMEOS=ON .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Install Maven 3.9.6
ENV MAVEN_HOME=/usr/share/maven
ENV MAVEN_CONFIG="/root/.m2"
COPY --from=maven:3.9.6-eclipse-temurin-11 ${MAVEN_HOME} ${MAVEN_HOME}
COPY --from=maven:3.9.6-eclipse-temurin-11 /usr/local/bin/mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
COPY --from=maven:3.9.6-eclipse-temurin-11 /usr/share/maven/ref/settings-docker.xml /usr/share/maven/ref/settings-docker.xml
RUN ln -s ${MAVEN_HOME}/bin/mvn /usr/bin/mvn

# Clone the examples repository
# RUN git clone https://github.com/MobilityDB/JMEOS-examples /usr/local/jmeos-examples


##################
# No puedo copiar el jar . En jashan esta y ocupa mas de 25 mega.
# el pudo poner mas de 25 mega. Nosotros noooo
###################


## POR AHORA LO COPIO LOCAL

RUN mkdir -p /usr/local/jmeos-examples/lib/jar 


COPY JMEOS-fat.jar  /usr/local/jmeos-examples/lib/jar/JMEOS-fat.jar 

COPY chapterJMEOS-1.0-jar-with-dependencies.jar  /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar 



# Copy libmeos.so so JarLibraryLoader can find it
#RUN mkdir -p /usr/local/jmeos-examples/src && \
#    cp /usr/local/lib/libmeos.so /usr/local/jmeos-examples/src/libmeos.so



RUN mkdir -p /data && cd /data && \
    jar xf /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar    berlinmod_trips.csv && \
    jar xf /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar    brussels_communes.csv  && \
    jar xf /usr/local/jmeos-examples/chapterJMEOS-1.0-jar-with-dependencies.jar    brussels_region.csv







RUN mkdir -p /data && \
    curl -L \
    -o /data/aisdk-2024-03-04.zip \
    http://aisdata.ais.dk/2024/aisdk-2024-03-04.zip && \
    unzip /data/aisdk-2024-03-04.zip -d /data && \
    rm -f /data/aisdk-2024-03-04.zip

ENV LD_LIBRARY_PATH=/usr/local/lib

# CLEAN_UP
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && apt-get remove --purge --autoremove -y curl gnupg

WORKDIR /usr/local/jmeos-examples
CMD ["/bin/bash"]