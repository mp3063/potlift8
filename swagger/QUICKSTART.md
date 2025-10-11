# Potlift8 API - Quick Start Guide

Get up and running with the Potlift8 API in 5 minutes.

## Prerequisites

- Access to Potlift8 system
- Company account with API token
- Basic knowledge of REST APIs

## Step 1: Get Your API Token

### Option A: Via Rails Console

```bash
bin/rails console
```

```ruby
company = Company.find_by(code: 'YOUR_COMPANY_CODE')
api_token = company.api_token

# Or regenerate if needed
api_token = company.regenerate_api_token!

puts "Your API Token: #{api_token}"
```

### Option B: Via Web Interface

1. Log in to Potlift8
2. Navigate to Company Settings
3. Copy or regenerate your API token

## Step 2: Test the Connection

### Using cURL

```bash
curl -X GET http://localhost:3246/api/v1/products \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Accept: application/json"
```

**Expected Response:**
```json
[
  {
    "sku": "PROD001",
    "name": "Product Name",
    "product_status": "active",
    "total_saldo": 100
  }
]
```

### Using HTTPie (Alternative)

```bash
http GET http://localhost:3246/api/v1/products \
  "Authorization: Bearer YOUR_API_TOKEN"
```

## Step 3: Choose Your Integration Method

### Option A: Ruby Client SDK (Recommended for Ruby Projects)

**1. Install:**
```ruby
require_relative 'lib/potlift_api_client'
```

**2. Initialize:**
```ruby
client = PotliftApiClient::Client.new(
  api_token: ENV['POTLIFT_API_TOKEN'],
  base_url: 'http://localhost:3246'
)
```

**3. Make API Calls:**
```ruby
# List products
products = client.products.list
puts "Found #{products.size} products"

# Get product details
product = client.products.get('PROD001')
puts "Product: #{product['name']}"
puts "Stock: #{product['total_saldo']}"

# Update product
client.products.update('PROD001', {
  name: 'Updated Name',
  product_status: 'active'
})

# Update inventory
client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 150 },
  { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
])
```

### Option B: JavaScript/TypeScript Client SDK

**1. Install:**
```bash
npm install potlift-api-client
```

**2. Initialize:**
```typescript
import { PotliftClient } from 'potlift-api-client';

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN!,
  baseUrl: 'http://localhost:3246'
});
```

**3. Make API Calls:**
```typescript
// List products
const products = await client.products.list();
console.log(`Found ${products.length} products`);

// Get product details
const product = await client.products.get('PROD001');
console.log('Product:', product.name);
console.log('Stock:', product.total_saldo);

// Update product
await client.products.update('PROD001', {
  name: 'Updated Name',
  product_status: 'active'
});

// Update inventory
await client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 150 },
  { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
]);
```

### Option C: Direct HTTP Requests

**Using Fetch (JavaScript):**
```javascript
const response = await fetch('http://localhost:3246/api/v1/products', {
  headers: {
    'Authorization': `Bearer ${apiToken}`,
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
});

const products = await response.json();
console.log(products);
```

**Using HTTParty (Ruby):**
```ruby
require 'httparty'

response = HTTParty.get(
  'http://localhost:3246/api/v1/products',
  headers: {
    'Authorization' => "Bearer #{api_token}",
    'Accept' => 'application/json'
  }
)

products = response.parsed_response
puts products
```

**Using Axios (JavaScript):**
```javascript
import axios from 'axios';

const client = axios.create({
  baseURL: 'http://localhost:3246/api/v1',
  headers: {
    'Authorization': `Bearer ${apiToken}`,
    'Content-Type': 'application/json'
  }
});

const { data: products } = await client.get('/products');
console.log(products);
```

## Step 4: Common Operations

### List All Products

```bash
curl -X GET http://localhost:3246/api/v1/products \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Get Product by SKU

```bash
curl -X GET http://localhost:3246/api/v1/products/PROD001 \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### Update Product

```bash
curl -X PATCH http://localhost:3246/api/v1/products/PROD001 \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "product": {
      "name": "New Product Name",
      "product_status": "active"
    }
  }'
```

### Update Inventory

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
        }
      ]
    }
  }'
```

### Create Sync Task

```bash
curl -X POST http://localhost:3246/api/v1/sync_tasks \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin_event_id": "ext_system_123",
    "direction": "inbound",
    "event_type": "product.updated",
    "key": "PROD001",
    "load": {
      "sku": "PROD001",
      "name": "Updated Name"
    }
  }'
```

## Step 5: Error Handling

### Handle Common Errors

**Ruby:**
```ruby
begin
  product = client.products.get('INVALID_SKU')
rescue PotliftApiClient::NotFoundError => e
  puts "Product not found: #{e.message}"
rescue PotliftApiClient::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue PotliftApiClient::ValidationError => e
  puts "Validation failed: #{e.message}"
  e.field_errors.each do |field, errors|
    puts "  #{field}: #{errors.join(', ')}"
  end
rescue PotliftApiClient::ApiError => e
  puts "API error: #{e.message} (#{e.status_code})"
