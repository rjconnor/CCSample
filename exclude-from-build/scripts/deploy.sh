#!/bin/bash

<<COMMENT
===============================================================
Deployment Script for ***
version  0.1 created: *** , 27/9/2019
=============================================================

References:
https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/shared-services
https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration
https://www.danielstechblog.io/build-azure-kubernetes-service-cluster-with-bring-your-own-virtual-network-on-azure/

COMMENT
echo off

SUBSCRIPTIONNAME="Clyde & Co - UK - Leap - Sandbox - CDW UK CSP"
SUBSCRIPTIONID="00bcabe9-0608-46f3-a624-a53c00ecbf5b"

az account set --subscription $SUBSCRIPTIONID

ORG="cc"
ENV="sb" 
EnvFull="Sandbox"
TAGS="Environment=$EnvFull Application-Taxonomy=- Billed-To=- IT-Owner-Contact=- Business-Owner-Contact=- Days-Operational=0 Hours-Operational=0 Service=-"
LOCATION="uksouth"
REGIONSHORT='uks'

GEN_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}"
HUB_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-hub"
AKS_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-aks"
ACR_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-acr"
NW_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-network"

WORKSPACE_NAME="${ORG}-${REGIONSHORT}-law-leap-${ENV}-001"
AKS_WORKSPACE_RESOURCE_ID="/subscriptions/$SUBSCRIPTIONID/resourcegroups/$GEN_RG/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"

AAD_SERVER_APP_ID="d99f8e30-6873-4219-8981-94c2473d32b8"
AAD_SERVER_APP_SECRET="pCS/QMoM9QgN9uFJ08GmbQ?[WGawOEm?"
AAD_CLIENT_APP_ID="6d121ab4-7a85-4288-a7b6-e1cc8fa8b555"
AAD_TENANT_ID="eb5e156e-540c-42da-8f8c-0cd5639f036a"

SQL_NAME="${ORG}-${REGIONSHORT}-sqlmi-${ENV}-01"
SQL_USERNAME="clydeandcosbadmin"
SQL_PASSWORD="Zxcvbnm12345#####"

HUB_VNET_NAME="${ORG}-${REGIONSHORT}-vnet-hub-01"
HUB_VNET_ADDRESS_PREFIX="10.125.240.0/20"

SPOKE_VNET_NAME="${ORG}-${REGIONSHORT}-vnet-leap-${ENV}-01"
SPOKE_VNET_ADDRESS_PREFIX="10.1.0.0/16"

GW_SUBNET_NAME="${ORG}-${REGIONSHORT}-snet-gw"
GW_SUBNET_ADDRESS_PREFIX="10.0.0.0/24"
GW_NSG_NAME="${ORG}-${REGIONSHORT}-nsg-gw"

SQL_SUBNET_NAME="${ORG}-${REGIONSHORT}-subnet-sql-${ENV}"
SQL_SUBNET_ADDRESS_PREFIX="10.1.0.0/24"
SQL_NSG_NAME="${ORG}-${REGIONSHORT}-nsg-sql"

AKS_SUBNET_NAME="${ORG}-${REGIONSHORT}-leap-${ENV}-snet-aks-01"
AKS_SUBNET_ADDRESS_PREFIX="10.125.0.0/22"
AKS_NSG_NAME="${ORG}-${REGIONSHORT}-nsg-${ENV}-snet-aks-01"

ACR_NAME="ccukssbacr"

AKS_CLUSTER_NAME="${ORG}-${REGIONSHORT}-aks-leap-${ENV}-01"
AKS_NODE_COUNT="3"
AKS_MAX_PODS="30"
AKS_SERVICE_CIDR="10.125.4.0/24"
AKS_DNS_SERVICE_IP="10.125.4.254"
AKS_DOCKER_BRIDGE_ADDRESS="10.125.5.1/28"
AKS_VERSION="1.13.12"

echo $ENV
echo $EnvFull
echo $TAGS
echo $HUB_RG
echo $GEN_RG
echo $AKS_RG
echo $ACR_RG
echo $NW_RG
echo $WORKSPACE_NAME
echo $AKS_WORKSPACE_RESOURCE_ID
echo $HUB_VNET_NAME
echo $SPOKE_VNET_NAME
echo $GW_SUBNET_NAME
echo $GW_NSG_NAME
echo $SQL_SUBNET_NAME
echo $SQL_NSG_NAME
echo $AKS_SUBNET_NAME
echo $AKS_NSG_NAME
echo $SQL_NAME
echo $SQL_USERNAME
echo $SQL_PASSWORD
echo $AKS_RG
echo $AKS_CLUSTER_NAME
echo $AKS_VERSION
echo $ACR_NAME

# DO STUFF FROM HERE

# ----------- Create Resource Groups --------------
az group create --location $LOCATION --name $HUB_RG --tags $TAGS
az group lock create --lock-type CanNotDelete -n lock -g $HUB_RG

az group create --location $LOCATION --name $SPOKE_RG --tags $TAGS
az group lock create --lock-type CanNotDelete -n lock -g $SPOKE_RG

az group create --location $LOCATION --name $AKS_RG --tags $TAGS
az group lock create --lock-type CanNotDelete -n lock -g $AKS_RG

az group create --location $LOCATION --name $LOG_ANALYTICS_RG --tags $TAGS
az group lock create --lock-type CanNotDelete -n lock -g $LOG_ANALYTICS_RG

# ---------------- Create Hub VNET ------------------------
az network vnet create \
    --name $HUB_VNET_NAME \
    --location $LOCATION \
    --subscription $SUBSCRIPTIONID \
    --resource-group $HUB_RG \
    --address-prefix $HUB_VNET_ADDRESS_PREFIX \
    --tags $TAGS

