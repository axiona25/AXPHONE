import React, { useState } from 'react';
import { ThemeProvider } from '@mui/material/styles';
import { CssBaseline, Box, CircularProgress } from '@mui/material';
import { securevoxTheme } from './theme/securevoxTheme';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Layout from './components/layout/Layout';
import Login from './components/auth/Login';
import MockupDashboard from './components/dashboard/MockupDashboard';
import GroupsManagement from './components/groups/GroupsManagement';
import ServersManagement from './components/servers/ServersManagement';
import SettingsPage from './components/settings/SettingsPage';
import ChatPage from './components/chat/ChatPage';
import UserChatsPage from './components/chat/UserChatsPage';
import { securevoxColors } from './theme/securevoxTheme';

function AppContent() {
  const { isAuthenticated, loading } = useAuth();
  const [currentPage, setCurrentPage] = useState('dashboard');
  const [selectedUserId, setSelectedUserId] = useState<number | null>(null);

  const getPageTitle = () => {
    switch (currentPage) {
      case 'dashboard':
        return 'Dashboard';
      case 'chat':
        return selectedUserId ? 'Monitoraggio Chat Utente' : 'Monitoraggio Chat';
      case 'groups':
        return 'Gestione Gruppi';
      case 'servers':
        return 'Gestione Server';
      case 'settings':
        return 'Impostazioni';
      default:
        return 'Dashboard';
    }
  };

  const renderCurrentPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <MockupDashboard />;
      case 'chat':
        return selectedUserId ? (
          <UserChatsPage 
            userId={selectedUserId} 
            onBack={() => setSelectedUserId(null)} 
          />
        ) : (
          <ChatPage onViewUserChats={(userId) => setSelectedUserId(userId)} />
        );
      case 'groups':
        return <GroupsManagement />;
      case 'servers':
        return <ServersManagement />;
      case 'settings':
        return <SettingsPage />;
      default:
        return <MockupDashboard />;
    }
  };

  const handlePageChange = (page: string) => {
    setCurrentPage(page);
    // Reset selectedUserId quando cambio pagina
    if (page !== 'chat') {
      setSelectedUserId(null);
    }
  };

  const handleRefresh = () => {
    // Implementare refresh dei dati
    window.location.reload();
  };

  if (loading) {
    return (
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          height: '100vh',
          backgroundColor: securevoxColors.surface,
        }}
      >
        <CircularProgress size={60} sx={{ color: securevoxColors.primary }} />
      </Box>
    );
  }

  if (!isAuthenticated) {
    return <Login />;
  }

  return (
    <Layout
      currentPage={currentPage}
      onPageChange={handlePageChange}
      title={getPageTitle()}
      onRefresh={handleRefresh}
      systemStatus="online"
      notificationsCount={0}
    >
      {renderCurrentPage()}
    </Layout>
  );
}

function App() {
  return (
    <ThemeProvider theme={securevoxTheme}>
      <CssBaseline />
      <AuthProvider>
        <AppContent />
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;