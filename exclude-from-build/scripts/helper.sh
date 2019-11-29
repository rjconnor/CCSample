
# nigel wardle account id
#84a27076-a246-4e98-8590-58822ad2f74f

kubectl apply -f rbac-aad-user.yaml

kubectl config view

# clear local config for sb AKS
kubectl config delete-context cc-uks-aks-leap-sb-01

az account set --subscription 00bcabe9-0608-46f3-a624-a53c00ecbf5b

az aks get-credentials --resource-group cc-uks-rsg-leap-sb-aks --name cc-uks-aks-leap-sb-01 --overwrite-existing --admin

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

az ad user show --upn-or-object-id nigel.wardle@clydeandco.onmicrosoft.com --query objectId -o tsv

# assign Network Contributor role to AKS Service Principle to RG that hosts the VNET- need this to specify ILB subnet for service 
az role assignment create --assignee caa68f4b-b41e-4d36-9000-c2a3f3606a19 --role "Network Contributor" --resource-group cc-uks-rsg-leap-sb-network

# launch kubernetes Dashboard for sb
az aks browse --name cc-uks-aks-leap-sb-01 --resource-group cc-uks-rsg-leap-sb-aks

# make Dashboard publically writable - DONT DO THIS!!
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

# make Daskboard Read only with the following 2 commands
kubectl apply -f dashboard-viewonly-ClusterRole.yaml

kubectl apply -f dashboard-viewonly-ClusterRoleBinding.yaml

# link ACR if not already linked to AKS
az aks update -n cc-uks-aks-leap-sb-01 -g cc-uks-rsg-leap-sb-aks --attach-acr ccukssbacr

# scale NodePool
az aks nodepool scale \
    --resource-group cc-demo-rg \
    --cluster-name k8scc \
    --name mynodepool \
    --node-count 1 \
    --no-wait



# helm stuff ====================
kubectl apply -f helm-rbac.yaml

helm init --history-max 200 --service-account tiller --node-selectors "beta.kubernetes.io/os=linux"

helm install stable/nginx-ingress \
    --namespace ingress-basic \
    --generate-name \
    -f internal-ingress.yaml \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux