import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  Chip,
  LinearProgress,
  Alert,
  CircularProgress,
  IconButton,
  Divider,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
} from '@mui/material';
import {
  Computer,
  Terminal,
  Storage,
  Memory,
  Speed,
  NetworkCheck,
  Close,
  Refresh,
  Warning,
  CheckCircle,
  Error,
  Timeline,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import api from '../../services/api';

interface Server {
  id: string;
  name: string;
  ip_address: string;
  port: number;
  size: string;
  technology: string;
  vertical_function: string;
  status: 'active' | 'inactive' | 'maintenance';
  alerts: number;
  cpu_usage: number;
  memory_usage: number;
  disk_usage: number;
  last_seen: string;
  created_at: string;
}

interface ServerStats {
  uptime: string;
  processes: number;
  network_in: string;
  network_out: string;
  disk_read: string;
  disk_write: string;
  load_average: number[];
  temperature: number;
}

interface ServerDetailsDialogProps {
  open: boolean;
  onClose: () => void;
  server: Server | null;
}

const ServerDetailsDialog: React.FC<ServerDetailsDialogProps> = ({ open, onClose, server }) => {
  const [stats, setStats] = useState<ServerStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open && server) {
      fetchServerStats();
      // Polling ogni 10 secondi per statistiche real-time
      const interval = setInterval(fetchServerStats, 10000);
      return () => clearInterval(interval);
    }
  }, [open, server]);

  const fetchServerStats = async () => {
    if (!server) return;
    
    try {
      setLoading(true);
      setError(null);
      const response = await api.get(`/servers/${server.id}/stats/`);
      setStats(response.data);
    } catch (err) {
      setError('Errore nel caricamento delle statistiche del server');
      console.error('Errore fetch stats:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleTerminalAccess = () => {
    if (server) {
      window.open(`/admin/terminal/${server.id}/`, '_blank');
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'active':
        return <CheckCircle sx={{ color: securevoxColors.success }} />;
      case 'inactive':
        return <Error sx={{ color: securevoxColors.error }} />;
      case 'maintenance':
        return <Warning sx={{ color: securevoxColors.warning }} />;
      default:
        return <Error sx={{ color: securevoxColors.error }} />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'success';
      case 'inactive':
        return 'error';
      case 'maintenance':
        return 'warning';
      default:
        return 'error';
    }
  };

  const getUsageColor = (usage: number) => {
    if (usage >= 90) return securevoxColors.error;
    if (usage >= 70) return securevoxColors.warning;
    return securevoxColors.success;
  };

  if (!server) return null;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Computer sx={{ color: securevoxColors.primary }} />
            <Box>
              <Typography variant="h6">
                Dettagli Server: {server.name}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                {server.ip_address}:{server.port} • {server.technology}
              </Typography>
            </Box>
          </Box>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <IconButton onClick={fetchServerStats} size="small">
              <Refresh />
            </IconButton>
            <IconButton onClick={onClose} size="small">
              <Close />
            </IconButton>
          </Box>
        </Box>
      </DialogTitle>
      
      <DialogContent>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        {/* Informazioni Generali */}
        <Grid container spacing={2} sx={{ mb: 3 }}>
          <Grid size={{ xs: 12, md: 6 }}>
            <Card>
              <CardContent>
                <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Computer />
                  Informazioni Server
                </Typography>
                <List dense>
                  <ListItem>
                    <ListItemIcon>
                      <Computer />
                    </ListItemIcon>
                    <ListItemText
                      primary="Nome"
                      secondary={server.name}
                    />
                  </ListItem>
                  <ListItem>
                    <ListItemIcon>
                      <NetworkCheck />
                    </ListItemIcon>
                    <ListItemText
                      primary="Indirizzo"
                      secondary={`${server.ip_address}:${server.port}`}
                    />
                  </ListItem>
                  <ListItem>
                    <ListItemIcon>
                      <Storage />
                    </ListItemIcon>
                    <ListItemText
                      primary="Dimensioni"
                      secondary={server.size}
                    />
                  </ListItem>
                  <ListItem>
                    <ListItemIcon>
                      <Speed />
                    </ListItemIcon>
                    <ListItemText
                      primary="Tecnologia"
                      secondary={server.technology}
                    />
                  </ListItem>
                  <ListItem>
                    <ListItemText
                      primary="Funzione"
                      secondary={server.vertical_function}
                    />
                  </ListItem>
                </List>
              </CardContent>
            </Card>
          </Grid>
          
          <Grid size={{ xs: 12, md: 6 }}>
            <Card>
              <CardContent>
                <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Timeline />
                  Stato e Allerte
                </Typography>
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    {getStatusIcon(server.status)}
                    <Chip
                      label={server.status}
                      color={getStatusColor(server.status) as any}
                    />
                  </Box>
                  
                  {server.alerts > 0 && (
                    <Alert severity="warning" icon={<Warning />}>
                      {server.alerts} allerte attive su questo server
                    </Alert>
                  )}
                  
                  <Typography variant="body2" color="textSecondary">
                    <strong>Ultimo accesso:</strong> {new Date(server.last_seen).toLocaleString('it-IT')}
                  </Typography>
                  
                  <Typography variant="body2" color="textSecondary">
                    <strong>Creato il:</strong> {new Date(server.created_at).toLocaleDateString('it-IT')}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Statistiche di Utilizzo */}
        <Typography variant="h6" sx={{ mb: 2 }}>
          Statistiche di Utilizzo
        </Typography>
        
        <Grid container spacing={2} sx={{ mb: 3 }}>
          <Grid size={{ xs: 12, md: 4 }}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Speed sx={{ color: securevoxColors.primary }} />
                  <Typography variant="subtitle1">CPU</Typography>
                </Box>
                <Typography variant="h4" sx={{ color: getUsageColor(server.cpu_usage) }}>
                  {server.cpu_usage}%
                </Typography>
                <LinearProgress
                  variant="determinate"
                  value={server.cpu_usage}
                  sx={{
                    mt: 1,
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: securevoxColors.surface,
                    '& .MuiLinearProgress-bar': {
                      backgroundColor: getUsageColor(server.cpu_usage),
                    },
                  }}
                />
              </CardContent>
            </Card>
          </Grid>
          
          <Grid size={{ xs: 12, md: 4 }}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Memory sx={{ color: securevoxColors.primary }} />
                  <Typography variant="subtitle1">Memoria</Typography>
                </Box>
                <Typography variant="h4" sx={{ color: getUsageColor(server.memory_usage) }}>
                  {server.memory_usage}%
                </Typography>
                <LinearProgress
                  variant="determinate"
                  value={server.memory_usage}
                  sx={{
                    mt: 1,
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: securevoxColors.surface,
                    '& .MuiLinearProgress-bar': {
                      backgroundColor: getUsageColor(server.memory_usage),
                    },
                  }}
                />
              </CardContent>
            </Card>
          </Grid>
          
          <Grid size={{ xs: 12, md: 4 }}>
            <Card>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Storage sx={{ color: securevoxColors.primary }} />
                  <Typography variant="subtitle1">Disco</Typography>
                </Box>
                <Typography variant="h4" sx={{ color: getUsageColor(server.disk_usage) }}>
                  {server.disk_usage}%
                </Typography>
                <LinearProgress
                  variant="determinate"
                  value={server.disk_usage}
                  sx={{
                    mt: 1,
                    height: 8,
                    borderRadius: 4,
                    backgroundColor: securevoxColors.surface,
                    '& .MuiLinearProgress-bar': {
                      backgroundColor: getUsageColor(server.disk_usage),
                    },
                  }}
                />
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Statistiche Real-time */}
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
            <CircularProgress sx={{ color: securevoxColors.primary }} />
          </Box>
        ) : stats ? (
          <Box>
            <Typography variant="h6" sx={{ mb: 2 }}>
              Statistiche Real-time
            </Typography>
            <Grid container spacing={2}>
              <Grid size={{ xs: 12, md: 6 }}>
                <Card>
                  <CardContent>
                    <Typography variant="subtitle1" sx={{ mb: 2 }}>
                      Sistema
                    </Typography>
                    <List dense>
                      <ListItem>
                        <ListItemText
                          primary="Uptime"
                          secondary={stats.uptime}
                        />
                      </ListItem>
                      <ListItem>
                        <ListItemText
                          primary="Processi Attivi"
                          secondary={stats.processes}
                        />
                      </ListItem>
                      <ListItem>
                        <ListItemText
                          primary="Temperatura"
                          secondary={`${stats.temperature}°C`}
                        />
                      </ListItem>
                    </List>
                  </CardContent>
                </Card>
              </Grid>
              
              <Grid size={{ xs: 12, md: 6 }}>
                <Card>
                  <CardContent>
                    <Typography variant="subtitle1" sx={{ mb: 2 }}>
                      Network & I/O
                    </Typography>
                    <List dense>
                      <ListItem>
                        <ListItemText
                          primary="Network In"
                          secondary={stats.network_in}
                        />
                      </ListItem>
                      <ListItem>
                        <ListItemText
                          primary="Network Out"
                          secondary={stats.network_out}
                        />
                      </ListItem>
                      <ListItem>
                        <ListItemText
                          primary="Disk Read"
                          secondary={stats.disk_read}
                        />
                      </ListItem>
                      <ListItem>
                        <ListItemText
                          primary="Disk Write"
                          secondary={stats.disk_write}
                        />
                      </ListItem>
                    </List>
                  </CardContent>
                </Card>
              </Grid>
            </Grid>
          </Box>
        ) : null}
      </DialogContent>
      
      <DialogActions>
        <Button onClick={handleTerminalAccess} startIcon={<Terminal />}>
          Accedi al Terminale
        </Button>
        <Button onClick={onClose}>
          Chiudi
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default ServerDetailsDialog;
