import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  Box,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Avatar,
  Chip,
  IconButton,
  Alert,
  CircularProgress,
  Divider,
} from '@mui/material';
import {
  PersonRemove,
  Group,
  Close,
  Refresh,
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

interface GroupMembersDialogProps {
  open: boolean;
  onClose: () => void;
  group: Group | null;
}

const GroupMembersDialog: React.FC<GroupMembersDialogProps> = ({ open, onClose, group }) => {
  const [members, setMembers] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open && group) {
      fetchGroupMembers();
    }
  }, [open, group]);

  const fetchGroupMembers = async () => {
    if (!group) return;
    
    try {
      setLoading(true);
      setError(null);
      const response = await api.get(`/groups/${group.id}/members/`);
      setMembers(response.data.members || []);
    } catch (err) {
      setError('Errore nel caricamento dei membri del gruppo');
      console.error('Errore fetch membri:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveMember = async (userId: number) => {
    if (!group) return;
    
    try {
      await api.post(`/groups/${group.id}/remove-users/`, {
        user_ids: [userId],
      });
      fetchGroupMembers();
    } catch (err) {
      setError('Errore nella rimozione del membro dal gruppo');
      console.error('Errore rimozione:', err);
    }
  };

  if (!group) return null;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Group sx={{ color: securevoxColors.primary }} />
            <Box>
              <Typography variant="h6">
                Membri del Gruppo: {group.name}
              </Typography>
              <Typography variant="body2" color="textSecondary">
                {group.description || 'Nessuna descrizione'}
              </Typography>
            </Box>
          </Box>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <IconButton onClick={fetchGroupMembers} size="small">
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

        <Box sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 2 }}>
          <Chip
            label={`${members.length} membri`}
            color="primary"
            variant="outlined"
          />
          <Typography variant="body2" color="textSecondary">
            Creato il {new Date(group.created_at).toLocaleDateString('it-IT')}
          </Typography>
        </Box>

        <Divider sx={{ my: 2 }} />

        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
            <CircularProgress sx={{ color: securevoxColors.primary }} />
          </Box>
        ) : (
          <TableContainer component={Paper}>
            <Table>
              <TableHead>
                <TableRow sx={{ backgroundColor: securevoxColors.surface }}>
                  <TableCell sx={{ fontWeight: 600 }}>Avatar</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Nome</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Username</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Email</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Stato</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Ultimo Accesso</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Azioni</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {members.map((member) => (
                  <TableRow key={member.id} hover>
                    <TableCell>
                      <Avatar sx={{ backgroundColor: securevoxColors.primary }}>
                        {member.full_name.charAt(0).toUpperCase()}
                      </Avatar>
                    </TableCell>
                    <TableCell>
                      {member.full_name}
                    </TableCell>
                    <TableCell>{member.username}</TableCell>
                    <TableCell>{member.email}</TableCell>
                    <TableCell>
                      <Chip
                        label={member.is_active ? 'Attivo' : 'Disattivo'}
                        color={member.is_active ? 'success' : 'error'}
                        size="small"
                      />
                    </TableCell>
                    <TableCell>
                      {member.last_login ? new Date(member.last_login).toLocaleDateString('it-IT') : 'Mai'}
                    </TableCell>
                    <TableCell>
                      <IconButton
                        onClick={() => handleRemoveMember(member.id)}
                        sx={{ color: securevoxColors.error }}
                        size="small"
                      >
                        <PersonRemove />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}

        {members.length === 0 && !loading && (
          <Alert severity="info">
            Nessun membro in questo gruppo.
          </Alert>
        )}

        <Box sx={{ mt: 3, p: 2, backgroundColor: securevoxColors.surface, borderRadius: 1 }}>
          <Typography variant="body2" color="textSecondary">
            <strong>Importante:</strong> I membri di questo gruppo possono comunicare solo tra loro. 
            Le chat e le chiamate sono limitate all'interno del gruppo per garantire la privacy e la sicurezza.
          </Typography>
        </Box>
      </DialogContent>
      
      <DialogActions>
        <Button onClick={onClose}>
          Chiudi
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default GroupMembersDialog;
