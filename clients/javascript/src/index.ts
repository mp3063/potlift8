/**
 * Potlift8 API Client for JavaScript/TypeScript
 *
 * A comprehensive client library for interacting with the Potlift8 Product Information Management API.
 *
 * @example
 * ```typescript
 * import { PotliftClient } from 'potlift-api-client';
 *
 * const client = new PotliftClient({
 *   apiToken: 'your_api_token',
 *   baseUrl: 'http://localhost:3246'
 * });
 *
 * // List products
 * const products = await client.products.list();
 *
 * // Get product details
 * const product = await client.products.get('PROD001');
 *
 * // Update product
 * await client.products.update('PROD001', { name: 'New Name' });
 *
 * // Update inventory
 * await client.inventories.update('PROD001', [
 *   { storage_code: 'MAIN', value: 150 }
 * ]);
 * ```
 */

// Type definitions
export interface ClientConfig {
  apiToken: string;
  baseUrl?: string;
  timeout?: number;
}

export interface Product {
  sku: string;
  name: string;
  product_status: 'draft' | 'active' | 'incoming' | 'discontinuing' | 'disabled' | 'discontinued' | 'deleted';
  product_type: 'sellable' | 'configurable' | 'bundle';
  configuration_type?: 'variant' | 'option';
  ean?: string;
  total_saldo: number;
  info?: Record<string, any>;
  attributes?: Record<string, string>;
  inventory?: InventoryItem[];
}

export interface ProductDetail extends Product {
  total_max_sellable_saldo: number;
  attributes: ProductAttribute[];
  labels: Label[];
  subproducts: SubProduct[];
}

export interface ProductAttribute {
  code: string;
  name: string;
  value: string;
  attribute_type?: 'string' | 'integer' | 'decimal' | 'boolean' | 'date';
}

export interface InventoryItem {
  storage_code: string;
  storage_name: string;
  storage_type: 'physical' | 'virtual' | 'incoming';
  value: number;
  default: boolean;
  eta?: string;
}

export interface InventoryUpdate {
  storage_code: string;
  value: number;
  eta?: string;
}

export interface InventoryUpdateResponse {
  success: boolean;
  inventory: InventoryItem[];
  total_saldo: number;
}

export interface Label {
  code: string;
  name: string;
  label_type: string;
  info?: Record<string, any>;
}

export interface SubProduct {
  sku: string;
  name: string;
  product_status: string;
  product_type: string;
  total_saldo: number;
}

export interface SyncTask {
  origin_event_id: string;
  direction: 'inbound' | 'outbound';
  event_type: string;
  key: string;
  load: Record<string, any>;
}

export interface SyncTaskResponse {
  success: boolean;
  message: string;
  task_id: string;
}

export interface ListOptions {
  page?: number;
  per_page?: number;
}

export interface ProductUpdateData {
  name?: string;
  product_status?: 'draft' | 'active' | 'incoming' | 'discontinuing' | 'disabled' | 'discontinued' | 'deleted';
  ean?: string;
  info?: Record<string, any>;
}

export interface ApiError {
  error: string;
  details?: Record<string, string[]>;
}

// Custom error classes
export class PotliftApiError extends Error {
  public statusCode?: number;
  public response?: any;

  constructor(message: string, statusCode?: number, response?: any) {
    super(message);
    this.name = 'PotliftApiError';
    this.statusCode = statusCode;
    this.response = response;
  }
}

export class AuthenticationError extends PotliftApiError {
  constructor(message: string = 'Unauthorized', response?: any) {
    super(message, 401, response);
    this.name = 'AuthenticationError';
  }
}

export class NotFoundError extends PotliftApiError {
  constructor(message: string = 'Not found', response?: any) {
    super(message, 404, response);
    this.name = 'NotFoundError';
  }
}

export class ValidationError extends PotliftApiError {
  public fieldErrors: Record<string, string[]>;

  constructor(message: string = 'Validation failed', details?: Record<string, string[]>, response?: any) {
    super(message, 422, response);
    this.name = 'ValidationError';
    this.fieldErrors = details || {};
  }
}

export class TimeoutError extends PotliftApiError {
  constructor(message: string = 'Request timeout') {
    super(message);
    this.name = 'TimeoutError';
  }
}

export class ConnectionError extends PotliftApiError {
  constructor(message: string = 'Connection failed') {
    super(message);
    this.name = 'ConnectionError';
  }
}

/**
 * HTTP client for making API requests
 */
class HttpClient {
  private baseUrl: string;
  private apiToken: string;
  private timeout: number;

  constructor(config: ClientConfig) {
    this.baseUrl = (config.baseUrl || 'http://localhost:3246').replace(/\/$/, '');
    this.apiToken = config.apiToken;
    this.timeout = config.timeout || 30000;
  }

