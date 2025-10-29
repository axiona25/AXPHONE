import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  CardHeader,
  TextField,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Switch,
  FormControlLabel,
  Divider,
  Alert,
  CircularProgress,
  Avatar,
  IconButton,
  Chip,
  Paper,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction,
} from '@mui/material';
import {
  Language,
  Upload,
  Business,
  Palette,
  Save,
  Refresh,
  PhotoCamera,
  CheckCircle,
  Warning,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import api from '../../services/api';

interface SettingsData {
  // Lingua e Localizzazione
  language: string;
  timezone: string;
  
  // Branding e Logo
  company_name: string;
  company_logo: string;
  company_website: string;
  company_email: string;
  company_phone: string;
  company_address: string;
  
  // Colori White-label
  primary_color: string;
  secondary_color: string;
  accent_color: string;
  background_color: string;
  text_color: string;
  
  // Impostazioni Generali
  enable_notifications: boolean;
  enable_analytics: boolean;
  enable_audit_log: boolean;
  session_timeout: number;
  max_file_size: number;
  
  // Sicurezza
  require_2fa: boolean;
  password_min_length: number;
  password_require_special: boolean;
  enable_ip_whitelist: boolean;
  allowed_ips: string[];
}

const SettingsPage: React.FC = () => {
  const [settings, setSettings] = useState<SettingsData>({
    language: 'it',
    timezone: 'Europe/Rome',
    company_name: 'AXPHONE',
    company_logo: '',
    company_website: '',
    company_email: '',
    company_phone: '',
    company_address: '',
    primary_color: securevoxColors.primary,
    secondary_color: securevoxColors.secondary,
    accent_color: securevoxColors.accent,
    background_color: securevoxColors.background,
    text_color: securevoxColors.textPrimary,
    enable_notifications: true,
    enable_analytics: true,
    enable_audit_log: true,
    session_timeout: 3600,
    max_file_size: 10,
    require_2fa: false,
    password_min_length: 8,
    password_require_special: true,
    enable_ip_whitelist: false,
    allowed_ips: [],
  });
  
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const languages = [
    { code: 'it', name: 'Italiano', flag: '🇮🇹' },
    { code: 'en', name: 'English', flag: '🇺🇸' },
  ];

  const timezones = [
    { value: 'Europe/Rome', label: 'Europa/Roma (GMT+1)' },
    { value: 'Europe/London', label: 'Europa/Londra (GMT+0)' },
    { value: 'America/New_York', label: 'America/New York (GMT-5)' },
    { value: 'Asia/Tokyo', label: 'Asia/Tokyo (GMT+9)' },
  ];

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/settings/');
      setSettings({ ...settings, ...response.data });
    } catch (err) {
      setError('Errore nel caricamento delle impostazioni');
      console.error('Errore fetch settings:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError(null);
      setSuccess(null);
      
      await api.put('/settings/', settings);
      setSuccess('Impostazioni salvate con successo!');
    } catch (err) {
      setError('Errore nel salvataggio delle impostazioni');
      console.error('Errore save settings:', err);
    } finally {
      setSaving(false);
    }
  };

  const handleLogoUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        setSettings({ ...settings, company_logo: e.target?.result as string });
      };
      reader.readAsDataURL(file);
    }
  };

  const handleColorChange = (colorType: string, value: string) => {
    setSettings({ ...settings, [colorType]: value });
  };

  const handleSwitchChange = (field: string, value: boolean) => {
    setSettings({ ...settings, [field]: value });
  };

  const handleInputChange = (field: string, value: string | number) => {
    setSettings({ ...settings, [field]: value });
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
        <CircularProgress sx={{ color: securevoxColors.primary }} />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3, color: securevoxColors.textPrimary }}>
        Impostazioni Sistema
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      <Grid container spacing={3}>
        {/* Lingua e Localizzazione */}
        <Grid size={{ xs: 12, md: 6 }}>
          <Card>
            <CardHeader
              title={
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Language sx={{ color: securevoxColors.primary }} />
                  <Typography variant="h6">Lingua e Localizzazione</Typography>
                </Box>
              }
            />
            <CardContent>
              <FormControl fullWidth sx={{ mb: 2 }}>
                <InputLabel>Lingua dell'Applicazione</InputLabel>
                <Select
                  value={settings.language}
                  onChange={(e) => handleInputChange('language', e.target.value)}
                  label="Lingua dell'Applicazione"
                >
                  {languages.map((lang) => (
                    <MenuItem key={lang.code} value={lang.code}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <span>{lang.flag}</span>
                        <span>{lang.name}</span>
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>

              <FormControl fullWidth>
                <InputLabel>Fuso Orario</InputLabel>
                <Select
                  value={settings.timezone}
                  onChange={(e) => handleInputChange('timezone', e.target.value)}
                  label="Fuso Orario"
                >
                  {timezones.map((tz) => (
                    <MenuItem key={tz.value} value={tz.value}>
                      {tz.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </CardContent>
          </Card>
        </Grid>

        {/* Caricamento Logo */}
        <Grid size={{ xs: 12, md: 6 }}>
          <Card>
            <CardHeader
              title={
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Upload sx={{ color: securevoxColors.primary }} />
                  <Typography variant="h6">Logo Aziendale</Typography>
                </Box>
              }
            />
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                <Avatar
                  src={settings.company_logo}
                  sx={{ width: 80, height: 80 }}
                  variant="rounded"
                >
                  <PhotoCamera />
                </Avatar>
                <Box>
                  <input
                    accept="image/*"
                    style={{ display: 'none' }}
                    id="logo-upload"
                    type="file"
                    onChange={handleLogoUpload}
                  />
                  <label htmlFor="logo-upload">
                    <Button variant="outlined" component="span" startIcon={<Upload />}>
                      Carica Logo
                    </Button>
                  </label>
                  <Typography variant="caption" display="block" color="textSecondary">
                    Formati supportati: PNG, JPG, SVG (max 2MB)
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Dati Societari */}
        <Grid size={{ xs: 12 }}>
          <Card>
            <CardHeader
              title={
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Business sx={{ color: securevoxColors.primary }} />
                  <Typography variant="h6">Dati Societari</Typography>
                </Box>
              }
            />
            <CardContent>
              <Grid container spacing={2}>
                <Grid size={{ xs: 12, sm: 6 }}>
                  <TextField
                    label="Nome Azienda"
                    value={settings.company_name}
                    onChange={(e) => handleInputChange('company_name', e.target.value)}
                    fullWidth
                  />
                </Grid>
                <Grid size={{ xs: 12, sm: 6 }}>
                  <TextField
                    label="Sito Web"
                    value={settings.company_website}
                    onChange={(e) => handleInputChange('company_website', e.target.value)}
                    fullWidth
                  />
                </Grid>
                <Grid size={{ xs: 12, sm: 6 }}>
                  <TextField
                    label="Email"
                    type="email"
                    value={settings.company_email}
                    onChange={(e) => handleInputChange('company_email', e.target.value)}
                    fullWidth
                  />
                </Grid>
                <Grid size={{ xs: 12, sm: 6 }}>
                  <TextField
                    label="Telefono"
                    value={settings.company_phone}
                    onChange={(e) => handleInputChange('company_phone', e.target.value)}
                    fullWidth
                  />
                </Grid>
                <Grid size={{ xs: 12 }}>
                  <TextField
                    label="Indirizzo"
                    value={settings.company_address}
                    onChange={(e) => handleInputChange('company_address', e.target.value)}
                    fullWidth
                    multiline
                    rows={2}
                  />
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Grid>

        {/* Colori per White-label */}
        <Grid size={{ xs: 12 }}>
          <Card>
            <CardHeader
              title={
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Palette sx={{ color: securevoxColors.primary }} />
                  <Typography variant="h6">Colori per White-label</Typography>
                </Box>
              }
            />
            <CardContent>
              <Grid container spacing={2}>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                  <TextField
                    label="Colore Primario"
                    type="color"
                    value={settings.primary_color}
                    onChange={(e) => handleColorChange('primary_color', e.target.value)}
                    fullWidth
                    InputProps={{
                      startAdornment: (
                        <Box
                          sx={{
                            width: 20,
                            height: 20,
                            backgroundColor: settings.primary_color,
                            borderRadius: '50%',
                            mr: 1,
                          }}
                        />
                      ),
                    }}
                  />
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                  <TextField
                    label="Colore Secondario"
                    type="color"
                    value={settings.secondary_color}
                    onChange={(e) => handleColorChange('secondary_color', e.target.value)}
                    fullWidth
                    InputProps={{
                      startAdornment: (
                        <Box
                          sx={{
                            width: 20,
                            height: 20,
                            backgroundColor: settings.secondary_color,
                            borderRadius: '50%',
                            mr: 1,
                          }}
                        />
                      ),
                    }}
                  />
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                  <TextField
                    label="Colore Accent"
                    type="color"
                    value={settings.accent_color}
                    onChange={(e) => handleColorChange('accent_color', e.target.value)}
                    fullWidth
                    InputProps={{
                      startAdornment: (
                        <Box
                          sx={{
                            width: 20,
                            height: 20,
                            backgroundColor: settings.accent_color,
                            borderRadius: '50%',
                            mr: 1,
                          }}
                        />
                      ),
                    }}
                  />
                </Grid>
                <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                  <TextField
                    label="Colore Sfondo"
                    type="color"
                    value={settings.background_color}
                    onChange={(e) => handleColorChange('background_color', e.target.value)}
                    fullWidth
                    InputProps={{
                      startAdornment: (
                        <Box
                          sx={{
                            width: 20,
                            height: 20,
                            backgroundColor: settings.background_color,
                            borderRadius: '50%',
                            mr: 1,
                            border: '1px solid #ccc',
                          }}
                        />
                      ),
                    }}
                  />
                </Grid>
              </Grid>

              {/* Anteprima Colori */}
              <Box sx={{ mt: 3 }}>
                <Typography variant="subtitle1" sx={{ mb: 2 }}>
                  Anteprima Colori
                </Typography>
                <Paper
                  sx={{
                    p: 3,
                    background: `linear-gradient(135deg, ${settings.primary_color}, ${settings.secondary_color})`,
                    color: settings.text_color,
                  }}
                >
                  <Typography variant="h6" sx={{ color: 'inherit' }}>
                    {settings.company_name}
                  </Typography>
                  <Typography variant="body2" sx={{ color: 'inherit', opacity: 0.8 }}>
                    Anteprima del tema personalizzato
                  </Typography>
                </Paper>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Impostazioni Generali */}
        <Grid size={{ xs: 12, md: 6 }}>
          <Card>
            <CardHeader
              title={
                <Typography variant="h6">Impostazioni Generali</Typography>
              }
            />
            <CardContent>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.enable_notifications}
                      onChange={(e) => handleSwitchChange('enable_notifications', e.target.checked)}
                    />
                  }
                  label="Abilita Notifiche"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.enable_analytics}
                      onChange={(e) => handleSwitchChange('enable_analytics', e.target.checked)}
                    />
                  }
                  label="Abilita Analytics"
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.enable_audit_log}
                      onChange={(e) => handleSwitchChange('enable_audit_log', e.target.checked)}
                    />
                  }
                  label="Abilita Audit Log"
                />
                
                <Divider sx={{ my: 1 }} />
                
                <TextField
                  label="Timeout Sessione (secondi)"
                  type="number"
                  value={settings.session_timeout}
                  onChange={(e) => handleInputChange('session_timeout', parseInt(e.target.value))}
                  fullWidth
                />
                
                <TextField
                  label="Dimensione Max File (MB)"
                  type="number"
                  value={settings.max_file_size}
                  onChange={(e) => handleInputChange('max_file_size', parseInt(e.target.value))}
                  fullWidth
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Impostazioni Sicurezza */}
        <Grid size={{ xs: 12, md: 6 }}>
          <Card>
            <CardHeader
              title={
                <Typography variant="h6">Sicurezza</Typography>
              }
            />
            <CardContent>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.require_2fa}
                      onChange={(e) => handleSwitchChange('require_2fa', e.target.checked)}
                    />
                  }
                  label="Richiedi Autenticazione a 2 Fattori"
                />
                
                <TextField
                  label="Lunghezza Minima Password"
                  type="number"
                  value={settings.password_min_length}
                  onChange={(e) => handleInputChange('password_min_length', parseInt(e.target.value))}
                  fullWidth
                />
                
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.password_require_special}
                      onChange={(e) => handleSwitchChange('password_require_special', e.target.checked)}
                    />
                  }
                  label="Richiedi Caratteri Speciali"
                />
                
                <FormControlLabel
                  control={
                    <Switch
                      checked={settings.enable_ip_whitelist}
                      onChange={(e) => handleSwitchChange('enable_ip_whitelist', e.target.checked)}
                    />
                  }
                  label="Abilita Whitelist IP"
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Pulsanti Azione */}
      <Box sx={{ mt: 4, display: 'flex', gap: 2, justifyContent: 'flex-end' }}>
        <Button
          variant="outlined"
          startIcon={<Refresh />}
          onClick={fetchSettings}
          disabled={saving}
        >
          Ripristina
        </Button>
        <Button
          variant="contained"
          startIcon={<Save />}
          onClick={handleSave}
          disabled={saving}
          sx={{
            backgroundColor: securevoxColors.primary,
            '&:hover': { backgroundColor: securevoxColors.secondary },
          }}
        >
          {saving ? <CircularProgress size={20} color="inherit" /> : 'Salva Impostazioni'}
        </Button>
      </Box>
    </Box>
  );
};

export default SettingsPage;
