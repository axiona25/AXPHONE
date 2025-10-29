import React, { useState } from 'react';
import {
  Drawer,
  Box,
  Typography,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  IconButton,
  Badge,
  Chip,
  Button,
  Divider,
  Tooltip,
  Alert,
} from '@mui/material';
import {
  Notifications,
  Close,
  CheckCircle,
  Error,
  Warning,
  Info,
  MarkEmailRead,
  ClearAll,
} from '@mui/icons-material';
import { useRealtimeNotifications } from '../../hooks/useRealtimeData';
import { securevoxColors } from '../../theme/securevoxTheme';

interface NotificationCenterProps {
  open: boolean;
  onClose: () => void;
}

const NotificationCenter: React.FC<NotificationCenterProps> = ({ open, onClose }) => {
  const {
    notifications,
    unreadCount,
    markAsRead,
    markAllAsRead,
    clearNotifications,
  } = useRealtimeNotifications();

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'success':
        return <CheckCircle sx={{ color: securevoxColors.success }} />;
      case 'error':
        return <Error sx={{ color: securevoxColors.error }} />;
      case 'warning':
        return <Warning sx={{ color: securevoxColors.warning }} />;
      case 'info':
      default:
        return <Info sx={{ color: securevoxColors.primary }} />;
    }
  };

  const getNotificationColor = (type: string) => {
    switch (type) {
      case 'success':
        return securevoxColors.success;
      case 'error':
        return securevoxColors.error;
      case 'warning':
        return securevoxColors.warning;
      case 'info':
      default:
        return securevoxColors.primary;
    }
  };

  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      sx={{
        '& .MuiDrawer-paper': {
          width: 400,
          maxWidth: '90vw',
        },
      }}
    >
      <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Typography variant="h6" sx={{ fontWeight: 600 }}>
            Notifiche
            {unreadCount > 0 && (
              <Chip
                label={unreadCount}
                size="small"
                color="error"
                sx={{ ml: 1 }}
              />
            )}
          </Typography>
          <IconButton onClick={onClose}>
            <Close />
          </IconButton>
        </Box>

        {notifications.length > 0 && (
          <Box sx={{ mt: 2, display: 'flex', gap: 1 }}>
            <Button
              size="small"
              startIcon={<MarkEmailRead />}
              onClick={markAllAsRead}
              disabled={unreadCount === 0}
            >
              Segna tutte come lette
            </Button>
            <Button
              size="small"
              startIcon={<ClearAll />}
              onClick={clearNotifications}
              color="error"
            >
              Cancella tutte
            </Button>
          </Box>
        )}
      </Box>

      <Box sx={{ flex: 1, overflow: 'auto' }}>
        {notifications.length === 0 ? (
          <Box sx={{ p: 3, textAlign: 'center' }}>
            <Notifications sx={{ fontSize: 48, color: securevoxColors.textTertiary, mb: 2 }} />
            <Typography variant="body2" color="textSecondary">
              Nessuna notifica
            </Typography>
          </Box>
        ) : (
          <List sx={{ p: 0 }}>
            {notifications.map((notification, index) => (
              <React.Fragment key={notification.id}>
                <ListItem
                  sx={{
                    py: 2,
                    px: 2,
                    backgroundColor: notification.read ? 'transparent' : `${securevoxColors.primary}05`,
                    borderLeft: `4px solid ${notification.read ? 'transparent' : getNotificationColor(notification.type)}`,
                    '&:hover': {
                      backgroundColor: `${securevoxColors.primary}10`,
                    },
                    cursor: notification.read ? 'default' : 'pointer',
                  }}
                  onClick={() => !notification.read && markAsRead(notification.id)}
                >
                  <ListItemIcon sx={{ minWidth: 40 }}>
                    {getNotificationIcon(notification.type)}
                  </ListItemIcon>
                  <ListItemText
                    primary={
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography
                          variant="subtitle2"
                          sx={{
                            fontWeight: notification.read ? 400 : 600,
                            color: notification.read ? securevoxColors.textSecondary : securevoxColors.textPrimary,
                          }}
                        >
                          {notification.title}
                        </Typography>
                        {!notification.read && (
                          <Box
                            sx={{
                              width: 8,
                              height: 8,
                              borderRadius: '50%',
                              backgroundColor: getNotificationColor(notification.type),
                            }}
                          />
                        )}
                      </Box>
                    }
                    secondary={
                      <Box>
                        <Typography
                          variant="body2"
                          sx={{
                            color: notification.read ? securevoxColors.textTertiary : securevoxColors.textSecondary,
                            mb: 0.5,
                          }}
                        >
                          {notification.message}
                        </Typography>
                        <Typography
                          variant="caption"
                          sx={{ color: securevoxColors.textTertiary }}
                        >
                          {notification.timestamp.toLocaleTimeString('it-IT')}
                        </Typography>
                      </Box>
                    }
                  />
                </ListItem>
                {index < notifications.length - 1 && <Divider />}
              </React.Fragment>
            ))}
          </List>
        )}
      </Box>

      {/* Footer con statistiche */}
      {notifications.length > 0 && (
        <Box sx={{ p: 2, borderTop: 1, borderColor: 'divider' }}>
          <Typography variant="caption" color="textSecondary">
            {notifications.length} notifiche totali • {unreadCount} non lette
          </Typography>
        </Box>
      )}
    </Drawer>
  );
};

export default NotificationCenter;
