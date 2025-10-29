import React, { createContext, useContext, useReducer, useEffect, ReactNode } from 'react';
import { User, AuthState, LoginCredentials } from '../types';
import apiService from '../services/api';

interface AuthContextType extends AuthState {
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

type AuthAction =
  | { type: 'LOGIN_START' }
  | { type: 'LOGIN_SUCCESS'; payload: User }
  | { type: 'LOGIN_FAILURE'; payload: string }
  | { type: 'LOGOUT' }
  | { type: 'REFRESH_USER'; payload: User }
  | { type: 'CLEAR_ERROR' };

// Funzioni per gestire il localStorage
const saveAuthState = (user: User) => {
  localStorage.setItem('securevox_auth_user', JSON.stringify(user));
  localStorage.setItem('securevox_auth_timestamp', Date.now().toString());
};

const getAuthState = (): { user: User | null; timestamp: number } => {
  const userStr = localStorage.getItem('securevox_auth_user');
  const timestampStr = localStorage.getItem('securevox_auth_timestamp');
  
  if (userStr && timestampStr) {
    try {
      const user = JSON.parse(userStr);
      const timestamp = parseInt(timestampStr);
      return { user, timestamp };
    } catch (error) {
      clearAuthState();
      return { user: null, timestamp: 0 };
    }
  }
  
  return { user: null, timestamp: 0 };
};

const clearAuthState = () => {
  localStorage.removeItem('securevox_auth_user');
  localStorage.removeItem('securevox_auth_timestamp');
};

// Verifica se la sessione è scaduta (24 ore)
const isSessionExpired = (timestamp: number): boolean => {
  const now = Date.now();
  const sessionDuration = 24 * 60 * 60 * 1000; // 24 ore in millisecondi
  return (now - timestamp) > sessionDuration;
};

const initialState: AuthState = {
  isAuthenticated: false,
  user: null,
  loading: true,
  error: null,
};

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case 'LOGIN_START':
      return {
        ...state,
        loading: true,
        error: null,
      };
    case 'LOGIN_SUCCESS':
      // Salva lo stato di autenticazione nel localStorage
      saveAuthState(action.payload);
      return {
        ...state,
        isAuthenticated: true,
        user: action.payload,
        loading: false,
        error: null,
      };
    case 'LOGIN_FAILURE':
      return {
        ...state,
        isAuthenticated: false,
        user: null,
        loading: false,
        error: action.payload,
      };
    case 'LOGOUT':
      // Pulisce lo stato di autenticazione dal localStorage
      clearAuthState();
      return {
        ...state,
        isAuthenticated: false,
        user: null,
        loading: false,
        error: null,
      };
    case 'REFRESH_USER':
      // Aggiorna anche il localStorage quando si aggiorna l'utente
      saveAuthState(action.payload);
      return {
        ...state,
        isAuthenticated: true,
        user: action.payload,
        loading: false,
        error: null,
      };
    case 'CLEAR_ERROR':
      return {
        ...state,
        error: null,
      };
    default:
      return state;
  }
}

interface AuthProviderProps {
  children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [state, dispatch] = useReducer(authReducer, initialState);

  // Verifica se l'utente è già autenticato al caricamento
  useEffect(() => {
    const checkAuth = async () => {
      try {
        // Prima controlla il localStorage
        const { user: savedUser, timestamp } = getAuthState();
        
        if (savedUser && !isSessionExpired(timestamp)) {
          // Se abbiamo un utente salvato e la sessione non è scaduta,
          // imposta l'utente come autenticato senza verificare con il backend
          // per evitare loop infiniti
          dispatch({ type: 'REFRESH_USER', payload: savedUser });
          return;
        } else if (savedUser && isSessionExpired(timestamp)) {
          // Sessione scaduta, pulisci
          clearAuthState();
        }
        
        // Nessuna sessione valida trovata
        dispatch({ type: 'LOGOUT' });
      } catch (error) {
        dispatch({ type: 'LOGOUT' });
      }
    };

    checkAuth();
  }, []);

  const login = async (credentials: LoginCredentials) => {
    dispatch({ type: 'LOGIN_START' });
    
    try {
      const authState = await apiService.login(credentials);
      
      if (authState.isAuthenticated && authState.user) {
        dispatch({ type: 'LOGIN_SUCCESS', payload: authState.user });
      } else {
        dispatch({ type: 'LOGIN_FAILURE', payload: authState.error || 'Login failed' });
      }
    } catch (error: any) {
      dispatch({ 
        type: 'LOGIN_FAILURE', 
        payload: error.response?.data?.error || 'Errore durante il login' 
      });
    }
  };

  const logout = async () => {
    try {
      await apiService.logout();
    } catch (error) {
      console.error('Errore durante il logout:', error);
    } finally {
      dispatch({ type: 'LOGOUT' });
      // Non facciamo più il redirect automatico, lasciamo che il componente App gestisca la navigazione
    }
  };

  const refreshUser = async () => {
    try {
      const user = await apiService.getCurrentUser();
      if (user) {
        dispatch({ type: 'REFRESH_USER', payload: user });
      } else {
        dispatch({ type: 'LOGOUT' });
      }
    } catch (error) {
      dispatch({ type: 'LOGOUT' });
    }
  };

  const value: AuthContextType = {
    ...state,
    login,
    logout,
    refreshUser,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