  private async request<T>(
    method: string,
    path: string,
    options: {
      params?: Record<string, any>;
      body?: any;
    } = {}
  ): Promise<T> {
    const url = new URL(`${this.baseUrl}/api/v1${path}`);

    // Add query parameters
    if (options.params) {
      Object.entries(options.params).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          url.searchParams.append(key, String(value));
        }
      });
    }

    const headers: Record<string, string> = {
      'Authorization': `Bearer ${this.apiToken}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(url.toString(), {
        method,
        headers,
        body: options.body ? JSON.stringify(options.body) : undefined,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      const data = await response.json();

      if (!response.ok) {
        return this.handleError(response.status, data);
      }

      return data as T;
    } catch (error: any) {
      clearTimeout(timeoutId);

      if (error.name === 'AbortError') {
        throw new TimeoutError('Request timeout');
      }

      if (error instanceof PotliftApiError) {
        throw error;
      }

      throw new ConnectionError(`Connection failed: ${error.message}`);
    }
  }

  private handleError(status: number, data: any): never {
    const errorMessage = data?.error || `HTTP ${status}`;

    switch (status) {
      case 401:
        throw new AuthenticationError(errorMessage, data);
      case 404:
        throw new NotFoundError(errorMessage, data);
      case 422:
        throw new ValidationError(errorMessage, data?.details, data);
      default:
        throw new PotliftApiError(errorMessage, status, data);
    }
  }

  public async get<T>(path: string, params?: Record<string, any>): Promise<T> {
    return this.request<T>('GET', path, { params });
  }

  public async post<T>(path: string, body?: any): Promise<T> {
    return this.request<T>('POST', path, { body });
  }

  public async patch<T>(path: string, body?: any): Promise<T> {
    return this.request<T>('PATCH', path, { body });
  }

  public async put<T>(path: string, body?: any): Promise<T> {
    return this.request<T>('PUT', path, { body });
  }

  public async delete<T>(path: string): Promise<T> {
    return this.request<T>('DELETE', path);
  }
}

/**
 * Products API resource
 */
export class ProductsResource {
  constructor(private client: HttpClient) {}

  /**
   * List all products
   *
   * @param options - Pagination options
   * @returns Array of products
   *
   * @example
   * ```typescript
   * const products = await client.products.list({ page: 1, per_page: 50 });
   * products.forEach(p => console.log(p.sku, p.name));
   * ```
   */
  async list(options: ListOptions = {}): Promise<Product[]> {
    return this.client.get<Product[]>('/products', options);
  }

  /**
   * Get product by SKU
   *
   * @param sku - Product SKU (case-insensitive)
   * @returns Product details
   * @throws {NotFoundError} If product not found
   *
   * @example
   * ```typescript
   * const product = await client.products.get('PROD001');
   * console.log('Name:', product.name);
   * console.log('Inventory:', product.total_saldo);
   * ```
   */
  async get(sku: string): Promise<ProductDetail> {
    return this.client.get<ProductDetail>(`/products/${sku}`);
  }

  /**
   * Update product
   *
   * @param sku - Product SKU
   * @param data - Product data to update
   * @returns Updated product
   * @throws {NotFoundError} If product not found
   * @throws {ValidationError} If validation fails
   *
   * @example
   * ```typescript
   * await client.products.update('PROD001', {
   *   name: 'New Name',
   *   product_status: 'active'
   * });
   * ```
   */
  async update(sku: string, data: ProductUpdateData): Promise<Product> {
    return this.client.patch<Product>(`/products/${sku}`, { product: data });
  }
}

/**
 * Inventories API resource
 */
export class InventoriesResource {
  constructor(private client: HttpClient) {}

  /**
   * Update product inventory
   *
   * @param sku - Product SKU
   * @param updates - Array of inventory updates
   * @returns Update response with new inventory levels
   * @throws {NotFoundError} If product or storage not found
   * @throws {ValidationError} If validation fails
   *
   * @example
   * ```typescript
   * const result = await client.inventories.update('PROD001', [
   *   { storage_code: 'MAIN', value: 150 },
   *   { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
   * ]);
   * console.log('Total inventory:', result.total_saldo);
   * ```
   */
  async update(sku: string, updates: InventoryUpdate[]): Promise<InventoryUpdateResponse> {
    return this.client.post<InventoryUpdateResponse>('/inventories/update', {
      sku,
      inventory: { updates }
    });
  }
}

/**
 * Sync Tasks API resource
 */
export class SyncTasksResource {
  constructor(private client: HttpClient) {}

  /**
   * Create sync task
   *
   * @param task - Sync task data
   * @returns Sync task response
   * @throws {ValidationError} If validation fails
   *
   * @example
   * ```typescript
   * const result = await client.syncTasks.create({
   *   origin_event_id: 'shopify3_evt_12345',
   *   direction: 'inbound',
   *   event_type: 'product.updated',
   *   key: 'PROD001',
   *   load: { sku: 'PROD001', name: 'Updated Name' }
   * });
   * console.log('Task ID:', result.task_id);
   * ```
   */
  async create(task: SyncTask): Promise<SyncTaskResponse> {
    return this.client.post<SyncTaskResponse>('/sync_tasks', task);
  }
}

/**
 * Main Potlift8 API Client
 */
export class PotliftClient {
  private httpClient: HttpClient;

  /** Products API resource */
  public readonly products: ProductsResource;

  /** Inventories API resource */
  public readonly inventories: InventoriesResource;

  /** Sync Tasks API resource */
  public readonly syncTasks: SyncTasksResource;

  /**
   * Create a new Potlift8 API client
   *
   * @param config - Client configuration
   * @throws {Error} If apiToken is not provided
   *
   * @example
   * ```typescript
   * const client = new PotliftClient({
   *   apiToken: process.env.POTLIFT_API_TOKEN,
   *   baseUrl: 'http://localhost:3246',
   *   timeout: 30000
   * });
   * ```
   */
  constructor(config: ClientConfig) {
    if (!config.apiToken) {
      throw new Error('apiToken is required');
    }

    this.httpClient = new HttpClient(config);
    this.products = new ProductsResource(this.httpClient);
    this.inventories = new InventoriesResource(this.httpClient);
    this.syncTasks = new SyncTasksResource(this.httpClient);
  }
}

// Default export
export default PotliftClient;
