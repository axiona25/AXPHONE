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
  FormControl,
  InputLabel,
  Select,
  Alert,
  CircularProgress,
  Tooltip,
  Checkbox,
} from '@mui/material';
import { User } from '../../types';
import {
  Edit,
  Delete,
  MoreVert,
  Add,
  Person,
  Group,
  Block,
  CheckCircle,
  Refresh,
  FilterList,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import api from '../../services/api';


interface UsersTableProps {
  onUserSelect: (users: User[]) => void;
  selectedUsers: User[];
}

const UsersTable: React.FC<UsersTableProps> = ({ onUserSelect, selectedUsers }) => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [openDialog, setOpenDialog] = useState(false);
  const [dialogMode, setDialogMode] = useState<'create' | 'edit'>('create');
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    full_name: '',
    password: '',
    is_active: true,
    is_staff: false,
    is_superuser: false,
  });

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/users-management/');
      setUsers(response.data.users || []);
    } catch (err) {
      setError('Errore nel caricamento degli utenti');
      console.error('Errore fetch utenti:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>, user: User) => {
    setAnchorEl(event.currentTarget);
    setSelectedUser(user);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
    setSelectedUser(null);
  };

  const handleEdit = () => {
    if (selectedUser) {
      setFormData({
        username: selectedUser.username,
        email: selectedUser.email,
        full_name: selectedUser.full_name,
        password: '',
        is_active: selectedUser.is_active,
        is_staff: selectedUser.is_staff,
        is_superuser: selectedUser.is_superuser,
      });
      setDialogMode('edit');
      setOpenDialog(true);
    }
    handleMenuClose();
  };

  const handleDelete = async () => {
    if (selectedUser) {
      if (window.confirm(`Sei sicuro di voler eliminare l'utente ${selectedUser.username}?`)) {
        try {
          await api.delete(`/users/${selectedUser.id}/delete/`);
          fetchUsers();
        } catch (err) {
          setError('Errore nell\'eliminazione dell\'utente');
        }
      }
    }
    handleMenuClose();
  };

  const handleToggleActive = async () => {
    if (selectedUser) {
      try {
        await api.put(`/users/${selectedUser.id}/update/`, {
          is_active: !selectedUser.is_active,
        });
        fetchUsers();
      } catch (err) {
        setError('Errore nell\'aggiornamento dell\'utente');
      }
    }
    handleMenuClose();
  };

  const handleCreate = () => {
    setFormData({
      username: '',
      email: '',
      full_name: '',
      password: '',
      is_active: true,
      is_staff: false,
      is_superuser: false,
    });
    setDialogMode('create');
    setOpenDialog(true);
  };

  const handleSave = async () => {
    try {
      if (dialogMode === 'create') {
        await api.post('/users/create/', formData);
      } else if (selectedUser) {
        await api.put(`/users/${selectedUser.id}/update/`, formData);
      }
      setOpenDialog(false);
      fetchUsers();
    } catch (err) {
      setError('Errore nel salvataggio dell\'utente');
    }
  };

  const handleSelectUser = (user: User, checked: boolean) => {
    if (checked) {
      onUserSelect([...selectedUsers, user]);
    } else {
      onUserSelect(selectedUsers.filter(u => u.id !== user.id));
    }
  };

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      onUserSelect([...users]);
    } else {
      onUserSelect([]);
    }
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

      <Paper sx={{ mb: 2 }}>
        <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Person sx={{ color: securevoxColors.primary }} />
            <Box>
              <Box component="h3" sx={{ margin: 0, fontSize: '1.25rem', fontWeight: 600 }}>
                Gestione Utenti
              </Box>
              <Box component="p" sx={{ margin: 0, color: securevoxColors.textSecondary, fontSize: '0.875rem' }}>
                {users.length} utenti totali
              </Box>
            </Box>
          </Box>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Tooltip title="Aggiorna">
              <IconButton onClick={fetchUsers} sx={{ color: securevoxColors.primary }}>
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
              Nuovo Utente
            </Button>
          </Box>
        </Box>
      </Paper>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow sx={{ backgroundColor: securevoxColors.surface }}>
              <TableCell padding="checkbox">
                <Checkbox
                  indeterminate={selectedUsers.length > 0 && selectedUsers.length < users.length}
                  checked={users.length > 0 && selectedUsers.length === users.length}
                  onChange={(e) => handleSelectAll(e.target.checked)}
                />
              </TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Avatar</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Username</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Email</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Nome Completo</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Ruolo</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Stato</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Ultimo Accesso</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Azioni</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {users.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((user) => (
              <TableRow key={user.id} hover>
                <TableCell padding="checkbox">
                  <Checkbox
                    checked={selectedUsers.some(u => u.id === user.id)}
                    onChange={(e) => handleSelectUser(user, e.target.checked)}
                  />
                </TableCell>
                <TableCell>
                  <Avatar sx={{ backgroundColor: securevoxColors.primary }}>
                    {user.full_name.charAt(0).toUpperCase()}
                  </Avatar>
                </TableCell>
                <TableCell>{user.username}</TableCell>
                <TableCell>{user.email}</TableCell>
                <TableCell>{user.full_name}</TableCell>
                <TableCell>
                  {user.is_superuser && (
                    <Chip label="Superuser" color="error" size="small" sx={{ mr: 0.5 }} />
                  )}
                  {user.is_staff && (
                    <Chip label="Staff" color="warning" size="small" />
                  )}
                </TableCell>
                <TableCell>
                  <Chip
                    icon={user.is_active ? <CheckCircle /> : <Block />}
                    label={user.is_active ? 'Attivo' : 'Disattivo'}
                    color={user.is_active ? 'success' : 'error'}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  {user.last_login ? new Date(user.last_login).toLocaleDateString('it-IT') : 'Mai'}
                </TableCell>
                <TableCell>
                  <IconButton
                    onClick={(e) => handleMenuOpen(e, user)}
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
          count={users.length}
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
        <MenuItem onClick={handleEdit}>
          <Edit sx={{ mr: 1 }} />
          Modifica
        </MenuItem>
        <MenuItem onClick={handleToggleActive}>
          {selectedUser?.is_active ? <Block sx={{ mr: 1 }} /> : <CheckCircle sx={{ mr: 1 }} />}
          {selectedUser?.is_active ? 'Disattiva' : 'Attiva'}
        </MenuItem>
        <MenuItem onClick={handleDelete} sx={{ color: securevoxColors.error }}>
          <Delete sx={{ mr: 1 }} />
          Elimina
        </MenuItem>
      </Menu>

      {/* Dialog Crea/Modifica */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {dialogMode === 'create' ? 'Crea Nuovo Utente' : 'Modifica Utente'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
            <TextField
              label="Username"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              fullWidth
              required
            />
            <TextField
              label="Email"
              type="email"
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              fullWidth
              required
            />
            <Box sx={{ display: 'flex', gap: 2 }}>
              <TextField
                label="Nome"
                value={formData.full_name}
                onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                fullWidth
              />
            </Box>
            <TextField
              label="Password"
              type="password"
              value={formData.password}
              onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              fullWidth
              required={dialogMode === 'create'}
            />
            <FormControl fullWidth>
              <InputLabel>Ruoli</InputLabel>
              <Select
                multiple
                value={[
                  ...(formData.is_active ? ['active'] : []),
                  ...(formData.is_staff ? ['staff'] : []),
                  ...(formData.is_superuser ? ['superuser'] : []),
                ]}
                onChange={(e) => {
                  const values = e.target.value as string[];
                  setFormData({
                    ...formData,
                    is_active: values.includes('active'),
                    is_staff: values.includes('staff'),
                    is_superuser: values.includes('superuser'),
                  });
                }}
              >
                <MenuItem value="active">Attivo</MenuItem>
                <MenuItem value="staff">Staff</MenuItem>
                <MenuItem value="superuser">Superuser</MenuItem>
              </Select>
            </FormControl>
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

export default UsersTable;
