#!/bin/bash
set -e

# ==================================== Mandatory configs ==================================== #
if [[ -z "$NAMESPACE" ]]; then
    echo "Provide k8 namespace"
    exit 1
fi

if [[ -z "$PROCESS_ROLES" ]]; then
    echo "Provide kafka process role"
    exit 1
fi
# ==================================== Set Default Configs ==================================== #
CONFIG_FILE="kafka.$PROCESS_ROLES.properties"
CONFIG_PATH="$KAFKA_HOME/config/kraft/$CONFIG_FILE"
VALIDITY="3650"
SSL_PATH="/opt/kafka/ssl"
cp /tmp/ca/* $SSL_PATH
CA_KEY_FILE="$SSL_PATH/ca-key"
CA_CERT_FILE="$SSL_PATH/ca-root-cert"
CA_ALIAS="ca-cert"
CSR_FILE="$SSL_PATH/ca-request-$PROCESS_ROLES"
CSR_SIGNED_FILE="$SSL_PATH/ca-signed-$PROCESS_ROLES"
HOST_NAME=`hostname`
HOST_FQDN=`hostname  -f`
NODE_ID=${HOST_NAME##*-}

if [ $PROCESS_ROLES == "broker" ]; then
    NODE_ID="10$NODE_ID"
fi

if [[ -z "$PORT" ]]; then
    PORT=9092
fi

if [[ -z "$EXTERNAL_PORT" ]]; then
    EXTERNAL_PORT=9093
fi

if [[ -z "$INTERNAL_PORT" ]]; then
    INTERNAL_PORT=9094
fi

if [[ -z "$PROMETHEUS_PORT" ]]; then
    PROMETHEUS_PORT=9090
fi

if [[ -z "$CONTROLLER_REPLICAS" ]]; then
    CONTROLLER_REPLICAS=3
fi

if [[ -z "$CONTROLLER_QUORUM_VOTERS" ]]; then
    CONTROLLER_QUORUM_VOTERS=""
    for (( i=0; i<$CONTROLLER_REPLICAS; i++))
    do
        CONTROLLER_QUORUM_VOTERS+="$i@controller-$i.controller-svc.$NAMESPACE.svc.cluster.local:$PORT"

        if [ $i != `expr $CONTROLLER_REPLICAS - 1` ] 
        then
            CONTROLLER_QUORUM_VOTERS+="," 
        fi
    done
fi

if [[ -z "$INTER_KAFKA_LISTENER_NAME" ]]; then
    INTER_KAFKA_LISTENER_NAME="BROKER"
fi

if [[ -z "$CONTROLLER_LISTENER_NAMES" ]]; then
    CONTROLLER_LISTENER_NAMES="CONTROLLER"
fi

if [[ -z "$LISTENERS" ]]; then
    if [ $PROCESS_ROLES == "broker" ]
    then
        LISTENERS="EXTERNAL://:$EXTERNAL_PORT,INTERNAL://:$INTERNAL_PORT,$INTER_KAFKA_LISTENER_NAME://:$PORT"
    else
        LISTENERS="$CONTROLLER_LISTENER_NAMES://:$PORT"
    fi
fi
ESCAPED_LISTENERS=$(printf '%s\n' "$LISTENERS" | sed -e 's/[\/&]/\\&/g')

if [[ -z "$ADVERTISED_LISTENERS" ]]; then
    if [ $PROCESS_ROLES == "broker" ]
    then
        ADVERTISED_LISTENERS="EXTERNAL://$HOST_FQDN:$EXTERNAL_PORT,INTERNAL://$HOST_FQDN:$INTERNAL_PORT,$INTER_KAFKA_LISTENER_NAME://$HOST_FQDN:$PORT"
    else
        ADVERTISED_LISTENERS="$CONTROLLER_LISTENER_NAMES://$HOST_FQDN:$PORT"
    fi
fi
ESCAPED_ADVERTISED_LISTENERS=$(printf '%s\n' "$ADVERTISED_LISTENERS" | sed -e 's/[\/&]/\\&/g')

if [[ -z "$INTER_BROKER_LISTENER_NAME" ]]; then
    INTER_BROKER_LISTENER_NAME=$INTER_KAFKA_LISTENER_NAME
fi

if [[ -z "$LISTENER_SECURITY_PROTOCOL_MAP" ]]; then
    if [ $PROCESS_ROLES == "broker" ]
    then
        LISTENER_SECURITY_PROTOCOL_MAP="EXTERNAL:SSL,INTERNAL:SSL,$INTER_KAFKA_LISTENER_NAME:SSL,$CONTROLLER_LISTENER_NAMES:SSL"
    else
        LISTENER_SECURITY_PROTOCOL_MAP="$CONTROLLER_LISTENER_NAMES:SSL"
    fi
    
fi

if [[ -z "$BROKER_HEARTBEAT_INTERVAL_MS" ]]; then
    BROKER_HEARTBEAT_INTERVAL_MS="2000"
fi

if [[ -z "$LOG_DIRS" ]]; then
    LOG_DIRS="/opt/kafka/data"
fi
ESCAPED_LOG_DIRS=$(printf '%s\n' "$LOG_DIRS" | sed -e 's/[\/&]/\\&/g')

if [[ -z "$METADATA_LOG_DIR" ]]; then
    METADATA_LOG_DIR="/opt/kafka/metadata"
fi
ESCAPED_METADATA_LOG_DIR=$(printf '%s\n' "$METADATA_LOG_DIR" | sed -e 's/[\/&]/\\&/g')

if [[ -z "$METADATA_LOG_MAX_RECORD_BYTES_BETWEEN_SNAPSHOTS" ]]; then
    METADATA_LOG_MAX_RECORD_BYTES_BETWEEN_SNAPSHOTS="20971520"
fi

if [[ -z "$NUM_PARTITIONS" ]]; then
    NUM_PARTITIONS="1"
fi

if [[ -z "$DEFAULT_REPLICATION_FACTOR" ]]; then
    DEFAULT_REPLICATION_FACTOR="3"
fi

if [[ -z "$MIN_INSYNC_REPLICAS" ]]; then
    MIN_INSYNC_REPLICAS="2"
fi

if [[ -z "$LOG_RETENTION_HOURS" ]]; then
    LOG_RETENTION_HOURS="168"
fi

if [[ -z "$LOG_RETENTION_BYTES" ]]; then
    LOG_RETENTION_BYTES="1073741824"
fi

if [[ -z "$LOG_SEGMENT_BYTES" ]]; then
    LOG_SEGMENT_BYTES="1073741824"
fi

if [[ -z "$AUTO_CREATE_TOPICS_ENABLE" ]]; then
    AUTO_CREATE_TOPICS_ENABLE="false"
fi

if [[ -z "$AUTO_LEADER_REBALANCE_ENABLE" ]]; then
    AUTO_LEADER_REBALANCE_ENABLE="true"
fi

if [[ -z "$DELETE_TOPIC_ENABLE" ]]; then
    DELETE_TOPIC_ENABLE="false"
fi

if [[ -z "$SECURITY_INTER_BROKER_PROTOCOL" ]]; then
    SECURITY_INTER_BROKER_PROTOCOL="SSL"
fi

if [[ -z "$SSL_TRUSTSTORE_LOCATION" ]]; then
    SSL_TRUSTSTORE_LOCATION="$SSL_PATH/$PROCESS_ROLES.truststore.jks"
fi
ESCAPED_SSL_TRUSTSTORE_LOCATION=$(printf '%s\n' "$SSL_TRUSTSTORE_LOCATION" | sed -e 's/[\/&]/\\&/g')

if [[ -z "$SSL_KEYSTORE_LOCATION" ]]; then
    SSL_KEYSTORE_LOCATION="$SSL_PATH/$PROCESS_ROLES.keystore.jks"
fi
ESCAPED_SSL_KEYSTORE_LOCATION=$(printf '%s\n' "$SSL_KEYSTORE_LOCATION" | sed -e 's/[\/&]/\\&/g')

if [[ -z "$SSL_KEYSTORE_PASSWORD" ]]; then
    SSL_KEYSTORE_PASSWORD="aashayeinkeystorekafka"
fi

if [[ -z "$SSL_TRUSTSTORE_PASSWORD" ]]; then
    SSL_TRUSTSTORE_PASSWORD="aashayeintruststorekafka"
fi

if [[ -z "$SSL_KEY_PASSWORD" ]]; then
    SSL_KEY_PASSWORD=$SSL_KEYSTORE_PASSWORD
fi

if [[ -z "$CA_CERT_PASSWORD" ]]; then
    CA_CERT_PASSWORD="aashayeincakafka"
fi

if [[ -z "$METRIC_REPORTERS" ]]; then
    METRIC_REPORTERS="com.linkedin.kafka.cruisecontrol.metricsreporter.CruiseControlMetricsReporter"
fi

if [[ -z "$CRUISE_CONTROL_METRICS_TOPIC_AUTO_CREATE" ]]; then
    CRUISE_CONTROL_METRICS_TOPIC_AUTO_CREATE="true"
fi

if [[ -z "$CRUISE_CONTROL_METRICS_TOPIC_NUM_PARTITIONS" ]]; then
    CRUISE_CONTROL_METRICS_TOPIC_NUM_PARTITIONS="1"
fi

if [[ -z "$CRUISE_CONTROL_METRICS_TOPIC_REPLICATION_FACTOR" ]]; then
    CRUISE_CONTROL_METRICS_TOPIC_REPLICATION_FACTOR="1"
fi

if [[ -z "$CRUISE_CONTROL_METRICS_TOPIC_MIN_INSYNC_REPLICAS" ]]; then
    CRUISE_CONTROL_METRICS_TOPIC_MIN_INSYNC_REPLICAS="1"
fi

if [[ -z "$CC_METRICS_REPORTER_BOOTSTRAP_SERVERS" ]]; then
    CC_METRICS_REPORTER_BOOTSTRAP_SERVERS=""
    for (( i=0; i<$CONTROLLER_REPLICAS; i++))
    do
        CC_METRICS_REPORTER_BOOTSTRAP_SERVERS+="broker-$i.broker-svc.$NAMESPACE.svc.cluster.local:$PORT"

        if [ $i != `expr $CONTROLLER_REPLICAS - 1` ] 
        then
            CC_METRICS_REPORTER_BOOTSTRAP_SERVERS+="," 
        fi
    done
fi

if [[ -z "$CRUISE_CONTROL_METRICS_REPORTER_BOOTSTRAP_SERVERS" ]]; then
    CRUISE_CONTROL_METRICS_REPORTER_BOOTSTRAP_SERVERS=$CC_METRICS_REPORTER_BOOTSTRAP_SERVERS
fi

if [[ -z "$CRUISE_CONTROL_METRICS_REPORTER_SECURITY_PROTOCOL" ]]; then
    CRUISE_CONTROL_METRICS_REPORTER_SECURITY_PROTOCOL="SSL"
fi

if [[ -z "$CRUISE_CONTROL_METRICS_TOPIC" ]]; then
    CRUISE_CONTROL_METRICS_TOPIC="__CruiseControlMetrics"
fi
# ==================================== Create Truststore and Keystore ==================================== #
#https://github.com/confluentinc/confluent-platform-security-tools/blob/master/kafka-generate-ssl-automatic.sh

# Create Truststore
echo "Create Truststore"
keytool -noprompt \
 -alias $CA_ALIAS \
 -import -file $CA_CERT_FILE \
 -keystore $SSL_TRUSTSTORE_LOCATION \
 -storepass $SSL_TRUSTSTORE_PASSWORD \
 -keypass $SSL_KEY_PASSWORD

# Create Keystore
echo "Create Keystore"
keytool -genkey -noprompt \
 -alias $PROCESS_ROLES \
 -keyalg RSA \
 -validity $VALIDITY \
 -ext SAN=dns:$HOST_FQDN \
 -dname "CN=$HOST_FQDN, OU=Aashayein, O=Aashayein, L=BBSR, S=Odisha, C=IN" \
 -keystore $SSL_KEYSTORE_LOCATION \
 -storepass $SSL_KEYSTORE_PASSWORD \
 -keypass $SSL_KEY_PASSWORD

# Create CSR
echo "Create CSR"
keytool -certreq -noprompt \
 -alias $PROCESS_ROLES \
 -keystore $SSL_KEYSTORE_LOCATION \
 --file $CSR_FILE \
 -storepass $SSL_KEYSTORE_PASSWORD \
 -keypass $SSL_KEY_PASSWORD

# Sign CSR
echo "Sign CSR"
openssl x509 -sha256 -req -passin pass:$CA_CERT_PASSWORD -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE -in $CSR_FILE -out $CSR_SIGNED_FILE -days $VALIDITY -CAcreateserial

# Import CA cert into keystore
echo "Import CA cert into keystore"
keytool -noprompt \
 -keystore $SSL_KEYSTORE_LOCATION \
 -alias $CA_ALIAS \
 -import -file $CA_CERT_FILE \
 -storepass $SSL_KEYSTORE_PASSWORD \
 -keypass $SSL_KEY_PASSWORD

# Import signed CSR into keystore
echo "Import signed CSR into keystore"
keytool -noprompt \
 -keystore $SSL_KEYSTORE_LOCATION \
 -alias $PROCESS_ROLES \
 -import -file $CSR_SIGNED_FILE \
 -storepass $SSL_KEYSTORE_PASSWORD \
 -keypass $SSL_KEY_PASSWORD

# Clear ca related file and variable
rm $CA_KEY_FILE
rm $CSR_FILE
rm $CA_CERT_FILE
rm $SSL_PATH/ca-root-cert.srl
rm $CSR_SIGNED_FILE
#rm -r /tmp/ca
# ==================================== Replace Configs ==================================== #
sed -i "s/__process.roles__/$PROCESS_ROLES/" $CONFIG_PATH
sed -i "s/__node.id__/$NODE_ID/" $CONFIG_PATH
sed -i "s/__controller.quorum.voters__/$CONTROLLER_QUORUM_VOTERS/" $CONFIG_PATH
sed -i "s/__listeners__/$ESCAPED_LISTENERS/" $CONFIG_PATH

if [ $PROCESS_ROLES == "broker" ]
then
    sed -i "s/__inter.broker.listener.name__/$INTER_BROKER_LISTENER_NAME/" $CONFIG_PATH
fi

if [ $PROCESS_ROLES == "broker" ]
then
    sed -i "s/__controller.listener.names__/$CONTROLLER_LISTENER_NAMES/" $CONFIG_PATH
else
    sed -i "s/__controller.listener.names__/$CONTROLLER_LISTENER_NAMES/" $CONFIG_PATH
fi

sed -i "s/__advertised.listeners__/$ESCAPED_ADVERTISED_LISTENERS/" $CONFIG_PATH
sed -i "s/__listener.security.protocol.map__/$LISTENER_SECURITY_PROTOCOL_MAP/" $CONFIG_PATH
sed -i "s/__broker.heartbeat.interval.ms__/$BROKER_HEARTBEAT_INTERVAL_MS/" $CONFIG_PATH
sed -i "s/__log.dirs__/$ESCAPED_LOG_DIRS/" $CONFIG_PATH
sed -i "s/__metadata.log.dir__/$ESCAPED_METADATA_LOG_DIR/" $CONFIG_PATH
sed -i "s/__metadata.log.max.record.bytes.between.snapshots__/$METADATA_LOG_MAX_RECORD_BYTES_BETWEEN_SNAPSHOTS/" $CONFIG_PATH
sed -i "s/__num.partitions__/$NUM_PARTITIONS/" $CONFIG_PATH
sed -i "s/__default.replication.factor__/$DEFAULT_REPLICATION_FACTOR/" $CONFIG_PATH
sed -i "s/__min.insync.replicas__/$MIN_INSYNC_REPLICAS/" $CONFIG_PATH
sed -i "s/__log.retention.hours__/$LOG_RETENTION_HOURS/" $CONFIG_PATH
sed -i "s/__log.retention.bytes__/$LOG_RETENTION_BYTES/" $CONFIG_PATH
sed -i "s/__log.segment.bytes__/$LOG_SEGMENT_BYTES/" $CONFIG_PATH
sed -i "s/__auto.create.topics.enable__/$AUTO_CREATE_TOPICS_ENABLE/" $CONFIG_PATH
sed -i "s/__auto.leader.rebalance.enable__/$AUTO_LEADER_REBALANCE_ENABLE/" $CONFIG_PATH
sed -i "s/__delete.topic.enable__/$DELETE_TOPIC_ENABLE/" $CONFIG_PATH
sed -i "s/__security.inter.broker.protocol__/$SECURITY_INTER_BROKER_PROTOCOL/" $CONFIG_PATH
sed -i "s/__ssl.truststore.location__/$ESCAPED_SSL_TRUSTSTORE_LOCATION/" $CONFIG_PATH
sed -i "s/__ssl.truststore.password__/$SSL_TRUSTSTORE_PASSWORD/" $CONFIG_PATH
sed -i "s/__ssl.keystore.location__/$ESCAPED_SSL_KEYSTORE_LOCATION/" $CONFIG_PATH
sed -i "s/__ssl.keystore.password__/$SSL_KEYSTORE_PASSWORD/" $CONFIG_PATH
sed -i "s/__ssl.key.password__/$SSL_KEY_PASSWORD/" $CONFIG_PATH
sed -i "s/__metric.reporters__/$METRIC_REPORTERS/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.topic.auto.create__/$CRUISE_CONTROL_METRICS_TOPIC_AUTO_CREATE/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.topic.num.partitions__/$CRUISE_CONTROL_METRICS_TOPIC_NUM_PARTITIONS/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.topic.replication.factor__/$CRUISE_CONTROL_METRICS_TOPIC_REPLICATION_FACTOR/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.topic.min.insync.replicas__/$CRUISE_CONTROL_METRICS_TOPIC_MIN_INSYNC_REPLICAS/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.reporter.bootstrap.servers__/$CRUISE_CONTROL_METRICS_REPORTER_BOOTSTRAP_SERVERS/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.reporter.security.protocol__/$CRUISE_CONTROL_METRICS_REPORTER_SECURITY_PROTOCOL/" $CONFIG_PATH
sed -i "s/__cruise.control.metrics.topic__/$CRUISE_CONTROL_METRICS_TOPIC/" $CONFIG_PATH
# ==================================== Print Configs ==================================== #
printf "==================================== Start Configs ====================================\n"
cat $CONFIG_PATH
printf "\n==================================== End Configs ====================================\n"
# ==================================== Start Server ==================================== #

#if [[ ! -f "$LOG_DIRS/cluster_id" && "$NODE_ID" = "0" ]]; then
#    CLUSTER_ID=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid)
#    echo $CLUSTER_ID >> $LOG_DIRS/cluster_id
#else
 #   CLUSTER_ID=$(cat $LOG_DIRS/cluster_id)
#fi

#CLUSTER_ID=$($KAFKA_HOME/bin/kafka-storage.sh random-uuid)
CLUSTER_ID="xoDdMIihQ-eOzytDVXHYHw"
$KAFKA_HOME/bin/kafka-storage.sh format --ignore-formatted -t ${CLUSTER_ID} -c $CONFIG_PATH
$KAFKA_HOME/bin/kafka-storage.sh info -c $CONFIG_PATH


#export KAFKA_HEAP_OPTS="-Xmx200M –Xms100M"
export KAFKA_OPTS="-javaagent:$KAFKA_HOME/libs/jmx_prometheus_javaagent-$PROMETHEUS_JAVA_AGENT_VERSION.jar=$PROMETHEUS_PORT:$KAFKA_HOME/config/kraft/prometheus.yml"

exec $KAFKA_HOME/bin/kafka-server-start.sh $CONFIG_PATH