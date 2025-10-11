# Potlift8 API Client - Ruby

Ruby client library for the Potlift8 Product Information Management API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'potlift_api_client', path: 'lib/potlift_api_client'
```

Or install it directly:

```ruby
require_relative 'lib/potlift_api_client'
```

## Dependencies

The client requires the following gems:
- `faraday` (~> 2.7) - HTTP client
- `json` - JSON parsing (included in Ruby stdlib)

Add to your Gemfile if not already present:

```ruby
gem 'faraday', '~> 2.7'
```

## Quick Start

```ruby
require 'potlift_api_client'

# Initialize the client
client = PotliftApiClient::Client.new(
  api_token: 'your_api_token_here',
  base_url: 'http://localhost:3246'  # Optional, defaults to localhost:3246
)

# List all products
products = client.products.list
puts "Found #{products.size} products"

# Get specific product
product = client.products.get('PROD001')
puts "Product: #{product['name']}"
puts "Stock: #{product['total_saldo']}"
```

## Configuration

### Environment Variables

Set your API token as an environment variable:

```bash
export POTLIFT_API_TOKEN=your_api_token_here
export POTLIFT_API_URL=http://localhost:3246  # Optional
```

Then in your code:

```ruby
client = PotliftApiClient::Client.new(
  api_token: ENV['POTLIFT_API_TOKEN'],
  base_url: ENV.fetch('POTLIFT_API_URL', 'http://localhost:3246')
)
```

### Client Options

```ruby
client = PotliftApiClient::Client.new(
  api_token: 'your_token',
  base_url: 'http://localhost:3246',  # Default: http://localhost:3246
  timeout: 30,                         # Request timeout in seconds (default: 30)
  open_timeout: 10                     # Connection timeout in seconds (default: 10)
)
```

## API Reference

### Products

#### List Products

```ruby
# List all products with default pagination
products = client.products.list

# With pagination
products = client.products.list(page: 2, per_page: 50)

# Iterate through products
products.each do |product|
  puts "SKU: #{product['sku']}"
  puts "Name: #{product['name']}"
  puts "Status: #{product['product_status']}"
  puts "Inventory: #{product['total_saldo']}"
  puts "---"
end
```

#### Get Product Details

```ruby
# Get product by SKU
product = client.products.get('PROD001')

# Access product information
puts "Name: #{product['name']}"
puts "Type: #{product['product_type']}"
puts "Status: #{product['product_status']}"
puts "Total inventory: #{product['total_saldo']}"

# Access attributes (EAV pattern)
product['attributes'].each do |attr|
  puts "#{attr['name']}: #{attr['value']}"
end

# Access inventory by storage
product['inventory'].each do |inv|
  puts "#{inv['storage_name']}: #{inv['value']} units"
end

# Access labels
product['labels'].each do |label|
  puts "Label: #{label['name']} (#{label['label_type']})"
end

# Access subproducts (variants/components)
product['subproducts'].each do |sub|
  puts "Variant: #{sub['sku']} - #{sub['name']}"
end
```

#### Update Product

```ruby
# Update product name and status
updated_product = client.products.update('PROD001', {
  name: 'Updated Product Name',
  product_status: 'active'
})

# Update EAN code
client.products.update('PROD001', {
  ean: '1234567890123'
})

# Update metadata (info JSONB field)
client.products.update('PROD001', {
  info: {
    description: 'Premium quality product',
    thc_content: '22%',
    cbd_content: '1%'
  }
})

# Multiple updates at once
client.products.update('PROD001', {
  name: 'New Name',
  product_status: 'discontinuing',
  ean: '9876543210987',
  info: { discontinued_reason: 'End of season' }
})
```

### Inventories

#### Update Inventory

```ruby
# Update inventory for single storage
result = client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 150 }
])

# Update multiple storages at once
result = client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 120 },
  { storage_code: 'BACKUP', value: 30 }
])

# Update incoming inventory with ETA
result = client.inventories.update('PROD001', [
  { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
])

# Complete inventory restock
result = client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 200 },
  { storage_code: 'INCOMING', value: 100, eta: '2025-10-20' }
])

# Check result
puts "Success: #{result['success']}"
puts "Total inventory: #{result['total_saldo']}"
result['inventory'].each do |inv|
  puts "#{inv['storage_name']}: #{inv['value']}"
