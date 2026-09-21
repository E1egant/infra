# Azure AD — App Registration y MSAL

Guía mínima para configurar identidad en RutaExpress (Fase 5 del proyecto).

## 1. App Registration (backend / API)

1. Entra a **Azure Portal → Microsoft Entra ID → App registrations → New registration**.
2. Nombre: `rutaexpress-api`.
3. Supported account types: *Single tenant* (según política del equipo).
4. Redirect URI: dejar vacío (la API valida JWT, no redirige).
5. Tras crear, anota:
   - **Application (client) ID** → `AZURE_CLIENT_ID`
   - **Directory (tenant) ID** → `AZURE_TENANT_ID`
6. En **Expose an API**:
   - Setea el Application ID URI: `api://rutaexpress`
   - Agrega un scope: `access_as_user` (admin + users consent).
7. En **App roles** (si se necesita RBAC por rol):
   - `Operador`, `Bodega`, `Admin` con *user* como member type.

## 2. App Registration (frontend / SPA React)

1. Nueva registration: `rutaexpress-spa`.
2. Platform: **Single-page application**.
3. Redirect URI: `http://localhost:3000` (dev) y el dominio de producción.
4. API permissions → agregar el scope `api://rutaexpress/access_as_user`.

## 3. Configuración MSAL (React)

En el frontend, definir en `.env`:
\`\`\`
REACT_APP_AZURE_TENANT_ID=<tenant>
REACT_APP_AZURE_CLIENT_ID=<spa client id>
REACT_APP_AZURE_API_SCOPE=api://rutaexpress/access_as_user
\`\`\`

`@azure/msal-react` leerá estas variables para construir `PublicClientApplication`.

## 4. Validación en API

Los microservicios Spring Boot validan el JWT con:
- `issuer-uri: https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0`
- `audience: ${AZURE_CLIENT_ID}`

En AWS API Gateway (Fase 5/7) se agrega un **JWT Authorizer** apuntando al mismo issuer y audience.