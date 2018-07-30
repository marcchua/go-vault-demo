#!/bin/bash

#Exit code
FAIL=0

#Check vars
if [ -z ${PACKER_ENVIRONMENT} ]; then
  read -p $'\033[1;32mPlease enter your PACKER ENVIRONMENT: \033[0m' PACKER_ENVIRONMENT
  export PACKER_ENVIRONMENT="${PACKER_ENVIRONMENT}"
else
  export PACKER_ENVIRONMENT="${PACKER_ENVIRONMENT}"
fi

if [ -z ${ARM_CLIENT_ID} ]; then
  read -p $'\033[1;32mPlease enter an ARM Client ID for Packer: \033[0m' ARM_CLIENT_ID
  export ARM_CLIENT_ID="${ARM_CLIENT_ID}"
else
  export ARM_CLIENT_ID="${ARM_CLIENT_ID}"
fi

if [ -z ${ARM_CLIENT_SECRET} ]; then
  read -p $'\033[1;32mPlease enter an ARM Client Secret for Packer: \033[0m' ARM_CLIENT_SECRET
  export ARM_CLIENT_SECRET="${ARM_CLIENT_SECRET}"
else
  export ARM_CLIENT_SECRET="${ARM_CLIENT_SECRET}"
fi

if [ -z ${ARM_SUBSCRIPTION_ID} ]; then
  read -p $'\033[1;32mPlease enter an ARM Subscription ID for Packer: \033[0m' ARM_SUBSCRIPTION_ID
  export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID}"
else
  export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID}"
fi

if [ -z ${ARM_TENANT_ID} ]; then
  read -p $'\033[1;32mPlease enter an ARM Tenant ID for Packer: \033[0m' ARM_TENANT_ID
  export ARM_TENANT_ID="${ARM_TENANT_ID}"
else
  export ARM_TENANT_ID="${ARM_TENANT_ID}"
fi

if [ -z ${AZURE_RESOURCE_GROUP} ]; then
  read -p $'\033[1;32mPlease enter an Azure resource group for Packer: \033[0m' AZURE_RESOURCE_GROUP
  export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"
else
  export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP}"
fi

if [ -z ${AZURE_LOCATION} ]; then
  read -p $'\033[1;32mPlease enter an Azure location for Packer: \033[0m' AZURE_LOCATION
  export AZURE_LOCATION="${AZURE_LOCATION}"
else
  export AZURE_LOCATION="${AZURE_LOCATION}"
fi

#Build  app
echo "Building Go app..."
env GOOS=linux GOARCH=amd64 go build ../../../

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
