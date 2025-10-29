/**
 * SecureVox Call Server
 * Dedicated WebRTC Signaling Server
 */

require('dotenv').config({ path: './config.env' });
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const logger = require('./utils/logger');
const authMiddleware = require('./middleware/auth');
const CallManager = require('./services/CallManager');
const SignalingService = require('./services/SignalingService');
const NotificationService = require('./services/NotificationService');

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Configure CORS for Socket.IO
const io = socketIo(server, {
  cors: {
    origin: process.env.NODE_ENV === 'production' 
      ? ["https://your-domain.com"] 
      : ["http://localhost:3000", "http://localhost:8080"],
    methods: ["GET", "POST"],
    credentials: true
  },
  transports: ['websocket', 'polling']
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false, // Disable for development
  crossOriginEmbedderPolicy: false
}));

app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? ["https://your-domain.com"]
    : ["http://localhost:3000", "http://localhost:8080"],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 60000,
  max: parseInt(process.env.MAX_REQUESTS_PER_WINDOW) || 100,
  message: 'Too many requests from this IP'
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Initialize services
const callManager = new CallManager();
const signalingService = new SignalingService(io, callManager);
const notificationService = new NotificationService();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'SecureVox Call Server',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    connections: io.engine.clientsCount
  });
});

// API Routes
app.use('/api/calls', authMiddleware.authenticateToken, require('./routes/calls')(callManager, notificationService));
app.use('/api/ice', authMiddleware.authenticateToken, require('./routes/ice'));

// Socket.IO connection handling
io.use(authMiddleware.socketAuth);

io.on('connection', (socket) => {
  logger.info(`New client connected: ${socket.id} (User: ${socket.userId})`);
  
  // Join user to their personal room for notifications
  socket.join(`user:${socket.userId}`);
  
  // Register signaling handlers
  signalingService.handleConnection(socket);
  
  socket.on('disconnect', (reason) => {
    logger.info(`Client disconnected: ${socket.id} (Reason: ${reason})`);
    signalingService.handleDisconnection(socket);
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error('Express error:', error);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested endpoint does not exist'
  });
});

// Start server
const PORT = process.env.PORT || 8001;
const HOST = process.env.HOST || '0.0.0.0';

server.listen(PORT, HOST, () => {
  logger.info(`🎯 SecureVox Call Server started on ${HOST}:${PORT}`);
  logger.info(`📡 WebRTC Signaling ready`);
  logger.info(`🔗 Socket.IO ready for connections`);
  logger.info(`🌍 Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

module.exports = { app, server, io };
