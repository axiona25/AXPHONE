import React, { useState } from 'react';
import {
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Box,
  Typography,
  Avatar,
  Menu,
  MenuItem,
  Divider,
  Chip,
  useTheme,
  Paper,
} from '@mui/material';
import {
  Dashboard,
  Groups,
  Computer,
  Settings,
  AccountCircle,
  Logout,
  Person,
  Menu as MenuIcon,
  Chat,
} from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { securevoxColors, securevoxGradient } from '../../theme/securevoxTheme';

interface SidebarProps {
  open: boolean;
  onToggle: () => void;
  currentPage: string;
  onPageChange: (page: string) => void;
}

const menuItems = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    icon: <Dashboard />,
    color: securevoxColors.primary,
  },
  {
    id: 'chat',
    label: 'Utenti e Chat',
    icon: <Chat />,
    color: securevoxColors.primary,
  },
  {
    id: 'groups',
    label: 'Gruppi',
    icon: <Groups />,
    color: securevoxColors.primary,
  },
  {
    id: 'servers',
    label: 'Server',
    icon: <Computer />,
    color: securevoxColors.primary,
  },
  {
    id: 'settings',
    label: 'Impostazioni',
    icon: <Settings />,
    color: securevoxColors.primary,
  },
];

const Sidebar: React.FC<SidebarProps> = ({ open, onToggle, currentPage, onPageChange }) => {
  const { user, logout } = useAuth();
  const theme = useTheme();
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const profileMenuOpen = Boolean(anchorEl);

  const handleProfileClick = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleProfileClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = async () => {
    handleProfileClose();
    await logout();
  };

  const getCurrentDate = () => {
    return new Date().toLocaleDateString('it-IT', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  return (
    <>
      <Drawer
        variant="permanent"
        sx={{
          width: open ? 280 : 64,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: open ? 280 : 64,
            boxSizing: 'border-box',
            background: securevoxGradient.sidebar,
            color: '#FFFFFF',
            transition: theme.transitions.create('width', {
              easing: theme.transitions.easing.sharp,
              duration: theme.transitions.duration.enteringScreen,
            }),
            border: 'none',
            boxShadow: '2px 0 10px rgba(0, 0, 0, 0.1)',
          },
        }}
      >
        {/* Header */}
        <Box
          sx={{
            p: 2,
            display: 'flex',
            alignItems: 'center',
            justifyContent: open ? 'space-between' : 'center',
            minHeight: 64,
          }}
        >
          {open && (
            <Box>
              <Typography variant="h6" sx={{ fontWeight: 700, color: '#FFFFFF' }}>
                AXPHONE
              </Typography>
              <Typography variant="caption" sx={{ color: 'rgba(255, 255, 255, 0.7)' }}>
                Admin Dashboard
              </Typography>
            </Box>
          )}
          <Box
            onClick={onToggle}
            sx={{
              cursor: 'pointer',
              p: 1,
              borderRadius: 1,
              '&:hover': {
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
              },
            }}
          >
            <MenuIcon sx={{ color: '#FFFFFF' }} />
          </Box>
        </Box>

        {/* Logo AXPHONE */}
        {open && (
          <Box sx={{ p: 2, mb: 2, textAlign: 'center' }}>
            <Box
              component="img"
              src="/logo_axphone_orizzontale.png"
              alt="AXPHONE Logo"
              sx={{
                width: '100%',
                maxWidth: '240px',
                height: 'auto',
                display: 'block',
                margin: '0 auto',
              }}
            />
          </Box>
        )}

        {/* Data */}
        {open && (
          <Box sx={{ p: 2, borderBottom: '1px solid rgba(255, 255, 255, 0.1)' }}>
            <Typography variant="body2" sx={{ color: 'rgba(255, 255, 255, 0.8)' }}>
              {getCurrentDate()}
            </Typography>
          </Box>
        )}

        {/* Menu Items */}
        <List sx={{ flex: 1, pt: 1 }}>
          {menuItems.map((item) => (
            <ListItem key={item.id} disablePadding>
              <ListItemButton
                onClick={() => onPageChange(item.id)}
                sx={{
                  mx: 1,
                  mb: 0.5,
                  borderRadius: 2,
                  minHeight: 48,
                  backgroundColor: currentPage === item.id ? 'rgba(255, 255, 255, 0.1)' : 'transparent',
                  '&:hover': {
                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  },
                  '& .MuiListItemIcon-root': {
                    minWidth: open ? 40 : 'auto',
                    color: currentPage === item.id ? '#FFFFFF' : 'rgba(255, 255, 255, 0.7)',
                  },
                  '& .MuiListItemText-primary': {
                    color: currentPage === item.id ? '#FFFFFF' : 'rgba(255, 255, 255, 0.8)',
                    fontWeight: currentPage === item.id ? 600 : 400,
                  },
                }}
              >
                <ListItemIcon>{item.icon}</ListItemIcon>
                {open && <ListItemText primary={item.label} />}
              </ListItemButton>
            </ListItem>
          ))}
        </List>

        {/* User Profile */}
        <Box sx={{ p: 2, borderTop: '1px solid rgba(255, 255, 255, 0.1)' }}>
          <Box
            onClick={handleProfileClick}
            sx={{
              display: 'flex',
              alignItems: 'center',
              cursor: 'pointer',
              p: 1,
              borderRadius: 2,
              '&:hover': {
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
              },
            }}
          >
            <Avatar
              src={user?.avatar_url}
              sx={{
                width: 32,
                height: 32,
                bgcolor: securevoxColors.primary,
                mr: open ? 2 : 0,
              }}
            >
              {user?.full_name?.charAt(0) || user?.username?.charAt(0) || 'A'}
            </Avatar>
            {open && (
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Typography
                  variant="body2"
                  sx={{
                    color: '#FFFFFF',
                    fontWeight: 500,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {user?.full_name || user?.username}
                </Typography>
                <Typography
                  variant="caption"
                  sx={{
                    color: 'rgba(255, 255, 255, 0.7)',
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {user?.is_superuser ? 'Super Admin' : user?.is_staff ? 'Admin' : 'User'}
                </Typography>
              </Box>
            )}
            {open && (
              <Box>
                <AccountCircle sx={{ color: 'rgba(255, 255, 255, 0.7)' }} />
              </Box>
            )}
          </Box>

          {/* Status Chip */}
          {open && (
            <Box sx={{ mt: 1 }}>
              <Chip
                label="Online"
                size="small"
                sx={{
                  backgroundColor: securevoxColors.success,
                  color: '#FFFFFF',
                  fontSize: '0.75rem',
                  height: 20,
                }}
              />
            </Box>
          )}
        </Box>
      </Drawer>

      {/* Profile Menu */}
      <Menu
        anchorEl={anchorEl}
        open={profileMenuOpen}
        onClose={handleProfileClose}
        PaperProps={{
          sx: {
            mt: 1,
            minWidth: 200,
            borderRadius: 2,
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.12)',
          },
        }}
      >
        <MenuItem onClick={handleProfileClose}>
          <ListItemIcon>
            <Person fontSize="small" />
          </ListItemIcon>
          <ListItemText primary="Profilo" />
        </MenuItem>
        <Divider />
        <MenuItem onClick={handleLogout}>
          <ListItemIcon>
            <Logout fontSize="small" />
          </ListItemIcon>
          <ListItemText primary="Logout" />
        </MenuItem>
      </Menu>
    </>
  );
};

export default Sidebar;
