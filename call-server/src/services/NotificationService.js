/**
 * SecureVox Notification Service
 * Gestisce notifiche push per chiamate in arrivo
 */

const axios = require('axios');
const logger = require('../utils/logger');

class NotificationService {
  constructor() {
    this.notifyServerUrl = process.env.NOTIFY_SERVER_URL || 'http://localhost:8002';
    this.apiKey = process.env.NOTIFY_SERVER_API_KEY || 'default-key';
  }

  /**
   * Invia notifica di chiamata in arrivo
   */
  async sendIncomingCallNotification(calleeId, callerInfo, callData) {
    try {
      logger.info(`📱 Sending incoming call notification to user ${calleeId}`);

      const notification = {
        type: 'incoming_call',
        userId: calleeId,
        title: `Chiamata ${callData.callType === 'video' ? 'video' : 'audio'} in arrivo`,
        body: `${callerInfo.name} ti sta chiamando`,
        data: {
          sessionId: callData.sessionId,
          callerId: callData.callerId,
          callerName: callerInfo.name,
          callerAvatar: callerInfo.avatar || '',
          callType: callData.callType,
          timestamp: new Date().toISOString()
        },
        priority: 'high',
        sound: 'call_ringtone.mp3',
        vibration: [0, 1000, 500, 1000],
        actions: [
          {
            id: 'answer',
            title: 'Rispondi',
            icon: 'ic_call_answer'
          },
          {
            id: 'decline',
            title: 'Rifiuta',
            icon: 'ic_call_decline'
          }
        ]
      };

      // Invia al notification server
      const response = await axios.post(
        `${this.notifyServerUrl}/api/notifications/send`,
        notification,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 5000
        }
      );

      if (response.status === 200) {
        logger.info(`✅ Incoming call notification sent successfully to user ${calleeId}`);
        return true;
      } else {
        logger.error(`❌ Failed to send notification: ${response.status}`);
        return false;
      }

    } catch (error) {
      logger.error(`❌ Notification service error: ${error.message}`);
      return false;
    }
  }

  /**
   * Invia notifica di chiamata persa
   */
  async sendMissedCallNotification(userId, callerInfo, callData) {
    try {
      logger.info(`📱 Sending missed call notification to user ${userId}`);

      const notification = {
        type: 'missed_call',
        userId: userId,
        title: 'Chiamata persa',
        body: `Chiamata persa da ${callerInfo.name}`,
        data: {
          sessionId: callData.sessionId,
          callerId: callData.callerId,
          callerName: callerInfo.name,
          callerAvatar: callerInfo.avatar || '',
          callType: callData.callType,
          timestamp: new Date().toISOString()
        },
        priority: 'normal',
        sound: 'notification.mp3'
      };

      const response = await axios.post(
        `${this.notifyServerUrl}/api/notifications/send`,
        notification,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 5000
        }
      );

      if (response.status === 200) {
        logger.info(`✅ Missed call notification sent to user ${userId}`);
        return true;
      }

    } catch (error) {
      logger.error(`❌ Missed call notification error: ${error.message}`);
    }

    return false;
  }

  /**
   * Cancella notifica di chiamata in arrivo
   */
  async cancelIncomingCallNotification(userId, sessionId) {
    try {
      logger.info(`🚫 Cancelling incoming call notification for user ${userId}`);

      const response = await axios.delete(
        `${this.notifyServerUrl}/api/notifications/cancel`,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          data: {
            userId: userId,
            type: 'incoming_call',
            sessionId: sessionId
          },
          timeout: 5000
        }
      );

      if (response.status === 200) {
        logger.info(`✅ Incoming call notification cancelled for user ${userId}`);
        return true;
      }

    } catch (error) {
      logger.error(`❌ Cancel notification error: ${error.message}`);
    }

    return false;
  }

  /**
   * Invia notifica di stato chiamata
   */
  async sendCallStatusNotification(userId, status, callData) {
    try {
      const statusMessages = {
        'answered': 'Chiamata in corso',
        'ended': 'Chiamata terminata',
        'failed': 'Chiamata fallita',
        'timeout': 'Chiamata non risposta'
      };

      const message = statusMessages[status] || `Stato chiamata: ${status}`;

      const notification = {
        type: 'call_status',
        userId: userId,
        title: 'SecureVox',
        body: message,
        data: {
          sessionId: callData.sessionId,
          status: status,
          timestamp: new Date().toISOString()
        },
        priority: 'normal'
      };

      const response = await axios.post(
        `${this.notifyServerUrl}/api/notifications/send`,
        notification,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 5000
        }
      );

      logger.info(`📱 Call status notification sent: ${status} to user ${userId}`);

    } catch (error) {
      logger.error(`❌ Call status notification error: ${error.message}`);
    }
  }

  /**
   * Ottiene informazioni utente per notifiche
   */
  async getUserInfo(userId) {
    try {
      // TODO: Integrare con API utenti
      const mockUsers = {
        '2': {
          name: 'Raffaele Amoroso',
          avatar: '/api/media/download/avatars/2_ae28338a-b9a4-49c1-9348-0c4d215217d8.jpg'
        },
        '3': {
          name: 'Riccardo Dicamillo',
          avatar: null
        }
      };

      return mockUsers[userId] || {
        name: `User ${userId}`,
        avatar: null
      };

    } catch (error) {
      logger.error(`❌ Get user info error: ${error.message}`);
      return {
        name: `User ${userId}`,
        avatar: null
      };
    }
  }

  /**
   * Testa connessione al notification server
   */
  async testConnection() {
    try {
      const response = await axios.get(
        `${this.notifyServerUrl}/health`,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`
          },
          timeout: 5000
        }
      );

      if (response.status === 200) {
        logger.info(`✅ Notification server connection OK`);
        return true;
      }

    } catch (error) {
      logger.warn(`⚠️ Notification server not available: ${error.message}`);
    }

    return false;
  }
}

module.exports = NotificationService;

