/**
 * API Client for RevCopy Admin Panel
 * 
 * Provides secure API communication with the backend including:
 * - Authentication management
 * - Error handling
 * - Request/response interceptors
 * - Token refresh logic
 */

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  errors?: string[];
}

/**
 * Get the appropriate API base URL based on the current location
 */
const getApiBaseUrl = (): string => {
  const hostname = window.location.hostname;
  const port = window.location.port;
  
  // If we're running on localhost or development
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return 'http://localhost:8000/api/v1/admin';
  }
  
  // If we're running on port 3001 (standalone admin), point to main server's API
  if (port === '3001') {
    return `http://${hostname}/api/v1/admin`;
  }
  
  // For production, use the nginx proxy to backend via /api/
  return `http://${hostname}/api/v1/admin`;
};

/**
 * Configuration for the API client
 */
const API_CONFIG = {
  BASE_URL: getApiBaseUrl(),
  TIMEOUT: 30000,
  RETRY_ATTEMPTS: 3,
  RETRY_DELAY: 1000,
};

/**
 * Authentication token management
 */
class TokenManager {
  private static ACCESS_TOKEN_KEY = 'admin_access_token';
  private static REFRESH_TOKEN_KEY = 'admin_refresh_token';
  private static TOKEN_EXPIRY_KEY = 'admin_token_expiry';

  /**
   * Store authentication tokens securely
   */
  static setTokens(authResponse: AuthResponse): void {
    const expiryTime = Date.now() + (authResponse.expires_in * 1000);
    
    localStorage.setItem(this.ACCESS_TOKEN_KEY, authResponse.access_token);
    localStorage.setItem(this.REFRESH_TOKEN_KEY, authResponse.refresh_token);
    localStorage.setItem(this.TOKEN_EXPIRY_KEY, expiryTime.toString());
  }

  /**
   * Get the current access token
   */
  static getAccessToken(): string | null {
    return localStorage.getItem(this.ACCESS_TOKEN_KEY);
  }

  /**
   * Get the refresh token
   */
  static getRefreshToken(): string | null {
    return localStorage.getItem(this.REFRESH_TOKEN_KEY);
  }

  /**
   * Check if the access token is expired
   */
  static isTokenExpired(): boolean {
    const expiryTime = localStorage.getItem(this.TOKEN_EXPIRY_KEY);
    if (!expiryTime) return true;
    
    return Date.now() >= parseInt(expiryTime);
  }

  /**
   * Clear all stored tokens
   */
  static clearTokens(): void {
    localStorage.removeItem(this.ACCESS_TOKEN_KEY);
    localStorage.removeItem(this.REFRESH_TOKEN_KEY);
    localStorage.removeItem(this.TOKEN_EXPIRY_KEY);
  }

  /**
   * Check if user is authenticated
   */
  static isAuthenticated(): boolean {
    const token = this.getAccessToken();
    return token !== null && !this.isTokenExpired();
  }
}

/**
 * Main API client class
 */
class ApiClient {
  private baseURL: string;
  private timeout: number;

  constructor() {
    this.baseURL = API_CONFIG.BASE_URL;
    this.timeout = API_CONFIG.TIMEOUT;
  }

  /**
   * Make an authenticated API request
   */
  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    
    // Prepare headers
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    // Add authentication token if available
    const token = TokenManager.getAccessToken();
    console.log('🔍 API Request DEBUG:', {
      endpoint,
      hasToken: !!token,
      tokenLength: token?.length || 0,
      isTokenExpired: TokenManager.isTokenExpired(),
      tokenPreview: token?.substring(0, 50) + '...'
    });
    
    if (token && !TokenManager.isTokenExpired()) {
      headers['Authorization'] = `Bearer ${token}`;
      console.log('✅ Authorization header added');
    } else {
      console.log('❌ No valid token available');
    }

