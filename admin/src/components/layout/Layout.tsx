import React, { useState, ReactNode } from 'react';
import { Box, useTheme } from '@mui/material';
import Sidebar from './Sidebar';
import Header from './Header';
import { securevoxColors } from '../../theme/securevoxTheme';

interface LayoutProps {
  children: ReactNode;
  currentPage: string;
  onPageChange: (page: string) => void;
  title: string;
  onRefresh?: () => void;
  systemStatus?: 'online' | 'offline' | 'warning';
  notificationsCount?: number;
}

const Layout: React.FC<LayoutProps> = ({
  children,
  currentPage,
  onPageChange,
  title,
  onRefresh,
  systemStatus,
  notificationsCount,
}) => {
  const theme = useTheme();
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const handleToggleSidebar = () => {
    setSidebarOpen(!sidebarOpen);
  };

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      {/* Sidebar */}
      <Sidebar
        open={sidebarOpen}
        onToggle={handleToggleSidebar}
        currentPage={currentPage}
        onPageChange={onPageChange}
      />

      {/* Main Content */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          backgroundColor: securevoxColors.surface,
          minHeight: '100vh',
          transition: theme.transitions.create('margin', {
            easing: theme.transitions.easing.sharp,
            duration: theme.transitions.duration.leavingScreen,
          }),
          marginLeft: sidebarOpen ? 0 : 0, // La sidebar è sempre visibile ma si restringe
        }}
      >
        {/* Header */}
        <Header
          title={title}
          onRefresh={onRefresh}
          systemStatus={systemStatus}
          notificationsCount={notificationsCount}
        />

        {/* Content */}
        <Box
          sx={{
            mt: 8, // Altezza dell'header
            p: 3,
            minHeight: 'calc(100vh - 64px)',
          }}
        >
          {children}
        </Box>
      </Box>
    </Box>
  );
};

export default Layout;
