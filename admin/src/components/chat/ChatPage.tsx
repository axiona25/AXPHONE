import React, { useState, useEffect } from 'react';
import {
  Box,
  Paper,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  CircularProgress,
  Chip,
  Avatar,
  IconButton,
  Tooltip,
  Badge,
  Menu,
  MenuItem,
  ListItemIcon,
  ListItemText,
} from '@mui/material';
import {
  LockOpen,
  CheckCircle,
  Cancel,
  Visibility,
  MoreVert,
  Lock,
  LockOpenOutlined,
  Delete,
  Block,
  LockReset,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import { ApiService } from '../../services/api';

interface Statistics {
  total_users_with_chats: number;
  total_chats: number;
  total_messages: number;
  total_notifications: number;
  messages_today: number;
  active_users_today: number;
  encrypted_messages: number;
  encryption_percentage: number;
}

interface User {
  id: number;
  username: string;
  email: string;
  full_name: string;
  first_name: string;
  last_name: string;
  date_joined: string;
  is_active: boolean;
  is_online: boolean;
  last_seen: string | null;
  total_chats: number;
  total_messages: number;
  e2e_enabled: boolean;
  e2e_has_key: boolean;
  e2e_force_disabled: boolean;
  avatar_url: string | null;
}

interface ResetPasswordDialogProps {
  open: boolean;
  user: User | null;
  onClose: () => void;
  onSuccess: (password: string) => void;
}

const ResetPasswordDialog: React.FC<ResetPasswordDialogProps> = ({ open, user, onClose, onSuccess }) => {
  const [newPassword, setNewPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleReset = async () => {
    if (!user) return;

    setLoading(true);
    setError('');

    try {
      const apiService = new ApiService();
      const response = await apiService.resetUserPassword(user.id, newPassword || undefined);
      onSuccess(response.new_password);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Errore nel reset della password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>
        Reset Password - {user?.full_name}
      </DialogTitle>
      <DialogContent>
        <Box sx={{ pt: 2 }}>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Lascia vuoto per generare una password casuale automatica
          </Typography>
          <TextField
            fullWidth
            label="Nuova Password"
            type="text"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            placeholder="Lascia vuoto per generare automaticamente"
          />
          {error && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {error}
            </Alert>
          )}
        </Box>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={loading}>
          Annulla
        </Button>
        <Button onClick={handleReset} variant="contained" disabled={loading}>
          {loading ? <CircularProgress size={24} /> : 'Reset Password'}
        </Button>
      </DialogActions>
    </Dialog>
  );
};

const ChatPage: React.FC<{ onViewUserChats: (userId: number) => void }> = ({ onViewUserChats }) => {
  const [statistics, setStatistics] = useState<Statistics | null>(null);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [resetDialog, setResetDialog] = useState<{ open: boolean; user: User | null }>({
    open: false,
    user: null,
  });
  const [successMessage, setSuccessMessage] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [menuAnchorEl, setMenuAnchorEl] = useState<null | HTMLElement>(null);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [deleteDialog, setDeleteDialog] = useState<{ open: boolean; user: User | null }>({
    open: false,
    user: null,
  });
  const [blockDialog, setBlockDialog] = useState<{ open: boolean; user: User | null }>({
    open: false,
    user: null,
  });

  // Helper per costruire URL completo dell'avatar
  const getFullAvatarUrl = (avatarUrl: string | null): string | undefined => {
    if (!avatarUrl) return undefined;
    if (avatarUrl.startsWith('http')) return avatarUrl;
    // Costruisci URL completo con il backend
    return `http://127.0.0.1:8001${avatarUrl}`;
  };

  // Helper per ottenere le iniziali NC (Nome Cognome)
  const getInitials = (user: User): string => {
    const firstName = user.first_name?.trim() || '';
    const lastName = user.last_name?.trim() || '';
    
    if (firstName && lastName) {
      return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
    }
    if (firstName) {
      return firstName.substring(0, 2).toUpperCase();
    }
    if (lastName) {
      return lastName.substring(0, 2).toUpperCase();
    }
    // Fallback: prime 2 lettere dello username
    return user.username.substring(0, 2).toUpperCase();
  };

  const loadData = async () => {
    setLoading(true);
    setError('');

    try {
      const apiService = new ApiService();
      const [statsData, usersData] = await Promise.all([
        apiService.getChatStatistics(),
        apiService.getUsersList(),
      ]);

      setStatistics(statsData);
      setUsers(usersData);
    } catch (err: any) {
      setError(err.message || 'Errore nel caricamento dei dati');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();

    // Ricarica dati ogni 10 secondi per statistiche in tempo reale
    const interval = setInterval(loadData, 10000);
    return () => clearInterval(interval);
  }, []);

  const handleResetPassword = (user: User) => {
    setResetDialog({ open: true, user });
  };

  const handleResetSuccess = (password: string) => {
    setNewPassword(password);
    setSuccessMessage(`Password resettata con successo! Nuova password: ${password}`);
    setTimeout(() => {
      setSuccessMessage('');
      setNewPassword('');
    }, 10000);
  };

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>, user: User) => {
    setMenuAnchorEl(event.currentTarget);
    setSelectedUser(user);
  };

  const handleMenuClose = () => {
    setMenuAnchorEl(null);
    setSelectedUser(null);
  };

  const handleBlockUser = async () => {
    if (!selectedUser) return;

    try {
      const apiService = new ApiService();
      if (selectedUser.is_active) {
        // Blocca l'utente
        await apiService.blockUser(selectedUser.id);
        setSuccessMessage(`✅ Utente ${selectedUser.full_name} bloccato con successo. Non potrà più accedere all'app.`);
      } else {
        // Sblocca l'utente
        await apiService.unblockUser(selectedUser.id);
        setSuccessMessage(`✅ Utente ${selectedUser.full_name} sbloccato con successo. Può di nuovo accedere all'app.`);
      }
      
      handleMenuClose();
      loadData(); // Ricarica la lista

      // Nascondi il messaggio dopo 10 secondi
      setTimeout(() => setSuccessMessage(''), 10000);
    } catch (err: any) {
      setError(err.message || 'Errore nel blocco/sblocco dell\'utente');
      handleMenuClose();
    }
  };

  const handleToggleE2E = async () => {
    if (!selectedUser) return;

    try {
      const apiService = new ApiService();
      const forceDisabled = !selectedUser.e2e_force_disabled;
      
      await apiService.toggleUserE2E(selectedUser.id, forceDisabled);
      
      if (forceDisabled) {
        setSuccessMessage(`🔓 Cifratura E2EE disabilitata per ${selectedUser.full_name}. I messaggi saranno in chiaro.`);
      } else {
        setSuccessMessage(`🔐 Cifratura E2EE abilitata per ${selectedUser.full_name}. I messaggi saranno cifrati.`);
      }
      
      handleMenuClose();
      loadData(); // Ricarica la lista

      // Nascondi il messaggio dopo 10 secondi
      setTimeout(() => setSuccessMessage(''), 10000);
    } catch (err: any) {
      setError(err.message || 'Errore nel toggle E2EE');
      handleMenuClose();
    }
  };

  const handleDeleteUser = async () => {
    if (!deleteDialog.user) return;

    try {
      const apiService = new ApiService();
      await apiService.deleteUser(deleteDialog.user.id);
      setSuccessMessage(`✅ Utente ${deleteDialog.user.full_name} eliminato definitivamente dal sistema.`);
      
      setDeleteDialog({ open: false, user: null });
      loadData(); // Ricarica la lista

      // Nascondi il messaggio dopo 10 secondi
      setTimeout(() => setSuccessMessage(''), 10000);
    } catch (err: any) {
      setError(err.message || 'Errore nell\'eliminazione dell\'utente');
      setDeleteDialog({ open: false, user: null });
    }
  };

  if (loading && !statistics) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '50vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ backgroundColor: '#F5F5F5', minHeight: '100vh', p: 3 }}>
      {/* Success Message */}
      {successMessage && (
        <Alert severity="success" sx={{ mb: 3 }}>
          {successMessage}
        </Alert>
      )}

      {/* Error Message */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {/* Statistics Cards */}
      {statistics && (
        <Box sx={{ display: 'flex', gap: 3, mb: 3, flexWrap: 'wrap' }}>
          {/* Utenti in Chat */}
          <Box sx={{ flex: '1 1 calc(25% - 24px)', minWidth: '220px' }}>
            <Paper
              sx={{
                p: 2.5,
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
                height: '100%',
              }}
            >
              <Typography variant="body2" color="textSecondary" sx={{ mb: 0.5, fontSize: '0.85rem' }}>
                Utenti in Chat
              </Typography>
              <Typography variant="h4" sx={{ 
                fontWeight: 700, 
                color: '#1A1A1A',
                fontSize: '1.75rem',
              }}>
                {statistics.total_users_with_chats}
              </Typography>
              <Typography variant="caption" color="textSecondary" sx={{ display: 'block', mt: 0.5, fontSize: '0.7rem' }}>
                {statistics.active_users_today} attivi oggi
              </Typography>
            </Paper>
          </Box>

          {/* Chat Aperte */}
          <Box sx={{ flex: '1 1 calc(25% - 24px)', minWidth: '220px' }}>
            <Paper
              sx={{
                p: 2.5,
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
                height: '100%',
              }}
            >
              <Typography variant="body2" color="textSecondary" sx={{ mb: 0.5, fontSize: '0.85rem' }}>
                Chat Aperte
              </Typography>
              <Typography variant="h4" sx={{ 
                fontWeight: 700, 
                color: '#1A1A1A',
                fontSize: '1.75rem',
              }}>
                {statistics.total_chats}
              </Typography>
            </Paper>
          </Box>

          {/* Messaggi Creati */}
          <Box sx={{ flex: '1 1 calc(25% - 24px)', minWidth: '220px' }}>
            <Paper
              sx={{
                p: 2.5,
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
                height: '100%',
              }}
            >
              <Typography variant="body2" color="textSecondary" sx={{ mb: 0.5, fontSize: '0.85rem' }}>
                Messaggi Creati
              </Typography>
              <Typography variant="h4" sx={{ 
                fontWeight: 700, 
                color: '#1A1A1A',
                fontSize: '1.75rem',
              }}>
                {statistics.total_messages}
              </Typography>
              <Typography variant="caption" color="textSecondary" sx={{ display: 'block', mt: 0.5, fontSize: '0.7rem' }}>
                {statistics.messages_today} oggi • 🔐 {statistics.encryption_percentage}% cifrati
              </Typography>
            </Paper>
          </Box>

          {/* Notifiche Create */}
          <Box sx={{ flex: '1 1 calc(25% - 24px)', minWidth: '220px' }}>
            <Paper
              sx={{
                p: 2.5,
                borderRadius: 3,
                boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
                backgroundColor: '#FFFFFF',
                height: '100%',
              }}
            >
              <Typography variant="body2" color="textSecondary" sx={{ mb: 0.5, fontSize: '0.85rem' }}>
                Notifiche Create
              </Typography>
              <Typography variant="h4" sx={{ 
                fontWeight: 700, 
                color: '#1A1A1A',
                fontSize: '1.75rem',
              }}>
                {statistics.total_notifications}
              </Typography>
            </Paper>
          </Box>
        </Box>
      )}

      {/* Users Table */}
      <Paper sx={{ 
        borderRadius: 3, 
        overflow: 'hidden',
        boxShadow: '0 4px 16px rgba(0, 0, 0, 0.1)',
        backgroundColor: '#FFFFFF',
      }}>
        <Box sx={{ p: 3, borderBottom: '1px solid #e0e0e0' }}>
          <Typography variant="h6" sx={{ fontWeight: 600, color: '#1A1A1A' }}>
            Utenti del Sistema
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Clicca su un utente per vedere le sue chat e messaggi
          </Typography>
        </Box>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow sx={{ backgroundColor: '#F5F5F5' }}>
                <TableCell></TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Nome</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Cognome</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Email</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Chat</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Messaggi</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Stato</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Cifratura</TableCell>
                <TableCell sx={{ fontWeight: 600, color: '#1A1A1A' }}>Azioni</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {users.map((user) => (
                <TableRow
                  key={user.id}
                  hover
                  sx={{
                    cursor: 'pointer',
                    '&:hover': { backgroundColor: '#f9f9f9' },
                  }}
                >
                  <TableCell>
                    <Badge
                      overlap="circular"
                      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                      variant="dot"
                      sx={{
                        '& .MuiBadge-badge': {
                          backgroundColor: user.is_online ? '#44b700' : '#9e9e9e',
                          color: user.is_online ? '#44b700' : '#9e9e9e',
                          boxShadow: '0 0 0 2px #fff',
                          width: 12,
                          height: 12,
                          borderRadius: '50%',
                          '&::after': user.is_online ? {
                            position: 'absolute',
                            top: 0,
                            left: 0,
                            width: '100%',
                            height: '100%',
                            borderRadius: '50%',
                            animation: 'ripple 1.2s infinite ease-in-out',
                            border: '1px solid currentColor',
                            content: '""',
                          } : {},
                        },
                        '@keyframes ripple': {
                          '0%': {
                            transform: 'scale(.8)',
                            opacity: 1,
                          },
                          '100%': {
                            transform: 'scale(2.4)',
                            opacity: 0,
                          },
                        },
                      }}
                    >
                      <Avatar
                        src={getFullAvatarUrl(user.avatar_url)}
                        sx={{ bgcolor: securevoxColors.primary, width: 40, height: 40 }}
                      >
                        {getInitials(user)}
                      </Avatar>
                    </Badge>
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                      {user.first_name || user.username}
                    </Typography>
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    <Typography variant="body2">
                      {user.last_name || '-'}
                    </Typography>
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      {user.email}
                    </Typography>
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    <Chip label={user.total_chats} size="small" sx={{ borderRadius: 2 }} />
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    <Chip label={user.total_messages} size="small" sx={{ borderRadius: 2 }} />
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    <Box>
                      {user.is_online ? (
                        <Chip 
                          label="Online" 
                          size="small" 
                          sx={{ 
                            bgcolor: '#e8f5e9', 
                            color: '#2e7d32',
                            fontWeight: 600,
                            borderRadius: 2,
                          }} 
                        />
                      ) : (
                        <Chip 
                          label={user.last_seen ? new Date(user.last_seen).toLocaleString('it-IT', {
                            day: '2-digit',
                            month: '2-digit',
                            year: '2-digit',
                            hour: '2-digit',
                            minute: '2-digit',
                          }) : 'Offline'}
                          size="small" 
                          sx={{ bgcolor: '#f5f5f5', color: '#757575', borderRadius: 2 }} 
                        />
                      )}
                    </Box>
                  </TableCell>
                  <TableCell onClick={() => onViewUserChats(user.id)}>
                    {user.e2e_force_disabled ? (
                      <Tooltip title="⛔ E2EE Disabilitato dall'Admin">
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                          <LockOpenOutlined sx={{ color: securevoxColors.error, fontSize: 20 }} />
                          <Typography variant="caption" sx={{ color: securevoxColors.error, fontSize: '0.65rem' }}>
                            Admin
                          </Typography>
                        </Box>
                      </Tooltip>
                    ) : user.e2e_enabled && user.e2e_has_key ? (
                      <Tooltip title="🔐 Cifratura E2EE Attiva">
                        <Lock sx={{ color: securevoxColors.success, fontSize: 20 }} />
                      </Tooltip>
                    ) : (
                      <Tooltip title="⚠️ E2EE Non Configurato (nessuna chiave pubblica)">
                        <LockOpenOutlined sx={{ color: '#f57c00', fontSize: 20 }} />
                      </Tooltip>
                    )}
                  </TableCell>
                  <TableCell>
                    <IconButton
                      size="small"
                      onClick={(e) => handleMenuOpen(e, user)}
                    >
                      <MoreVert />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Actions Menu */}
      <Menu
        anchorEl={menuAnchorEl}
        open={Boolean(menuAnchorEl)}
        onClose={handleMenuClose}
        anchorOrigin={{
          vertical: 'bottom',
          horizontal: 'right',
        }}
        transformOrigin={{
          vertical: 'top',
          horizontal: 'right',
        }}
      >
        <MenuItem onClick={() => {
          if (selectedUser) onViewUserChats(selectedUser.id);
          handleMenuClose();
        }}>
          <ListItemIcon>
            <Visibility fontSize="small" />
          </ListItemIcon>
          <ListItemText primary="Visualizza Chat" />
        </MenuItem>

        <MenuItem 
          onClick={() => {
            handleMenuClose();
            if (selectedUser) {
              setResetDialog({ open: true, user: selectedUser });
            }
          }}
        >
          <ListItemIcon>
            <LockReset fontSize="small" color="primary" />
          </ListItemIcon>
          <ListItemText primary="Reset Password" />
        </MenuItem>

        <MenuItem 
          onClick={() => {
            handleToggleE2E();
          }}
          sx={{
            color: selectedUser?.e2e_force_disabled ? securevoxColors.success : securevoxColors.warning,
          }}
        >
          <ListItemIcon>
            {selectedUser?.e2e_force_disabled ? (
              <Lock fontSize="small" sx={{ color: securevoxColors.success }} />
            ) : (
              <LockOpenOutlined fontSize="small" sx={{ color: securevoxColors.warning }} />
            )}
          </ListItemIcon>
          <ListItemText 
            primary={selectedUser?.e2e_force_disabled ? "Abilita E2EE" : "Disabilita E2EE"}
          />
        </MenuItem>

        <MenuItem 
          onClick={() => {
            handleBlockUser();
          }}
          sx={{
            color: selectedUser?.is_active ? securevoxColors.warning : securevoxColors.success,
          }}
        >
          <ListItemIcon>
            {selectedUser?.is_active ? (
              <Block fontSize="small" sx={{ color: securevoxColors.warning }} />
            ) : (
              <LockOpen fontSize="small" sx={{ color: securevoxColors.success }} />
            )}
          </ListItemIcon>
          <ListItemText 
            primary={selectedUser?.is_active ? "Blocca Utente" : "Sblocca Utente"}
          />
        </MenuItem>

        <MenuItem 
          onClick={() => {
            handleMenuClose();
            if (selectedUser) {
              setDeleteDialog({ open: true, user: selectedUser });
            }
          }}
          sx={{ color: securevoxColors.error }}
        >
          <ListItemIcon>
            <Delete fontSize="small" color="error" />
          </ListItemIcon>
          <ListItemText primary="Elimina Utente" />
        </MenuItem>
      </Menu>

      {/* Reset Password Dialog */}
      <ResetPasswordDialog
        open={resetDialog.open}
        user={resetDialog.user}
        onClose={() => setResetDialog({ open: false, user: null })}
        onSuccess={handleResetSuccess}
      />

      {/* Delete User Confirmation Dialog */}
      <Dialog 
        open={deleteDialog.open} 
        onClose={() => setDeleteDialog({ open: false, user: null })}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle sx={{ color: securevoxColors.error }}>
          ⚠️ Conferma Eliminazione Utente
        </DialogTitle>
        <DialogContent>
          <Typography variant="body1" sx={{ mb: 2 }}>
            Sei sicuro di voler eliminare definitivamente l'utente <strong>{deleteDialog.user?.full_name}</strong>?
          </Typography>
          <Alert severity="error" sx={{ mb: 2 }}>
            <Typography variant="body2" sx={{ fontWeight: 600, mb: 1 }}>
              ⚠️ ATTENZIONE: Questa azione è irreversibile!
            </Typography>
            <Typography variant="body2">
              Verranno eliminati permanentemente:
            </Typography>
            <Box component="ul" sx={{ mt: 1, mb: 0 }}>
              <li>Account utente e credenziali</li>
              <li>Tutte le chat create dall'utente</li>
              <li>Tutti i messaggi inviati</li>
              <li>Profilo e impostazioni</li>
              <li>Token di accesso e sessioni</li>
            </Box>
          </Alert>
          <Typography variant="body2" color="text.secondary">
            Email: {deleteDialog.user?.email}
          </Typography>
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button 
            onClick={() => setDeleteDialog({ open: false, user: null })} 
            variant="outlined"
          >
            Annulla
          </Button>
          <Button 
            onClick={handleDeleteUser} 
            variant="contained" 
            color="error"
            startIcon={<Delete />}
          >
            Elimina Definitivamente
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default ChatPage;

