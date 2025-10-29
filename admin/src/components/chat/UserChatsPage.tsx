import React, { useState, useEffect, useRef } from 'react';
import {
  Box,
  Paper,
  Typography,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  ListItemAvatar,
  Avatar,
  Chip,
  CircularProgress,
  Alert,
  IconButton,
  Tooltip,
  Badge,
  Divider,
  Card,
  CardContent,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
} from '@mui/material';
import {
  ArrowBack,
  Refresh,
  Lock,
  LockOpen,
  Person,
  Group,
  Schedule,
  CalendarToday,
  Clear,
  Close,
  Image,
  VideoLibrary,
  InsertDriveFile,
  Contacts,
  LocationOn,
} from '@mui/icons-material';
import { securevoxColors } from '../../theme/securevoxTheme';
import { ApiService } from '../../services/api';

interface Participant {
  id: number;
  username: string;
  full_name: string;
  email: string;
  avatar_url: string | null;
  is_online?: boolean;
  last_seen?: string | null;
}

interface LastMessage {
  id: number;
  content: string;
  timestamp: string;
  sender: string;
  message_type: string;
  is_encrypted: boolean;
}

interface Chat {
  id: string;
  name: string;
  is_group: boolean;
  created_at: string;
  updated_at: string;
  creator: {
    id: number;
    username: string;
    full_name: string;
  };
  participants: Participant[];
  total_messages: number;
  last_message: LastMessage | null;
}

interface Message {
  id: number;
  timestamp: string;
  sender: {
    id: number;
    username: string;
    full_name: string;
    first_name?: string;
    last_name?: string;
    avatar_url?: string | null;
  };
  message_type: string;
  is_encrypted: boolean;
  content?: string;
  encrypted_payload?: {
    ciphertext_length: number;
    has_iv: boolean;
    has_mac: boolean;
  };
  has_attachment?: boolean;
  file_type?: string;
  file_url?: string;
  file_name?: string;
  image_url?: string;
  video_url?: string;
}

interface UserChatsPageProps {
  userId: number;
  onBack: () => void;
}