    try {
      const response = await fetch(url, {
        ...options,
        headers,
        signal: AbortSignal.timeout(this.timeout),
      });

      console.log('🔍 Response status:', response.status, response.statusText);

      // Handle authentication errors
      if (response.status === 401) {
        console.log('❌ 401 Unauthorized - attempting token refresh');
        await this.handleAuthError();
        throw new Error('Authentication required');
      }

      if (response.status === 403) {
        console.log('❌ 403 Forbidden - access denied');
        throw new Error('Access denied');
      }

      // Parse response
      const data = await response.json();

      if (!response.ok) {
        console.error('❌ Request failed:', { status: response.status, data });
        throw new Error(data.detail || `HTTP ${response.status}: ${response.statusText}`);
      }

      console.log('✅ Request successful');
      return {
        success: true,
        data,
      };
    } catch (error) {
      console.error(`API Request failed: ${endpoint}`, error);
      
      return {
        success: false,
        message: error instanceof Error ? error.message : 'Unknown error occurred',
      };
    }
  }

  /**
   * Handle authentication errors by attempting token refresh
   */
  private async handleAuthError(): Promise<void> {
    const refreshToken = TokenManager.getRefreshToken();
    
    if (!refreshToken) {
      TokenManager.clearTokens();
      // Redirect to login
      window.location.href = '/login';
      return;
    }

    try {
      const response = await fetch(`${this.baseURL}/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });

      if (response.ok) {
        const authResponse: AuthResponse = await response.json();
        TokenManager.setTokens(authResponse);
      } else {
        TokenManager.clearTokens();
        window.location.href = '/login';
      }
    } catch (error) {
      console.error('Token refresh failed:', error);
      TokenManager.clearTokens();
      window.location.href = '/login';
    }
  }

  /**
   * Authentication methods
   */
  async login(credentials: LoginCredentials): Promise<ApiResponse<AuthResponse>> {
    return this.request<AuthResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });
  }

  async logout(): Promise<void> {
    try {
      await this.request('/auth/logout', {
        method: 'POST',
      });
    } finally {
      TokenManager.clearTokens();
    }
  }

  /**
   * Get current user profile
   */
  async getUserProfile(): Promise<ApiResponse<any>> {
    return this.request('/auth/me');
  }

  /**
   * Prompt Template Management
   */
  async getPromptTemplates(): Promise<ApiResponse<any[]>> {
    return this.request('/prompt-templates');
  }

  async createPromptTemplate(template: any): Promise<ApiResponse<any>> {
    return this.request('/prompt-templates', {
      method: 'POST',
      body: JSON.stringify(template),
    });
  }

  async updatePromptTemplate(id: number, template: any): Promise<ApiResponse<any>> {
    return this.request(`/prompt-templates/${id}`, {
      method: 'PUT',
      body: JSON.stringify(template),
    });
  }

  async deletePromptTemplate(id: number): Promise<ApiResponse<void>> {
    return this.request(`/prompt-templates/${id}`, {
      method: 'DELETE',
    });
  }

  /**
   * Content Generation Settings
   */
  async getContentSettings(): Promise<ApiResponse<any>> {
    return this.request('/content-settings');
  }

  async updateContentSettings(settings: any): Promise<ApiResponse<any>> {
    return this.request('/content-settings', {
      method: 'PUT',
      body: JSON.stringify(settings),
    });
  }

  /**
   * User Management
   */
  async getUsers(page: number = 1, limit: number = 20): Promise<ApiResponse<any>> {
    return this.request(`/users?page=${page}&limit=${limit}`);
  }

  async getUserDetails(userId: number): Promise<ApiResponse<any>> {
    return this.request(`/users/${userId}`);
  }

  async updateUserStatus(userId: number, status: string): Promise<ApiResponse<any>> {
    return this.request(`/users/${userId}/status`, {
      method: 'PUT',
      body: JSON.stringify({ status }),
    });
  }

  /**
   * Admin Management
   */
  async getAdmins(): Promise<ApiResponse<any[]>> {
    return this.request('/administrators');
  }

  async createAdmin(adminData: {
    name: string;
    email: string;
    role: string;
    password: string;
  }): Promise<ApiResponse<any>> {
    return this.request('/administrators', {
      method: 'POST',
      body: JSON.stringify(adminData),
    });
  }

  async updateAdmin(adminId: number, adminData: any): Promise<ApiResponse<any>> {
    return this.request(`/administrators/${adminId}`, {
      method: 'PUT',
      body: JSON.stringify(adminData),
    });
  }

  async deleteAdmin(adminId: number): Promise<ApiResponse<void>> {
    return this.request(`/administrators/${adminId}`, {
      method: 'DELETE',
    });
  }

  /**
   * Payment Management
   */
  async getPayments(period: string = 'all'): Promise<ApiResponse<any>> {
    return this.request(`/payments?period=${period}`);
  }

  async getPaymentStats(period: string = 'all'): Promise<ApiResponse<any>> {
    return this.request(`/payments/stats?period=${period}`);
  }

  async getPaymentDetails(paymentId: string): Promise<ApiResponse<any>> {
    return this.request(`/payments/${paymentId}`);
  }

  /**
   * Amazon Account Management
   */
  async getAmazonAccounts(): Promise<ApiResponse<any[]>> {
    return this.request('/amazon-accounts');
  }

  async createAmazonAccount(accountData: {
    username: string;
    password: string;
    avatar_url?: string;
  }): Promise<ApiResponse<any>> {
    return this.request('/amazon-accounts', {
      method: 'POST',
      body: JSON.stringify(accountData),
    });
  }

  async updateAmazonAccount(accountId: number, accountData: any): Promise<ApiResponse<any>> {
    return this.request(`/amazon-accounts/${accountId}`, {
      method: 'PUT',
      body: JSON.stringify(accountData),
    });
  }

  async deleteAmazonAccount(accountId: number): Promise<ApiResponse<void>> {
    return this.request(`/amazon-accounts/${accountId}`, {
      method: 'DELETE',
    });
  }

  /**
   * Proxy Server Management
   */
  async getProxyServers(): Promise<ApiResponse<any[]>> {
    return this.request('/proxy-servers');
  }

  async createProxyServer(proxyData: {
    name: string;
    address: string;
    location: string;
  }): Promise<ApiResponse<any>> {
    return this.request('/proxy-servers', {
      method: 'POST',
      body: JSON.stringify(proxyData),
    });
  }

  async updateProxyServer(proxyId: number, proxyData: any): Promise<ApiResponse<any>> {
    return this.request(`/proxy-servers/${proxyId}`, {
      method: 'PUT',
      body: JSON.stringify(proxyData),
    });
  }

  async deleteProxyServer(proxyId: number): Promise<ApiResponse<void>> {
    return this.request(`/proxy-servers/${proxyId}`, {
      method: 'DELETE',
    });
  }

  /**
   * Crawler Management
   */
  async getCrawlers(): Promise<ApiResponse<any[]>> {
    return this.request('/crawlers');
  }

  async createCrawler(crawlerData: {
    name: string;
    crawler_type: string;
    target_url: string;
    css_selector?: string;
    user_agent?: string;
    interval_minutes: number;
  }): Promise<ApiResponse<any>> {
    return this.request('/crawlers', {
      method: 'POST',
      body: JSON.stringify(crawlerData),
    });
  }

  async updateCrawler(crawlerId: number, crawlerData: {
    name?: string;
    crawler_type?: string;
    target_url?: string;
    css_selector?: string;
    user_agent?: string;
    interval_minutes?: number;
    status?: string;
  }): Promise<ApiResponse<any>> {
    return this.request(`/crawlers/${crawlerId}`, {
      method: 'PUT',
      body: JSON.stringify(crawlerData),
    });
  }

  async updateCrawlerStatus(crawlerId: number, status: string): Promise<ApiResponse<any>> {
    return this.request(`/crawlers/${crawlerId}/status`, {
      method: 'PUT',
      body: JSON.stringify({ status }),
    });
  }

  async deleteCrawler(crawlerId: number): Promise<ApiResponse<void>> {
    return this.request(`/crawlers/${crawlerId}`, {
      method: 'DELETE',
    });
  }

  /**
   * Analytics and Dashboard
   */
  async getDashboardStats(): Promise<ApiResponse<any>> {
    return this.request('/dashboard/stats');
  }

  async getUsageAnalytics(period: string = '7d'): Promise<ApiResponse<any>> {
    return this.request(`/analytics/usage?period=${period}`);
  }

  /**
   * System Settings
   */
  async getSystemSettings(): Promise<ApiResponse<any>> {
    return this.request('/settings');
  }

  async updateSystemSettings(settings: any): Promise<ApiResponse<any>> {
    return this.request('/settings', {
      method: 'PUT',
      body: JSON.stringify(settings),
    });
  }
}

// Export singleton instance
export const apiClient = new ApiClient();
export { TokenManager };

// Export utility functions
export const isAuthenticated = (): boolean => TokenManager.isAuthenticated();
export const clearAuth = (): void => TokenManager.clearTokens(); 