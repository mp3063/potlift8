# Potlift8 API Client - JavaScript/TypeScript

JavaScript/TypeScript client library for the Potlift8 Product Information Management API.

## Installation

### Using npm

```bash
npm install potlift-api-client
```

### Using yarn

```bash
yarn add potlift-api-client
```

### Using pnpm

```bash
pnpm add potlift-api-client
```

## Requirements

- Node.js 14 or higher
- Modern browser with `fetch` API support (or polyfill)

## Quick Start

### TypeScript

```typescript
import { PotliftClient } from 'potlift-api-client';

// Initialize the client
const client = new PotliftClient({
  apiToken: 'your_api_token_here',
  baseUrl: 'http://localhost:3246' // Optional, defaults to localhost:3246
});

// List all products
const products = await client.products.list();
console.log(`Found ${products.length} products`);

// Get specific product
const product = await client.products.get('PROD001');
console.log('Product:', product.name);
console.log('Stock:', product.total_saldo);
```

### JavaScript (ES Modules)

```javascript
import { PotliftClient } from 'potlift-api-client';

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN,
  baseUrl: 'http://localhost:3246'
});

const products = await client.products.list();
products.forEach(p => console.log(p.sku, p.name));
```

### JavaScript (CommonJS)

```javascript
const { PotliftClient } = require('potlift-api-client');

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN,
  baseUrl: 'http://localhost:3246'
});

(async () => {
  const products = await client.products.list();
  console.log(products);
})();
```

## Configuration

### Client Options

```typescript
const client = new PotliftClient({
  apiToken: 'your_token',          // Required: Your company's API token
  baseUrl: 'http://localhost:3246', // Optional: API base URL
  timeout: 30000                    // Optional: Request timeout in ms (default: 30000)
});
```

### Environment Variables

Create a `.env` file:

```bash
POTLIFT_API_TOKEN=your_api_token_here
POTLIFT_API_URL=http://localhost:3246
```

Then use in your code:

```typescript
import { PotliftClient } from 'potlift-api-client';

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN!,
  baseUrl: process.env.POTLIFT_API_URL || 'http://localhost:3246'
});
```

## API Reference

### Products

#### List Products

```typescript
// List all products with default pagination
const products = await client.products.list();

// With pagination
const products = await client.products.list({
  page: 2,
  per_page: 50
});

// Iterate through products
products.forEach(product => {
  console.log('SKU:', product.sku);
  console.log('Name:', product.name);
  console.log('Status:', product.product_status);
  console.log('Inventory:', product.total_saldo);
  console.log('---');
});
```

#### Get Product Details

```typescript
// Get product by SKU
const product = await client.products.get('PROD001');

// Access product information
console.log('Name:', product.name);
console.log('Type:', product.product_type);
console.log('Status:', product.product_status);
console.log('Total inventory:', product.total_saldo);
console.log('Max sellable:', product.total_max_sellable_saldo);

// Access attributes (EAV pattern)
product.attributes.forEach(attr => {
  console.log(`${attr.name}: ${attr.value}`);
});

// Access inventory by storage
product.inventory?.forEach(inv => {
  console.log(`${inv.storage_name}: ${inv.value} units`);
});

// Access labels
product.labels.forEach(label => {
  console.log(`Label: ${label.name} (${label.label_type})`);
});

// Access subproducts (variants/components)
product.subproducts.forEach(sub => {
  console.log(`Variant: ${sub.sku} - ${sub.name}`);
});
```

#### Update Product

```typescript
// Update product name and status
const updated = await client.products.update('PROD001', {
  name: 'Updated Product Name',
  product_status: 'active'
});

// Update EAN code
await client.products.update('PROD001', {
  ean: '1234567890123'
});

// Update metadata (info JSONB field)
await client.products.update('PROD001', {
  info: {
    description: 'Premium quality product',
    thc_content: '22%',
    cbd_content: '1%'
  }
});

// Multiple updates at once
await client.products.update('PROD001', {
  name: 'New Name',
  product_status: 'discontinuing',
  ean: '9876543210987',
  info: { discontinued_reason: 'End of season' }
});
```

### Inventories

#### Update Inventory

```typescript
// Update inventory for single storage
const result = await client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 150 }
]);

// Update multiple storages at once
const result = await client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 120 },
  { storage_code: 'BACKUP', value: 30 }
]);

// Update incoming inventory with ETA
const result = await client.inventories.update('PROD001', [
  { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
]);

// Complete inventory restock
const result = await client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 200 },
  { storage_code: 'INCOMING', value: 100, eta: '2025-10-20' }
]);

// Check result
console.log('Success:', result.success);
console.log('Total inventory:', result.total_saldo);
result.inventory.forEach(inv => {
  console.log(`${inv.storage_name}: ${inv.value}`);
});
```

