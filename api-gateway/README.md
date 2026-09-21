# API Gateway — JWT Authorizer (Azure AD)

Plantilla CloudFormation que crea un **HTTP API** con un **JWT Authorizer** de Azure AD
y enruta `ANY /api/{proxy+}` al BFF en EC2 (`http://<BackendHost>:8080/api/{proxy}`).

## Despliegue

```bash
aws cloudformation deploy \
  --stack-name rutaexpress-api \
  --template-file infra/api-gateway/template.yml \
  --parameter-overrides \
      AzureTenantId=<tenant-id> \
      AzureClientId=<api-client-id> \
      BackendHost=<dns-o-ip-del-ec2> \
      AllowedOrigin=https://<dominio-frontend>
```

Al terminar, tomar la URL base del output `ApiEndpoint` y usarla en el frontend:

```
VITE_BFF_URL=<ApiEndpoint>/api/bff
```

## Notas

- El authorizer valida el JWT contra `https://login.microsoftonline.com/<tenant>/v2.0`
  con audience = `AzureClientId`. Los servicios igualmente revalidan el token (defensa en profundidad).
- El token lo emite Azure AD para el **SPA** (`rutaexpress-spa`), con el scope `api://rutaexpress/access_as_user`.
- `BackendHost` debe ser alcanzable desde API Gateway. En producción se recomienda un ALB delante
  del EC2 (con el puerto 8080 restringido al security group del ALB/gateway) en vez de exponer el 8080.
- Para CORS en producción, fijar `AllowedOrigin` al dominio real del frontend.
