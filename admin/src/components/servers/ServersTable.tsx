import React, { useState, useEffect } from 'react';
import {
  Box,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
  IconButton,
  Button,
  Chip,
  Avatar,
  Menu,
  MenuItem,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  LinearProgress,
  Alert,
  CircularProgress,
  Tooltip,
  Grid,
  Card,
  CardContent,
  Typography,
} from '@mui/material';
import {
  Edit,
  Delete,
  MoreVert,
  Add,
  Computer,
  Terminal,
  Visibility,
  Warning,
  CheckCircle,
  Error,
  Refresh,
  Storage,
  Memory,
  Speed,
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

interface ServersTableProps {
  onServerSelect: (server: Server) => void;
}

const ServersTable: React.FC<ServersTableProps> = ({ onServerSelect }) => {
  const [servers, setServers] = useState<Server[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [selectedServer, setSelectedServer] = useState<Server | null>(null);
  const [openDialog, setOpenDialog] = useState(false);
  const [dialogMode, setDialogMode] = useState<'create' | 'edit'>('create');
  const [formData, setFormData] = useState({
    name: '',
    ip_address: '',
    port: 22,
    size: '',
    technology: '',
    vertical_function: '',
  });

  useEffect(() => {
    fetchServers();
    // Polling ogni 30 secondi per aggiornamenti real-time
    const interval = setInterval(fetchServers, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchServers = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/servers-management/');
      setServers(response.data.servers || []);
    } catch (err) {
      setError('Errore nel caricamento dei server');
      console.error('Errore fetch server:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>, server: Server) => {
    setAnchorEl(event.currentTarget);
    setSelectedServer(server);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
    setSelectedServer(null);
  };

  const handleViewDetails = () => {
    if (selectedServer) {
      onServerSelect(selectedServer);
    }
    handleMenuClose();
  };

  const handleTerminal = () => {
    if (selectedServer) {
      // Apri terminale dedicato
      window.open(`/admin/terminal/${selectedServer.id}/`, '_blank');
    }
    handleMenuClose();
  };

  const handleEdit = () => {
    if (selectedServer) {
      setFormData({
        name: selectedServer.name,
        ip_address: selectedServer.ip_address,
        port: selectedServer.port,
        size: selectedServer.size,
        technology: selectedServer.technology,
        vertical_function: selectedServer.vertical_function,
      });
      setDialogMode('edit');
      setOpenDialog(true);
    }
    handleMenuClose();
  };

  const handleDelete = async () => {
    if (selectedServer) {
      if (window.confirm(`Sei sicuro di voler eliminare il server "${selectedServer.name}"?`)) {
        try {
          await api.delete(`/servers/${selectedServer.id}/delete/`);
          fetchServers();
        } catch (err) {
          setError('Errore nell\'eliminazione del server');
        }
      }
    }
    handleMenuClose();
  };

  const handleCreate = () => {
    setFormData({
      name: '',
      ip_address: '',
      port: 22,
      size: '',
      technology: '',
      vertical_function: '',
    });
    setDialogMode('create');
    setOpenDialog(true);
  };

  const handleSave = async () => {
    try {
      if (dialogMode === 'create') {
        await api.post('/servers/create/', formData);
      } else if (selectedServer) {
        await api.put(`/servers/${selectedServer.id}/update/`, formData);
      }
      setOpenDialog(false);
      fetchServers();
    } catch (err) {
      setError('Errore nel salvataggio del server');
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

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
        <CircularProgress sx={{ color: securevoxColors.primary }} />
      </Box>
    );
  }

  return (
    <Box>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      {/* Statistiche Server */}
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Computer sx={{ color: securevoxColors.primary }} />
                <Box>
                  <Typography variant="h6">{servers.length}</Typography>
                  <Typography variant="body2" color="textSecondary">
                    Server Totali
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <CheckCircle sx={{ color: securevoxColors.success }} />
                <Box>
                  <Typography variant="h6">
                    {servers.filter(s => s.status === 'active').length}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Server Attivi
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Error sx={{ color: securevoxColors.error }} />
                <Box>
                  <Typography variant="h6">
                    {servers.filter(s => s.status === 'inactive').length}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Server Inattivi
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Warning sx={{ color: securevoxColors.warning }} />
                <Box>
                  <Typography variant="h6">
                    {servers.reduce((sum, s) => sum + s.alerts, 0)}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Allerte Totali
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Paper sx={{ mb: 2 }}>
        <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Computer sx={{ color: securevoxColors.primary }} />
            <Box>
              <Box component="h3" sx={{ margin: 0, fontSize: '1.25rem', fontWeight: 600 }}>
                Gestione Server
              </Box>
              <Box component="p" sx={{ margin: 0, color: securevoxColors.textSecondary, fontSize: '0.875rem' }}>
                Monitoraggio e gestione dei server AXPHONE
              </Box>
            </Box>
          </Box>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Tooltip title="Aggiorna">
              <IconButton onClick={fetchServers} sx={{ color: securevoxColors.primary }}>
                <Refresh />
              </IconButton>
            </Tooltip>
            <Button
              variant="contained"
              startIcon={<Add />}
              onClick={handleCreate}
              sx={{
                backgroundColor: securevoxColors.primary,
                '&:hover': { backgroundColor: securevoxColors.secondary },
              }}
            >
              Nuovo Server
            </Button>
          </Box>
        </Box>
      </Paper>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow sx={{ backgroundColor: securevoxColors.surface }}>
              <TableCell sx={{ fontWeight: 600 }}>Server</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Indirizzo</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Dimensioni</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Tecnologia</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Funzione</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Stato</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Allerte</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Utilizzo</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Ultimo Accesso</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Azioni</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {servers.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((server) => (
              <TableRow key={server.id} hover>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <Avatar sx={{ backgroundColor: securevoxColors.primary }}>
                      <Computer />
                    </Avatar>
                    <Box>
                      <Box sx={{ fontWeight: 600 }}>{server.name}</Box>
                      <Box sx={{ fontSize: '0.75rem', color: securevoxColors.textSecondary }}>
                        ID: {server.id}
                      </Box>
                    </Box>
                  </Box>
                </TableCell>
                <TableCell>
                  <Box>
                    <Box sx={{ fontWeight: 500 }}>{server.ip_address}</Box>
                    <Box sx={{ fontSize: '0.75rem', color: securevoxColors.textSecondary }}>
                      Porta: {server.port}
                    </Box>
                  </Box>
                </TableCell>
                <TableCell>
                  <Chip label={server.size} variant="outlined" size="small" />
                </TableCell>
                <TableCell>{server.technology}</TableCell>
                <TableCell>{server.vertical_function}</TableCell>
                <TableCell>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    {getStatusIcon(server.status)}
                    <Chip
                      label={server.status}
                      color={getStatusColor(server.status) as any}
                      size="small"
                    />
                  </Box>
                </TableCell>
                <TableCell>
                  {server.alerts > 0 ? (
                    <Chip
                      icon={<Warning />}
                      label={server.alerts}
                      color="error"
                      size="small"
                    />
                  ) : (
                    <Chip label="Nessuna" color="success" size="small" />
                  )}
                </TableCell>
                <TableCell>
                  <Box sx={{ minWidth: 100 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.5 }}>
                      <Storage sx={{ fontSize: 12, color: securevoxColors.textSecondary }} />
                      <Typography variant="caption">{server.cpu_usage}%</Typography>
                    </Box>
                    <LinearProgress
                      variant="determinate"
                      value={server.cpu_usage}
                      sx={{
                        height: 4,
                        borderRadius: 2,
                        backgroundColor: securevoxColors.surface,
                        '& .MuiLinearProgress-bar': {
                          backgroundColor: getUsageColor(server.cpu_usage),
                        },
                      }}
                    />
                  </Box>
                </TableCell>
                <TableCell>
                  {new Date(server.last_seen).toLocaleDateString('it-IT')}
                </TableCell>
                <TableCell>
                  <IconButton
                    onClick={(e) => handleMenuOpen(e, server)}
                    sx={{ color: securevoxColors.textSecondary }}
                  >
                    <MoreVert />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <TablePagination
          rowsPerPageOptions={[5, 10, 25]}
          component="div"
          count={servers.length}
          rowsPerPage={rowsPerPage}
          page={page}
          onPageChange={(_, newPage) => setPage(newPage)}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            setPage(0);
          }}
        />
      </TableContainer>

      {/* Menu Azioni */}
      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleMenuClose}
      >
        <MenuItem onClick={handleViewDetails}>
          <Visibility sx={{ mr: 1 }} />
          Visualizza Dettagli
        </MenuItem>
        <MenuItem onClick={handleTerminal}>
          <Terminal sx={{ mr: 1 }} />
          Terminale Dedicato
        </MenuItem>
        <MenuItem onClick={handleEdit}>
          <Edit sx={{ mr: 1 }} />
          Modifica Server
        </MenuItem>
        <MenuItem onClick={handleDelete} sx={{ color: securevoxColors.error }}>
          <Delete sx={{ mr: 1 }} />
          Elimina Server
        </MenuItem>
      </Menu>

      {/* Dialog Crea/Modifica */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {dialogMode === 'create' ? 'Aggiungi Nuovo Server' : 'Modifica Server'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
            <TextField
              label="Nome Server"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              fullWidth
              required
            />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                label="Indirizzo IP"
                value={formData.ip_address}
                onChange={(e) => setFormData({ ...formData, ip_address: e.target.value })}
                fullWidth
                required
              />
              <TextField
                label="Porta"
                type="number"
                value={formData.port}
                onChange={(e) => setFormData({ ...formData, port: parseInt(e.target.value) })}
                fullWidth
                required
              />
            </Box>
            <TextField
              label="Dimensioni"
              value={formData.size}
              onChange={(e) => setFormData({ ...formData, size: e.target.value })}
              fullWidth
              placeholder="es. Small, Medium, Large"
            />
            <TextField
              label="Tecnologia"
              value={formData.technology}
              onChange={(e) => setFormData({ ...formData, technology: e.target.value })}
              fullWidth
              placeholder="es. Ubuntu 20.04, CentOS 8"
            />
            <TextField
              label="Funzione Verticale"
              value={formData.vertical_function}
              onChange={(e) => setFormData({ ...formData, vertical_function: e.target.value })}
              fullWidth
              placeholder="es. Web Server, Database, API Gateway"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>Annulla</Button>
          <Button
            onClick={handleSave}
            variant="contained"
            sx={{ backgroundColor: securevoxColors.primary }}
          >
            Salva
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default ServersTable;
