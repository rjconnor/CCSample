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

# ----------- Define Variables --------------
SUBSCRIPTIONNAME="Clyde & Co - UK - Leap - Sandbox - CDW UK CSP"
SUBSCRIPTIONID="00bcabe9-0608-46f3-a624-a53c00ecbf5b"

# Set subscription
az account set --subscription $SUBSCRIPTIONID

ORG='cc'
ENV='sb' 
TAGS='environment='$ENV 
LOCATION="uksouth"
REGIONSHORT='uks'

# Resource groups
GEN_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}"
HUB_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-hub"
AKS_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-aks"
ACR_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-acr"
NW_RG="${ORG}-${REGIONSHORT}-rsg-leap-${ENV}-network"

WORKSPACE_NAME="${ORG}-${REGIONSHORT}-law-leap-${ENV}-001"

echo $HUB_RG
echo $AKS_RG
echo $ACR_RG
echo $NW_RG
echo $WORKSPACE_NAME

#Log analytics

AKS_WORKSPACE_RESOURCE_ID="/subscriptions/$SUBSCRIPTIONID/resourcegroups/$GEN_RG/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME"
echo $AKS_WORKSPACE_RESOURCE_ID

#AAD
AAD_SERVER_APP_ID="d99f8e30-6873-4219-8981-94c2473d32b8"
AAD_SERVER_APP_SECRET="pCS/QMoM9QgN9uFJ08GmbQ?[WGawOEm?"
AAD_CLIENT_APP_ID="6d121ab4-7a85-4288-a7b6-e1cc8fa8b555"
AAD_TENANT_ID="eb5e156e-540c-42da-8f8c-0cd5639f036a"

# SQL
SQL_NAME="${ORG}-${REGIONSHORT}-sqlmi-${ENV}-01"
SQL_USERNAME="clydeandcosbadmin"
SQL_PASSWORD="Zxcvbnm12345#####"
echo $SQL_NAME
echo $SQL_USERNAME
echo $SQL_PASSWORD

#VNET
HUB_VNET_NAME="${ORG}-${REGIONSHORT}-vnet-hub-01"
HUB_VNET_ADDRESS_PREFIX="10.125.240.0/20"
echo $HUB_VNET_NAME

SPOKE_VNET_NAME="${ORG}-${REGIONSHORT}-vnet-leap-${ENV}-01"
SPOKE_VNET_ADDRESS_PREFIX="10.1.0.0/16"
echo $SPOKE_VNET_NAME

#SUBNET
GW_SUBNET_NAME="${ORG}-${REGIONSHORT}-snet-gw"
GW_SUBNET_ADDRESS_PREFIX="10.0.0.0/24"
GW_NSG_NAME="${ORG}-${REGIONSHORT}-nsg-gw"
echo $GW_SUBNET_NAME
echo $GW_NSG_NAME

SQL_SUBNET_NAME="${ORG}-${REGIONSHORT}-subnet-sql-${ENV}"
SQL_SUBNET_ADDRESS_PREFIX="10.1.0.0/24"
SQL_NSG_NAME="${ORG}-${REGIONSHORT}-nsg-sql"
echo $SQL_SUBNET_NAME
echo $SQL_NSG_NAME

AKS_SUBNET_NAME="${ORG}-${REGIONSHORT}-leap-${ENV}-snet-aks-01"
AKS_SUBNET_ADDRESS_PREFIX="10.125.0.0/22"
AKS_NSG_NAME="${ORG}-${REGIONSHORT}-nsg-${ENV}-snet-aks-01"
echo $AKS_SUBNET_NAME
echo $AKS_NSG_NAME

#ACR
ACR_NAME="ccukssbacr"
echo $ACR_NAME

#AKS
AKS_CLUSTER_NAME="${ORG}-${REGIONSHORT}-aks-leap-${ENV}-01"
AKS_NODE_COUNT="3"
AKS_MAX_PODS="30"
AKS_SERVICE_CIDR="10.125.4.0/24"
AKS_DNS_SERVICE_IP="10.125.4.254"
AKS_DOCKER_BRIDGE_ADDRESS="10.125.5.1/28"
AKS_VERSION="1.14.8"
echo $AKS_RG
echo $AKS_CLUSTER_NAME
echo $AKS_VERSION


# ----------- Create Resource Groups --------------
#az group delete  --name $HUB_RG
#az group delete  --name $SPOKE_RG
#az group delete  --name $LOG_ANALYTICS_RG

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

# end

