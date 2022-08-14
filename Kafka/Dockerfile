FROM centos:7 AS builder

ARG cruise_control_metrics_reporter_version=2.5.45
ENV JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk"

RUN yum -y install git java-1.8.0-openjdk-devel
RUN git clone --branch $cruise_control_metrics_reporter_version https://github.com/linkedin/cruise-control.git
RUN cd cruise-control \
    && ./gradlew jar :cruise-control-metric-reporter:jar


FROM openjdk:11-jre-slim
LABEL org.aashayein.image.authors="avishek.akd@gmail.com"

ARG kafka_version=3.2.1
ARG scala_version=2.13
ARG jmx_prometheus_javaagent_version=0.17.0
ARG cruise_control_metrics_reporter_version=2.5.45
ARG KAFKA_DOWNLOAD_URL=https://downloads.apache.org/kafka
ARG KAFKA_DOWNLOAD_SHA=9b7ee73c9c088e2b1d15685cd1330546054bcf1f025f4825fadccd5076763230229480d87900ca4a8317cd01a36bec1082fcadfab7d220a415787e1ba2e3c9cf
ARG PROMETHEUS_JAVA_AGENT_DOWNLOAD_URL=https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent
ENV KAFKA_VERSION=$kafka_version \
    SCALA_VERSION=$scala_version \
    PROMETHEUS_JAVA_AGENT_VERSION=$jmx_prometheus_javaagent_version \
    CC_METRICS_REPORTER_VERSION=$cruise_control_metrics_reporter_version \
    KAFKA_HOME=/opt/kafka \
    PATH=${PATH}:${KAFKA_HOME}/bin

RUN set -eux ; \
    apt-get update ; \
    apt-get upgrade -y ; \
    apt-get install -y --no-install-recommends dnsutils wget curl libdigest-sha-perl ; \
    wget -O /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ${KAFKA_DOWNLOAD_URL}/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ; \
    shasum -a 512 /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz > checksum.txt ; \
    echo "$KAFKA_DOWNLOAD_SHA kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz" ; \
    tar xfz /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C /opt ; \
    rm /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ; \
    ln -s /opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION} ${KAFKA_HOME} ; \
    wget -O $KAFKA_HOME/libs/jmx_prometheus_javaagent-$PROMETHEUS_JAVA_AGENT_VERSION.jar $PROMETHEUS_JAVA_AGENT_DOWNLOAD_URL/$PROMETHEUS_JAVA_AGENT_VERSION/jmx_prometheus_javaagent-$PROMETHEUS_JAVA_AGENT_VERSION.jar ; \
    rm -rf /tmp/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ; \
    rm -rf /var/lib/apt/lists/* ; \
    mkdir $KAFKA_HOME/ssl ; \
    mkdir $KAFKA_HOME/data

COPY --from=builder cruise-control/cruise-control-metrics-reporter/build/libs/* ${KAFKA_HOME}/libs/
COPY ./config ${KAFKA_HOME}/config/kraft/
COPY ./entrypoint.sh /

RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT ["/entrypoint.sh"]

# https://github.com/confluentinc/confluent-platform-security-tools/blob/master/single-trust-store-diagram.pdf
# https://medium.com/jinternals/kafka-ssl-setup-with-self-signed-certificate-part-1-c2679a57e16c