end
```

### Sync Tasks

#### Create Sync Task

```ruby
# Product update event from external system
result = client.sync_tasks.create(
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
)

# Inventory sync from warehouse system
result = client.sync_tasks.create(
  origin_event_id: 'm23_inv_67890',
  direction: 'inbound',
  event_type: 'inventory.updated',
  key: 'PROD002',
  load: {
    sku: 'PROD002',
    storage_code: 'MAIN',
    value: 250
  }
)

# Order created (inventory deduction)
result = client.sync_tasks.create(
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
)

# Check result
puts "Success: #{result['success']}"
puts "Task ID: #{result['task_id']}"
```

## Error Handling

The client raises specific exceptions for different error types:

```ruby
require 'potlift_api_client'

client = PotliftApiClient::Client.new(api_token: 'your_token')

begin
  product = client.products.get('INVALID_SKU')
rescue PotliftApiClient::AuthenticationError => e
  # 401 Unauthorized - Invalid API token
  puts "Authentication failed: #{e.message}"
rescue PotliftApiClient::NotFoundError => e
  # 404 Not Found - Resource doesn't exist
  puts "Product not found: #{e.message}"
  puts "Status code: #{e.status_code}"
rescue PotliftApiClient::ValidationError => e
  # 422 Unprocessable Entity - Validation failed
  puts "Validation failed: #{e.message}"
  # Access field-specific errors
  e.field_errors.each do |field, errors|
    puts "  #{field}: #{errors.join(', ')}"
  end
rescue PotliftApiClient::TimeoutError => e
  # Request timeout
  puts "Request timed out: #{e.message}"
rescue PotliftApiClient::ConnectionError => e
  # Connection failed
  puts "Connection failed: #{e.message}"
rescue PotliftApiClient::ApiError => e
  # Other API errors
  puts "API error: #{e.message}"
  puts "Status code: #{e.status_code}"
end
```

### Exception Hierarchy

- `PotliftApiClient::Error` - Base exception class
  - `PotliftApiClient::ApiError` - API errors with response details
    - `PotliftApiClient::AuthenticationError` - 401 Unauthorized
    - `PotliftApiClient::NotFoundError` - 404 Not Found
    - `PotliftApiClient::ValidationError` - 422 Unprocessable Entity
  - `PotliftApiClient::ConnectionError` - Connection failures
  - `PotliftApiClient::TimeoutError` - Request timeouts

## Advanced Usage

### Batch Operations

```ruby
# Process multiple products
skus = ['PROD001', 'PROD002', 'PROD003']

products = skus.map do |sku|
  begin
    client.products.get(sku)
  rescue PotliftApiClient::NotFoundError
    nil
  end
end.compact

# Update multiple products
skus.each do |sku|
  begin
    client.products.update(sku, product_status: 'active')
  rescue PotliftApiClient::Error => e
    puts "Failed to update #{sku}: #{e.message}"
  end
end
```

### Pagination

```ruby
# Fetch all products with pagination
all_products = []
page = 1
per_page = 100

loop do
  products = client.products.list(page: page, per_page: per_page)
  break if products.empty?

  all_products.concat(products)
  page += 1

  # Optional: Add delay to respect rate limits
  sleep 0.5
end

puts "Fetched #{all_products.size} total products"
```

### Product Status Management

```ruby
# Activate product
client.products.update('PROD001', product_status: 'active')

# Discontinue product
client.products.update('PROD001', product_status: 'discontinuing')

# Disable product temporarily
client.products.update('PROD001', product_status: 'disabled')

# Mark as deleted (soft delete)
client.products.update('PROD001', product_status: 'deleted')
```

### Inventory Management

```ruby
# Check current inventory
product = client.products.get('PROD001')
current_inventory = product['total_saldo']

# Adjust inventory (increase)
new_value = current_inventory + 50
client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: new_value }
])

# Set incoming stock with ETA
client.inventories.update('PROD001', [
  { storage_code: 'INCOMING', value: 100, eta: Date.today + 7 }
])

# Zero out inventory
client.inventories.update('PROD001', [
  { storage_code: 'MAIN', value: 0 }
])
```

## Testing

### Using VCR for Testing

```ruby
# spec/spec_helper.rb
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<API_TOKEN>') { ENV['POTLIFT_API_TOKEN'] }
end

