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



##################################################
# Create service accounts
##################################################



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


curl --request POST \
  --url 'https://api.confluent.cloud/connect/v1/environments/$ENVIRONMENT/clusters/$CLUSTER/connectors' \
  --header 'Authorization: Basic REPLACE_BASIC_AUTH' \
  --header 'content-type: application/json' \
  --data '{"name":"string","config":{
  "connector.class": "SalesforceCdcSource",
  "name": "SalesforceCdcSourceConnector_0",
  "kafka.api.key": $SFDC_API_KEY,
  "kafka.api.secret": $SFDC_API_SECRET,
  "kafka.topic": "AccountChangeEvent",
  "salesforce.username": $SFDC_USERNAME,
  "salesforce.password": $SFDC_PASSWORD,
  "salesforce.password.token": $SFDC_PASSWORD_TOKEN
  "salesforce.consumer.key": $SFDC_CONSUMER_KEY,
  "salesforce.consumer.secret": $SFDC_CONSUMER_SECRET,
  "salesforce.cdc.name": "AccountChangeEvent",
  "output.data.format": "JSON",
  "tasks.max": "1"
}}'


##################################################
# Run ksql queries 
##################################################

