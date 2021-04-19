#!/bin/sh

LOC=westeurope
RG=myresourcegroup
ACRNAME=czkwacr
VM=my-aci-jump-vm-42
VMSSH=~/.ssh/my-aci-jump-vm

az group create -g $RG -l $LOC

az acr create --resource-group $RG --name $ACRNAME --sku Basic

az deployment group create --resource-group $RG --template-file multi-container.json

ssh-keygen -m PEM -t rsa -b 4096 -f my-aci-jump-vm

az vm create --name $VM --resource-group $RG --image UbuntuLTS \
    --vnet-name aci-vnet --subnet vm-subnet \
    --public-ip-address-dns-name $VM \
    --size Standard_DS2_v2 \
    --admin-username azureuser \
    --ssh-key-values $VMSSH.pub

ssh -i $VMSSH azureuser@$VM.$LOC.cloudapp.azure.com curl -v http://10.0.0.4

az acr login --name $ACRNAME
