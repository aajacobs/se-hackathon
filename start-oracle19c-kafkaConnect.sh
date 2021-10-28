#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

export ORACLE_IMAGE="oracle/database:19.3.0-ee"

if test -z "$(docker images -q $ORACLE_IMAGE)"
then
    if [ ! -z "$CI" ]
    then
        if [ ! -f ${DIR}/LINUX.X64_193000_db_home.zip ]
        then
            # running with github actions
            aws s3 cp --only-show-errors s3://kafka-docker-playground/3rdparty/LINUX.X64_193000_db_home.zip .
        fi
    fi
    if [ ! -f ${DIR}/LINUX.X64_193000_db_home.zip ]
    then
        logerror "ERROR: ${DIR}/LINUX.X64_193000_db_home.zip is missing. It must be downloaded manually in order to acknowledge user agreement.  Go to https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html#license-lightbox to download, place the zip file in this directory, and try again."
        exit 1
    fi
    log "Building $ORACLE_IMAGE docker image..it can take a while...(more than 15 minutes!)"
    OLDDIR=$PWD
    rm -rf ${DIR}/docker-images
    git clone https://github.com/oracle/docker-images.git

    mv ${DIR}/LINUX.X64_193000_db_home.zip ${DIR}/docker-images/OracleDatabase/SingleInstance/dockerfiles/19.3.0/LINUX.X64_193000_db_home.zip
    cd ${DIR}/docker-images/OracleDatabase/SingleInstance/dockerfiles
    ./buildContainerImage.sh -v 19.3.0 -e
    rm -rf ${DIR}/docker-images
    cd ${OLDDIR}
fi

docker-compose -f docker-compose.yml build
docker-compose -f docker-compose.yml down -v --remove-orphans
docker-compose -f docker-compose.yml up -d

# Verify Oracle DB has started within MAX_WAIT seconds
MAX_WAIT=2500
CUR_WAIT=0
log "Waiting up to $MAX_WAIT seconds for Oracle DB to start"
docker container logs oracle > /tmp/out.txt 2>&1
while [[ ! $(cat /tmp/out.txt) =~ "DONE: Executing user defined scripts" ]]; do
sleep 10
docker container logs oracle > /tmp/out.txt 2>&1
CUR_WAIT=$(( CUR_WAIT+10 ))
if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
     logerror "ERROR: The logs in oracle container do not show 'DONE: Executing user defined scripts' after $MAX_WAIT seconds. Please troubleshoot with 'docker container ps' and 'docker container logs'.\n"
     exit 1
fi
done
log "Oracle DB has started!"
sleep 60

# Create a redo-log-topic. Please make sure you create a topic with the same name you will use for "redo.log.topic.name": "redo-log-topic"
# CC-13104
# docker exec connect kafka-topics --create --topic redo-log-topic --bootstrap-server broker:9092 --replication-factor 1 --partitions 1 --config cleanup.policy=delete --config retention.ms=120960000
# log "redo-log-topic is created"
# sleep 5

log "Creating Oracle source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "connector.class": "io.confluent.connect.oracle.cdc.OracleCdcSourceConnector",
               "tasks.max": "2",
               "confluent.license": "",
               "confluent.topic.bootstrap.servers" : "pkc-4nym6.us-east-1.aws.confluent.cloud:9092",
               "confluent.topic.sasl.jaas.config" : "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"FL5BLSXWYJNYALTM\" password=\"m+OEQdObEdYNdGYJ8giCLcQbiigswaQbZcV2VJop1QXtOGix9Dqs5YpDaPIWpUUY\";",
               "confluent.topic.security.protocol" : "SASL_SSL",
               "confluent.topic.ssl.endpoint.identification.algorithm": "https",
               "confluent.topic.sasl.mechanism" : "PLAIN",
               "confluent.topic.replication.factor": "3",
               "oracle.server": "oracle",
               "oracle.port": 1521,
               "oracle.sid": "ORCLCDB",
               "oracle.username": "C##MYUSER",
               "oracle.password": "mypassword",
               "start.from":"snapshot",
               "redo.log.topic.name": "redo-log-topic",
               "redo.log.consumer.bootstrap.servers": "pkc-4nym6.us-east-1.aws.confluent.cloud:9092",
               "redo.log.consumer.sasl.jaas.config" : "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"FL5BLSXWYJNYALTM\" password=\"m+OEQdObEdYNdGYJ8giCLcQbiigswaQbZcV2VJop1QXtOGix9Dqs5YpDaPIWpUUY\";",
               "redo.log.consumer.security.protocol" : "SASL_SSL",
               "redo.log.consumer.ssl.endpoint.identification.algorithm": "https",
               "redo.log.consumer.sasl.mechanism" : "PLAIN",
               "request.timeout.ms": "20000",
               "retry.backoff.ms": "500",
               "table.inclusion.regex": ".*ORDERS.*",
               "table.topic.name.template": "${databaseName}.${schemaName}.${tableName}",
               "numeric.mapping": "best_fit",
               "connection.pool.max.size": 20,
               "redo.log.row.fetch.size": 1,
               "oracle.dictionary.mode": "auto",
               "topic.creation.default.partitions" : 1,
               "topic.creation.default.replication.factor" : 3, 
               "key.converter": "org.apache.kafka.connect.storage.StringConverter",
               "value.converter":"org.apache.kafka.connect.json.JsonConverter",
               "value.converter.schemas.enable":"true",
               "start.from": "snapshot",
               "offset.storage.topic": "oracle-connector-offset",
               "config.storage.topic": "oracle-connector-config",
               "status.storage.topic": "oracle-connector-status"
          }' \
     http://localhost:8083/connectors/cdc-oracle-source-cdb-test/config | jq .

log "Waiting 60s for connector to read existing data"
sleep 60

log "Running SQL scripts"
for script in ./oracle-assets/sample-sql-scripts/*
do
     $script "ORCLCDB"
done