$env:DAPR_HTTP_PORT = 3500
$env:DAPR_GRPC_PORT = 50001
$APP_PORT = 5000
$env:ASPNETCORE_URLS = "http://localhost:" + $APP_PORT + ";https://localhost:" + $($APP_PORT+1)
dapr run --app-id app1 --app-port $APP_PORT --grpc-port $env:DAPR_GRPC_PORT --port $env:DAPR_HTTP_PORT -- dotnet run --urls $env:ASPNETCORE_URLS