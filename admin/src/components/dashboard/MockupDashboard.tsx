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
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tooltip,
  Switch,
  FormControlLabel,
} from '@mui/material';
import {
  ArrowUpward,
  Star,
  Public,
  Storage,
  Memory,
  Speed,
  Notifications,
  Menu as MenuIcon,
  AccountCircle,
  Logout,
  Dashboard,
  People,
  Groups,
  Computer,
  Settings,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import { useAuth } from '../../contexts/AuthContext';
import api from '../../services/api';

interface DashboardStats {
  monthly_visitors: number;
  chats_today: number;
  calls_today: number;
  active_users: number;
  server_traffic: Array<{
    day: string;
    value: number;
  }>;
  servers: Array<{
    id: string;
    country: string;
    domain: string;
    storage: string;
    status: 'active' | 'issues' | 'down';
    page_load: string;
    report: string;
  }>;
}

const MockupDashboard: React.FC = () => {
  const { isAuthenticated, loading: authLoading } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Non fare nulla se l'auth è ancora in caricamento
    if (authLoading) {
      return;
    }
    
    // Solo se l'utente è autenticato, carica i dati
    if (isAuthenticated) {
      fetchDashboardStats();
      const interval = setInterval(fetchDashboardStats, 30000);
      return () => clearInterval(interval);
    } else {
      setLoading(false);
    }
  }, [isAuthenticated, authLoading]);

  const fetchDashboardStats = async () => {
    // Non fare richieste se non autenticato o se l'auth è ancora in caricamento
    if (!isAuthenticated || authLoading) {
      return;
    }
    
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/dashboard-stats/');
      setStats(response.data);
    } catch (err) {
      setError('Errore nel caricamento delle statistiche');
      console.error('Errore fetch dashboard:', err);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active':
        return '#4CAF50'; // Verde
      case 'issues':
        return '#FF9800'; // Arancione
      case 'down':
        return '#F44336'; // Rosso
      default:
        return '#9E9E9E'; // Grigio
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'active':
        return 'Attivo';
      case 'issues':
        return 'Problemi';
      case 'down':
        return 'Spento';
      default:
        return 'Sconosciuto';
    }
  };

  // Dati mock per il grafico del traffico server (seguendo il mockup)
  const trafficData = [
    { day: 'Lun', value: 45 },
    { day: 'Mar', value: 62 },
    { day: 'Mer', value: 38 },
    { day: 'Gio', value: 78 },
    { day: 'Ven', value: 55 },
    { day: 'Sab', value: 42 },
    { day: 'Dom', value: 68 },
  ];

  // Dati mock per i server (seguendo il mockup)
  const mockServers = [
    {
      id: '1',
      country: 'Italia',
      domain: 'https://www.securevox.it',
      storage: '1000 TB',
      status: 'active' as const,
      page_load: '2.0ms',
      report: 'italia.docs',
    },
    {
      id: '2',
      country: 'Europa',
      domain: 'https://www.securevox.eu',
      storage: '850 TB',
      status: 'issues' as const,
      page_load: '3.2ms',
      report: 'europa.docs',
    },
    {
      id: '3',
      country: 'America',
      domain: 'https://www.securevox.us',
      storage: '1200 TB',
      status: 'down' as const,
      page_load: 'N/A',
      report: 'america.docs',
    },
  ];

  if (loading && !stats) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
        <CircularProgress sx={{ color: securevoxColors.primary }} />
      </Box>
    );
  }

  return (
    <Box sx={{ backgroundColor: '#F5F5F5', minHeight: '100vh', p: 3 }}>
          {/* Card Statistiche Principali */}
          <Grid container spacing={3} sx={{ mb: 4 }}>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Card sx={{ 
                height: '100%', 
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
              }}>
                <CardContent sx={{ p: 3 }}>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 1 }}>
                    Visitatori Mensili
                  </Typography>
                  <Typography variant="h4" sx={{ 
                    fontWeight: 700, 
                    color: '#1A1A1A',
                    mb: 1,
                  }}>
                    12.399
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    Visitatori
                  </Typography>
                  <Chip
                    icon={<ArrowUpward sx={{ fontSize: 16 }} />}
                    label="24,4%"
                    size="small"
                    sx={{
                      backgroundColor: '#4CAF50',
                      color: '#FFFFFF',
                      fontWeight: 600,
                      fontSize: '0.75rem',
                    }}
                  />
                </CardContent>
              </Card>
            </Grid>

            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Card sx={{ 
                height: '100%', 
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
              }}>
                <CardContent sx={{ p: 3 }}>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 1 }}>
                    Chat Generate Oggi
                  </Typography>
                  <Typography variant="h4" sx={{ 
                    fontWeight: 700, 
                    color: '#1A1A1A',
                    mb: 1,
                  }}>
                    {stats?.chats_today || 156}
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    Chat
                  </Typography>
                  <Chip
                    icon={<ArrowUpward sx={{ fontSize: 16 }} />}
                    label="18,2%"
                    size="small"
                    sx={{
                      backgroundColor: '#4CAF50',
                      color: '#FFFFFF',
                      fontWeight: 600,
                      fontSize: '0.75rem',
                    }}
                  />
                </CardContent>
              </Card>
            </Grid>

            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Card sx={{ 
                height: '100%', 
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
              }}>
                <CardContent sx={{ p: 3 }}>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 1 }}>
                    Chiamate Oggi
                  </Typography>
                  <Typography variant="h4" sx={{ 
                    fontWeight: 700, 
                    color: '#1A1A1A',
                    mb: 1,
                  }}>
                    {stats?.calls_today || 89}
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    Chiamate
                  </Typography>
                  <Chip
                    icon={<ArrowUpward sx={{ fontSize: 16 }} />}
                    label="12,8%"
                    size="small"
                    sx={{
                      backgroundColor: '#4CAF50',
                      color: '#FFFFFF',
                      fontWeight: 600,
                      fontSize: '0.75rem',
                    }}
                  />
                </CardContent>
              </Card>
            </Grid>

            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Card sx={{ 
                height: '100%', 
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
              }}>
                <CardContent sx={{ p: 3 }}>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 1 }}>
                    Utenti Attivi
                  </Typography>
                  <Typography variant="h4" sx={{ 
                    fontWeight: 700, 
                    color: '#1A1A1A',
                    mb: 1,
                  }}>
                    {stats?.active_users || 234}
                  </Typography>
                  <Typography variant="body2" color="textSecondary" sx={{ mb: 2 }}>
                    Utenti
                  </Typography>
                  <Chip
                    icon={<ArrowUpward sx={{ fontSize: 16 }} />}
                    label="8,4%"
                    size="small"
                    sx={{
                      backgroundColor: '#4CAF50',
                      color: '#FFFFFF',
                      fontWeight: 600,
                      fontSize: '0.75rem',
                    }}
                  />
                </CardContent>
              </Card>
            </Grid>
          </Grid>

        <Grid container spacing={3}>
          {/* Grafico Traffico Server */}
          <Grid size={{ xs: 12, md: 6 }}>
            <Card sx={{ 
              borderRadius: 3,
              boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
              backgroundColor: '#FFFFFF',
              height: '100%',
            }}>
              <CardContent sx={{ p: 3 }}>
                <Typography variant="h6" sx={{ 
                  fontWeight: 600, 
                  color: '#1A1A1A',
                  mb: 3,
                }}>
                  Traffico Server
                </Typography>
                
                {/* Grafico a linee semplificato */}
                <Box sx={{ height: 250, position: 'relative', mb: 2 }}>
                  <svg width="100%" height="100%" viewBox="0 0 600 250">
                    {/* Griglia */}
                    {[0, 25, 50, 75, 100].map((value, index) => (
                      <g key={index}>
                        <line
                          x1="40"
                          y1={40 + index * 35}
                          x2="560"
                          y2={40 + index * 35}
                          stroke="#E0E0E0"
                          strokeWidth="1"
                          opacity="0.3"
                        />
                        <text
                          x="35"
                          y={45 + index * 35}
                          fontSize="10"
                          fill="#666"
                          textAnchor="end"
                        >
                          {value}
                        </text>
                      </g>
                    ))}
                    
                    {/* Linea del grafico */}
                    <polyline
                      fill="none"
                      stroke="#9C27B0"
                      strokeWidth="3"
                      points={trafficData.map((point, index) => 
                        `${80 + index * 70},${190 - (point.value * 1.4)}`
                      ).join(' ')}
                    />
                    
                    {/* Area sotto la linea */}
                    <polygon
                      fill="url(#gradient-purple)"
                      points={`80,190 ${trafficData.map((point, index) => 
                        `${80 + index * 70},${190 - (point.value * 1.4)}`
                      ).join(' ')} 560,190`}
                      opacity="0.2"
                    />
                    
                    {/* Punti dati */}
                    {trafficData.map((point, index) => (
                      <circle
                        key={index}
                        cx={80 + index * 70}
                        cy={190 - (point.value * 1.4)}
                        r="4"
                        fill="#9C27B0"
                      />
                    ))}
                    
                    {/* Etichette giorni */}
                    {trafficData.map((point, index) => (
                      <text
                        key={index}
                        x={80 + index * 70}
                        y="220"
                        fontSize="10"
                        fill="#666"
                        textAnchor="middle"
                      >
                        {point.day}
                      </text>
                    ))}
                    
                    {/* Gradiente */}
                    <defs>
                      <linearGradient id="gradient-purple" x1="0%" y1="0%" x2="0%" y2="100%">
                        <stop offset="0%" stopColor="#9C27B0" stopOpacity="0.3" />
                        <stop offset="100%" stopColor="#9C27B0" stopOpacity="0.1" />
                      </linearGradient>
                    </defs>
                  </svg>
                </Box>
              </CardContent>
            </Card>
          </Grid>

          {/* Piano di Abbonamento */}
          <Grid size={{ xs: 12, md: 3 }}>
            <Card sx={{ 
              borderRadius: 3,
              boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
              backgroundColor: '#FFFFFF',
              position: 'relative',
              overflow: 'hidden',
              height: '100%',
            }}>
              <Box
                sx={{
                  position: 'absolute',
                  top: 0,
                  right: 0,
                  width: 80,
                  height: 60,
                  background: 'linear-gradient(135deg, #FF9800, #F57C00)',
                  borderRadius: '0 24px 0 100%',
                  opacity: 0.8,
                }}
              />
              <CardContent sx={{ p: 3, position: 'relative' }}>
                <Typography variant="h6" sx={{ 
                  fontWeight: 600, 
                  color: '#1A1A1A',
                  mb: 2,
                  fontSize: '1rem',
                }}>
                  Piano di Abbonamento Attuale
                </Typography>
                <Typography variant="h4" sx={{ 
                  fontWeight: 700, 
                  color: '#1A1A1A',
                  mb: 1,
                  fontSize: '2rem',
                }}>
                  €1.248,00
                </Typography>
                <Typography variant="body1" sx={{ 
                  color: '#1A1A1A',
                  mb: 2,
                }}>
                  Premium Plus
                </Typography>
                <Button
                  variant="contained"
                  size="small"
                  sx={{
                    backgroundColor: '#9C27B0',
                    borderRadius: 2,
                    textTransform: 'none',
                    fontWeight: 600,
                    '&:hover': {
                      backgroundColor: '#7B1FA2',
                    },
                  }}
                >
                  Attivo
                </Button>
              </CardContent>
            </Card>
          </Grid>

          {/* Utilizzo CPU */}
          <Grid size={{ xs: 12, md: 3 }}>
            <Card sx={{ 
              borderRadius: 3,
              boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
              backgroundColor: '#FFFFFF',
              height: '100%',
            }}>
              <CardContent sx={{ 
                p: 3,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                height: '100%',
              }}>
                <Typography variant="h6" sx={{ 
                  fontWeight: 600, 
                  color: '#1A1A1A',
                  mb: 3,
                  fontSize: '1rem',
                  textAlign: 'center',
                }}>
                  Utilizzo CPU Giornaliero
                </Typography>
                
                {/* Grafico ad anello centrato */}
                <Box sx={{ 
                  display: 'flex', 
                  flexDirection: 'column', 
                  alignItems: 'center',
                  mb: 2,
                }}>
                  <Box sx={{ position: 'relative', display: 'inline-block' }}>
                    <svg width="120" height="120" viewBox="0 0 120 120">
                      {/* Cerchio di sfondo */}
                      <circle
                        cx="60"
                        cy="60"
                        r="50"
                        fill="none"
                        stroke="#E0E0E0"
                        strokeWidth="8"
                      />
                      
                      {/* Arco CPU - Viola */}
                      <circle
                        cx="60"
                        cy="60"
                        r="50"
                        fill="none"
                        stroke="#9C27B0"
                        strokeWidth="8"
                        strokeDasharray={`${2 * Math.PI * 50 * 0.655}`}
                        strokeDashoffset={`${2 * Math.PI * 50 * 0.655}`}
                        transform="rotate(-90 60 60)"
                        strokeLinecap="round"
                      />
                      
                      {/* Arco Storage - Arancione */}
                      <circle
                        cx="60"
                        cy="60"
                        r="50"
                        fill="none"
                        stroke="#FF9800"
                        strokeWidth="8"
                        strokeDasharray={`${2 * Math.PI * 50 * 0.7}`}
                        strokeDashoffset={`${2 * Math.PI * 50 * 0.655}`}
                        transform="rotate(-90 60 60)"
                        strokeLinecap="round"
                      />
                      
                      {/* Arco Memoria - Verde */}
                      <circle
                        cx="60"
                        cy="60"
                        r="50"
                        fill="none"
                        stroke="#4CAF50"
                        strokeWidth="8"
                        strokeDasharray={`${2 * Math.PI * 50 * 0.8}`}
                        strokeDashoffset={`${2 * Math.PI * 50 * (0.655 + 0.7)}`}
                        transform="rotate(-90 60 60)"
                        strokeLinecap="round"
                      />
                      
                      {/* Testo centrale */}
                      <text
                        x="60"
                        y="55"
                        fontSize="14"
                        fontWeight="700"
                        fill="#1A1A1A"
                        textAnchor="middle"
                      >
                        Sistema
                      </text>
                      <text
                        x="60"
                        y="70"
                        fontSize="12"
                        fontWeight="500"
                        fill="#666666"
                        textAnchor="middle"
                      >
                        Attivo
                      </text>
                    </svg>
                  </Box>
                  
                  {/* Legenda */}
                  <Box sx={{ 
                    display: 'flex', 
                    flexWrap: 'wrap', 
                    justifyContent: 'center',
                    gap: 1,
                    mt: 2,
                    maxWidth: '100%',
                  }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <Box sx={{ 
                        width: 8, 
                        height: 8, 
                        borderRadius: '50%', 
                        backgroundColor: '#9C27B0' 
                      }} />
                      <Typography variant="caption" sx={{ fontSize: '0.7rem' }}>
                        CPU 65.5%
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <Box sx={{ 
                        width: 8, 
                        height: 8, 
                        borderRadius: '50%', 
                        backgroundColor: '#FF9800' 
                      }} />
                      <Typography variant="caption" sx={{ fontSize: '0.7rem' }}>
                        Storage 70%
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <Box sx={{ 
                        width: 8, 
                        height: 8, 
                        borderRadius: '50%', 
                        backgroundColor: '#4CAF50' 
                      }} />
                      <Typography variant="caption" sx={{ fontSize: '0.7rem' }}>
                        Memoria 80%
                      </Typography>
                    </Box>
                  </Box>
                </Box>

                <Typography variant="body2" color="textSecondary" sx={{ 
                  textAlign: 'center', 
                  fontSize: '0.75rem',
                  mt: 1,
                }}>
                  L'utilizzo giornaliero è buono
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Tabella Server Attivi */}
        <Card sx={{ 
          mt: 3,
          borderRadius: 3,
          boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
          backgroundColor: '#FFFFFF',
        }}>
          <CardContent sx={{ p: 3 }}>
            <Typography variant="h6" sx={{ 
              fontWeight: 600, 
              color: '#1A1A1A',
              mb: 3,
            }}>
              Server Attivi
            </Typography>
            
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow sx={{ backgroundColor: '#F5F5F5' }}>
                    <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>
                      Paese
                    </TableCell>
                    <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>
                      Nome Dominio
                    </TableCell>
                    <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>
                      Storage
                    </TableCell>
                    <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>
                      Stato Server
                    </TableCell>
                    <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>
                      Caricamento Pagina
                    </TableCell>
                    <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>
                      Report Documento
                    </TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {mockServers.map((server) => (
                    <TableRow key={server.id} hover>
                      <TableCell>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                          <Avatar sx={{ 
                            width: 24, 
                            height: 24, 
                            backgroundColor: '#F5F5F5',
                            color: '#666',
                          }}>
                            <Public sx={{ fontSize: 16 }} />
                          </Avatar>
                          {server.country}
                        </Box>
                      </TableCell>
                      <TableCell>
                        <Typography variant="body2" sx={{ color: '#9C27B0' }}>
                          {server.domain}
                        </Typography>
                      </TableCell>
                      <TableCell>{server.storage}</TableCell>
                      <TableCell>
                        <Chip
                          label={getStatusLabel(server.status)}
                          size="small"
                          sx={{
                            backgroundColor: getStatusColor(server.status),
                            color: '#FFFFFF',
                            fontWeight: 600,
                            borderRadius: 2,
                          }}
                        />
                      </TableCell>
                      <TableCell>{server.page_load}</TableCell>
                      <TableCell>
                        <Typography variant="body2" sx={{ color: '#666' }}>
                          {server.report}
                        </Typography>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
    </Box>
  );
};

export default MockupDashboard;