### Sync Tasks

#### Create Sync Task

```typescript
// Product update event from external system
const result = await client.syncTasks.create({
  origin_event_id: 'shopify3_evt_12345',
  direction: 'inbound',
  event_type: 'product.updated',
  key: 'PROD001',
  load: {
    sku: 'PROD001',
    name: 'Updated Product Name',
    price: 3299,
    inventory: 100
  }
});

// Inventory sync from warehouse system
const result = await client.syncTasks.create({
  origin_event_id: 'm23_inv_67890',
  direction: 'inbound',
  event_type: 'inventory.updated',
  key: 'PROD002',
  load: {
    sku: 'PROD002',
    storage_code: 'MAIN',
    value: 250
  }
});

// Order created (inventory deduction)
const result = await client.syncTasks.create({
  origin_event_id: 'bizcart_order_54321',
  direction: 'inbound',
  event_type: 'order.created',
  key: 'ORDER001',
  load: {
    order_id: 'ORDER001',
    items: [
      { sku: 'PROD001', quantity: 2 },
      { sku: 'PROD002', quantity: 1 }
    ]
  }
});

// Check result
console.log('Success:', result.success);
console.log('Task ID:', result.task_id);
```

## Error Handling

The client throws specific error types for different scenarios:

```typescript
import {
  PotliftClient,
  AuthenticationError,
  NotFoundError,
  ValidationError,
  TimeoutError,
  ConnectionError,
  PotliftApiError
} from 'potlift-api-client';

const client = new PotliftClient({ apiToken: 'your_token' });

try {
  const product = await client.products.get('INVALID_SKU');
} catch (error) {
  if (error instanceof AuthenticationError) {
    // 401 Unauthorized - Invalid API token
    console.error('Authentication failed:', error.message);
  } else if (error instanceof NotFoundError) {
    // 404 Not Found - Resource doesn't exist
    console.error('Product not found:', error.message);
    console.error('Status code:', error.statusCode);
  } else if (error instanceof ValidationError) {
    // 422 Unprocessable Entity - Validation failed
    console.error('Validation failed:', error.message);
    // Access field-specific errors
    Object.entries(error.fieldErrors).forEach(([field, errors]) => {
      console.error(`  ${field}: ${errors.join(', ')}`);
    });
  } else if (error instanceof TimeoutError) {
    // Request timeout
    console.error('Request timed out:', error.message);
  } else if (error instanceof ConnectionError) {
    // Connection failed
    console.error('Connection failed:', error.message);
  } else if (error instanceof PotliftApiError) {
    // Other API errors
    console.error('API error:', error.message);
    console.error('Status code:', error.statusCode);
  } else {
    console.error('Unknown error:', error);
  }
}
```

### Error Types

- `PotliftApiError` - Base error class for API errors
  - `AuthenticationError` - 401 Unauthorized
  - `NotFoundError` - 404 Not Found
  - `ValidationError` - 422 Unprocessable Entity (includes `fieldErrors`)
- `TimeoutError` - Request timeout
- `ConnectionError` - Connection failures

## TypeScript Support

The library is written in TypeScript and provides full type definitions:

```typescript
import { PotliftClient, Product, ProductDetail, InventoryUpdate } from 'potlift-api-client';

const client = new PotliftClient({ apiToken: 'token' });

// Type-safe API calls
const products: Product[] = await client.products.list();
const product: ProductDetail = await client.products.get('PROD001');

// Type-safe updates
const updates: InventoryUpdate[] = [
  { storage_code: 'MAIN', value: 150 },
  { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
];
await client.inventories.update('PROD001', updates);
```

## Advanced Usage

### Batch Operations

```typescript
// Process multiple products
const skus = ['PROD001', 'PROD002', 'PROD003'];

const products = await Promise.all(
  skus.map(async (sku) => {
    try {
      return await client.products.get(sku);
    } catch (error) {
      if (error instanceof NotFoundError) {
        return null;
      }
      throw error;
    }
  })
);

const validProducts = products.filter(p => p !== null);
console.log(`Found ${validProducts.length} valid products`);
```

### Pagination

```typescript
// Fetch all products with pagination
async function fetchAllProducts() {
  const allProducts: Product[] = [];
  let page = 1;
  const perPage = 100;

  while (true) {
    const products = await client.products.list({ page, per_page: perPage });

    if (products.length === 0) {
      break;
    }

    allProducts.push(...products);
    page++;

    // Optional: Add delay to respect rate limits
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  return allProducts;
}

const allProducts = await fetchAllProducts();
console.log(`Fetched ${allProducts.length} total products`);
```

### Product Status Management

