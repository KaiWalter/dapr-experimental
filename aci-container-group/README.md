# ACI Dapr sample

## installing resources

```sh
multi-container-resources.sh
```

## checks and clean up

```sh
az container show --resource-group myresourcegroup --name myContainerGroup --output table
az container logs --resource-group myresourcegroup --name myContainerGroup --container-name aci-tutorial-app
az container stop --resource-group myresourcegroup --name myContainerGroup
az container delete --resource-group myresourcegroup --name myContainerGroup

ssh -i ~/.ssh/my-aci-jump-vm azureuser@my-aci-jump-vm-42.westeurope.cloudapp.azure.com

az vm delete --name my-aci-jump-vm-42 --resource-group myresourcegroup

az group delete -g myresourcegroup
```

## locally

### building and running

```
docker-compose up --build -d
```

### check

```
curl http://localhost:5010/health
curl http://localhost:5020/health
curl http://localhost:5010/healthapp2
```

### tearing down

```
docker-compose down
```

## pushing to ACR

```
ACRNAME=czkwacr
az acr login --name $ACRNAME
docker-compose push
```

## CURRENT STATUS

> app + sidecar can be deployed with `dapr-app-aci.json` but Dapr sidecar does not find app on port 5010

## Links

- [Tutorial: Deploy a multi-container group using Docker Compose](https://docs.microsoft.com/en-us/azure/container-instances/tutorial-docker-compose)
- [Tutorial: Deploy a multi-container group using a Resource Manager template](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-multi-container-group)
- [Deploy container instances into an Azure virtual network](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-vnet)