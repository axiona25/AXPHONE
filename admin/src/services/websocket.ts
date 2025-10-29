import { DashboardStats, SystemHealth, User, Server } from '../types';

class WebSocketService {
  private socket: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectInterval = 5000;
  private listeners: Map<string, Function[]> = new Map();
  private isConnecting = false;

  constructor() {
    // Non connettere automaticamente per evitare errori
    // this.connect();
  }

  public connect() {
    if (this.isConnecting || (this.socket && this.socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    this.isConnecting = true;
    
    try {
      const wsUrl = process.env.REACT_APP_WS_URL || 'ws://localhost:8001/ws/admin/';
      console.log('🔌 Tentativo connessione WebSocket a:', wsUrl);
      
      this.socket = new WebSocket(wsUrl);

      this.socket.onopen = () => {
        console.log('🔌 WebSocket connesso');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.emit('connection_status', { status: 'connected', timestamp: new Date() });
      };

      this.socket.onclose = (event) => {
        console.log('🔌 WebSocket disconnesso:', event.code, event.reason);
        this.isConnecting = false;
        this.emit('connection_status', { 
          status: 'disconnected', 
          code: event.code, 
          reason: event.reason, 
          timestamp: new Date() 
        });
        
        if (event.code !== 1000) { // Non chiudere manualmente
          this.handleReconnect();
        }
      };

      this.socket.onerror = (error) => {
        console.error('🔌 Errore WebSocket:', error);
        this.isConnecting = false;
        this.emit('connection_status', { 
          status: 'error', 
          error: 'WebSocket connection error', 
          timestamp: new Date() 
        });
        this.handleReconnect();
      };

      this.socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          console.log('📨 Messaggio WebSocket ricevuto:', data.type);
          
          switch (data.type) {
            case 'dashboard_stats_update':
              this.emit('dashboard_stats', data.data);
              break;
            case 'system_health_update':
              this.emit('system_health', data.data);
              break;
            case 'user_activity':
              this.emit('user_activity', data.data);
              break;
            case 'server_status_update':
              this.emit('server_status', data.data);
              break;
            case 'security_alert':
              this.emit('security_alert', data.data);
              break;
            case 'new_message':
              this.emit('new_message', data.data);
              break;
            case 'new_call':
              this.emit('new_call', data.data);
              break;
            case 'device_status_change':
              this.emit('device_status', data.data);
              break;
            default:
              console.log('📨 Messaggio WebSocket non riconosciuto:', data.type);
          }
        } catch (error) {
          console.error('❌ Errore parsing messaggio WebSocket:', error);
        }
      };

    } catch (error) {
      console.error('❌ Errore inizializzazione WebSocket:', error);
      this.isConnecting = false;
      this.handleReconnect();
    }
  }

  private handleReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`🔄 Tentativo di riconnessione ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
      
      setTimeout(() => {
        this.connect();
      }, this.reconnectInterval * this.reconnectAttempts);
    } else {
      console.error('❌ Raggiunto il numero massimo di tentativi di riconnessione');
      this.emit('connection_status', { 
        status: 'failed', 
        message: 'Impossibile riconnettersi al server', 
        timestamp: new Date() 
      });
    }
  }

  // Metodi per gestire i listener
  on(event: string, callback: Function) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)!.push(callback);

    // Restituisce una funzione per rimuovere il listener
    return () => {
      const callbacks = this.listeners.get(event);
      if (callbacks) {
        const index = callbacks.indexOf(callback);
        if (index > -1) {
          callbacks.splice(index, 1);
        }
      }
    };
  }

  private emit(event: string, data: any) {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      callbacks.forEach(callback => callback(data));
    }
  }

  // Metodi per inviare comandi al server
  private sendMessage(type: string, data: any = {}) {
    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify({ type, data }));
    } else {
      console.warn('⚠️ WebSocket non connesso, impossibile inviare:', type);
    }
  }

  requestDashboardStats() {
    this.sendMessage('request_dashboard_stats');
  }

  requestSystemHealth() {
    this.sendMessage('request_system_health');
  }

  requestServerStatus() {
    this.sendMessage('request_server_status');
  }

  subscribeToUser(userId: number) {
    this.sendMessage('subscribe_user', { user_id: userId });
  }

  subscribeToServer(serverId: string) {
    this.sendMessage('subscribe_server', { server_id: serverId });
  }

  unsubscribeFromUser(userId: number) {
    this.sendMessage('unsubscribe_user', { user_id: userId });
  }

  unsubscribeFromServer(serverId: string) {
    this.sendMessage('unsubscribe_server', { server_id: serverId });
  }

  // Metodi per controlli server
  restartServer(serverId: string) {
    this.sendMessage('server_action', { server_id: serverId, action: 'restart' });
  }

  stopServer(serverId: string) {
    this.sendMessage('server_action', { server_id: serverId, action: 'stop' });
  }

  startServer(serverId: string) {
    this.sendMessage('server_action', { server_id: serverId, action: 'start' });
  }

  // Metodi per gestione utenti real-time
  blockUser(userId: number) {
    this.sendMessage('user_action', { user_id: userId, action: 'block' });
  }

  unblockUser(userId: number) {
    this.sendMessage('user_action', { user_id: userId, action: 'unblock' });
  }

  // Metodi per terminale real-time
  sendTerminalCommand(serverId: string, command: string) {
    this.sendMessage('terminal_command', { server_id: serverId, command });
  }

  subscribeToTerminal(serverId: string) {
    this.sendMessage('subscribe_terminal', { server_id: serverId });
  }

  // Disconnessione
  disconnect() {
    if (this.socket) {
      this.socket.close(1000, 'Manual disconnect');
      this.socket = null;
    }
    this.listeners.clear();
    this.isConnecting = false;
  }

  // Stato connessione
  get isConnected(): boolean {
    return this.socket?.readyState === WebSocket.OPEN;
  }

  get connectionId(): string | undefined {
    return this.socket?.url;
  }
}

export default new WebSocketService();