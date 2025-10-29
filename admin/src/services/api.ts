import axios, { AxiosInstance, AxiosResponse } from 'axios';
import { 
  User, 
  Group, 
  Server, 
  DashboardStats, 
  SystemHealth, 
  AppSettings,
  LoginCredentials,
  AuthState,
  UserFilters,
  ServerFilters,
  BulkAction,
  ApiResponse,
  PaginatedResponse
} from '../types';

class ApiService {
  private api: AxiosInstance;
  private isRedirecting = false; // Previene loop di redirect

  constructor() {
    // Determina l'URL base dell'API
    const apiBaseUrl = this.getApiBaseUrl();
    
    // Recupera il token salvato se esiste
    const savedToken = localStorage.getItem('auth_token');
    
    this.api = axios.create({
      baseURL: apiBaseUrl,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
        ...(savedToken && { 'Authorization': `Token ${savedToken}` }),
      },
    });

    // Interceptor per gestire gli errori
    this.api.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401 && !this.isRedirecting) {
          // Previeni loop: esegui logout SOLO UNA VOLTA
          this.isRedirecting = true;
          
          // Pulisci TUTTO il localStorage (token vecchi potrebbero causare problemi)
          localStorage.clear();
          sessionStorage.clear();
          
          console.warn('🚨 Token non valido o scaduto - Redirect al login');
          
          // Redirect al login
          setTimeout(() => {
            window.location.href = '/';
          }, 100);
        }
        return Promise.reject(error);
      }
    );
  }

  private getApiBaseUrl(): string {
    // Priorità di configurazione:
    // 1. Variabile d'ambiente REACT_APP_API_URL
    // 2. Configurazione da localStorage (per DigitalOcean)
    // 3. Default locale
    
    const envApiUrl = process.env.REACT_APP_API_URL;
    if (envApiUrl) {
      return envApiUrl;
    }
    
    // Controlla se è configurato per DigitalOcean
    const digitalOceanConfig = localStorage.getItem('securevox_digitalocean_config');
    if (digitalOceanConfig) {
      try {
        const config = JSON.parse(digitalOceanConfig);
        if (config.apiUrl) {
          return config.apiUrl;
        }
      } catch (error) {
        console.error('Errore nel parsing della configurazione DigitalOcean:', error);
      }
    }
    
    // Default locale
    return 'http://127.0.0.1:8001/api';
  }

  // Metodi per configurazione DigitalOcean
  public setDigitalOceanConfig(apiUrl: string, apiToken?: string) {
    const config = {
      apiUrl,
      apiToken,
      configuredAt: new Date().toISOString(),
    };
    localStorage.setItem('securevox_digitalocean_config', JSON.stringify(config));
    
    // Ricrea l'istanza API con la nuova configurazione
    this.api = axios.create({
      baseURL: apiUrl,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
        ...(apiToken && { 'Authorization': `Bearer ${apiToken}` }),
      },
    });
  }

  public clearDigitalOceanConfig() {
    localStorage.removeItem('securevox_digitalocean_config');
    
    // Ricrea l'istanza API con configurazione locale
    this.api = axios.create({
      baseURL: 'http://127.0.0.1:8001/api',
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  public getDigitalOceanConfig() {
    const config = localStorage.getItem('securevox_digitalocean_config');
    return config ? JSON.parse(config) : null;
  }

  // Autenticazione
  async login(credentials: LoginCredentials): Promise<AuthState> {
    try {
      // Il backend si aspetta 'email' invece di 'username'
      const loginData = {
        email: credentials.username, // Il form usa 'username' ma il backend vuole 'email'
        password: credentials.password,
      };
      
      const response = await this.api.post('/auth/login/', loginData);
      
      // Salva il token per le richieste future
      if (response.data.token) {
        localStorage.setItem('auth_token', response.data.token);
        // Aggiorna l'header Authorization per le richieste future
        this.api.defaults.headers.common['Authorization'] = `Token ${response.data.token}`;
      }
      
      return {
        isAuthenticated: true,
        user: response.data.user,
        loading: false,
        error: null,
      };
    } catch (error: any) {
      return {
        isAuthenticated: false,
        user: null,
        loading: false,
        error: error.response?.data?.message || error.response?.data?.error || 'Errore durante il login',
      };
    }
  }

  async logout(): Promise<void> {
    try {
      await this.api.post('/auth/logout/');
    } finally {
      // Rimuovi il token anche se la richiesta fallisce
      localStorage.removeItem('auth_token');
      delete this.api.defaults.headers.common['Authorization'];
    }
  }

  async getCurrentUser(): Promise<User | null> {
    try {
      const response = await this.api.get('/current-user/');
      return response.data;
    } catch (error) {
      return null;
    }
  }

  // Dashboard
  async getDashboardStats(): Promise<DashboardStats> {
    const response = await this.api.get('/dashboard-stats/');
    return response.data;
  }

  async getSystemHealth(): Promise<SystemHealth> {
    const response = await this.api.get('/system-health/');
    return response.data;
  }

  async getRealTimeData(): Promise<any> {
    const response = await this.api.get('/real-time-data/');
    return response.data;
  }

  // Gestione Utenti
  async getUsers(filters: UserFilters): Promise<PaginatedResponse<User>> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== '') {
        params.append(key, value.toString());
      }
    });

    const response = await this.api.get(`/users-management/?${params}`);
    return response.data;
  }

  async getUser(userId: number): Promise<User> {
    const response = await this.api.get(`/users/${userId}/details/`);
    return response.data;
  }

  async createUser(userData: Partial<User>): Promise<User> {
    const response = await this.api.post('/users/create/', userData);
    return response.data;
  }

  async updateUser(userId: number, userData: Partial<User>): Promise<User> {
    const response = await this.api.put(`/users/${userId}/update/`, userData);
    return response.data;
  }

  async bulkUserAction(action: BulkAction): Promise<void> {
    await this.api.post('/users/bulk-actions/', action);
  }

  // Gestione Gruppi
  async getGroups(): Promise<Group[]> {
    const response = await this.api.get('/groups-management/');
    return response.data.groups;
  }

  async getGroup(groupId: string): Promise<Group> {
    const response = await this.api.get(`/groups/${groupId}/`);
    return response.data;
  }

  async createGroup(groupData: Partial<Group>): Promise<Group> {
    const response = await this.api.post('/groups/create/', groupData);
    return response.data;
  }

  async updateGroup(groupId: string, groupData: Partial<Group>): Promise<Group> {
    const response = await this.api.put(`/groups/${groupId}/update/`, groupData);
    return response.data;
  }

  async deleteGroup(groupId: string): Promise<void> {
    await this.api.delete(`/groups/${groupId}/delete/`);
  }

  async getGroupMembers(groupId: string): Promise<User[]> {
    const response = await this.api.get(`/groups/${groupId}/members/`);
    return response.data.members;
  }

  async manageGroupMembers(groupId: string, action: BulkAction): Promise<void> {
    await this.api.post(`/groups/${groupId}/manage-members/`, action);
  }

  // Gestione Server
  async getServers(filters: ServerFilters): Promise<PaginatedResponse<Server>> {
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== '') {
        params.append(key, value.toString());
      }
    });

    const response = await this.api.get(`/servers/?${params}`);
    return response.data;
  }

  async getServer(serverId: string): Promise<Server> {
    const response = await this.api.get(`/servers/${serverId}/`);
    return response.data;
  }

  async getServersStatus(): Promise<Server[]> {
    const response = await this.api.get('/servers/status/');
    return response.data;
  }

  async controlServer(serverId: string, action: string): Promise<void> {
    await this.api.post(`/servers/${serverId}/control/`, { action });
  }

  async getServerLogs(serverId: string): Promise<string[]> {
    const response = await this.api.get(`/servers/${serverId}/logs/`);
    return response.data.logs;
  }

  async getServerPerformance(serverId: string): Promise<any> {
    const response = await this.api.get(`/servers/${serverId}/performance/`);
    return response.data;
  }

  // Terminale
  async getTerminalSession(serverId: string): Promise<any> {
    const response = await this.api.post('/terminal/session/', { server_id: serverId });
    return response.data;
  }

  async sendTerminalInput(sessionId: string, input: string): Promise<void> {
    await this.api.post('/terminal/input/', { session_id: sessionId, input });
  }

  async getTerminalOutput(sessionId: string): Promise<string> {
    const response = await this.api.get(`/terminal/output/?session_id=${sessionId}`);
    return response.data.output;
  }

  async closeTerminalSession(sessionId: string): Promise<void> {
    await this.api.post('/terminal/close/', { session_id: sessionId });
  }

  async executeQuickCommand(serverId: string, command: string): Promise<string> {
    const response = await this.api.post('/terminal/quick-command/', { 
      server_id: serverId, 
      command 
    });
    return response.data.output;
  }

  // Impostazioni
  async getSettings(): Promise<AppSettings> {
    const response = await this.api.get('/settings/');
    return response.data;
  }

  async updateSettings(settings: Partial<AppSettings>): Promise<AppSettings> {
    const response = await this.api.put('/settings/', settings);
    return response.data;
  }

  async uploadLogo(file: File): Promise<string> {
    const formData = new FormData();
    formData.append('logo', file);
    
    const response = await this.api.post('/settings/upload-logo/', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data.logo_url;
  }

  // Sicurezza
  async getSecurityMonitoring(): Promise<any> {
    const response = await this.api.get('/security-monitoring/');
    return response.data;
  }

  // Dispositivi
  async getDevices(): Promise<any> {
    const response = await this.api.get('/devices-management/');
    return response.data;
  }

  async blockDevice(deviceId: string): Promise<void> {
    await this.api.post('/block-device/', { device_id: deviceId });
  }

  // Chat e Media
  async getChatsManagement(): Promise<any> {
    const response = await this.api.get('/chats-management/');
    return response.data;
  }

  async getMediaManagement(): Promise<any> {
    const response = await this.api.get('/media-management/');
    return response.data;
  }

  async getCallsManagement(): Promise<any> {
    const response = await this.api.get('/calls-management/');
    return response.data;
  }

  // Analytics
  async getAnalyticsData(): Promise<any> {
    const response = await this.api.get('/analytics-data/');
    return response.data;
  }

  async getMonitoringData(): Promise<any> {
    const response = await this.api.get('/monitoring-data/');
    return response.data;
  }

  // Chat Monitoring (Admin Dashboard)
  async getChatStatistics(): Promise<any> {
    const response = await this.api.get('/monitoring/chat/statistics/');
    return response.data;
  }

  async getUsersList(): Promise<any> {
    const response = await this.api.get('/monitoring/chat/users/');
    return response.data;
  }

  async getUserChats(userId: number): Promise<any> {
    const response = await this.api.get(`/monitoring/chat/users/${userId}/chats/`);
    return response.data;
  }

  async getChatMessages(chatId: string, limit: number = 100, offset: number = 0): Promise<any> {
    const response = await this.api.get(`/monitoring/chat/chats/${chatId}/messages/`, {
      params: { limit, offset },
    });
    return response.data;
  }

  async resetUserPassword(userId: number, newPassword?: string): Promise<any> {
    const response = await this.api.post(`/monitoring/chat/users/${userId}/reset-password/`, {
      new_password: newPassword,
    });
    return response.data;
  }

  async blockUser(userId: number): Promise<any> {
    const response = await this.api.post(`/monitoring/chat/users/${userId}/block/`);
    return response.data;
  }

  async unblockUser(userId: number): Promise<any> {
    const response = await this.api.post(`/monitoring/chat/users/${userId}/unblock/`);
    return response.data;
  }

  async deleteUser(userId: number): Promise<any> {
    const response = await this.api.delete(`/monitoring/chat/users/${userId}/delete/`);
    return response.data;
  }

  async toggleUserE2E(userId: number, forceDisabled: boolean): Promise<any> {
    const response = await this.api.post(`/monitoring/chat/users/${userId}/toggle-e2e/`, {
      force_disabled: forceDisabled,
    });
    return response.data;
  }

  // Metodi HTTP esposti
  async get(url: string, config?: any) {
    return this.api.get(url, config);
  }

  async post(url: string, data?: any, config?: any) {
    return this.api.post(url, data, config);
  }

  async put(url: string, data?: any, config?: any) {
    return this.api.put(url, data, config);
  }

  async delete(url: string, config?: any) {
    return this.api.delete(url, config);
  }
}

export { ApiService };
export default new ApiService();
