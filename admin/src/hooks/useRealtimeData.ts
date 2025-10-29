import { useState, useEffect, useCallback, useRef } from 'react';
import { DashboardStats, SystemHealth, User, Server } from '../types';
import apiService from '../services/api';
import websocketService from '../services/websocket';

interface RealtimeData<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  lastUpdate: Date | null;
  isConnected: boolean;
}

interface UseRealtimeDataOptions {
  pollingInterval?: number; // in millisecondi
  enableWebSocket?: boolean;
  enablePolling?: boolean;
  autoFetch?: boolean;
}

// Hook per dati dashboard real-time
export function useRealtimeDashboard(options: UseRealtimeDataOptions = {}) {
  const {
    pollingInterval = 10000, // 10 secondi
    enableWebSocket = false, // Disabilitato temporaneamente
    enablePolling = true,
    autoFetch = true,
  } = options;

  const [state, setState] = useState<RealtimeData<DashboardStats>>({
    data: null,
    loading: true,
    error: null,
    lastUpdate: null,
    isConnected: false,
  });

  const pollingRef = useRef<NodeJS.Timeout | null>(null);
  const wsUnsubscribeRef = useRef<(() => void) | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, loading: true, error: null }));
      const data = await apiService.getDashboardStats();
      setState(prev => ({
        ...prev,
        data,
        loading: false,
        lastUpdate: new Date(),
      }));
    } catch (error: any) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Errore nel caricamento dei dati',
      }));
    }
  }, []);

  // WebSocket listener
  useEffect(() => {
    if (!enableWebSocket) return;

    const unsubscribe = websocketService.on('dashboard_stats', (data: DashboardStats) => {
      setState(prev => ({
        ...prev,
        data,
        loading: false,
        error: null,
        lastUpdate: new Date(),
      }));
    });

    const connectionUnsubscribe = websocketService.on('connection_status', (status: any) => {
      setState(prev => ({
        ...prev,
        isConnected: status.status === 'connected',
      }));
    });

    wsUnsubscribeRef.current = () => {
      unsubscribe();
      connectionUnsubscribe();
    };

    return () => {
      if (wsUnsubscribeRef.current) {
        wsUnsubscribeRef.current();
      }
    };
  }, [enableWebSocket]);

  // Polling
  useEffect(() => {
    if (!enablePolling) return;

    if (autoFetch) {
      fetchData();
    }

    pollingRef.current = setInterval(fetchData, pollingInterval);

    return () => {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
      }
    };
  }, [fetchData, pollingInterval, enablePolling, autoFetch]);

  // Richiesta manuale dati
  const refresh = useCallback(() => {
    fetchData();
    if (enableWebSocket) {
      websocketService.requestDashboardStats();
    }
  }, [fetchData, enableWebSocket]);

  return {
    ...state,
    refresh,
  };
}

// Hook per system health real-time
export function useRealtimeSystemHealth(options: UseRealtimeDataOptions = {}) {
  const {
    pollingInterval = 5000, // 5 secondi per system health
    enableWebSocket = false, // Disabilitato temporaneamente
    enablePolling = true,
    autoFetch = true,
  } = options;

  const [state, setState] = useState<RealtimeData<SystemHealth>>({
    data: null,
    loading: true,
    error: null,
    lastUpdate: null,
    isConnected: false,
  });

  const pollingRef = useRef<NodeJS.Timeout | null>(null);
  const wsUnsubscribeRef = useRef<(() => void) | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, loading: true, error: null }));
      const data = await apiService.getSystemHealth();
      setState(prev => ({
        ...prev,
        data,
        loading: false,
        lastUpdate: new Date(),
      }));
    } catch (error: any) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Errore nel caricamento dei dati',
      }));
    }
  }, []);

  // WebSocket listener
  useEffect(() => {
    if (!enableWebSocket) return;

    const unsubscribe = websocketService.on('system_health', (data: SystemHealth) => {
      setState(prev => ({
        ...prev,
        data,
        loading: false,
        error: null,
        lastUpdate: new Date(),
      }));
    });

    const connectionUnsubscribe = websocketService.on('connection_status', (status: any) => {
      setState(prev => ({
        ...prev,
        isConnected: status.status === 'connected',
      }));
    });

    wsUnsubscribeRef.current = () => {
      unsubscribe();
      connectionUnsubscribe();
    };

    return () => {
      if (wsUnsubscribeRef.current) {
        wsUnsubscribeRef.current();
      }
    };
  }, [enableWebSocket]);

  // Polling
  useEffect(() => {
    if (!enablePolling) return;

    if (autoFetch) {
      fetchData();
    }

    pollingRef.current = setInterval(fetchData, pollingInterval);

    return () => {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
      }
    };
  }, [fetchData, pollingInterval, enablePolling, autoFetch]);

  const refresh = useCallback(() => {
    fetchData();
    if (enableWebSocket) {
      websocketService.requestSystemHealth();
    }
  }, [fetchData, enableWebSocket]);

  return {
    ...state,
    refresh,
  };
}

