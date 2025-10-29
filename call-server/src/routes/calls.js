/**
 * SecureVox Call Server - Calls Routes
 * API endpoints per gestione chiamate
 */

const express = require('express');
const { requirePermission, requireOwnership, sanitizeInput } = require('../middleware/auth');
const logger = require('../utils/logger');

module.exports = (callManager, notificationService) => {
  const router = express.Router();

  // Middleware di sanitizzazione per tutte le route
  router.use(sanitizeInput);

  /**
   * POST /api/calls/create
   * Crea una nuova sessione di chiamata
   */
  router.post('/create', async (req, res) => {
    try {
      const { callee_id, call_type = 'video', encrypted_payload } = req.body;
      const caller_id = req.user.id;

      // Validazione input
      if (!callee_id) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'callee_id è obbligatorio'
        });
      }

      if (!['audio', 'video'].includes(call_type)) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'call_type deve essere audio o video'
        });
      }

      // Verifica che non stia chiamando se stesso
      if (caller_id === callee_id) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'Non puoi chiamare te stesso'
        });
      }

      logger.info(`📞 Creating call: ${caller_id} -> ${callee_id} (${call_type})`);

      // Crea sessione di chiamata
      const callSession = await callManager.createCall(
        caller_id,
        callee_id,
        call_type,
        {
          encryptedPayload: encrypted_payload,
          userAgent: req.headers['user-agent'],
          clientIp: req.ip
        }
      );

      if (!callSession) {
        return res.status(500).json({
          error: 'CALL_CREATION_FAILED',
          message: 'Impossibile creare la sessione di chiamata'
        });
      }

      // Invia notifica push al destinatario
      try {
        const callerInfo = await notificationService.getUserInfo(caller_id);
        await notificationService.sendIncomingCallNotification(
          callee_id,
          callerInfo,
          {
            sessionId: callSession.callId,
            callerId: caller_id,
            callType: call_type
          }
        );
      } catch (notifyError) {
        logger.warn(`⚠️ Failed to send push notification: ${notifyError.message}`);
        // Non bloccare la chiamata se la notifica fallisce
      }

      res.status(201).json({
        session_id: callSession.callId,
        room_id: callSession.callId,
        call_type: call_type,
        ice_servers: callSession.iceServers,
        signaling_endpoint: callSession.signalingEndpoint,
        turn_credentials: callSession.turnCredentials,
        mode: 'p2p',
        created_at: new Date().toISOString()
      });

      logger.info(`✅ Call session created: ${callSession.callId}`);

    } catch (error) {
      logger.error(`❌ Call creation error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * POST /api/calls/answer
   * Risponde a una chiamata in arrivo
   */
  router.post('/answer', async (req, res) => {
    try {
      const { session_id } = req.body;
      const user_id = req.user.id;

      if (!session_id) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'session_id è obbligatorio'
        });
      }

      logger.info(`📞 Answering call: ${session_id} by user ${user_id}`);

      // Verifica e aggiorna sessione
      const result = await callManager.answerCall(session_id, user_id);

      if (!result.success) {
        return res.status(400).json({
          error: result.error || 'ANSWER_FAILED',
          message: result.message || 'Impossibile rispondere alla chiamata'
        });
      }

      // Cancella notifica push
      try {
        await notificationService.cancelIncomingCallNotification(user_id, session_id);
      } catch (notifyError) {
        logger.warn(`⚠️ Failed to cancel notification: ${notifyError.message}`);
      }

      res.json({
        session_id: session_id,
        status: 'answered',
        ice_servers: result.iceServers,
        answered_at: new Date().toISOString()
      });

      logger.info(`✅ Call answered: ${session_id}`);

    } catch (error) {
      logger.error(`❌ Call answer error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * POST /api/calls/reject
   * Rifiuta una chiamata in arrivo
   */
  router.post('/reject', async (req, res) => {
    try {
      const { session_id, reason = 'declined' } = req.body;
      const user_id = req.user.id;

      if (!session_id) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'session_id è obbligatorio'
        });
      }

      logger.info(`❌ Rejecting call: ${session_id} by user ${user_id} (${reason})`);

      const result = await callManager.rejectCall(session_id, user_id, reason);

      if (!result.success) {
        return res.status(400).json({
          error: result.error || 'REJECT_FAILED',
          message: result.message || 'Impossibile rifiutare la chiamata'
        });
      }

      // Cancella notifica push
      try {
        await notificationService.cancelIncomingCallNotification(user_id, session_id);
      } catch (notifyError) {
        logger.warn(`⚠️ Failed to cancel notification: ${notifyError.message}`);
      }

      res.json({
        session_id: session_id,
        status: 'rejected',
        reason: reason,
        rejected_at: new Date().toISOString()
      });

      logger.info(`✅ Call rejected: ${session_id}`);

    } catch (error) {
      logger.error(`❌ Call reject error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * POST /api/calls/end
   * Termina una chiamata attiva
   */
  router.post('/end', async (req, res) => {
    try {
      const { session_id } = req.body;
      const user_id = req.user.id;

      if (!session_id) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'session_id è obbligatorio'
        });
      }

      logger.info(`🔚 Ending call: ${session_id} by user ${user_id}`);

      const result = await callManager.endCall(session_id, user_id);

      if (!result.success) {
        return res.status(400).json({
          error: result.error || 'END_FAILED',
          message: result.message || 'Impossibile terminare la chiamata'
        });
      }

      res.json({
        session_id: session_id,
        status: 'ended',
        duration: result.duration,
        ended_at: new Date().toISOString()
      });

      logger.info(`✅ Call ended: ${session_id} (duration: ${result.duration}ms)`);

    } catch (error) {
      logger.error(`❌ Call end error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * GET /api/calls/active
   * Ottiene chiamate attive dell'utente
   */
  router.get('/active', async (req, res) => {
    try {
      const user_id = req.user.id;

      const activeCalls = await callManager.getActiveCalls(user_id);

      res.json({
        active_calls: activeCalls,
        count: activeCalls.length
      });

    } catch (error) {
      logger.error(`❌ Get active calls error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * GET /api/calls/history
   * Ottiene cronologia chiamate dell'utente
   */
  router.get('/history', async (req, res) => {
    try {
      const user_id = req.user.id;
      const { limit = 50, offset = 0, type } = req.query;

      const history = await callManager.getCallHistory(user_id, {
        limit: parseInt(limit),
        offset: parseInt(offset),
        type: type
      });

      res.json({
        calls: history.calls,
        total: history.total,
        limit: parseInt(limit),
        offset: parseInt(offset)
      });

    } catch (error) {
      logger.error(`❌ Get call history error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * GET /api/calls/:sessionId/stats
   * Ottiene statistiche di una chiamata specifica
   */
  router.get('/:sessionId/stats', requireOwnership('sessionId'), async (req, res) => {
    try {
      const { sessionId } = req.params;

      const stats = await callManager.getCallStats(sessionId);

      if (!stats) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Chiamata non trovata'
        });
      }

      res.json(stats);

    } catch (error) {
      logger.error(`❌ Get call stats error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  /**
   * POST /api/calls/group
   * Crea una chiamata di gruppo
   */
  router.post('/group', async (req, res) => {
    try {
      const { room_name, max_participants = 10, participants = [] } = req.body;
      const creator_id = req.user.id;

      if (!room_name) {
        return res.status(400).json({
          error: 'BAD_REQUEST',
          message: 'room_name è obbligatorio'
        });
      }

      logger.info(`👥 Creating group call: ${room_name} by user ${creator_id}`);

      const groupCall = await callManager.createGroupCall(
        creator_id,
        room_name,
        max_participants,
        participants
      );

      if (!groupCall) {
        return res.status(500).json({
          error: 'GROUP_CALL_CREATION_FAILED',
          message: 'Impossibile creare la chiamata di gruppo'
        });
      }

      res.status(201).json(groupCall);

      logger.info(`✅ Group call created: ${groupCall.session_id}`);

    } catch (error) {
      logger.error(`❌ Group call creation error: ${error.message}`);
      res.status(500).json({
        error: 'INTERNAL_ERROR',
        message: 'Errore interno del server'
      });
    }
  });

  return router;
};