const UserChatsPage: React.FC<UserChatsPageProps> = ({ userId, onBack }) => {
  const [userData, setUserData] = useState<any>(null);
  const [chats, setChats] = useState<Chat[]>([]);
  const [selectedChat, setSelectedChat] = useState<Chat | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [error, setError] = useState('');
  const [filterDate, setFilterDate] = useState<string>('');
  const isFirstLoad = useRef(true);
  const [previewMessage, setPreviewMessage] = useState<Message | null>(null);
  const [previewOpen, setPreviewOpen] = useState(false);

  // Helper per costruire URL completo dell'avatar
  const getFullAvatarUrl = (avatarUrl: string | null | undefined): string | undefined => {
    if (!avatarUrl) return undefined;
    if (avatarUrl.startsWith('http')) return avatarUrl;
    // Costruisci URL completo con il backend
    return `http://127.0.0.1:8001${avatarUrl}`;
  };

  // Helper per ottenere le iniziali NC (Nome Cognome)
  const getInitials = (sender: { first_name?: string; last_name?: string; full_name: string; username: string }): string => {
    const firstName = sender.first_name?.trim() || '';
    const lastName = sender.last_name?.trim() || '';
    
    if (firstName && lastName) {
      return `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
    }
    if (firstName) {
      return firstName.substring(0, 2).toUpperCase();
    }
    if (lastName) {
      return lastName.substring(0, 2).toUpperCase();
    }
    // Fallback: prime 2 lettere del full_name o username
    const fallbackName = sender.full_name || sender.username;
    return fallbackName.substring(0, 2).toUpperCase();
  };

  const loadUserChats = async (silent = false) => {
    if (!silent) {
      setLoading(true);
    }
    setError('');

    try {
      const apiService = new ApiService();
      const data = await apiService.getUserChats(userId);
      setUserData(data.user);
      setChats(data.chats);
    } catch (err: any) {
      if (!silent) {
        setError(err.message || 'Errore nel caricamento delle chat');
      }
    } finally {
      if (!silent) {
        setLoading(false);
      }
    }
  };

  const loadChatMessages = async (chatId: string, silent = false) => {
    if (!silent) {
      setMessagesLoading(true);
    }
    setError('');

    try {
      const apiService = new ApiService();
      const data = await apiService.getChatMessages(chatId);
      setMessages(data.messages);
    } catch (err: any) {
      if (!silent) {
        setError(err.message || 'Errore nel caricamento dei messaggi');
      }
    } finally {
      if (!silent) {
        setMessagesLoading(false);
      }
    }
  };

  useEffect(() => {
    loadUserChats();

    // Ricarica ogni 5 secondi per aggiornamento real-time in background
    const interval = setInterval(() => loadUserChats(true), 5000);
    return () => clearInterval(interval);
  }, [userId]);

  useEffect(() => {
    if (selectedChat) {
      loadChatMessages(selectedChat.id);
      isFirstLoad.current = false;

      // Ricarica messaggi ogni 3 secondi per real-time in background
      const interval = setInterval(() => loadChatMessages(selectedChat.id, true), 3000);
      return () => clearInterval(interval);
    }
  }, [selectedChat]);

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('it-IT', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleTimeString('it-IT', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const filteredMessages = filterDate
    ? messages.filter((message) => {
        const messageDate = new Date(message.timestamp).toISOString().split('T')[0];
        return messageDate === filterDate;
      })
    : messages;

  const handleOpenPreview = (message: Message) => {
    if (message.has_attachment || message.image_url || message.video_url || message.file_url) {
      setPreviewMessage(message);
      setPreviewOpen(true);
    }
  };

  const handleClosePreview = () => {
    setPreviewOpen(false);
    setPreviewMessage(null);
  };

  const getMediaType = (message: Message | null) => {
    if (!message) return null;
    if (message.image_url || message.message_type === 'image') return 'image';
    if (message.video_url || message.message_type === 'video') return 'video';
    if (message.message_type === 'contact') return 'contact';
    if (message.message_type === 'location') return 'location';
    if (message.file_url || message.has_attachment) return 'file';
    return null;
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '50vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3, height: '100%' }}>
      {/* Header */}
      <Box sx={{ mb: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <IconButton onClick={onBack}>
            <ArrowBack />
          </IconButton>
          <Box>
            <Typography variant="h5" sx={{ fontWeight: 700, color: securevoxColors.textPrimary }}>
              Chat di {userData?.full_name}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {userData?.email}
            </Typography>
            
            {/* E2EE Status Indicator */}
            {userData?.e2e_force_disabled ? (
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 0.5 }}>
                <LockOpen sx={{ fontSize: 16, color: securevoxColors.error }} />
                <Typography variant="caption" sx={{ color: securevoxColors.error, fontWeight: 600 }}>
                  ⛔ Cifratura Disabilitata dall'Admin
                </Typography>
              </Box>
            ) : userData?.e2e_enabled && userData?.e2e_has_key ? (
              <Box 
                sx={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: 0.5, 
                  mt: 0.5,
                  animation: 'pulse 2s ease-in-out infinite',
                  '@keyframes pulse': {
                    '0%, 100%': { opacity: 1 },
                    '50%': { opacity: 0.7 },
                  },
                }}
              >
                <Lock sx={{ fontSize: 16, color: securevoxColors.success }} />
                <Typography variant="caption" sx={{ color: securevoxColors.success, fontWeight: 600 }}>
                  🔐 Chat Cifrata E2EE
                </Typography>
              </Box>
            ) : (
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 0.5 }}>
                <LockOpen sx={{ fontSize: 16, color: '#9e9e9e' }} />
                <Typography variant="caption" sx={{ color: '#9e9e9e', fontWeight: 600 }}>
                  ⚠️ Chat Non Cifrata
                </Typography>
              </Box>
            )}
          </Box>
        </Box>
        <Tooltip title="Ricarica">
          <IconButton onClick={() => loadUserChats(false)} disabled={loading}>
            <Refresh />
          </IconButton>
        </Tooltip>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      <Box sx={{ display: 'flex', gap: 3, height: 'calc(100vh - 220px)' }}>
        {/* Chats List */}
        <Paper sx={{ width: '350px', borderRadius: 3, overflow: 'hidden' }}>
          <Box sx={{ p: 2, backgroundColor: securevoxColors.primary }}>
            <Typography variant="h6" sx={{ fontWeight: 600, color: '#FFFFFF' }}>
              Chat ({chats.length})
            </Typography>
          </Box>
          <List sx={{ overflow: 'auto', height: 'calc(100% - 64px)' }}>
            {chats.map((chat) => (
              <ListItem key={chat.id} disablePadding>
                <ListItemButton
                  selected={selectedChat?.id === chat.id}
                  onClick={() => setSelectedChat(chat)}
                  sx={{
                    '&.Mui-selected': {
                      backgroundColor: '#e8f5e9',
                    },
                  }}
                >
                  <ListItemAvatar>
                    <Avatar 
                      src={chat.is_group ? undefined : getFullAvatarUrl(chat.participants.find(p => p.id !== userId)?.avatar_url)}
                      sx={{ bgcolor: chat.is_group ? securevoxColors.secondary : securevoxColors.primary }}
                    >
                      {chat.is_group ? (
                        <Group />
                      ) : (() => {
                        const participant = chat.participants.find(p => p.id !== userId);
                        if (!participant) return <Person />;
                        const nameParts = participant.full_name.trim().split(' ');
                        if (nameParts.length >= 2) {
                          return `${nameParts[0].charAt(0)}${nameParts[nameParts.length - 1].charAt(0)}`.toUpperCase();
                        }
                        return participant.full_name.substring(0, 2).toUpperCase();
                      })()}
                    </Avatar>
                  </ListItemAvatar>
                  <ListItemText
                    primary={
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1 }}>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          {chat.name}
                        </Typography>
                        {/* Pallino stato online/offline a destra del nome */}
                        <Box
                          sx={{
                            width: 10,
                            height: 10,
                            borderRadius: '50%',
                            backgroundColor: chat.participants.some(p => p.is_online) ? '#44b700' : '#9e9e9e',
                            boxShadow: '0 0 0 2px #fff',
                          }}
                        />
                      </Box>
                    }
                    secondary={
                      <Box component="div">
                        <Typography variant="caption" color="text.secondary" display="block">
                          {chat.participants.length} partecipanti
                        </Typography>
                        <Typography variant="caption" color="text.secondary" display="block">
                          {chat.total_messages} messaggi
                        </Typography>
                      </Box>
                    }
                    secondaryTypographyProps={{ component: 'div' }}
                  />
                </ListItemButton>
              </ListItem>
            ))}
          </List>
        </Paper>

        {/* Messages Timeline */}
        <Paper sx={{ flex: 1, borderRadius: 3, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          {selectedChat ? (
            <>
              {/* Chat Header */}
              <Box sx={{ p: 2, backgroundColor: '#f5f5f5', borderBottom: '1px solid #e0e0e0' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <Box>
                    <Typography variant="h6" sx={{ fontWeight: 600 }}>
                      {selectedChat.name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" component="div">
                      {selectedChat.participants.length} partecipanti • {selectedChat.total_messages} messaggi totali
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
                    <TextField
                      type="date"
                      size="small"
                      value={filterDate}
                      onChange={(e) => setFilterDate(e.target.value)}
                      InputProps={{
                        startAdornment: <CalendarToday sx={{ fontSize: 18, mr: 1, color: 'text.secondary' }} />,
                      }}
                      sx={{ 
                        width: 200,
                        backgroundColor: 'white',
                        borderRadius: 1,
                        '& .MuiOutlinedInput-root': {
                          fontSize: '0.875rem',
                        }
                      }}
                      placeholder="Filtra per data"
                    />
                    {filterDate && (
                      <Tooltip title="Rimuovi filtro">
                        <IconButton size="small" onClick={() => setFilterDate('')} sx={{ bgcolor: 'white' }}>
                          <Clear fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {filterDate && (
                      <Chip
                        label={`${filteredMessages.length} di ${messages.length}`}
                        size="small"
                        color="primary"
                        sx={{ fontSize: '0.75rem' }}
                      />
                    )}
                  </Box>
                </Box>
              </Box>

              {/* Messages - Mobile Chat Style */}
              <Box sx={{ 
                flex: 1, 
                overflow: 'auto', 
                backgroundColor: '#f5f5f5',
                p: 2,
              }}>
                {messagesLoading && messages.length === 0 ? (
                  <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                    <CircularProgress />
                  </Box>
                ) : filteredMessages.length === 0 ? (
                  <Box sx={{ textAlign: 'center', p: 4 }}>
                    <Typography color="text.secondary">
                      {filterDate ? 'Nessun messaggio trovato per questa data' : 'Nessun messaggio in questa chat'}
                    </Typography>
                  </Box>
                ) : (
                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
                    {filteredMessages.map((message) => {
                      // Determina se il messaggio è inviato o ricevuto rispetto all'utente monitorato
                      const isUserMessage = message.sender.id === userId;
                      const hasMedia = message.has_attachment || message.image_url || message.video_url || message.file_url;
                      
                      return (
                        <Box
                          key={message.id}
                          sx={{
                            display: 'flex',
                            justifyContent: isUserMessage ? 'flex-end' : 'flex-start',
                            alignItems: 'flex-end',
                            gap: 1,
                          }}
                        >
                          {/* Avatar per messaggi ricevuti (sinistra) */}
                          {!isUserMessage && (
                            <Avatar
                              src={getFullAvatarUrl(message.sender.avatar_url)}
                              sx={{ 
                                width: 32, 
                                height: 32,
                                bgcolor: securevoxColors.primary,
                              }}
                            >
                              {getInitials(message.sender)}
                            </Avatar>
                          )}

                          {/* Message Bubble */}
                          <Box
                            onClick={() => hasMedia && handleOpenPreview(message)}
                            sx={{
                              maxWidth: '70%',
                              minWidth: '120px',
                              p: 1.5,
                              borderRadius: '18px',
                              backgroundColor: message.is_encrypted
                                ? 'transparent'
                                : isUserMessage
                                  ? securevoxColors.primary
                                  : '#E0E0E0',
                              border: message.is_encrypted 
                                ? `2px solid ${securevoxColors.success}`
                                : 'none',
                              boxShadow: message.is_encrypted 
                                ? 'none'
                                : '0 2px 4px rgba(0,0,0,0.1)',
                              cursor: hasMedia ? 'pointer' : 'default',
                              transition: 'transform 0.2s',
                              '&:hover': hasMedia ? {
                                transform: 'scale(1.02)',
                              } : {},
                              // Angolo tagliato in basso
                              borderBottomLeftRadius: isUserMessage ? '18px' : '4px',
                              borderBottomRightRadius: isUserMessage ? '4px' : '18px',
                            }}
                          >
                            {/* Nome mittente (solo per messaggi ricevuti in chat di gruppo) */}
                            {!isUserMessage && selectedChat?.is_group && (
                              <Typography
                                variant="caption"
                                sx={{
                                  display: 'block',
                                  fontWeight: 600,
                                  color: '#666',
                                  mb: 0.5,
                                  fontSize: '0.7rem',
                                }}
                              >
                                {message.sender.full_name}
                              </Typography>
                            )}

                            {/* Contenuto del messaggio */}
                            {message.is_encrypted ? (
                              // Messaggio cifrato: mostra solo lucchetto verde chiuso
                              <Box sx={{ textAlign: 'center', py: 2 }}>
                                <Lock sx={{ 
                                  fontSize: 40, 
                                  color: securevoxColors.success,
                                  display: 'block',
                                  margin: '0 auto',
                                }} />
                                <Typography
                                  variant="caption"
                                  sx={{
                                    display: 'block',
                                    color: securevoxColors.success,
                                    fontWeight: 600,
                                    mt: 1,
                                    fontSize: '0.75rem',
                                  }}
                                >
                                  Messaggio Cifrato E2EE
                                </Typography>
                                {message.encrypted_payload && (
                                  <Typography
                                    variant="caption"
                                    sx={{
                                      display: 'block',
                                      color: '#999',
                                      fontSize: '0.65rem',
                                      mt: 0.5,
                                    }}
                                  >
                                    {message.encrypted_payload.ciphertext_length} bytes
                                  </Typography>
                                )}
                              </Box>
                            ) : (
                              // Messaggio in chiaro: mostra lucchetto grigio aperto e contenuto
                              <Box>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.5 }}>
                                  <LockOpen sx={{ 
                                    fontSize: 16, 
                                    color: isUserMessage ? 'rgba(255,255,255,0.7)' : '#999'
                                  }} />
                                  <Typography
                                    variant="caption"
                                    sx={{
                                      fontSize: '0.7rem',
                                      fontWeight: 500,
                                      color: isUserMessage ? 'rgba(255,255,255,0.85)' : '#999',
                                    }}
                                  >
                                    Non cifrato
                                  </Typography>
                                </Box>
                                <Typography
                                  sx={{
                                    fontSize: '0.95rem',
                                    color: isUserMessage ? '#FFFFFF' : '#000000',
                                    wordWrap: 'break-word',
                                    whiteSpace: 'pre-wrap',
                                  }}
                                >
                                  {message.content}
                                </Typography>
                              </Box>
                            )}

                            {/* Timestamp */}
                            <Typography
                              variant="caption"
                              sx={{
                                display: 'block',
                                textAlign: 'right',
                                mt: 0.5,
                                fontSize: '0.7rem',
                                color: message.is_encrypted
                                  ? '#999'
                                  : isUserMessage
                                    ? 'rgba(255,255,255,0.7)'
                                    : '#666',
                              }}
                            >
                              {formatTime(message.timestamp)}
                            </Typography>
                          </Box>

                          {/* Avatar per messaggi inviati (destra) */}
                          {isUserMessage && (
                            <Avatar
                              src={getFullAvatarUrl(message.sender.avatar_url)}
                              sx={{ 
                                width: 32, 
                                height: 32,
                                bgcolor: securevoxColors.primary,
                              }}
                            >
                              {getInitials(message.sender)}
                            </Avatar>
                          )}
                        </Box>
                      );
                    })}
                  </Box>
                )}
              </Box>

              {/* Encryption Info */}
              <Box sx={{ p: 2, backgroundColor: '#f5f5f5', borderTop: '1px solid #e0e0e0' }}>
                <Typography variant="caption" color="text.secondary">
                  🔐 I messaggi cifrati E2EE sono sicuri e NON leggibili dal server
                </Typography>
              </Box>
            </>
          ) : (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
              <Typography color="text.secondary">
                Seleziona una chat per visualizzare i messaggi
              </Typography>
            </Box>
          )}
        </Paper>
      </Box>

      {/* Preview Dialog */}
      <Dialog
        open={previewOpen}
        onClose={handleClosePreview}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              {getMediaType(previewMessage) === 'image' && <Image />}
              {getMediaType(previewMessage) === 'video' && <VideoLibrary />}
              {getMediaType(previewMessage) === 'contact' && <Contacts />}
              {getMediaType(previewMessage) === 'location' && <LocationOn />}
              {getMediaType(previewMessage) === 'file' && <InsertDriveFile />}
              <Typography variant="h6">
                Anteprima {getMediaType(previewMessage) === 'contact' ? 'Contatto' : getMediaType(previewMessage) === 'location' ? 'Posizione' : 'Media'}
              </Typography>
            </Box>
            <IconButton onClick={handleClosePreview} size="small">
              <Close />
            </IconButton>
          </Box>
        </DialogTitle>
        <DialogContent>
          {previewMessage && (
            <Box>
              {/* Sender Info */}
              <Box sx={{ mb: 2, p: 2, backgroundColor: '#f5f5f5', borderRadius: 2 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  <Avatar sx={{ width: 32, height: 32 }}>
                    {previewMessage.sender.full_name.charAt(0)}
                  </Avatar>
                  <Box>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {previewMessage.sender.full_name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      {formatDate(previewMessage.timestamp)}
                    </Typography>
                  </Box>
                </Box>
                <Chip
                  icon={previewMessage.is_encrypted ? <Lock /> : <LockOpen />}
                  label={previewMessage.is_encrypted ? 'Cifrato E2EE' : 'In chiaro'}
                  size="small"
                  color={previewMessage.is_encrypted ? 'success' : 'warning'}
                />
              </Box>

              {/* Content Preview */}
              {previewMessage.is_encrypted ? (
                <Box sx={{ p: 3, backgroundColor: '#e8f5e9', borderRadius: 2, border: '2px solid #4caf50' }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
                    <Lock sx={{ color: securevoxColors.success }} />
                    <Typography variant="h6" sx={{ color: securevoxColors.success, fontWeight: 600 }}>
                      🔐 Contenuto Cifrato
                    </Typography>
                  </Box>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    Il contenuto è protetto con crittografia end-to-end e non è leggibile sul server.
                  </Typography>
                  {previewMessage.encrypted_payload && (
                    <Box sx={{ p: 2, backgroundColor: 'white', borderRadius: 1, fontFamily: 'monospace' }}>
                      <Typography variant="caption" display="block" sx={{ mb: 1 }}>
                        <strong>📦 Payload Cifrato:</strong>
                      </Typography>
                      <Typography variant="caption" display="block" sx={{ wordBreak: 'break-all', color: '#666' }}>
                        • Dimensione: {previewMessage.encrypted_payload.ciphertext_length} bytes
                      </Typography>
                      <Typography variant="caption" display="block" sx={{ color: '#666' }}>
                        • IV (Initialization Vector): {previewMessage.encrypted_payload.has_iv ? '✅ Presente' : '❌ Assente'}
                      </Typography>
                      <Typography variant="caption" display="block" sx={{ color: '#666' }}>
                        • MAC (Message Authentication Code): {previewMessage.encrypted_payload.has_mac ? '✅ Presente' : '❌ Assente'}
                      </Typography>
                    </Box>
                  )}
                  {previewMessage.file_name && (
                    <Box sx={{ mt: 2 }}>
                      <Chip
                        icon={<InsertDriveFile />}
                        label={`Nome File: ${previewMessage.file_name}`}
                        size="small"
                      />
                    </Box>
                  )}
                </Box>
              ) : (
                <Box>
                  {/* Image Preview */}
                  {getMediaType(previewMessage) === 'image' && previewMessage.image_url && (
                    <Box sx={{ textAlign: 'center' }}>
                      <img
                        src={previewMessage.image_url}
                        alt="Anteprima"
                        style={{
                          maxWidth: '100%',
                          maxHeight: '500px',
                          borderRadius: '8px',
                          boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                        }}
                      />
                    </Box>
                  )}

                  {/* Video Preview */}
                  {getMediaType(previewMessage) === 'video' && previewMessage.video_url && (
                    <Box sx={{ textAlign: 'center' }}>
                      <video
                        controls
                        style={{
                          maxWidth: '100%',
                          maxHeight: '500px',
                          borderRadius: '8px',
                          boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                        }}
                      >
                        <source src={previewMessage.video_url} />
                        Il tuo browser non supporta il tag video.
                      </video>
                    </Box>
                  )}

                  {/* File Preview */}
                  {getMediaType(previewMessage) === 'file' && (
                    <Box sx={{ p: 3, backgroundColor: '#fff3e0', borderRadius: 2, border: '2px solid #ffb74d' }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                        <InsertDriveFile sx={{ fontSize: 48, color: '#ff9800' }} />
                        <Box>
                          <Typography variant="h6" sx={{ fontWeight: 600 }}>
                            {previewMessage.file_name || 'File allegato'}
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Tipo: {previewMessage.file_type || 'Sconosciuto'}
                          </Typography>
                        </Box>
                      </Box>
                      {previewMessage.file_url && (
                        <Button
                          variant="contained"
                          startIcon={<InsertDriveFile />}
                          href={previewMessage.file_url}
                          target="_blank"
                          download
                        >
                          Scarica File
                        </Button>
                      )}
                    </Box>
                  )}

                  {/* Contact Preview */}
                  {getMediaType(previewMessage) === 'contact' && (
                    <Box sx={{ p: 3, backgroundColor: '#e3f2fd', borderRadius: 2, border: '2px solid #2196f3' }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                        <Contacts sx={{ fontSize: 48, color: '#1976d2' }} />
                        <Box>
                          <Typography variant="h6" sx={{ fontWeight: 600 }}>
                            👤 {previewMessage.file_name || 'Contatto'}
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Contatto condiviso dalla rubrica
                          </Typography>
                        </Box>
                      </Box>
                      {previewMessage.content && (
                        <Box sx={{ mt: 2, p: 2, backgroundColor: 'white', borderRadius: 1 }}>
                          <Typography variant="body2">
                            {previewMessage.content}
                          </Typography>
                        </Box>
                      )}
                    </Box>
                  )}

                  {/* Location Preview */}
                  {getMediaType(previewMessage) === 'location' && (
                    <Box sx={{ p: 3, backgroundColor: '#f3e5f5', borderRadius: 2, border: '2px solid #9c27b0' }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                        <LocationOn sx={{ fontSize: 48, color: '#7b1fa2' }} />
                        <Box>
                          <Typography variant="h6" sx={{ fontWeight: 600 }}>
                            📍 Posizione Condivisa
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            Coordinate GPS
                          </Typography>
                        </Box>
                      </Box>
                      {previewMessage.content && (
                        <Box sx={{ mt: 2, p: 2, backgroundColor: 'white', borderRadius: 1 }}>
                          <Typography variant="body2">
                            {previewMessage.content}
                          </Typography>
                        </Box>
                      )}
                    </Box>
                  )}

                  {/* Text Content - solo per messaggi senza tipo specifico */}
                  {previewMessage.content && !['contact', 'location', 'image', 'video', 'file'].includes(getMediaType(previewMessage) || '') && (
                    <Box sx={{ mt: 2, p: 2, backgroundColor: '#f5f5f5', borderRadius: 2 }}>
                      <Typography variant="body2">
                        {previewMessage.content}
                      </Typography>
                    </Box>
                  )}
                </Box>
              )}
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClosePreview} variant="outlined">
            Chiudi
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default UserChatsPage;

