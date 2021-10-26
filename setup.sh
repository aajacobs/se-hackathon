#!/bin/bash


# Source demo-specific configurations
source config/demo.cfg

##################################################
# Create a new environment and specify it as the default
##################################################

ENVIRONMENT_NAME="account-aggregation-demo"
echo -e "\n# Create a new Confluent Cloud environment $ENVIRONMENT_NAME"
echo "ccloud environment create $ENVIRONMENT_NAME -o json"
OUTPUT=$(ccloud environment create $ENVIRONMENT_NAME -o json)
if [[ $? != 0 ]]; then
  echo "ERROR: Failed to create environment $ENVIRONMENT_NAME. Please troubleshoot (maybe run ./cleanup.sh) and run again"
  exit 1
fi
echo "$OUTPUT" | jq .
ENVIRONMENT=$(echo "$OUTPUT" | jq -r ".id")
#echo $ENVIRONMENT

echo -e "\n# Specify $ENVIRONMENT as the active environment"
echo "ccloud environment use $ENVIRONMENT"
ccloud environment use $ENVIRONMENT

##################################################
# Create a new Kafka cluster and specify it as the default
##################################################

CLUSTER_NAME="${CLUSTER_NAME:-demo-kafka-cluster}"
CLUSTER_CLOUD="${CLUSTER_CLOUD:-aws}"
CLUSTER_REGION="${CLUSTER_REGION:-us-east-1}"
echo -e "\n# Create a new Confluent Cloud cluster $CLUSTER_NAME"
echo "ccloud kafka cluster create $CLUSTER_NAME --cloud $CLUSTER_CLOUD --region $CLUSTER_REGION"
OUTPUT=$(ccloud kafka cluster create $CLUSTER_NAME --cloud $CLUSTER_CLOUD --region $CLUSTER_REGION)
status=$?
echo "$OUTPUT"
if [[ $status != 0 ]]; then
  echo "ERROR: Failed to create Kafka cluster $CLUSTER_NAME. Please troubleshoot and run again"
  exit 1
fi
CLUSTER=$(echo "$OUTPUT" | grep '| Id' | awk '{print $4;}')

echo -e "\n# Specify $CLUSTER as the active Kafka cluster"
echo "ccloud kafka cluster use $CLUSTER"
ccloud kafka cluster use $CLUSTER

BOOTSTRAP_SERVERS=$(ccloud kafka cluster describe $CLUSTER -o json | jq -r ".endpoint" | cut -c 12-)
#echo "BOOTSTRAP_SERVERS: $BOOTSTRAP_SERVERS"

##################################################
# Create a user key/secret pair and specify it as the default
##################################################

echo -e "\n# Create a new API key for user"
echo "ccloud api-key create --description \"Demo credentials\" --resource $CLUSTER -o json"
OUTPUT=$(ccloud api-key create --description "Demo credentials" --resource $CLUSTER -o json)
status=$?
if [[ $status != 0 ]]; then
  echo "ERROR: Failed to create an API key.  Please troubleshoot and run again"
  exit 1
fi
echo "$OUTPUT" | jq .

API_KEY=$(echo "$OUTPUT" | jq -r ".key")
echo -e "\n# Associate the API key $API_KEY to the Kafka cluster $CLUSTER"
echo "ccloud api-key use $API_KEY --resource $CLUSTER"
ccloud api-key use $API_KEY --resource $CLUSTER

sleep 100


##################################################
# Create necessary topics
##################################################

SFDC_TOPIC="SFSourceCDC"

echo -e "\n# Create a new Kafka topic for SFDC CDC Data $SFDC_TOPIC"
echo "ccloud kafka topic create $SFDC_TOPIC"
ccloud kafka topic create $SFDC_TOPIC
status=$?
if [[ $status != 0 ]]; then
  echo "ERROR: Failed to create topic $SFDC_TOPIC. Please troubleshoot and run again"
  exit 1
fi


##################################################
# Create service accounts
##################################################

echo -e "\n# Create a new service account for SFDC connector "
RANDOM_NUM=$((1 + RANDOM % 1000000))
SFDC_SERVICE_NAME="sfdc-source-$RANDOM_NUM"
echo "ccloud service-account create $SFDC_SERVICE_NAME --description $SFDC_SERVICE_NAME -o json"
OUTPUT=$(ccloud service-account create $SFDC_SERVICE_NAME --description $SFDC_SERVICE_NAME  -o json)
echo "$OUTPUT" | jq .
SFDC_SERVICE_ACCOUNT_ID=$(echo "$OUTPUT" | jq -r ".id")

