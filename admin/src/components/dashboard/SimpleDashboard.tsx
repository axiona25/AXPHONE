import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  CircularProgress,
  Alert,
  Button,
  Chip,
  Tooltip,
  IconButton,
} from '@mui/material';
import {
  People,
  Computer,
  Message,
  Phone,
  Security,
  Wifi,
  WifiOff,
  Refresh,
  CloudOff,
  CloudDone,
} from '@mui/icons-material';
import StatsCard from './StatsCard';
import { useRealtimeDashboard, useRealtimeSystemHealth, useRealtimeNotifications, useWebSocketConnection } from '../../hooks/useRealtimeData';
import { securevoxColors } from '../../theme/securevoxTheme';

const SimpleDashboard: React.FC = () => {
  // Hook per dati real-time
  const dashboardData = useRealtimeDashboard({
    pollingInterval: 10000, // 10 secondi
    enableWebSocket: true,
    enablePolling: true,
  });

  const systemHealthData = useRealtimeSystemHealth({
    pollingInterval: 5000, // 5 secondi
    enableWebSocket: true,
    enablePolling: true,
  });

  const notifications = useRealtimeNotifications();
  const connection = useWebSocketConnection();

  // Alias per compatibilità
  const stats = dashboardData.data;
  const systemHealth = systemHealthData.data;
  const loading = dashboardData.loading;
  const error = dashboardData.error || systemHealthData.error;
  const lastUpdate = dashboardData.lastUpdate || systemHealthData.lastUpdate;

  if (loading && !stats) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          height: '50vh',
        }}
      >
        <CircularProgress size={60} sx={{ color: securevoxColors.primary }} />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mb: 3 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      {/* Header */}
      <Box sx={{ mb: 4 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
          <Typography variant="h4" sx={{ fontWeight: 700 }}>
            AXPHONE Admin Dashboard
          </Typography>
          
          {/* Status di connessione */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    <Chip
                      icon={<CloudOff />}
                      label="Real-time Disabilitato"
                      color="warning"
                      size="small"
                    />
            
            {notifications.unreadCount > 0 && (
              <Chip
                label={`${notifications.unreadCount} notifiche`}
                color="warning"
                size="small"
              />
            )}
            
            <Tooltip title="Aggiorna manualmente">
              <IconButton
                onClick={() => {
                  dashboardData.refresh();
                  systemHealthData.refresh();
                }}
                disabled={loading}
                sx={{ color: securevoxColors.primary }}
              >
                <Refresh />
              </IconButton>
            </Tooltip>
          </Box>
        </Box>
        
                <Typography variant="body2" color="textSecondary">
                  Ultimo aggiornamento: {lastUpdate?.toLocaleTimeString('it-IT') || 'Mai'}
                  <span style={{ marginLeft: 8, color: securevoxColors.warning }}>
                    • Aggiornamento manuale
                  </span>
                </Typography>
      </Box>

      {/* Stats Cards in riga semplice */}
      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 3, mb: 4 }}>
        <Box sx={{ flex: '1 1 300px', minWidth: 300 }}>
          <StatsCard
            title="Utenti Totali"
            value={stats?.users.total || 0}
            subtitle={`${stats?.users.active_24h || 0} attivi oggi`}
            icon={<People />}
            trend={{
              value: stats?.users.growth_rate || 0,
              direction: stats?.users.growth_rate && stats.users.growth_rate > 0 ? 'up' : 'down',
              period: 'vs mese scorso',
            }}
            onRefresh={dashboardData.refresh}
            loading={loading}
          />
        </Box>

        <Box sx={{ flex: '1 1 300px', minWidth: 300 }}>
          <StatsCard
            title="Dispositivi Attivi"
            value={stats?.devices.active || 0}
            subtitle={`${stats?.devices.total || 0} totali`}
            icon={<Computer />}
            progress={{
              value: stats?.devices.active || 0,
              max: stats?.devices.total || 1,
              label: 'Attivi',
            }}
            onRefresh={dashboardData.refresh}
            loading={loading}
          />
        </Box>

        <Box sx={{ flex: '1 1 300px', minWidth: 300 }}>
          <StatsCard
            title="Messaggi Oggi"
            value={stats?.messages.last_24h || 0}
            subtitle={`${stats?.messages.total || 0} totali`}
            icon={<Message />}
            trend={{
              value: Math.round(((stats?.messages.last_24h || 0) / (stats?.messages.last_7d || 1)) * 100 - 100),
              direction: 'up',
              period: 'vs settimana',
            }}
            onRefresh={dashboardData.refresh}
            loading={loading}
          />
        </Box>

        <Box sx={{ flex: '1 1 300px', minWidth: 300 }}>
          <StatsCard
            title="Chiamate Oggi"
            value={stats?.calls.last_24h || 0}
            subtitle={`${Math.round(stats?.calls.average_duration || 0)}min media`}
            icon={<Phone />}
            onRefresh={dashboardData.refresh}
            loading={loading}
          />
        </Box>
      </Box>

      {/* System Health e Security in riga */}
      <Box sx={{ display: 'flex', gap: 3, flexWrap: 'wrap' }}>
        {/* System Health */}
        <Box sx={{ flex: '1 1 400px', minWidth: 400 }}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                {systemHealth?.status === 'healthy' ? <Wifi color="success" /> : <WifiOff color="error" />}
                Stato Sistema
              </Typography>
              
              {systemHealth && (
                <Box>
                  <Box sx={{ mb: 2 }}>
                    <Typography variant="body2" color="textSecondary" gutterBottom>
                      CPU Usage: {systemHealth.system.cpu_usage.toFixed(1)}%
                    </Typography>
                    <Box sx={{ width: '100%', bgcolor: 'grey.200', borderRadius: 1, height: 8, mb: 1 }}>
                      <Box
                        sx={{
                          width: `${systemHealth.system.cpu_usage}%`,
                          bgcolor: systemHealth.system.cpu_usage > 80 ? 'error.main' : 'success.main',
                          height: 8,
                          borderRadius: 1,
                        }}
                      />
                    </Box>
                  </Box>

                  <Box sx={{ mb: 2 }}>
                    <Typography variant="body2" color="textSecondary" gutterBottom>
                      Memoria: {systemHealth.system.memory_usage.toFixed(1)}%
                    </Typography>
                    <Box sx={{ width: '100%', bgcolor: 'grey.200', borderRadius: 1, height: 8, mb: 1 }}>
                      <Box
                        sx={{
                          width: `${systemHealth.system.memory_usage}%`,
                          bgcolor: systemHealth.system.memory_usage > 85 ? 'error.main' : 'warning.main',
                          height: 8,
                          borderRadius: 1,
                        }}
                      />
                    </Box>
                  </Box>

                  <Box sx={{ mb: 2 }}>
                    <Typography variant="body2" color="textSecondary" gutterBottom>
                      Disco: {systemHealth.system.disk_usage.toFixed(1)}%
                    </Typography>
                    <Box sx={{ width: '100%', bgcolor: 'grey.200', borderRadius: 1, height: 8, mb: 1 }}>
                      <Box
                        sx={{
                          width: `${systemHealth.system.disk_usage}%`,
                          bgcolor: systemHealth.system.disk_usage > 90 ? 'error.main' : 'primary.main',
                          height: 8,
                          borderRadius: 1,
                        }}
                      />
                    </Box>
                  </Box>

                  <Typography variant="body2" color="textSecondary">
                    Health Score: {systemHealth.health_score.toFixed(0)}%
                  </Typography>
                </Box>
              )}
            </CardContent>
          </Card>
        </Box>

        {/* Security Status */}
        <Box sx={{ flex: '1 1 400px', minWidth: 400 }}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <Security />
                Sicurezza
              </Typography>
              
              {stats && (
                <Box>
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                    <Typography variant="body2">Login falliti (24h)</Typography>
                    <Typography variant="body2" color="error.main">
                      {stats.security.failed_logins_24h}
                    </Typography>
                  </Box>
                  
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                    <Typography variant="body2">IP bloccati</Typography>
                    <Typography variant="body2" color="warning.main">
                      {stats.security.blocked_ips}
                    </Typography>
                  </Box>
                  
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                    <Typography variant="body2">Attività sospette</Typography>
                    <Typography variant="body2" color="error.main">
                      {stats.security.suspicious_activity}
                    </Typography>
                  </Box>
                  
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                    <Typography variant="body2">Dispositivi compromessi</Typography>
                    <Typography variant="body2" color="error.main">
                      {stats.devices.compromised}
                    </Typography>
                  </Box>
                </Box>
              )}
            </CardContent>
          </Card>
        </Box>
      </Box>

      {/* Info aggiuntive */}
      <Box sx={{ mt: 4, p: 3, bgcolor: 'grey.50', borderRadius: 2 }}>
        <Typography variant="h6" sx={{ mb: 2 }}>
          🚀 Dashboard Real-time AXPHONE
        </Typography>
        <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
          Questa dashboard fornisce una vista a 360° sempre aggiornata del sistema AXPHONE.
          Tutti i dati vengono aggiornati in tempo reale tramite WebSocket.
        </Typography>
        
        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
          <Chip label="WebSocket Real-time" color="success" size="small" />
          <Chip label="Aggiornamento automatico" color="primary" size="small" />
          <Chip label="Notifiche live" color="secondary" size="small" />
          <Chip label="Sicurezza enterprise" color="warning" size="small" />
        </Box>
      </Box>
    </Box>
  );
};

export default SimpleDashboard;
