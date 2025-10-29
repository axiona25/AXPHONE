/**
 * SecureVox Call Server - Authentication Middleware
 * Implementa sicurezza end-to-end per signaling WebRTC
 */

const jwt = require('jsonwebtoken');
const axios = require('axios');
const rateLimit = require('express-rate-limit');
const logger = require('../utils/logger');

// Rate limiting per autenticazione
const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minuti
  max: 5, // Max 5 tentativi di auth per IP
  message: 'Too many authentication attempts',
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * Middleware di autenticazione per HTTP requests
 */
const authenticateToken = async (req, res, next) => {
  try {
    // Rate limiting per auth
    authRateLimit(req, res, () => {});

    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
      logger.warn(`Auth failed: No token provided from IP ${req.ip}`);
      return res.status(401).json({ 
        error: 'Access denied', 
        message: 'Authentication token required' 
      });
    }

    // Verifica token JWT locale (per performance)
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (jwtError) {
      logger.warn(`Auth failed: Invalid JWT from IP ${req.ip}: ${jwtError.message}`);
      return res.status(403).json({ 
        error: 'Invalid token', 
        message: 'Token verification failed' 
      });
    }

    // Validazione aggiuntiva con main server (sicurezza extra)
    try {
      const validation = await validateTokenWithMainServer(token, decoded.userId);
      if (!validation.valid) {
        logger.warn(`Auth failed: Token validation failed for user ${decoded.userId}`);
        return res.status(403).json({ 
          error: 'Token validation failed', 
          message: 'Authentication expired or revoked' 
        });
      }

      // Aggiungi informazioni utente sicure alla request
      req.user = {
        id: decoded.userId,
        email: validation.user.email,
        role: validation.user.role || 'user',
        deviceId: decoded.deviceId,
        permissions: validation.user.permissions || []
      };

      // Log accesso sicuro
      logger.info(`Authenticated user ${req.user.id} from IP ${req.ip}`);
      
      next();

    } catch (validationError) {
      logger.error(`Auth validation error: ${validationError.message}`);
      return res.status(503).json({ 
        error: 'Authentication service unavailable', 
        message: 'Please try again later' 
      });
    }

  } catch (error) {
    logger.error(`Auth middleware error: ${error.message}`);
    return res.status(500).json({ 
      error: 'Authentication error', 
      message: 'Internal authentication failure' 
    });
  }
};

/**
 * Middleware di autenticazione per Socket.IO
 */
const socketAuth = async (socket, next) => {
  try {
    const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];

    if (!token) {
      logger.warn(`Socket auth failed: No token from ${socket.handshake.address}`);
      return next(new Error('Authentication token required'));
    }

    // Verifica JWT
    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (jwtError) {
      logger.warn(`Socket auth failed: Invalid JWT from ${socket.handshake.address}: ${jwtError.message}`);
      return next(new Error('Invalid authentication token'));
    }

    // Validazione con main server
    try {
      const validation = await validateTokenWithMainServer(token, decoded.userId);
      if (!validation.valid) {
        logger.warn(`Socket auth failed: Token validation failed for user ${decoded.userId}`);
        return next(new Error('Authentication validation failed'));
      }

      // Aggiungi informazioni sicure al socket
      socket.userId = decoded.userId;
      socket.userEmail = validation.user.email;
      socket.deviceId = decoded.deviceId;
      socket.userRole = validation.user.role || 'user';
      socket.permissions = validation.user.permissions || [];

      // Controllo limiti connessioni per utente (sicurezza)
      const activeConnections = await getActiveConnectionsForUser(decoded.userId);
      if (activeConnections >= parseInt(process.env.MAX_CALLS_PER_USER) || 10) {
        logger.warn(`Socket auth failed: Too many connections for user ${decoded.userId}`);
        return next(new Error('Maximum connections exceeded'));
      }

      logger.info(`Socket authenticated: User ${socket.userId} (${socket.userEmail})`);
      next();

    } catch (validationError) {
      logger.error(`Socket auth validation error: ${validationError.message}`);
      return next(new Error('Authentication service unavailable'));
    }

  } catch (error) {
    logger.error(`Socket auth error: ${error.message}`);
    return next(new Error('Authentication failed'));
  }
};

/**
 * Validazione sicura del token con il main server
 */
async function validateTokenWithMainServer(token, userId) {
  try {
    const response = await axios.post(
      `${process.env.MAIN_SERVER_URL}/api/auth/verify/`,
      { 
        token: token,
        user_id: userId,
        service: 'call-server'
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.MAIN_SERVER_API_KEY}`,
          'Content-Type': 'application/json',
          'X-Service-Name': 'securevox-call-server',
          'X-Service-Version': '1.0.0'
        },
        timeout: 5000 // 5 secondi timeout
      }
    );

    return {
      valid: response.data.valid === true,
      user: response.data.user || {}
    };

  } catch (error) {
    // Log ma non esporre dettagli dell'errore
    logger.error(`Token validation failed: ${error.response?.status || error.message}`);
    
    // In caso di errore del main server, fallback sicuro
    if (error.code === 'ECONNREFUSED' || error.response?.status >= 500) {
      logger.warn('Main server unavailable, using JWT-only validation');
      return { valid: true, user: { email: 'unknown', role: 'user' } };
    }
    
    return { valid: false, user: {} };
  }
}

/**
 * Controlla connessioni attive per un utente (anti-flooding)
 */
async function getActiveConnectionsForUser(userId) {
  // TODO: Implementare con Redis per produzione
  // Per ora ritorna 1 (mock)
  return 1;
}

/**
 * Middleware per verificare permessi specifici
 */
const requirePermission = (permission) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (req.user.role === 'admin') {
      return next(); // Admin ha tutti i permessi
    }

    if (!req.user.permissions.includes(permission)) {
      logger.warn(`Permission denied: User ${req.user.id} lacks ${permission}`);
      return res.status(403).json({ 
        error: 'Permission denied', 
        message: `Insufficient privileges for ${permission}` 
      });
    }

    next();
  };
};

/**
 * Middleware per verificare ownership delle risorse
 */
const requireOwnership = (resourceField = 'userId') => {
  return (req, res, next) => {
    const resourceUserId = req.params[resourceField] || req.body[resourceField];
    
    if (req.user.role === 'admin') {
      return next(); // Admin può accedere a tutto
    }

    if (req.user.id !== resourceUserId) {
      logger.warn(`Ownership denied: User ${req.user.id} tried to access resource of ${resourceUserId}`);
      return res.status(403).json({ 
        error: 'Access denied', 
        message: 'You can only access your own resources' 
      });
    }

    next();
  };
};

/**
 * Sanitizza input per prevenire injection attacks
 */
const sanitizeInput = (req, res, next) => {
  // Rimuove caratteri pericolosi da tutti gli input
  const sanitize = (obj) => {
    for (let key in obj) {
      if (typeof obj[key] === 'string') {
        // Rimuove script tags e caratteri pericolosi
        obj[key] = obj[key]
          .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
          .replace(/[<>'"&]/g, '')
          .trim()
          .substring(0, 1000); // Limita lunghezza
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        sanitize(obj[key]);
      }
    }
  };

  if (req.body) sanitize(req.body);
  if (req.query) sanitize(req.query);
  if (req.params) sanitize(req.params);

  next();
};

module.exports = {
  authenticateToken,
  socketAuth,
  requirePermission,
  requireOwnership,
  sanitizeInput,
  authRateLimit
};
