# frozen_string_literal: true

require_relative 'potlift_api_client/version'
require_relative 'potlift_api_client/client'

# Potlift8 API Client
#
# Ruby client library for the Potlift8 Product Information Management API.
#
# @example Basic usage
#   require 'potlift_api_client'
#
#   client = PotliftApiClient::Client.new(
#     api_token: ENV['POTLIFT_API_TOKEN'],
#     base_url: 'http://localhost:3246'
#   )
#
#   # List products
#   products = client.products.list
#
#   # Get product details
#   product = client.products.get('PROD001')
#
#   # Update product
#   client.products.update('PROD001', name: 'New Name')
#
#   # Update inventory
#   client.inventories.update('PROD001', [
#     { storage_code: 'MAIN', value: 150 }
#   ])
#
#   # Create sync task
#   client.sync_tasks.create(
#     origin_event_id: 'evt_123',
#     direction: 'inbound',
#     event_type: 'product.updated',
#     key: 'PROD001',
#     load: { sku: 'PROD001', name: 'Updated' }
#   )
#
module PotliftApiClient
end