# spec/products_spec.rb
require 'spec_helper'
require 'potlift_api_client'

RSpec.describe 'Products API' do
  let(:client) do
    PotliftApiClient::Client.new(
      api_token: ENV['POTLIFT_API_TOKEN'],
      base_url: 'http://localhost:3246'
    )
  end

  it 'lists products', :vcr do
    products = client.products.list
    expect(products).to be_an(Array)
    expect(products.first).to have_key('sku')
  end

  it 'gets product details', :vcr do
    product = client.products.get('PROD001')
    expect(product['sku']).to eq('PROD001')
    expect(product).to have_key('name')
    expect(product).to have_key('total_saldo')
  end
end
```

### Mocking in Tests

```ruby
# spec/products_spec.rb
require 'spec_helper'
require 'potlift_api_client'
require 'webmock/rspec'

RSpec.describe 'Products API' do
  let(:client) do
    PotliftApiClient::Client.new(
      api_token: 'test_token',
      base_url: 'http://localhost:3246'
    )
  end

  before do
    stub_request(:get, 'http://localhost:3246/api/v1/products')
      .with(headers: { 'Authorization' => 'Bearer test_token' })
      .to_return(
        status: 200,
        body: [{ sku: 'PROD001', name: 'Test Product' }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'lists products' do
    products = client.products.list
    expect(products).to be_an(Array)
    expect(products.first['sku']).to eq('PROD001')
  end
end
```

## Production Usage

### Best Practices

1. **Always use environment variables** for API tokens
2. **Implement retry logic** for transient failures
3. **Log all API calls** for debugging
4. **Handle rate limits** by implementing backoff
5. **Use batch operations** when possible
6. **Monitor error rates** and set up alerts

### Example Production Setup

```ruby
require 'potlift_api_client'
require 'logger'

class PotliftService
  attr_reader :client, :logger

  def initialize
    @logger = Logger.new(STDOUT)
    @client = PotliftApiClient::Client.new(
      api_token: ENV.fetch('POTLIFT_API_TOKEN'),
      base_url: ENV.fetch('POTLIFT_API_URL', 'https://api.potlift.com'),
      timeout: 30,
      open_timeout: 10
    )
  end

  def sync_product(sku, data)
    retries = 0
    max_retries = 3

    begin
      logger.info("Syncing product #{sku}")
      client.products.update(sku, data)
      logger.info("Successfully synced product #{sku}")
    rescue PotliftApiClient::TimeoutError, PotliftApiClient::ConnectionError => e
      retries += 1
      if retries <= max_retries
        logger.warn("Retry #{retries}/#{max_retries} for #{sku}: #{e.message}")
        sleep(2**retries) # Exponential backoff
        retry
      else
        logger.error("Failed to sync #{sku} after #{max_retries} retries: #{e.message}")
        raise
      end
    rescue PotliftApiClient::ValidationError => e
      logger.error("Validation failed for #{sku}: #{e.message}")
      logger.error("Field errors: #{e.field_errors}")
      raise
    rescue PotliftApiClient::Error => e
      logger.error("API error for #{sku}: #{e.message}")
      raise
    end
  end

  def bulk_sync_products(products_data)
    results = { success: [], failed: [] }

    products_data.each do |sku, data|
      begin
        sync_product(sku, data)
        results[:success] << sku
      rescue PotliftApiClient::Error => e
        results[:failed] << { sku: sku, error: e.message }
      end

      # Rate limiting: wait between requests
      sleep 0.1
    end

    logger.info("Bulk sync complete: #{results[:success].size} succeeded, #{results[:failed].size} failed")
    results
  end
end

# Usage
service = PotliftService.new
service.sync_product('PROD001', name: 'Updated Name')

# Bulk sync
products = {
  'PROD001' => { name: 'Product 1', product_status: 'active' },
  'PROD002' => { name: 'Product 2', product_status: 'active' }
}
results = service.bulk_sync_products(products)
```

## Support

For API support, documentation, or questions:
- API Documentation: http://localhost:3246/api/v1/docs
- OpenAPI Spec: `swagger/v1/swagger.yaml`
- Email: support@potlift.com

## License

Proprietary - Copyright (c) 2025 Potlift8
