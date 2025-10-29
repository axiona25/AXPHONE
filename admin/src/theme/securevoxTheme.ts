import { createTheme } from '@mui/material/styles';

// Colori ufficiali AXPHONE
export const securevoxColors = {
  // Colori principali
  primary: '#26A884', // Verde chiaro AXPHONE
  primaryLight: '#4FC3A1', // Verde chiaro più chiaro
  secondary: '#0D7557', // Verde scuro AXPHONE
  accent: '#4FC3A1', // Verde accent
  background: '#0D7557', // Verde scuro come base
  surface: '#F5F5F5', // Grigio chiaro
  card: '#E0E0E0', // Grigio card
  
  // Colori di stato
  success: '#26A884',
  error: '#F44336',
  warning: '#FF9800',
  
  // Colori testo
  textPrimary: '#000000',
  textSecondary: '#666666',
  textTertiary: '#999999',
  
  // Colori aggiuntivi per dashboard
  sidebar: '#1A1A1A',
  sidebarHover: '#2A2A2A',
  header: '#FFFFFF',
  border: '#E0E0E0',
  shadow: 'rgba(0, 0, 0, 0.1)',
};

export const securevoxTheme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: securevoxColors.primary,
      dark: securevoxColors.secondary,
      light: '#4FC3A1',
      contrastText: '#FFFFFF',
    },
    secondary: {
      main: securevoxColors.secondary,
      dark: '#0A5A47',
      light: '#2D8A6F',
      contrastText: '#FFFFFF',
    },
    background: {
      default: securevoxColors.surface,
      paper: securevoxColors.card,
    },
    text: {
      primary: securevoxColors.textPrimary,
      secondary: securevoxColors.textSecondary,
    },
    success: {
      main: securevoxColors.success,
    },
    error: {
      main: securevoxColors.error,
    },
    warning: {
      main: securevoxColors.warning,
    },
  },
  typography: {
    fontFamily: '"Poppins", "Roboto", "Helvetica", "Arial", sans-serif',
    h1: {
      fontSize: '2.5rem',
      fontWeight: 700,
      color: securevoxColors.textPrimary,
    },
    h2: {
      fontSize: '2rem',
      fontWeight: 600,
      color: securevoxColors.textPrimary,
    },
    h3: {
      fontSize: '1.75rem',
      fontWeight: 600,
      color: securevoxColors.textPrimary,
    },
    h4: {
      fontSize: '1.5rem',
      fontWeight: 500,
      color: securevoxColors.textPrimary,
    },
    h5: {
      fontSize: '1.25rem',
      fontWeight: 500,
      color: securevoxColors.textPrimary,
    },
    h6: {
      fontSize: '1rem',
      fontWeight: 500,
      color: securevoxColors.textPrimary,
    },
    body1: {
      fontSize: '1rem',
      fontWeight: 400,
      color: securevoxColors.textPrimary,
    },
    body2: {
      fontSize: '0.875rem',
      fontWeight: 400,
      color: securevoxColors.textSecondary,
    },
    button: {
      fontSize: '0.875rem',
      fontWeight: 500,
      textTransform: 'none',
    },
  },
  shape: {
    borderRadius: 12,
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          textTransform: 'none',
          fontWeight: 500,
          padding: '8px 16px',
        },
        contained: {
          backgroundColor: securevoxColors.primary,
          color: '#FFFFFF',
          '&:hover': {
            backgroundColor: securevoxColors.secondary,
          },
        },
        outlined: {
          borderColor: securevoxColors.primary,
          color: securevoxColors.primary,
          '&:hover': {
            backgroundColor: `${securevoxColors.primary}10`,
            borderColor: securevoxColors.secondary,
          },
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          backgroundColor: securevoxColors.card,
          borderRadius: 16,
          boxShadow: `0 4px 20px ${securevoxColors.shadow}`,
          border: `1px solid ${securevoxColors.border}`,
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundColor: securevoxColors.card,
          borderRadius: 16,
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          backgroundColor: securevoxColors.header,
          color: securevoxColors.textPrimary,
          boxShadow: `0 2px 10px ${securevoxColors.shadow}`,
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          fontWeight: 500,
        },
        colorPrimary: {
          backgroundColor: securevoxColors.primary,
          color: '#FFFFFF',
        },
        colorSecondary: {
          backgroundColor: securevoxColors.secondary,
          color: '#FFFFFF',
        },
      },
    },
    MuiTextField: {
      styleOverrides: {
        root: {
          '& .MuiOutlinedInput-root': {
            borderRadius: 12,
            '&:hover .MuiOutlinedInput-notchedOutline': {
              borderColor: securevoxColors.primary,
            },
            '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
              borderColor: securevoxColors.primary,
            },
          },
        },
      },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          backgroundColor: `${securevoxColors.primary}10`,
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&:nth-of-type(even)': {
            backgroundColor: `${securevoxColors.primary}05`,
          },
          '&:hover': {
            backgroundColor: `${securevoxColors.primary}10`,
          },
        },
      },
    },
  },
});

// Gradiente personalizzato per elementi speciali
export const securevoxGradient = {
  primary: `linear-gradient(135deg, ${securevoxColors.primary} 0%, ${securevoxColors.secondary} 100%)`,
  card: `linear-gradient(135deg, ${securevoxColors.card} 0%, #FFFFFF 100%)`,
  sidebar: `linear-gradient(180deg, ${securevoxColors.sidebar} 0%, #2A2A2A 100%)`,
};

// Ombre personalizzate
export const securevoxShadows = {
  card: `0 4px 20px ${securevoxColors.shadow}`,
  hover: `0 8px 30px ${securevoxColors.shadow}`,
  sidebar: `2px 0 10px ${securevoxColors.shadow}`,
};
