// Tipi per l'autenticazione
export interface User {
  id: number;
  username: string;
  email: string;
  full_name: string; // Backend restituisce full_name invece di first_name/last_name
  is_active: boolean;
  is_staff: boolean;
  is_superuser: boolean;
  date_joined: string;
  last_login?: string;
  avatar_url?: string;
  devices_count: number;
  groups: Group[];
  devices: Device[];
  statistics: UserStatistics;
  security_status: 'secure' | 'warning' | 'inactive';
}

export interface UserStatistics {
  messages_sent: number;
  messages_received: number;
  calls_made: number;
  data_usage_mb: number;
  last_activity?: string;
}

// Tipi per i gruppi
export interface Group {
  id: string;
  name: string;
  description: string;
  color: string;
  members_count: number;
  created_by_username: string;
  created_at: string;
  updated_at: string;
  permissions: string[];
}

export interface GroupMembership {
  user_id: number;
  group_id: string;
  assigned_at: string;
  is_active: boolean;
}

// Tipi per i dispositivi
export interface Device {
  id: string;
  device_name: string;
  device_type: 'android' | 'ios' | 'web' | 'desktop';
  last_seen?: string;
  is_active: boolean;
  is_rooted: boolean;
  is_jailbroken: boolean;
  is_compromised: boolean;
  user_id: number;
}

// Tipi per i server
export interface Server {
  id: string;
  name: string;
  hostname: string;
  ip_address: string;
  port: number;
  technology: string;
  function: string;
  status: 'active' | 'inactive' | 'maintenance' | 'error';
  cpu_usage: number;
  memory_usage: number;
  disk_usage: number;
  uptime: number;
  last_checked: string;
  alerts: ServerAlert[];
  size: string;
}

export interface ServerAlert {
  id: string;
  type: 'warning' | 'error' | 'info';
  message: string;
  timestamp: string;
  resolved: boolean;
}

// Tipi per le statistiche dashboard
export interface DashboardStats {
  users: {
    total: number;
    active_24h: number;
    online: number;
    blocked: number;
    growth_rate: number;
  };
  devices: {
    total: number;
    active: number;
    compromised: number;
    by_type: {
      android: number;
      ios: number;
      web: number;
      desktop: number;
    };
  };
  messages: {
    total: number;
    last_24h: number;
    last_7d: number;
    by_type: {
      text: number;
      image: number;
      video: number;
      audio: number;
      file: number;
    };
  };
  calls: {
    total: number;
    last_24h: number;
    average_duration: number;
  };
  chats: {
    total: number;
    active: number;
  };
  traffic: {
    total_mb: number;
    daily_average_mb: number;
    trend: 'increasing' | 'decreasing' | 'stable';
  };
  security: {
    failed_logins_24h: number;
    blocked_ips: number;
    suspicious_activity: number;
  };
}

// Tipi per il sistema
export interface SystemHealth {
  system: {
    cpu_usage: number;
    memory_usage: number;
    memory_total: number;
    memory_available: number;
    disk_usage: number;
    disk_total: number;
    disk_free: number;
    uptime: number;
  };
  services: {
    django: boolean;
    call_server: boolean;
    notification_server: boolean;
    database: boolean;
    redis: boolean;
  };
  health_score: number;
  status: 'healthy' | 'warning' | 'critical';
}

// Tipi per le impostazioni
export interface AppSettings {
  language: 'it' | 'en';
  company_logo?: string;
  company_name: string;
  company_data: {
    name: string;
    address: string;
    phone: string;
    email: string;
    website: string;
  };
  branding: {
    primary_color: string;
    secondary_color: string;
    logo_url?: string;
    favicon_url?: string;
  };
  notifications: {
    email_enabled: boolean;
    push_enabled: boolean;
    sms_enabled: boolean;
  };
}

// Tipi per l'autenticazione
export interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  loading: boolean;
  error: string | null;
}

export interface LoginCredentials {
  username: string;
  password: string;
}

// Tipi per le API
export interface ApiResponse<T> {
  data: T;
  success: boolean;
  message?: string;
  error?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  pagination: {
    page: number;
    per_page: number;
    total: number;
    pages: number;
  };
}

// Tipi per i filtri
export interface UserFilters {
  search: string;
  status: 'all' | 'active' | 'blocked' | 'online';
  group_id?: string;
  page: number;
  per_page: number;
}

export interface ServerFilters {
  search: string;
  status: 'all' | 'active' | 'inactive' | 'maintenance' | 'error';
  technology?: string;
  function?: string;
  page: number;
  per_page: number;
}

// Tipi per le azioni
export interface BulkAction {
  action: 'activate' | 'deactivate' | 'delete' | 'assign_group' | 'remove_group';
  items: number[];
  group_id?: string;
}

// Tipi per i grafici
export interface ChartData {
  name: string;
  value: number;
  color?: string;
}

export interface TimeSeriesData {
  date: string;
  value: number;
  label?: string;
}

// Tipi per le notifiche
export interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message: string;
  timestamp: string;
  read: boolean;
}

// Tipi per il terminale
export interface TerminalSession {
  id: string;
  server_id: string;
  connected: boolean;
  last_activity: string;
}

export interface TerminalCommand {
  command: string;
  output: string;
  timestamp: string;
  exit_code: number;
}
