# Windows - PowerShell with Azure CLI
# deployment based on YAML file : https://docs.microsoft.com/en-us/azure/container-instances/container-instances-reference-yaml

[System.Console]::ResetColor()

$LOC = "westeurope"
$RG = "myresourcegroup"
$ACRNAME = "czkwacr"

az group create -g $RG -l $LOC

az configure --defaults location=$LOC group=$RG

$acr = az acr show -n $ACRNAME -o json | ConvertFrom-Json -Depth 10

# az container create --name app1 --image $($acr.loginServer+"/app1") `
#     --assign-identity --role acrpull --scope $acr.id `
#     --debug

az container create -f ./dapr-aci-public.yaml `
    --registry-login-server $acr.loginServer `
    --assign-identity --role AcrPull --scope $acr.id `
    -o json | ConvertFrom-Json -Depth 10

$cg = az container create -f ./dapr-aci-public.yaml --assign-identity --role AcrPull --scope '$acr.id' -o json | ConvertFrom-Json -Depth 10

Write-Host "started on" $cg.properties.ipAddress.ip

$url = "http://" + $cg.properties.ipAddress.ip + ":5010/health"
Invoke-WebRequest $url

$url = "http://" + $cg.properties.ipAddress.ip + ":5020/health"
Invoke-WebRequest $url

$url = "http://" + $cg.properties.ipAddress.ip + ":5010/healthapp2"
Invoke-WebRequest $url

Read-Host "Hit enter to stop container group"

az container stop -g $RG -n $cg.name

Read-Host "Hit enter to delete container group"

az container delete -g $RG -n $cg.name -y