echo -e "\n# Create an API key and secret for the service account $SFDC_SERVICE_ACCOUNT_ID"
echo "ccloud api-key create --service-account $SFDC_SERVICE_ACCOUNT_ID --resource $CLUSTER -o json"
OUTPUT=$(ccloud api-key create --service-account $SFDC_SERVICE_ACCOUNT_ID --resource $CLUSTER -o json)
echo "$OUTPUT" | jq .
API_KEY_SFDC_SA=$(echo "$OUTPUT" | jq -r ".key")
API_SECRET_SFDC_SA=$(echo "$OUTPUT" | jq -r ".secret")

echo -e "\n# Create ACLs for the service account"
echo "ccloud kafka acl create --allow --service-account $SFDC_SERVICE_ACCOUNT_ID --operation CREATE --topic $SFDC_TOPIC"
echo "ccloud kafka acl create --allow --service-account $SFDC_SERVICE_ACCOUNT_ID --operation WRITE --topic $SFDC_TOPIC"
ccloud kafka acl create --allow --service-account $SFDC_SERVICE_ACCOUNT_ID --operation CREATE --topic $SFDC_TOPIC
ccloud kafka acl create --allow --service-account $SFDC_SERVICE_ACCOUNT_ID --operation WRITE --topic $SFDC_TOPIC
echo
echo "ccloud kafka acl list --service-account $SFDC_SERVICE_ACCOUNT_ID"
ccloud kafka acl list --service-account $SFDC_SERVICE_ACCOUNT_ID
sleep 2



##################################################
# Create ksqlDB Application
##################################################

read -p "Do you acknowledge this script creates a Confluent Cloud KSQL app (hourly charges may apply)? [y/n] " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
  printf "\n"

echo -e "\n# Create a new API key for user"
echo "ccloud api-key create --description \"Demo credentials\" --resource \"cluster_id\" -o json"
OUTPUT_KSQL_CREATE_KEY=$(ccloud api-key create --description "Demo credentials" --resource $CLUSTER -o json)
status=$?
if [[ $status != 0 ]]; then
  echo "ERROR: Failed to create an API key.  Please troubleshoot and run again"
  exit 1
fi
echo "$OUTPUT_KSQL_CREATE_KEY" | jq .

API_KEY_CREATE_KSQL=$(echo "$OUTPUT_KSQL_CREATE_KEY" | jq -r ".key")
API_SECRET_CREATE_KSQL=$(echo "$OUTPUT_KSQL_CREATE_KEY" | jq -r ".secret")
echo -e "\n# Associate the API key $API_KEY_CREATE_KSQL to the Kafka cluster $CLUSTER"
echo "ccloud api-key store $API_KEY_CREATE_KSQL $API_SECRET_CREATE_KSQL --resource $CLUSTER"

echo "ccloud api-key use $API_KEY_CREATE_KSQL --resource $CLUSTER"
ccloud api-key use $API_KEY_CREATE_KSQL --resource $CLUSTER


ccloud ksql app create odds-calculation-app --api-key $API_KEY_CREATE_KSQL --api-secret $API_SECRET_CREATE_KSQL
#! ccloud ksql app configure-acls

echo "Provisioning ksqlDB application"

ksqldb_meta=$(ccloud ksql app list -o json | jq -r 'map(select(.endpoint == "'"$ksqldb_endpoint"'")) | .[]')
ksqldb_status=$(ccloud ksql app list -o json | jq '.[].status')
ksqldb_status=$(echo $ksqldb_status | tr -d '"')
 
while [ $ksqldb_status != "UP" ]; do
    echo "Waiting 60 seconds for ksqlDB to come up"
    sleep 60
    ksqldb_status=$(ccloud ksql app list -o json | jq '.[].status')
    ksqldb_status=$(echo $ksqldb_status | tr -d '"')
  done

echo "ksql is up moving on" 
#NEED TO ADD IN A FAILSAFE TO MAKE SURE IT'S UP 


