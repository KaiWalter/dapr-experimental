$env:DAPR_HTTP_PORT = 3501
$env:DAPR_GRPC_PORT = 50002
$APP_PORT = 5002
$env:ASPNETCORE_URLS = "http://localhost:" + $APP_PORT + ";https://localhost:" + $($APP_PORT+1)
dapr run --app-id app2 --app-port $APP_PORT --grpc-port $env:DAPR_GRPC_PORT --port $env:DAPR_HTTP_PORT -- dotnet run --urls $env:ASPNETCORE_URLS