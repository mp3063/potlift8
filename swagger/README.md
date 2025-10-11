# Potlift8 API Documentation

Comprehensive API documentation for the Potlift8 Product Information Management system.

## Quick Links

- **Interactive Documentation (RapiDoc)**: [http://localhost:3246/api/v1/docs.html](http://localhost:3246/api/v1/docs.html)
- **Interactive Documentation (Swagger UI)**: [http://localhost:3246/api/v1/swagger.html](http://localhost:3246/api/v1/swagger.html)
- **OpenAPI Specification**: `/swagger/v1/swagger.yaml`
- **Ruby Client SDK**: `/lib/potlift_api_client/`
- **JavaScript Client SDK**: `/clients/javascript/`

## Overview

The Potlift8 API provides RESTful endpoints for managing cannabis inventory, products, and synchronization with external systems (M23, Shopify3, Bizcart).

### Key Features

- **Multi-tenant architecture** - All data is scoped to your company
- **Bearer token authentication** - Simple and secure API authentication
- **RESTful design** - Standard HTTP methods and status codes
- **JSON responses** - Consistent, well-structured data format
- **Comprehensive error handling** - Detailed error messages with validation details
- **Rate limiting** - Configurable per catalog (default: 100 req/60s)

## Getting Started

### 1. Obtain Your API Token

Contact your system administrator or regenerate your API token from the company settings.

```ruby
# In Rails console
company = Company.find_by(code: 'YOUR_COMPANY_CODE')
api_token = company.regenerate_api_token!
puts "API Token: #{api_token}"
```

### 2. Make Your First API Call

#### Using cURL

```bash
curl -X GET http://localhost:3246/api/v1/products \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Accept: application/json"
```

#### Using Ruby Client

```ruby
require 'potlift_api_client'

client = PotliftApiClient::Client.new(
  api_token: 'YOUR_API_TOKEN',
  base_url: 'http://localhost:3246'
)

products = client.products.list
puts "Found #{products.size} products"
```

#### Using JavaScript Client

```javascript
import { PotliftClient } from 'potlift-api-client';

const client = new PotliftClient({
  apiToken: 'YOUR_API_TOKEN',
  baseUrl: 'http://localhost:3246'
});

const products = await client.products.list();
console.log(`Found ${products.length} products`);
```

## API Endpoints

### Products

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/products` | List all active, sellable products |
| GET | `/api/v1/products/{sku}` | Get product details by SKU |
| PATCH | `/api/v1/products/{sku}` | Update product information |

### Inventories

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/inventories/update` | Update product inventory across storages |

### Sync Tasks

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/sync_tasks` | Create synchronization task from external system |

## Authentication

All API requests require Bearer token authentication. Include your API token in the `Authorization` header:

```
Authorization: Bearer YOUR_API_TOKEN
```

### Example

```bash
curl -X GET http://localhost:3246/api/v1/products/PROD001 \
  -H "Authorization: Bearer abc123xyz789..."
```

### Error Responses

**401 Unauthorized** - Missing or invalid API token
```json
{
  "error": "Unauthorized"
}
```

## Rate Limiting

API requests are rate-limited based on catalog configuration:
- **Default**: 100 requests per 60 seconds
- **Configurable**: Per-catalog rate limits can be adjusted

Rate limit information is included in response headers:
- `X-RateLimit-Limit`: Maximum requests per period
- `X-RateLimit-Remaining`: Remaining requests in current period
- `X-RateLimit-Reset`: Unix timestamp when limit resets

## Response Format

All successful responses return JSON data:

```json
{
  "sku": "PROD001",
  "name": "Premium Cannabis Flower",
  "product_status": "active",
  "total_saldo": 150
}
```

## Error Handling

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 401 | Unauthorized - Invalid or missing API token |
| 404 | Not Found - Resource doesn't exist |
| 422 | Unprocessable Entity - Validation failed |
| 500 | Internal Server Error |

### Error Response Format

```json
{
  "error": "Validation failed",
  "details": {
    "name": ["can't be blank"],
    "sku": ["has already been taken"]
  }
}
```

## Common Use Cases

### 1. Sync Product from External System

```bash
curl -X POST http://localhost:3246/api/v1/sync_tasks \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin_event_id": "shopify3_evt_12345",
    "direction": "inbound",
    "event_type": "product.updated",
    "key": "PROD001",
    "load": {
      "sku": "PROD001",
      "name": "Updated Product Name",
      "price": 3299
    }
  }'
```

### 2. Update Inventory Levels

```bash
curl -X POST http://localhost:3246/api/v1/inventories/update \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sku": "PROD001",
    "inventory": {
      "updates": [
        {
          "storage_code": "MAIN",
          "value": 150
        },
        {
          "storage_code": "INCOMING",
          "value": 50,
          "eta": "2025-10-15"
        }
      ]
    }
  }'
```

### 3. Get Product Details with Inventory

```bash
curl -X GET http://localhost:3246/api/v1/products/PROD001 \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

