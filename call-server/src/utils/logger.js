/**
 * SecureVox Call Server - Logger
 * Sistema di logging enterprise con Winston
 */

const winston = require('winston');
const path = require('path');

// Configurazione formato log
const logFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss'
  }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      service: 'call-server',
      ...meta
    });
  })
);

// Configurazione trasporti
const transports = [
  // Console output (sempre attivo)
  new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple(),
      winston.format.printf(({ timestamp, level, message, ...meta }) => {
        const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
        return `${timestamp} [${level}]: ${message} ${metaStr}`;
      })
    )
  })
];

// File logging (solo in produzione)
if (process.env.NODE_ENV === 'production') {
  const logDir = process.env.LOG_DIR || './logs';
  
  // Log generale
  transports.push(
    new winston.transports.File({
      filename: path.join(logDir, 'call-server.log'),
      format: logFormat,
      maxsize: 10485760, // 10MB
      maxFiles: 5,
      tailable: true
    })
  );
  
  // Log errori
  transports.push(
    new winston.transports.File({
      filename: path.join(logDir, 'call-server-error.log'),
      level: 'error',
      format: logFormat,
      maxsize: 10485760, // 10MB
      maxFiles: 3,
      tailable: true
    })
  );
}

// Creazione logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  transports,
  exitOnError: false
});

// Gestione errori non catturati
logger.exceptions.handle(
  new winston.transports.Console({
    format: winston.format.simple()
  })
);

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', { promise, reason });
});

// Funzioni helper per logging strutturato
logger.logCall = (action, sessionId, data = {}) => {
  logger.info(`Call ${action}`, {
    action,
    sessionId,
    category: 'call',
    ...data
  });
};

logger.logSignaling = (event, sessionId, data = {}) => {
  logger.debug(`Signaling ${event}`, {
    event,
    sessionId,
    category: 'signaling',
    ...data
  });
};

logger.logSecurity = (event, userId, data = {}) => {
  logger.warn(`Security ${event}`, {
    event,
    userId,
    category: 'security',
    ...data
  });
};

logger.logPerformance = (metric, value, data = {}) => {
  logger.info(`Performance ${metric}`, {
    metric,
    value,
    category: 'performance',
    ...data
  });
};

// Middleware per logging richieste HTTP
logger.httpMiddleware = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id
    };
    
    if (res.statusCode >= 400) {
      logger.warn('HTTP Request', logData);
    } else {
      logger.info('HTTP Request', logData);
    }
  });
  
  next();
};

module.exports = logger;

