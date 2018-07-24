#!/bin/bash

#Exit code
FAIL=0

#Build  app
env GOOS=linux GOARCH=amd64 go build ../../../

#Get vars
if [ -z ${PACKER_ENVIRONMENT} ]; then
  read -p $'\033[1;32mPlease enter your PACKER ENVIRONMENT: \033[0m' PACKER_ENVIRONMENT
  export PACKER_ENVIRONMENT="${PACKER_ENVIRONMENT}"
else
  export PACKER_ENVIRONMENT="${PACKER_ENVIRONMENT}"
fi

if [ -z ${GCP_ACCOUNT_FILE_JSON} ]; then
  read -p $'\033[1;32mPlease enter an GCP account file for Packer: \033[0m' GCP_ACCOUNT_FILE_JSON
  export GCP_ACCOUNT_FILE_JSON="${GCP_ACCOUNT_FILE_JSON}"
else
  export GCP_ACCOUNT_FILE_JSON="${GCP_ACCOUNT_FILE_JSON}"
fi

if [ -z ${GCP_PROJECT_ID} ]; then
  read -p $'\033[1;32mPlease enter a GCP project for Packer: \033[0m' GCP_PROJECT_ID
  export GCP_PROJECT_ID="${GCP_PROJECT_ID}"
else
  export GCP_PROJECT_ID="${GCP_PROJECT_ID}"
fi

if [ -z ${GCP_ZONE} ]; then
  read -p $'\033[1;32mPlease enter a GCP Zone for Packer: \033[0m' GCP_ZONE
  export GCP_ZONE="${GCP_ZONE}"
else
  export GCP_ZONE="${GCP_ZONE}"
fi

#Start Jobs
echo "Starting Packer builds..."
packer build -force go.json &

#Wait for completion
for job in `jobs -p`; do
  echo $job
  wait $job || let "FAIL+=1"
done

if [ "$FAIL" == "0" ]; then
  echo -e "\033[32m\033[1m[BUILD SUCCESFUL]\033[0m"
else
  echo -e "\033[31m\033[1m[BUILD ERROR]\033[0m"
fi
