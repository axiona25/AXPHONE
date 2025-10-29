import React, { useState } from 'react';
import { Box, Typography } from '@mui/material';
import ServersTable from './ServersTable';
import ServerDetailsDialog from './ServerDetailsDialog';
import { securevoxColors } from '../../theme/securevoxTheme';

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

const ServersManagement: React.FC = () => {
  const [selectedServer, setSelectedServer] = useState<Server | null>(null);
  const [openDetailsDialog, setOpenDetailsDialog] = useState(false);

  const handleServerSelect = (server: Server) => {
    setSelectedServer(server);
    setOpenDetailsDialog(true);
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3, color: securevoxColors.textPrimary }}>
        Gestione Server
      </Typography>

      <ServersTable onServerSelect={handleServerSelect} />

      <ServerDetailsDialog
        open={openDetailsDialog}
        onClose={() => setOpenDetailsDialog(false)}
        server={selectedServer}
      />
    </Box>
  );
};

export default ServersManagement;