Response:
```json
{
  "sku": "PROD001",
  "name": "Premium Cannabis Flower - Indica",
  "product_status": "active",
  "product_type": "sellable",
  "total_saldo": 150,
  "total_max_sellable_saldo": 100,
  "attributes": [
    {
      "code": "price",
      "name": "Price",
      "value": "2999"
    }
  ],
  "inventory": [
    {
      "storage_code": "MAIN",
      "storage_name": "Main Warehouse",
      "value": 100,
      "default": true
    },
    {
      "storage_code": "INCOMING",
      "storage_name": "Incoming Stock",
      "value": 50,
      "eta": "2025-10-15"
    }
  ]
}
```

### 4. List Products with Pagination

```bash
curl -X GET "http://localhost:3246/api/v1/products?page=2&per_page=50" \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

## Client SDKs

### Ruby Client SDK

Location: `/lib/potlift_api_client/`

**Installation:**
```ruby
require_relative 'lib/potlift_api_client'

client = PotliftApiClient::Client.new(
  api_token: ENV['POTLIFT_API_TOKEN'],
  base_url: 'http://localhost:3246'
)
```

**Documentation:** [Ruby Client README](/lib/potlift_api_client/README.md)

### JavaScript/TypeScript Client SDK

Location: `/clients/javascript/`

**Installation:**
```bash
npm install potlift-api-client
```

**Usage:**
```typescript
import { PotliftClient } from 'potlift-api-client';

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN,
  baseUrl: 'http://localhost:3246'
});
```

**Documentation:** [JavaScript Client README](/clients/javascript/README.md)

## Interactive Documentation

### RapiDoc (Recommended)

Modern, responsive API documentation with dark theme and live testing.

**URL:** [http://localhost:3246/api/v1/docs.html](http://localhost:3246/api/v1/docs.html)

**Features:**
- Dark theme optimized for developers
- Live API testing with "Try It Out" functionality
- Schema visualization
- Request/response examples
- Authentication configuration

### Swagger UI

Classic Swagger interface with comprehensive testing capabilities.

**URL:** [http://localhost:3246/api/v1/swagger.html](http://localhost:3246/api/v1/swagger.html)

**Features:**
- Standard Swagger UI interface
- Request code snippets (cURL, PowerShell, etc.)
- Schema models
- Live API testing

## OpenAPI Specification

The complete OpenAPI 3.0.0 specification is available at:
- **Source:** `/swagger/v1/swagger.yaml`
- **Public:** `/public/swagger/v1/swagger.yaml`

You can use this specification to:
- Generate client SDKs in other languages
- Import into Postman or Insomnia
- Validate API requests/responses
- Generate documentation

### Using with Postman

1. Open Postman
2. Click "Import" → "Link"
3. Enter: `http://localhost:3246/swagger/v1/swagger.yaml`
4. Configure authentication: Add header `Authorization: Bearer YOUR_API_TOKEN`

### Using with Insomnia

1. Open Insomnia
2. Click "Create" → "Import From" → "URL"
3. Enter: `http://localhost:3246/swagger/v1/swagger.yaml`
4. Set environment variable: `api_token` with your token value

## Development

### Running the API Server

```bash
# Start Rails server
bin/rails server

# Or with bin/dev (includes Tailwind)
bin/dev
```

The API will be available at `http://localhost:3246/api/v1`

### Testing API Endpoints

```bash
# Using Rails console
bin/rails console

# Create test company with API token
company = Company.create!(
  code: 'TEST123',
  name: 'Test Company'
)
token = company.api_token
puts "API Token: #{token}"

# Test API call
require 'net/http'
uri = URI('http://localhost:3246/api/v1/products')
req = Net::HTTP::Get.new(uri)
req['Authorization'] = "Bearer #{token}"
res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
puts res.body
```

### Validating OpenAPI Spec

```bash
# Install OpenAPI validator
npm install -g @apidevtools/swagger-cli

# Validate spec
swagger-cli validate swagger/v1/swagger.yaml
```

## Production Deployment

### Environment Variables

```bash
# .env.production
POTLIFT_API_URL=https://api.potlift.com
RAILS_ENV=production
```

### Security Considerations

1. **Use HTTPS** in production
2. **Rotate API tokens** regularly
3. **Monitor rate limits** and adjust per catalog
4. **Log API access** for security audits
5. **Set up alerts** for unusual API activity

### CORS Configuration

If accessing the API from browser-based applications, configure CORS in Rails:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://your-frontend.com'
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options]
  end
end
```

## Support

### Documentation Resources

- **OpenAPI Spec**: `/swagger/v1/swagger.yaml`
- **RapiDoc UI**: http://localhost:3246/api/v1/docs.html
- **Swagger UI**: http://localhost:3246/api/v1/swagger.html
- **Ruby SDK Docs**: `/lib/potlift_api_client/README.md`
- **JS SDK Docs**: `/clients/javascript/README.md`

### Contact

- **Email**: support@potlift.com
- **Issues**: Report bugs or request features via your project management system

### Version History

- **v1.0.0** (2025-10-11) - Initial API release
  - Products endpoints
  - Inventories endpoints
  - Sync tasks endpoints
  - Ruby client SDK
  - JavaScript/TypeScript client SDK
  - Interactive documentation

## License

Proprietary - Copyright (c) 2025 Potlift8

All rights reserved. This API and its documentation are proprietary and confidential.