```typescript
// Activate product
await client.products.update('PROD001', { product_status: 'active' });

// Discontinue product
await client.products.update('PROD001', { product_status: 'discontinuing' });

// Disable product temporarily
await client.products.update('PROD001', { product_status: 'disabled' });

// Mark as deleted (soft delete)
await client.products.update('PROD001', { product_status: 'deleted' });
```

### Retry Logic

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> {
  let lastError: Error;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (
        error instanceof TimeoutError ||
        error instanceof ConnectionError
      ) {
        console.log(`Retry ${i + 1}/${maxRetries} after error:`, error.message);
        await new Promise(resolve => setTimeout(resolve, delay * Math.pow(2, i)));
        continue;
      }

      throw error;
    }
  }

  throw lastError!;
}

// Usage
const product = await withRetry(() => client.products.get('PROD001'));
```

## Browser Usage

The client works in modern browsers with native `fetch` support:

```html
<!DOCTYPE html>
<html>
<head>
  <script type="module">
    import { PotliftClient } from 'https://unpkg.com/potlift-api-client';

    const client = new PotliftClient({
      apiToken: 'your_token',
      baseUrl: 'http://localhost:3246'
    });

    async function loadProducts() {
      try {
        const products = await client.products.list();
        console.log('Products:', products);
      } catch (error) {
        console.error('Error:', error);
      }
    }

    loadProducts();
  </script>
</head>
<body>
  <h1>Potlift8 API Client Demo</h1>
</body>
</html>
```

For older browsers, use a `fetch` polyfill:

```bash
npm install whatwg-fetch
```

```javascript
import 'whatwg-fetch';
import { PotliftClient } from 'potlift-api-client';
```

## React Integration

```typescript
import { useState, useEffect } from 'react';
import { PotliftClient, Product } from 'potlift-api-client';

const client = new PotliftClient({
  apiToken: process.env.REACT_APP_POTLIFT_API_TOKEN!,
  baseUrl: process.env.REACT_APP_POTLIFT_API_URL
});

function ProductList() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadProducts() {
      try {
        const data = await client.products.list();
        setProducts(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setLoading(false);
      }
    }

    loadProducts();
  }, []);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div>
      <h1>Products</h1>
      <ul>
        {products.map(product => (
          <li key={product.sku}>
            {product.name} - Stock: {product.total_saldo}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

## Node.js Integration

```typescript
import { PotliftClient } from 'potlift-api-client';
import * as dotenv from 'dotenv';

dotenv.config();

const client = new PotliftClient({
  apiToken: process.env.POTLIFT_API_TOKEN!,
  baseUrl: process.env.POTLIFT_API_URL || 'http://localhost:3246'
});

async function syncProducts() {
  try {
    const products = await client.products.list();

    for (const product of products) {
      console.log(`Syncing ${product.sku}...`);

      // Your sync logic here
      await client.products.update(product.sku, {
        product_status: 'active'
      });
    }

    console.log('Sync complete');
  } catch (error) {
    console.error('Sync failed:', error);
    process.exit(1);
  }
}

syncProducts();
```

## Testing

### Jest Setup

```typescript
// __tests__/client.test.ts
import { PotliftClient, NotFoundError } from 'potlift-api-client';

// Mock fetch
global.fetch = jest.fn();

describe('PotliftClient', () => {
  let client: PotliftClient;

  beforeEach(() => {
    client = new PotliftClient({
      apiToken: 'test_token',
      baseUrl: 'http://localhost:3246'
    });
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('lists products', async () => {
    const mockProducts = [
      { sku: 'PROD001', name: 'Test Product', total_saldo: 100 }
    ];

    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => mockProducts
    });

    const products = await client.products.list();

    expect(products).toEqual(mockProducts);
    expect(global.fetch).toHaveBeenCalledWith(
      expect.stringContaining('/api/v1/products'),
      expect.objectContaining({
        headers: expect.objectContaining({
          'Authorization': 'Bearer test_token'
        })
      })
    );
  });

  it('throws NotFoundError for 404', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 404,
      json: async () => ({ error: 'Product not found' })
    });

    await expect(client.products.get('INVALID')).rejects.toThrow(NotFoundError);
  });
});
```

## Building from Source

```bash
# Clone the repository
git clone https://github.com/potlift/potlift8.git
cd potlift8/clients/javascript

# Install dependencies
npm install

# Build the library
npm run build

# Run tests
npm test

# Type check
npm run typecheck

# Lint
npm run lint
```

## Support

For API support, documentation, or questions:
- API Documentation: http://localhost:3246/api/v1/docs
- OpenAPI Spec: `swagger/v1/swagger.yaml`
- Email: support@potlift.com

## License

Proprietary - Copyright (c) 2025 Potlift8