end
```

**JavaScript:**
```typescript
import { NotFoundError, ValidationError } from 'potlift-api-client';

try {
  const product = await client.products.get('INVALID_SKU');
} catch (error) {
  if (error instanceof NotFoundError) {
    console.error('Product not found:', error.message);
  } else if (error instanceof ValidationError) {
    console.error('Validation failed:', error.message);
    console.error('Field errors:', error.fieldErrors);
  } else {
    console.error('API error:', error);
  }
}
```

## Step 6: Explore Interactive Documentation

### RapiDoc (Recommended)

Visit [http://localhost:3246/api/v1/docs.html](http://localhost:3246/api/v1/docs.html)

Features:
- Live API testing
- Request/response examples
- Schema visualization
- Dark theme

### Swagger UI

Visit [http://localhost:3246/api/v1/swagger.html](http://localhost:3246/api/v1/swagger.html)

Features:
- Classic Swagger interface
- Code snippet generation
- Try it out functionality

## Step 7: Set Up Environment Variables

### Create .env File

```bash
# .env
POTLIFT_API_TOKEN=your_api_token_here
POTLIFT_API_URL=http://localhost:3246
```

### Load in Your Application

**Ruby:**
```ruby
require 'dotenv'
Dotenv.load

client = PotliftApiClient::Client.new(
  api_token: ENV['POTLIFT_API_TOKEN'],
  base_url: ENV.fetch('POTLIFT_API_URL', 'http://localhost:3246')
)
```

**JavaScript:**
```typescript
import dotenv from 'dotenv';
dotenv.config();

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN!,
  baseUrl: process.env.POTLIFT_API_URL || 'http://localhost:3246'
});
```

## Common Scenarios

### Scenario 1: Sync Products from External System

```ruby
# External system webhook handler
def handle_product_update(webhook_data)
  client = PotliftApiClient::Client.new(api_token: ENV['POTLIFT_API_TOKEN'])

  client.sync_tasks.create(
    origin_event_id: webhook_data[:event_id],
    direction: 'inbound',
    event_type: 'product.updated',
    key: webhook_data[:product_sku],
    load: webhook_data[:product_data]
  )
end
```

### Scenario 2: Monitor Inventory Levels

```ruby
# Check low stock products
client = PotliftApiClient::Client.new(api_token: ENV['POTLIFT_API_TOKEN'])

products = client.products.list
low_stock = products.select { |p| p['total_saldo'] < 10 }

low_stock.each do |product|
  puts "Low stock alert: #{product['sku']} - #{product['name']}"
  puts "Current stock: #{product['total_saldo']}"
  # Send notification or create reorder task
end
```

### Scenario 3: Bulk Product Updates

```ruby
# Update multiple products in batch
client = PotliftApiClient::Client.new(api_token: ENV['POTLIFT_API_TOKEN'])

products_to_update = [
  { sku: 'PROD001', status: 'active' },
  { sku: 'PROD002', status: 'active' },
  { sku: 'PROD003', status: 'discontinuing' }
]

products_to_update.each do |update|
  begin
    client.products.update(update[:sku], product_status: update[:status])
    puts "Updated #{update[:sku]}"
  rescue => e
    puts "Failed to update #{update[:sku]}: #{e.message}"
  end

  # Respect rate limits
  sleep 0.1
end
```

## Troubleshooting

### Issue: "Unauthorized" Error

**Problem:** Invalid or missing API token

**Solution:**
1. Verify your API token is correct
2. Check the Authorization header format: `Bearer YOUR_TOKEN`
3. Regenerate API token if needed

```ruby
company = Company.find_by(code: 'YOUR_CODE')
new_token = company.regenerate_api_token!
```

### Issue: "Not Found" Error

**Problem:** Product SKU doesn't exist

**Solution:**
1. Verify the SKU is correct (case-insensitive)
2. Check that the product belongs to your company
3. Ensure product is not soft-deleted

### Issue: Rate Limit Exceeded

**Problem:** Too many requests

**Solution:**
1. Add delays between requests (e.g., `sleep 0.1`)
2. Implement exponential backoff
3. Contact admin to adjust rate limits

```ruby
# Exponential backoff retry
def with_retry(max_retries: 3)
  retries = 0
  begin
    yield
  rescue PotliftApiClient::ApiError => e
    retries += 1
    if retries <= max_retries
      sleep(2 ** retries)
      retry
    else
      raise
    end
  end
end
```

## Next Steps

1. **Read Full Documentation**: [/swagger/README.md](/swagger/README.md)
2. **Explore Client SDKs**:
   - [Ruby SDK](/lib/potlift_api_client/README.md)
   - [JavaScript SDK](/clients/javascript/README.md)
3. **Try Interactive Docs**: [http://localhost:3246/api/v1/docs.html](http://localhost:3246/api/v1/docs.html)
4. **Review OpenAPI Spec**: [/swagger/v1/swagger.yaml](/swagger/v1/swagger.yaml)

## Support

- **Email**: support@potlift.com
- **Documentation**: http://localhost:3246/api/v1/docs.html
- **OpenAPI Spec**: /swagger/v1/swagger.yaml

---

**Happy Coding!** 🚀
