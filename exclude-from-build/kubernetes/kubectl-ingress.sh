
# install Helm/Tiller
#https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm

# create ServiceAccount and ClusterRoleBinding for Tiller
kubectl apply -f helm-rbac.yaml

# deploy Tiller
helm init --history-max 200 --service-account tiller --node-selectors "beta.kubernetes.io/os=linux"

helm repo update

# install internal ingress controller
# https://docs.microsoft.com/en-us/azure/aks/ingress-internal-ip

# Create a namespace for your ingress resources
kubectl create namespace ingress-basic

# Use Helm to deploy an NGINX ingress controller
helm install stable/nginx-ingress \
    --namespace ingress-basic \
    -f internal-ingress.yaml \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

helm list

#helm delete flailing-alpaca
