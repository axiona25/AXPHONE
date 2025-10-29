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
  Alert,
  CircularProgress,
  Tooltip,
} from '@mui/material';
import {
  Edit,
  Delete,
  MoreVert,
  Add,
  Group,
  People,
  Refresh,
  Settings,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import api from '../../services/api';

interface Group {
  id: string;
  name: string;
  description: string;
  user_count: number;
  created_at: string;
  is_active: boolean;
}

interface GroupsTableProps {
  onGroupSelect: (group: Group) => void;
}

const GroupsTable: React.FC<GroupsTableProps> = ({ onGroupSelect }) => {
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [selectedGroup, setSelectedGroup] = useState<Group | null>(null);
  const [openDialog, setOpenDialog] = useState(false);
  const [dialogMode, setDialogMode] = useState<'create' | 'edit'>('create');
  const [formData, setFormData] = useState({
    name: '',
    description: '',
  });

  useEffect(() => {
    fetchGroups();
  }, []);

  const fetchGroups = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/groups-management/');
      setGroups(response.data.groups || []);
    } catch (err) {
      setError('Errore nel caricamento dei gruppi');
      console.error('Errore fetch gruppi:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>, group: Group) => {
    setAnchorEl(event.currentTarget);
    setSelectedGroup(group);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
    setSelectedGroup(null);
  };

  const handleEdit = () => {
    if (selectedGroup) {
      setFormData({
        name: selectedGroup.name,
        description: selectedGroup.description,
      });
      setDialogMode('edit');
      setOpenDialog(true);
    }
    handleMenuClose();
  };

  const handleManageMembers = () => {
    if (selectedGroup) {
      onGroupSelect(selectedGroup);
    }
    handleMenuClose();
  };

  const handleDelete = async () => {
    if (selectedGroup) {
      if (window.confirm(`Sei sicuro di voler eliminare il gruppo "${selectedGroup.name}"?`)) {
        try {
          await api.delete(`/groups/${selectedGroup.id}/delete-advanced/`);
          fetchGroups();
        } catch (err) {
          setError('Errore nell\'eliminazione del gruppo');
        }
      }
    }
    handleMenuClose();
  };

  const handleCreate = () => {
    setFormData({
      name: '',
      description: '',
    });
    setDialogMode('create');
    setOpenDialog(true);
  };

  const handleSave = async () => {
    try {
      if (dialogMode === 'create') {
        await api.post('/groups/create-advanced/', formData);
      } else if (selectedGroup) {
        await api.put(`/groups/${selectedGroup.id}/update/`, formData);
      }
      setOpenDialog(false);
      fetchGroups();
    } catch (err) {
      setError('Errore nel salvataggio del gruppo');
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
            <Group sx={{ color: securevoxColors.primary }} />
            <Box>
              <Box component="h3" sx={{ margin: 0, fontSize: '1.25rem', fontWeight: 600 }}>
                Gestione Gruppi
              </Box>
              <Box component="p" sx={{ margin: 0, color: securevoxColors.textSecondary, fontSize: '0.875rem' }}>
                {groups.length} gruppi totali
              </Box>
            </Box>
          </Box>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Tooltip title="Aggiorna">
              <IconButton onClick={fetchGroups} sx={{ color: securevoxColors.primary }}>
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
              Nuovo Gruppo
            </Button>
          </Box>
        </Box>
      </Paper>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow sx={{ backgroundColor: securevoxColors.surface }}>
              <TableCell sx={{ fontWeight: 600 }}>Icona</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Nome Gruppo</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Descrizione</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Numero Utenti</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Stato</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Data Creazione</TableCell>
              <TableCell sx={{ fontWeight: 600 }}>Azioni</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {groups.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((group) => (
              <TableRow key={group.id} hover>
                <TableCell>
                  <Avatar sx={{ backgroundColor: securevoxColors.secondary }}>
                    <Group />
                  </Avatar>
                </TableCell>
                <TableCell>
                  <Box sx={{ fontWeight: 600 }}>{group.name}</Box>
                </TableCell>
                <TableCell>{group.description || 'Nessuna descrizione'}</TableCell>
                <TableCell>
                  <Chip
                    icon={<People />}
                    label={group.user_count}
                    color="primary"
                    variant="outlined"
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  <Chip
                    label={group.is_active ? 'Attivo' : 'Disattivo'}
                    color={group.is_active ? 'success' : 'error'}
                    size="small"
                  />
                </TableCell>
                <TableCell>
                  {new Date(group.created_at).toLocaleDateString('it-IT')}
                </TableCell>
                <TableCell>
                  <IconButton
                    onClick={(e) => handleMenuOpen(e, group)}
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
          count={groups.length}
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
          Modifica Gruppo
        </MenuItem>
        <MenuItem onClick={handleManageMembers}>
          <Settings sx={{ mr: 1 }} />
          Gestisci Membri
        </MenuItem>
        <MenuItem onClick={handleDelete} sx={{ color: securevoxColors.error }}>
          <Delete sx={{ mr: 1 }} />
          Elimina Gruppo
        </MenuItem>
      </Menu>

      {/* Dialog Crea/Modifica */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {dialogMode === 'create' ? 'Crea Nuovo Gruppo' : 'Modifica Gruppo'}
        </DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
            <TextField
              label="Nome Gruppo"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              fullWidth
              required
            />
            <TextField
              label="Descrizione"
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              fullWidth
              multiline
              rows={3}
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

export default GroupsTable;
