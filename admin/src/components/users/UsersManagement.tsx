import React, { useState } from 'react';
import { Box, Paper, Typography, Chip, Button, Menu, MenuItem, IconButton } from '@mui/material';
import { Group, MoreVert, AssignmentInd } from '@mui/icons-material';
import UsersTable from './UsersTable';
import GroupsDialog from '../groups/GroupsDialog';
import { securevoxColors } from '../../theme/securevoxTheme';
import { User, Group as GroupType, UserStatistics } from '../../types';

const UsersManagement: React.FC = () => {
  const [selectedUsers, setSelectedUsers] = useState<User[]>([]);
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [openGroupsDialog, setOpenGroupsDialog] = useState(false);

  const handleUserSelect = (users: User[]) => {
    setSelectedUsers(users);
  };

  const handleMenuOpen = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleAssignGroups = () => {
    setOpenGroupsDialog(true);
    handleMenuClose();
  };

  const handleBulkActions = (action: string) => {
    // Implementa azioni bulk (attiva/disattiva, elimina, etc.)
    console.log(`Azione bulk: ${action} su ${selectedUsers.length} utenti`);
    handleMenuClose();
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3, color: securevoxColors.textPrimary }}>
        Gestione Utenti
      </Typography>

      {/* Barra Azioni */}
      {selectedUsers.length > 0 && (
        <Paper sx={{ p: 2, mb: 3, backgroundColor: securevoxColors.primaryLight }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
              <Chip
                label={`${selectedUsers.length} utenti selezionati`}
                color="primary"
                variant="outlined"
              />
              <Typography variant="body2" color="textSecondary">
                Azioni disponibili per gli utenti selezionati
              </Typography>
            </Box>
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button
                variant="outlined"
                startIcon={<Group />}
                onClick={handleAssignGroups}
                sx={{ borderColor: securevoxColors.primary }}
              >
                Assegna a Gruppi
              </Button>
              <IconButton onClick={handleMenuOpen} sx={{ color: securevoxColors.primary }}>
                <MoreVert />
              </IconButton>
            </Box>
          </Box>
        </Paper>
      )}

      {/* Menu Azioni Bulk */}
      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleMenuClose}
      >
        <MenuItem onClick={() => handleBulkActions('activate')}>
          <AssignmentInd sx={{ mr: 1 }} />
          Attiva Utenti
        </MenuItem>
        <MenuItem onClick={() => handleBulkActions('deactivate')}>
          <AssignmentInd sx={{ mr: 1 }} />
          Disattiva Utenti
        </MenuItem>
        <MenuItem onClick={() => handleBulkActions('delete')} sx={{ color: securevoxColors.error }}>
          Elimina Utenti
        </MenuItem>
      </Menu>

      {/* Tabella Utenti */}
      <UsersTable
        onUserSelect={handleUserSelect}
        selectedUsers={selectedUsers}
      />

      {/* Dialog Assegnazione Gruppi */}
      <GroupsDialog
        open={openGroupsDialog}
        onClose={() => setOpenGroupsDialog(false)}
        selectedUsers={selectedUsers}
      />
    </Box>
  );
};

export default UsersManagement;
