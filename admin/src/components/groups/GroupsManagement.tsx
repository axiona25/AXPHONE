import React, { useState } from 'react';
import { Box, Typography } from '@mui/material';
import GroupsTable from './GroupsTable';
import GroupMembersDialog from './GroupMembersDialog';
import { securevoxColors } from '../../theme/securevoxTheme';

interface Group {
  id: string;
  name: string;
  description: string;
  user_count: number;
  created_at: string;
  is_active: boolean;
}

const GroupsManagement: React.FC = () => {
  const [selectedGroup, setSelectedGroup] = useState<Group | null>(null);
  const [openMembersDialog, setOpenMembersDialog] = useState(false);

  const handleGroupSelect = (group: Group) => {
    setSelectedGroup(group);
    setOpenMembersDialog(true);
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3, color: securevoxColors.textPrimary }}>
        Gestione Gruppi
      </Typography>

      <GroupsTable onGroupSelect={handleGroupSelect} />

      <GroupMembersDialog
        open={openMembersDialog}
        onClose={() => setOpenMembersDialog(false)}
        group={selectedGroup}
      />
    </Box>
  );
};

export default GroupsManagement;
