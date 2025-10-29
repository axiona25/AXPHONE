import React, { useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
  CircularProgress,
  InputAdornment,
  IconButton,
} from '@mui/material';
import {
  Visibility,
  VisibilityOff,
  Lock,
  Person,
  Security,
} from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';
import { securevoxColors, securevoxGradient } from '../../theme/securevoxTheme';

const Login: React.FC = () => {
  const { login, loading, error } = useAuth();
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });
  const [showPassword, setShowPassword] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await login(formData);
  };

  const handleTogglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: securevoxGradient.primary,
        padding: 2,
      }}
    >
      <Card
        sx={{
          maxWidth: 400,
          width: '100%',
          borderRadius: 3,
          boxShadow: '0 20px 40px rgba(0, 0, 0, 0.1)',
        }}
      >
        <CardContent sx={{ p: 4 }}>
          {/* Logo e Titolo */}
          <Box
            sx={{
              textAlign: 'center',
              mb: 4,
            }}
          >
            <Box
              component="img"
              src="/logo_axphone.png"
              alt="AXPHONE Logo"
              sx={{
                width: 180,
                height: 'auto',
                margin: '0 auto 24px',
                display: 'block',
              }}
            />
            <Typography
              variant="body1"
              sx={{
                color: securevoxColors.textSecondary,
                fontWeight: 500,
              }}
            >
              Admin Dashboard
            </Typography>
          </Box>

          {/* Form */}
          <Box component="form" onSubmit={handleSubmit}>
            {error && (
              <Alert severity="error" sx={{ mb: 3, borderRadius: 2 }}>
                {error}
              </Alert>
            )}

            <TextField
              fullWidth
              name="username"
              label="Username"
              value={formData.username}
              onChange={handleChange}
              required
              disabled={loading}
              sx={{ mb: 2 }}
              inputProps={{
                autoComplete: 'username',
              }}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <Person sx={{ color: securevoxColors.textSecondary }} />
                  </InputAdornment>
                ),
              }}
            />

            <TextField
              fullWidth
              name="password"
              label="Password"
              type={showPassword ? 'text' : 'password'}
              value={formData.password}
              onChange={handleChange}
              required
              disabled={loading}
              sx={{ mb: 3 }}
              inputProps={{
                autoComplete: 'current-password',
              }}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <Lock sx={{ color: securevoxColors.textSecondary }} />
                  </InputAdornment>
                ),
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton
                      onClick={handleTogglePasswordVisibility}
                      edge="end"
                      disabled={loading}
                    >
                      {showPassword ? <VisibilityOff /> : <Visibility />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />

            <Button
              type="submit"
              fullWidth
              variant="contained"
              disabled={loading}
              sx={{
                py: 1.5,
                fontSize: '1rem',
                fontWeight: 600,
                borderRadius: 2,
                textTransform: 'none',
                background: securevoxGradient.primary,
                '&:hover': {
                  background: securevoxColors.secondary,
                },
                '&:disabled': {
                  background: securevoxColors.textTertiary,
                },
              }}
            >
              {loading ? (
                <CircularProgress size={24} color="inherit" />
              ) : (
                'Accedi'
              )}
            </Button>
          </Box>

          {/* Footer */}
          <Box
            sx={{
              mt: 4,
              pt: 3,
              borderTop: `1px solid ${securevoxColors.border}`,
              textAlign: 'center',
            }}
          >
            <Typography
              variant="caption"
              sx={{
                color: securevoxColors.textTertiary,
              }}
            >
              Accesso riservato agli amministratori
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
};

export default Login;