##################################################
# Create connectors 
##################################################

# Create API Key for CC API 

echo -e "\n# Create a new API key for management API"

OUTPUT_API_CREATE_KEY=$(ccloud api-key create --resource cloud)
status=$?
if [[ $status != 0 ]]; then
  echo "ERROR: Failed to create an API key.  Please troubleshoot and run again"
  exit 1
fi
echo "$OUTPUT_API_CREATE_KEY" | jq .

API_KEY_API=$(echo "$OUTPUT_API_CREATE_KEY" | jq -r ".key")
API_SECRET_API=$(echo "$OUTPUT_API_CREATE_KEY" | jq -r ".secret")

BASE_64_API=$(echo -n "API_KEY_API:API_SECRET_API" | base64)


# Create MongoDB Connector 

curl --request POST \
  --url 'https://api.confluent.cloud/connect/v1/environments/$ENVIRONMENT/clusters/$CLUSTER/connectors' \
  --header 'Authorization: Basic $BASE_64_API' \
  --header 'content-type: application/json' \
  --data '{"name": "MongoDbAtlasSinkConnector_0",
  "config": {
    "connector.class": "MongoDbAtlasSink",
    "name": "MongoDbAtlasSinkConnector_0",
    "input.data.format": "JSON",
    "kafka.api.key": $API_KEY_MONGO_SA,
    "kafka.api.secret": $API_SECRET_MONGO_SA,
    "kafka.topic": "ORDER_PREP",
    "topics": "ORDER_PREP",
    "connection.host": $MONGO_CONNECTION_HOST,
    "connection.user": $MONGO_CONNECTION_USER,
    "connection.password": $MONGO_CONNECTION_PASSWORD,
    "database": $MONGO_CONNECTION_DATABASE,
    "collection": $MONGO_CONNECTION_COLLECTION,
    "tasks.max": "1"
  }
}'

# Create SFDC Connector

curl --request POST \
  --url 'https://api.confluent.cloud/connect/v1/environments/$ENVIRONMENT/clusters/$CLUSTER/connectors' \
  --header 'Authorization: Basic $BASE_64_API' \
  --header 'content-type: application/json' \
  --data '{"name":"SalesforceCdcSourceConnector_0","config":{
  "connector.class": "SalesforceCdcSource",
  "name": "SalesforceCdcSourceConnector_0",
  "kafka.api.key": $API_KEY_SFDC_SA,
  "kafka.api.secret": $API_SECRET_SFDC_SA,
  "kafka.topic": "$SFDC_TOPIC",
  "salesforce.username": $SFDC_USERNAME,
  "salesforce.password": $SFDC_PASSWORD,
  "salesforce.password.token": $SFDC_PASSWORD_TOKEN
  "salesforce.consumer.key": $SFDC_CONSUMER_KEY,
  "salesforce.consumer.secret": $SFDC_CONSUMER_SECRET,
  "salesforce.cdc.name": "AccountChangeEvent",
  "salesforce.initial.start": "all",
  "connection.timeout": "600000",
  "output.data.format": "JSON",
  "tasks.max": "1"
}}'

# Create Snowflake Connector 

curl --request POST \
  --url 'https://api.confluent.cloud/connect/v1/environments/$ENVIRONMENT/clusters/$CLUSTER/connectors' \
  --header 'Authorization: Basic $BASE_64_API' \
  --header 'content-type: application/json' \
  --data '{"name":"SnowflakeSinkConnector_0","config":{
  "connector.class": "SnowflakeSink",
  "name": "SnowflakeSinkConnector_0",
  "kafka.api.key": $SNOWFLAKE_API_KEY,
  "kafka.api.secret": $SNOWFLAKE_API_SECRET,
  "topics": $SNOWFLAKE_TOPIC_NAME,
  "input.data.format": "JSON",
  "snowflake.url.name": $SNOWFLAKE_URL,
  "snowflake.user.name": $SNOWFLAKE_USERNAME,
  "snowflake.private.key": $SNOWFLAKE_PRIVATEKEY,
  "snowflake.database.name": $SNOWFLAKE_DB_NAME,
  "snowflake.schema.name": $SNOWFLAKE_SCHEMA_NAME,
  "tasks.max": "1"
}}'


##################################################
# Run ksql queries 
##################################################

