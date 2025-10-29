import React, { useState } from 'react';
import {
  AppBar,
  Toolbar,
  Typography,
  Box,
  IconButton,
  Badge,
  Chip,
  useTheme,
} from '@mui/material';
import {
  Notifications,
  Refresh,
  Wifi,
  WifiOff,
  Security,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import NotificationCenter from '../notifications/NotificationCenter';
import { useRealtimeNotifications } from '../../hooks/useRealtimeData';

interface HeaderProps {
  title: string;
  onRefresh?: () => void;
  systemStatus?: 'online' | 'offline' | 'warning';
  notificationsCount?: number;
}

const Header: React.FC<HeaderProps> = ({
  title,
  onRefresh,
  systemStatus = 'online',
  notificationsCount = 0,
}) => {
  const theme = useTheme();
  const [notificationCenterOpen, setNotificationCenterOpen] = useState(false);
  const { unreadCount } = useRealtimeNotifications();

  const getStatusColor = () => {
    switch (systemStatus) {
      case 'online':
        return securevoxColors.success;
      case 'warning':
        return securevoxColors.warning;
      case 'offline':
        return securevoxColors.error;
      default:
        return securevoxColors.textSecondary;
    }
  };

  const getStatusIcon = () => {
    switch (systemStatus) {
      case 'online':
        return <Wifi sx={{ fontSize: 16 }} />;
      case 'warning':
        return <Wifi sx={{ fontSize: 16 }} />;
      case 'offline':
        return <WifiOff sx={{ fontSize: 16 }} />;
      default:
        return <Security sx={{ fontSize: 16 }} />;
    }
  };

  const getStatusLabel = () => {
    switch (systemStatus) {
      case 'online':
        return 'Sistema Online';
      case 'warning':
        return 'Attenzione';
      case 'offline':
        return 'Sistema Offline';
      default:
        return 'Stato Sconosciuto';
    }
  };

  return (
    <AppBar
      position="fixed"
      sx={{
        backgroundColor: securevoxColors.header,
        color: securevoxColors.textPrimary,
        boxShadow: '0 2px 10px rgba(0, 0, 0, 0.1)',
        borderBottom: `1px solid ${securevoxColors.border}`,
        zIndex: theme.zIndex.drawer + 1,
      }}
    >
      <Toolbar>
        <Box sx={{ flexGrow: 1 }}>
          <Typography variant="h6" component="div" sx={{ fontWeight: 600 }}>
            {title}
          </Typography>
        </Box>

        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          {/* System Status */}
          <Chip
            icon={getStatusIcon()}
            label={getStatusLabel()}
            size="small"
            sx={{
              backgroundColor: `${getStatusColor()}20`,
              color: getStatusColor(),
              border: `1px solid ${getStatusColor()}`,
              fontWeight: 500,
            }}
          />

          {/* Refresh Button */}
          {onRefresh && (
            <IconButton
              onClick={onRefresh}
              sx={{
                color: securevoxColors.textSecondary,
                '&:hover': {
                  backgroundColor: `${securevoxColors.primary}10`,
                  color: securevoxColors.primary,
                },
              }}
            >
              <Refresh />
            </IconButton>
          )}

          {/* Notifications */}
          <IconButton
            onClick={() => setNotificationCenterOpen(true)}
            sx={{
              color: securevoxColors.textSecondary,
              '&:hover': {
                backgroundColor: `${securevoxColors.primary}10`,
                color: securevoxColors.primary,
              },
            }}
          >
            <Badge badgeContent={unreadCount} color="error">
              <Notifications />
            </Badge>
          </IconButton>
        </Box>
      </Toolbar>
      
      {/* Notification Center */}
      <NotificationCenter
        open={notificationCenterOpen}
        onClose={() => setNotificationCenterOpen(false)}
      />
    </AppBar>
  );
};

export default Header;
