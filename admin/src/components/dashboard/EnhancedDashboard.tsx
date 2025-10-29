import React, { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  LinearProgress,
  Chip,
  IconButton,
  Alert,
  CircularProgress,
  Paper,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Avatar,
  Button,
} from '@mui/material';
import {
  Chat,
  Phone,
  People,
  Computer,
  TrendingUp,
  Warning,
  CheckCircle,
  Error,
  Refresh,
  Message,
  Call,
  Group,
  Analytics,
  Timeline,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import api from '../../services/api';

interface DashboardStats {
  total_users: number;
  active_users: number;
  total_groups: number;
  total_servers: number;
  active_servers: number;
  chats_today: number;
  calls_today: number;
  system_health: {
    status: 'healthy' | 'warning' | 'critical';
    cpu_usage: number;
    memory_usage: number;
    disk_usage: number;
    uptime: string;
  };
  recent_activities: Array<{
    id: string;
    type: 'chat' | 'call' | 'user' | 'system';
    message: string;
    timestamp: string;
    user?: string;
  }>;
  alerts: Array<{
    id: string;
    type: 'warning' | 'error' | 'info';
    message: string;
    timestamp: string;
    server?: string;
  }>;
}

const EnhancedDashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  useEffect(() => {
    fetchDashboardStats();
    // Polling ogni 30 secondi per aggiornamenti real-time
    const interval = setInterval(fetchDashboardStats, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchDashboardStats = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/dashboard-stats/');
      setStats(response.data);
      setLastUpdate(new Date());
    } catch (err) {
      setError('Errore nel caricamento delle statistiche');
      console.error('Errore fetch dashboard:', err);
    } finally {
      setLoading(false);
    }
  };

  const getHealthColor = (status: string) => {
    switch (status) {
      case 'healthy':
        return securevoxColors.success;
      case 'warning':
        return securevoxColors.warning;
      case 'critical':
        return securevoxColors.error;
      default:
        return securevoxColors.textSecondary;
    }
  };

  const getHealthIcon = (status: string) => {
    switch (status) {
      case 'healthy':
        return <CheckCircle sx={{ color: securevoxColors.success }} />;
      case 'warning':
        return <Warning sx={{ color: securevoxColors.warning }} />;
      case 'critical':
        return <Error sx={{ color: securevoxColors.error }} />;
      default:
        return <Error sx={{ color: securevoxColors.error }} />;
    }
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'chat':
        return <Message sx={{ color: securevoxColors.primary }} />;
      case 'call':
        return <Call sx={{ color: securevoxColors.success }} />;
      case 'user':
        return <People sx={{ color: securevoxColors.secondary }} />;
      case 'system':
        return <Computer sx={{ color: securevoxColors.accent }} />;
      default:
        return <Analytics sx={{ color: securevoxColors.textSecondary }} />;
    }
  };

  const getAlertColor = (type: string) => {
    switch (type) {
      case 'warning':
        return securevoxColors.warning;
      case 'error':
        return securevoxColors.error;
      case 'info':
        return securevoxColors.primary;
      default:
        return securevoxColors.textSecondary;
    }
  };

  if (loading && !stats) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
        <CircularProgress sx={{ color: securevoxColors.primary }} />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ m: 2 }}>
        {error}
      </Alert>
    );
  }

  if (!stats) return null;

  return (
    <Box sx={{ p: 3 }}>
      {/* Header con aggiornamento */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" sx={{ fontWeight: 700, color: securevoxColors.textPrimary }}>
          Dashboard AXPHONE
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <Typography variant="body2" color="textSecondary">
            Ultimo aggiornamento: {lastUpdate.toLocaleTimeString('it-IT')}
          </Typography>
          <IconButton onClick={fetchDashboardStats} disabled={loading}>
            <Refresh />
          </IconButton>
        </Box>
      </Box>

      {/* Card Statistiche Principali */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {/* Chat Oggi */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" sx={{ fontWeight: 700, color: securevoxColors.primary }}>
                    {stats.chats_today}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Chat Generate Oggi
                  </Typography>
                </Box>
                <Avatar sx={{ backgroundColor: securevoxColors.primary, width: 56, height: 56 }}>
                  <Chat />
                </Avatar>
              </Box>
              <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <TrendingUp sx={{ color: securevoxColors.success, fontSize: 16 }} />
                <Typography variant="caption" color="textSecondary">
                  +12% rispetto a ieri
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Chiamate Oggi */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" sx={{ fontWeight: 700, color: securevoxColors.success }}>
                    {stats.calls_today}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Chiamate Effettuate Oggi
                  </Typography>
                </Box>
                <Avatar sx={{ backgroundColor: securevoxColors.success, width: 56, height: 56 }}>
                  <Phone />
                </Avatar>
              </Box>
              <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <TrendingUp sx={{ color: securevoxColors.success, fontSize: 16 }} />
                <Typography variant="caption" color="textSecondary">
                  +8% rispetto a ieri
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Utenti Attivi */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" sx={{ fontWeight: 700, color: securevoxColors.secondary }}>
                    {stats.active_users}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Utenti Attivi
                  </Typography>
                </Box>
                <Avatar sx={{ backgroundColor: securevoxColors.secondary, width: 56, height: 56 }}>
                  <People />
                </Avatar>
              </Box>
              <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <Typography variant="caption" color="textSecondary">
                  {stats.total_users} utenti totali
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Server Attivi */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography variant="h4" sx={{ fontWeight: 700, color: securevoxColors.accent }}>
                    {stats.active_servers}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Server Attivi
                  </Typography>
                </Box>
                <Avatar sx={{ backgroundColor: securevoxColors.accent, width: 56, height: 56 }}>
                  <Computer />
                </Avatar>
              </Box>
              <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <Typography variant="caption" color="textSecondary">
                  {stats.total_servers} server totali
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        {/* Stato Sistema */}
        <Grid size={{ xs: 12, md: 4 }}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                {getHealthIcon(stats.system_health.status)}
                Stato Sistema
              </Typography>
              
              <Box sx={{ mb: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2">CPU</Typography>
                  <Typography variant="body2">{stats.system_health.cpu_usage}%</Typography>
                </Box>
                <LinearProgress
                  variant="determinate"
                  value={stats.system_health.cpu_usage}
                  sx={{
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: securevoxColors.surface,
                    '& .MuiLinearProgress-bar': {
                      backgroundColor: stats.system_health.cpu_usage > 80 ? securevoxColors.error : securevoxColors.primary,
                    },
                  }}
                />
              </Box>

              <Box sx={{ mb: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2">Memoria</Typography>
                  <Typography variant="body2">{stats.system_health.memory_usage}%</Typography>
                </Box>
                <LinearProgress
                  variant="determinate"
                  value={stats.system_health.memory_usage}
                  sx={{
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: securevoxColors.surface,
                    '& .MuiLinearProgress-bar': {
                      backgroundColor: stats.system_health.memory_usage > 80 ? securevoxColors.error : securevoxColors.secondary,
                    },
                  }}
                />
              </Box>

              <Box sx={{ mb: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                  <Typography variant="body2">Disco</Typography>
                  <Typography variant="body2">{stats.system_health.disk_usage}%</Typography>
                </Box>
                <LinearProgress
                  variant="determinate"
                  value={stats.system_health.disk_usage}
                  sx={{
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: securevoxColors.surface,
                    '& .MuiLinearProgress-bar': {
                      backgroundColor: stats.system_health.disk_usage > 80 ? securevoxColors.error : securevoxColors.accent,
                    },
                  }}
                />
              </Box>

              <Typography variant="body2" color="textSecondary">
                Uptime: {stats.system_health.uptime}
              </Typography>
            </CardContent>
          </Card>
        </Grid>

        {/* Attività Recenti */}
        <Grid size={{ xs: 12, md: 4 }}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <Timeline sx={{ color: securevoxColors.primary }} />
                Attività Recenti
              </Typography>
              
              <List dense>
                {stats.recent_activities.slice(0, 5).map((activity) => (
                  <ListItem key={activity.id} sx={{ px: 0 }}>
                    <ListItemIcon sx={{ minWidth: 32 }}>
                      {getActivityIcon(activity.type)}
                    </ListItemIcon>
                    <ListItemText
                      primary={
                        <Typography variant="body2" sx={{ fontWeight: 500 }}>
                          {activity.message}
                        </Typography>
                      }
                      secondary={
                        <Typography variant="caption" color="textSecondary">
                          {new Date(activity.timestamp).toLocaleString('it-IT')}
                          {activity.user && ` • ${activity.user}`}
                        </Typography>
                      }
                    />
                  </ListItem>
                ))}
              </List>

              {stats.recent_activities.length === 0 && (
                <Typography variant="body2" color="textSecondary" sx={{ textAlign: 'center', py: 2 }}>
                  Nessuna attività recente
                </Typography>
              )}
            </CardContent>
          </Card>
        </Grid>

        {/* Allerte */}
        <Grid size={{ xs: 12, md: 4 }}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                <Warning sx={{ color: securevoxColors.warning }} />
                Allerte Sistema
              </Typography>
              
              {stats.alerts.length > 0 ? (
                <List dense>
                  {stats.alerts.slice(0, 5).map((alert) => (
                    <ListItem key={alert.id} sx={{ px: 0 }}>
                      <ListItemIcon sx={{ minWidth: 32 }}>
                        <Warning sx={{ color: getAlertColor(alert.type) }} />
                      </ListItemIcon>
                      <ListItemText
                        primary={
                          <Typography variant="body2" sx={{ fontWeight: 500 }}>
                            {alert.message}
                          </Typography>
                        }
                        secondary={
                          <Typography variant="caption" color="textSecondary">
                            {new Date(alert.timestamp).toLocaleString('it-IT')}
                            {alert.server && ` • ${alert.server}`}
                          </Typography>
                        }
                      />
                    </ListItem>
                  ))}
                </List>
              ) : (
                <Box sx={{ textAlign: 'center', py: 2 }}>
                  <CheckCircle sx={{ color: securevoxColors.success, fontSize: 48, mb: 1 }} />
                  <Typography variant="body2" color="textSecondary">
                    Nessuna allerta attiva
                  </Typography>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Statistiche Gruppi */}
      <Card sx={{ mt: 3 }}>
        <CardContent>
          <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
            <Group sx={{ color: securevoxColors.primary }} />
            Panoramica Gruppi
          </Typography>
          
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Paper sx={{ p: 2, textAlign: 'center' }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: securevoxColors.primary }}>
                  {stats.total_groups}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Gruppi Totali
                </Typography>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Paper sx={{ p: 2, textAlign: 'center' }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: securevoxColors.success }}>
                  {Math.round((stats.active_users / stats.total_users) * 100)}%
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Utenti Attivi
                </Typography>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Paper sx={{ p: 2, textAlign: 'center' }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: securevoxColors.warning }}>
                  {Math.round((stats.active_servers / stats.total_servers) * 100)}%
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Server Attivi
                </Typography>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Paper sx={{ p: 2, textAlign: 'center' }}>
                <Typography variant="h5" sx={{ fontWeight: 700, color: securevoxColors.accent }}>
                  {stats.chats_today + stats.calls_today}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Comunicazioni Oggi
                </Typography>
              </Paper>
            </Grid>
          </Grid>
        </CardContent>
      </Card>
    </Box>
  );
};

export default EnhancedDashboard;
