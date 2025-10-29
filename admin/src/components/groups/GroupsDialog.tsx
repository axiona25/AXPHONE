import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction,
  IconButton,
  Checkbox,
  Chip,
  Alert,
  CircularProgress,
  Divider,
} from '@mui/material';
import {
  PersonAdd,
  PersonRemove,
  Group,
  Close,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import { User } from '../../types';
import api from '../../services/api';


interface Group {
  id: string;
  name: string;
  description: string;
  user_count: number;
  created_at: string;
  is_active: boolean;
}

interface GroupsDialogProps {
  open: boolean;
  onClose: () => void;
  selectedUsers: User[];
}

const GroupsDialog: React.FC<GroupsDialogProps> = ({ open, onClose, selectedUsers }) => {
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (open) {
      fetchGroups();
    }
  }, [open]);

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

  const handleAssignToGroup = async (groupId: string) => {
    try {
      setSaving(true);
      const userIds = selectedUsers.map(user => user.id);
      
      await api.post(`/groups/${groupId}/assign-users/`, {
        user_ids: userIds,
      });
      
      // Aggiorna la lista dei gruppi
      fetchGroups();
    } catch (err) {
      setError('Errore nell\'assegnazione degli utenti al gruppo');
      console.error('Errore assegnazione:', err);
    } finally {
      setSaving(false);
    }
  };

  const handleRemoveFromGroup = async (groupId: string) => {
    try {
      setSaving(true);
      const userIds = selectedUsers.map(user => user.id);
      
      await api.post(`/groups/${groupId}/remove-users/`, {
        user_ids: userIds,
      });
      
      // Aggiorna la lista dei gruppi
      fetchGroups();
    } catch (err) {
      setError('Errore nella rimozione degli utenti dal gruppo');
      console.error('Errore rimozione:', err);
    } finally {
      setSaving(false);
    }
  };

  const isUserInGroup = (groupId: string) => {
    return selectedUsers.some(user => user.groups && user.groups.some(group => group.id === groupId));
  };

  const canAssignToGroup = (groupId: string) => {
    // Verifica se almeno un utente selezionato non è già nel gruppo
    return selectedUsers.some(user => !user.groups || !user.groups.some(group => group.id === groupId));
  };

  const canRemoveFromGroup = (groupId: string) => {
    // Verifica se almeno un utente selezionato è nel gruppo
    return selectedUsers.some(user => user.groups && user.groups.some(group => group.id === groupId));
  };

  if (loading) {
    return (
      <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
        <DialogContent>
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
            <CircularProgress sx={{ color: securevoxColors.primary }} />
          </Box>
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Group sx={{ color: securevoxColors.primary }} />
            <Typography variant="h6">
              Assegna Utenti ai Gruppi
            </Typography>
          </Box>
          <IconButton onClick={onClose} size="small">
            <Close />
          </IconButton>
        </Box>
      </DialogTitle>
      
      <DialogContent>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        <Box sx={{ mb: 3 }}>
          <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
            Utenti Selezionati ({selectedUsers.length})
          </Typography>
          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
            {selectedUsers.map((user) => (
              <Chip
                key={user.id}
                label={`${user.full_name} (${user.username})`}
                variant="outlined"
                size="small"
              />
            ))}
          </Box>
        </Box>

        <Divider sx={{ my: 2 }} />

        <Box>
          <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2 }}>
            Gruppi Disponibili
          </Typography>
          
          {groups.length === 0 ? (
            <Alert severity="info">
              Nessun gruppo disponibile. Crea prima dei gruppi per poter assegnare gli utenti.
            </Alert>
          ) : (
            <List>
              {groups.map((group) => (
                <ListItem key={group.id} sx={{ border: 1, borderColor: 'divider', borderRadius: 1, mb: 1 }}>
                  <ListItemText
                    primary={
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                          {group.name}
                        </Typography>
                        <Chip
                          label={`${group.user_count} utenti`}
                          size="small"
                          variant="outlined"
                        />
                      </Box>
                    }
                    secondary={
                      <Typography variant="body2" color="textSecondary">
                        {group.description || 'Nessuna descrizione'}
                      </Typography>
                    }
                  />
                  <ListItemSecondaryAction>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                      {canAssignToGroup(group.id) && (
                        <Button
                          size="small"
                          startIcon={<PersonAdd />}
                          onClick={() => handleAssignToGroup(group.id)}
                          disabled={saving}
                          sx={{ color: securevoxColors.primary }}
                        >
                          Aggiungi
                        </Button>
                      )}
                      {canRemoveFromGroup(group.id) && (
                        <Button
                          size="small"
                          startIcon={<PersonRemove />}
                          onClick={() => handleRemoveFromGroup(group.id)}
                          disabled={saving}
                          color="error"
                        >
                          Rimuovi
                        </Button>
                      )}
                    </Box>
                  </ListItemSecondaryAction>
                </ListItem>
              ))}
            </List>
          )}
        </Box>

        <Box sx={{ mt: 3, p: 2, backgroundColor: securevoxColors.surface, borderRadius: 1 }}>
          <Typography variant="body2" color="textSecondary">
            <strong>Nota:</strong> Gli utenti assegnati a un gruppo potranno vedere e comunicare solo con gli altri membri dello stesso gruppo. 
            Le chat e le chiamate sono limitate all'interno del gruppo.
          </Typography>
        </Box>
      </DialogContent>
      
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>
          Chiudi
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default GroupsDialog;