// Hook per server status real-time
export function useRealtimeServers(options: UseRealtimeDataOptions = {}) {
  const {
    pollingInterval = 15000, // 15 secondi per server
    enableWebSocket = true,
    enablePolling = true,
    autoFetch = true,
  } = options;

  const [state, setState] = useState<RealtimeData<Server[]>>({
    data: null,
    loading: true,
    error: null,
    lastUpdate: null,
    isConnected: false,
  });

  const pollingRef = useRef<NodeJS.Timeout | null>(null);
  const wsUnsubscribeRef = useRef<(() => void) | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setState(prev => ({ ...prev, loading: true, error: null }));
      const data = await apiService.getServersStatus();
      setState(prev => ({
        ...prev,
        data,
        loading: false,
        lastUpdate: new Date(),
      }));
    } catch (error: any) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Errore nel caricamento dei server',
      }));
    }
  }, []);

  // WebSocket listener
  useEffect(() => {
    if (!enableWebSocket) return;

    const unsubscribe = websocketService.on('server_status', (data: { servers: Server[]; timestamp: string }) => {
      setState(prev => ({
        ...prev,
        data: data.servers,
        loading: false,
        error: null,
        lastUpdate: new Date(data.timestamp),
      }));
    });

    const connectionUnsubscribe = websocketService.on('connection_status', (status: any) => {
      setState(prev => ({
        ...prev,
        isConnected: status.status === 'connected',
      }));
    });

    wsUnsubscribeRef.current = () => {
      unsubscribe();
      connectionUnsubscribe();
    };

    return () => {
      if (wsUnsubscribeRef.current) {
        wsUnsubscribeRef.current();
      }
    };
  }, [enableWebSocket]);

  // Polling
  useEffect(() => {
    if (!enablePolling) return;

    if (autoFetch) {
      fetchData();
    }

    pollingRef.current = setInterval(fetchData, pollingInterval);

    return () => {
      if (pollingRef.current) {
        clearInterval(pollingRef.current);
      }
    };
  }, [fetchData, pollingInterval, enablePolling, autoFetch]);

  const refresh = useCallback(() => {
    fetchData();
    if (enableWebSocket) {
      websocketService.requestServerStatus();
    }
  }, [fetchData, enableWebSocket]);

  return {
    ...state,
    refresh,
  };
}

// Hook per notifiche real-time
export function useRealtimeNotifications() {
  const [notifications, setNotifications] = useState<Array<{
    id: string;
    type: 'success' | 'error' | 'warning' | 'info';
    title: string;
    message: string;
    timestamp: Date;
    read: boolean;
  }>>([]);

  // Disabilitato temporaneamente WebSocket
  useEffect(() => {
    // WebSocket disabilitato per ora
    return () => {};
  }, []);

  useEffect(() => {
    // WebSocket disabilitato temporaneamente
    return () => {};
  }, []);

  const markAsRead = (id: string) => {
    setNotifications(prev =>
      prev.map(notif => notif.id === id ? { ...notif, read: true } : notif)
    );
  };

  const markAllAsRead = () => {
    setNotifications(prev => prev.map(notif => ({ ...notif, read: true })));
  };

  const clearNotifications = () => {
    setNotifications([]);
  };

  return {
    notifications,
    unreadCount: notifications.filter(n => !n.read).length,
    markAsRead,
    markAllAsRead,
    clearNotifications,
  };
}

// Hook per connessione WebSocket
export function useWebSocketConnection() {
  const [connectionStatus, setConnectionStatus] = useState<{
    status: 'connected' | 'disconnected' | 'error' | 'failed';
    message?: string;
    timestamp?: Date;
  }>({
    status: 'disconnected', // WebSocket disabilitato
  });

  useEffect(() => {
    // WebSocket disabilitato temporaneamente - hook funziona ma non si connette
    return () => {};
  }, []);

  const reconnect = () => {
    // WebSocket disabilitato temporaneamente
    console.log('WebSocket reconnect disabilitato');
  };

  return {
    ...connectionStatus,
    isConnected: connectionStatus.status === 'connected',
    reconnect,
  };
}
