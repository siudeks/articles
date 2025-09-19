# Azure Container Apps vs App Service: Scale to Zero Demo

This Terraform configuration creates the infrastructure needed to test Java Spring Boot applications with scale-to-zero capabilities on Azure.

## Infrastructure Components

### 1. Azure Container Apps (Recommended for Scale to Zero)
- **True scale to zero**: Can scale down to 0 replicas when not in use
- **Fast cold starts**: Optimized for container startup
- **Event-driven scaling**: HTTP requests trigger scaling

### 2. Azure App Service (Alternative)
- **Near-zero scaling**: Can scale down but not to true zero
- **Always-on disabled**: Reduces costs but doesn't achieve true zero
- **Familiar platform**: Traditional web app hosting

## Prerequisites

1. Azure CLI installed and logged in:
   ```bash
   az login
   ```

2. Terraform installed (version >= 1.0)

3. Docker images built and pushed to a registry

## Deployment Steps

1. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan -var="container_image=your-registry.azurecr.io/spring-demo:latest"
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply -var="container_image=your-registry.azurecr.io/spring-demo:latest"
   ```

## Testing Scale to Zero

### Container Apps (True Scale to Zero)
1. Wait 2-3 minutes after deployment without traffic
2. Check replica count: should be 0
3. Send HTTP request - observe cold start time
4. Monitor scaling behavior in Azure portal

### App Service (Near Zero)
1. Disable "Always On" in configuration
2. Wait for idle timeout (20+ minutes)
3. Application becomes "cold" but container remains
4. First request after idle period shows warm-up time

## Performance Monitoring

The infrastructure includes:
- **Application Insights**: Performance metrics and startup times
- **Log Analytics**: Detailed logging and monitoring
- **Container metrics**: CPU, memory, and scaling events

## Cost Optimization

- Container Apps: Pay only for execution time (true zero cost when idle)
- App Service: Minimum plan cost even when idle
- Both include Application Insights and Log Analytics costs

## Cleanup

```bash
terraform destroy
```

## Variables

| Name | Description | Default |
|------|-------------|---------|
| location | Azure region | West Europe |
| resource_group_name | Resource group name | rg-spring-scale-to-zero |
| app_name | Application name | spring-scale-demo |
| container_image | Container image to deploy | your-registry.azurecr.io/spring-demo:latest |