# Get the id for Hub VNet.
HubVNetId=$(az network vnet show --resource-group $HUB_RG \
  --name $HUB_VNET_NAME --query id --out tsv)

# ---------------- Create Spoke VNET ------------------------
az network vnet create \
    --name $SPOKE_VNET_NAME \
    --location $LOCATION \
    --subscription $SUBSCRIPTIONID \
    --resource-group $SPOKE_RG \
    --address-prefix $SPOKE_VNET_ADDRESS_PREFIX \
    --tags $TAGS

# Get the id for Spoke VNet.
SpokeVNetId=$(az network vnet show --resource-group $SPOKE_RG \
  --name $SPOKE_VNET_NAME --query id --out tsv)

# ----------------- Create Peerings --------------------------
# Peer HUB to SPOKE.
az network vnet peering create \
  --name HubToSpoke \
  --resource-group $HUB_RG \
  --vnet-name $HUB_VNET_NAME \
  --remote-vnet-id $SpokeVNetId \
  --allow-vnet-access

# Peer SPOKE to HUB.
az network vnet peering create \
  --name SpokeToHub \
  --resource-group $SPOKE_RG \
  --vnet-name $SPOKE_VNET_NAME \
  --remote-vnet-id $HubVNetId \
  --allow-vnet-access

# ---------------- Create Hub GW NSG & Subnet ------------------
az network nsg create -g $HUB_RG -n $GW_NSG_NAME --tags $TAGS

az network vnet subnet create \
    --resource-group $HUB_RG \
    --vnet-name $HUB_VNET_NAME \
    --name $GW_SUBNET_NAME \
    --address-prefixes $GW_SUBNET_ADDRESS_PREFIX \
    --network-security-group $GW_NSG_NAME 

# ---------------- Create Spoke NSG & SQL Subnet ---------------

# coomented as SQL MI not want this at insrtallation
#az network nsg create -g $SPOKE_RG -n $SQL_NSG_NAME --tags $TAGS

az network vnet subnet create \
    --resource-group $SPOKE_RG \
    --vnet-name $SPOKE_VNET_NAME \
    --name $SQL_SUBNET_NAME \
    --address-prefixes $SQL_SUBNET_ADDRESS_PREFIX # \
#    --network-security-group $SQL_NSG_NAME 

# ---------------- Create Spoke NSG & AKS subnet ----------------
 az network nsg create -g $SPOKE_RG -n $AKS_NSG_NAME --tags $TAGS

 az network vnet subnet create \
    --resource-group $SPOKE_RG \
    --vnet-name $SPOKE_VNET_NAME \
    --name $AKS_SUBNET_NAME \
    --address-prefixes $AKS_SUBNET_ADDRESS_PREFIX \
    --network-security-group $AKS_NSG_NAME 

# ---------------- Create ACR ------------------------
az acr create \
  --name $ACR_NAME \
  --resource-group $ACR_RG \
  --sku Standard \
  --location $LOCATION \
  --subscription $SUBSCRIPTIONID \
  --tags $TAGS
    
# ------------ Create AKS Cluster --------------------
az aks create \
  --subscription $SUBSCRIPTIONID \
  --resource-group $AKS_RG \
  --name $AKS_CLUSTER_NAME \
  --node-count $AKS_NODE_COUNT \
  --max-pods $AKS_MAX_PODS \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME \
  --aad-server-app-id $AAD_SERVER_APP_ID \
  --aad-server-app-secret $AAD_SERVER_APP_SECRET \
  --aad-client-app-id $AAD_CLIENT_APP_ID \
  --aad-tenant-id $AAD_TENANT_ID \
  --network-plugin azure \
  --service-cidr $AKS_SERVICE_CIDR \
  --dns-service-ip $AKS_DNS_SERVICE_IP \
  --docker-bridge-address $AKS_DOCKER_BRIDGE_ADDRESS \
  --vnet-subnet-id /subscriptions/$SUBSCRIPTIONID/resourceGroups/$NW_RG/providers/Microsoft.Network/virtualNetworks/$SPOKE_VNET_NAME/subnets/$AKS_SUBNET_NAME \
  --kubernetes-version $AKS_VERSION \
  --workspace-resource-id $AKS_WORKSPACE_RESOURCE_ID \
  --tags $TAGS

#https://go.microsoft.com/fwlink/?linkid=871071

az sql mi create \
    --location $LOCATION \
    --admin-password $SQL_PASSWORD \
    --admin-user $SQL_USERNAME \
    --name $SQL_NAME \
    --resource-group $SPOKE_RG \
    --subnet $SQL_SUBNET_NAME \
    --vnet-name $SPOKE_VNET_NAME \
    --subscription $SUBSCRIPTIONID \
    --public-data-endpoint-enabled false \
    --capacity 4 \
    --edition GeneralPurpose \
    --family Gen5 \
    --license-type LicenseIncluded \
    --storage 32GB

az aks get-credentials \
    --resource-group $AKS_RG 
    --name $AKS_CLUSTER_NAME

# Get the resource ID of your AKS cluster
AKS_CLUSTER=$(az aks show --resource-group cc-uks-rsg-leap-sb-aks --name cc-uks-aks-leap-sb-01 --query id -o tsv)
# Get the account credentials for the logged in user
ACCOUNT_UPN=$(az account show --query user.name -o tsv)

ACCOUNT_ID=$(az ad user show --upn-or-object-id $ACCOUNT_UPN --query objectId -o tsv)

echo $ACCOUNT_UPN
echo $AKS_CLUSTER
echo $ACCOUNT_ID

# Assign the 'Cluster Admin' role to the logged in user
az role assignment create \
    --assignee $ACCOUNT_ID \
    --scope $AKS_CLUSTER \
    --role "Azure Kubernetes Service Cluster Admin Role"


