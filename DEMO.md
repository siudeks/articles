1. Create Azure App Containers using Terraform with scaled to 0 instance of Nginx
   export ARM_SUBSCRIPTION_ID=$(az account list --query "[?name == 'tech-spike'].id | [0]" --output tsv)
   terraform apply

2. Check number of replicas on just created environment (this command will NOT trigger scaling)
   az containerapp revision list --name $(az containerapp list --query "[0].name" -o tsv) --resource-group $(az containerapp list --query "[0].resourceGroup" -o tsv) --query "[].{Name:name, CreatedTime:properties.createdTime, Replicas:properties.replicas, Active:properties.active}" -o table

   Note: Azure Container Apps scale-down cooldown is minimum ~60 seconds (not configurable to 10 seconds)
   
3. Do cold start, measure response time using curl, ab, httpie

## HTTP Testing Commands:

### Get Container App URL:
```bash
APP_URL=$(az containerapp show --name $(az containerapp list --query "[0].name" -o tsv) --resource-group $(az containerapp list --query "[0].resourceGroup" -o tsv) --query "properties.configuration.ingress.fqdn" -o tsv)
echo "App URL: https://$APP_URL"
```

### Detailed curl timing (best for cold start analysis):
```bash
curl -w "@-" -o /dev/null -s "https://$APP_URL" <<'EOF'
     time_namelookup:  %{time_namelookup}s
        time_connect:  %{time_connect}s  
     time_appconnect:  %{time_appconnect}s
    time_pretransfer:  %{time_pretransfer}s
       time_redirect:  %{time_redirect}s
  time_starttransfer:  %{time_starttransfer}s (first byte - includes cold start)
                     ----------
          time_total:  %{time_total}s
           http_code:  %{http_code}
EOF
```