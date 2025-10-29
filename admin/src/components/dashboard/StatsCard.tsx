import React from 'react';
import {
  Card,
  CardContent,
  Typography,
  Box,
  IconButton,
  Tooltip,
  LinearProgress,
} from '@mui/material';
import {
  TrendingUp,
  TrendingDown,
  TrendingFlat,
  Refresh,
} from '@mui/icons-material';
import { securevoxColors, securevoxGradient } from '../../theme/securevoxTheme';

interface StatsCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: React.ReactNode;
  trend?: {
    value: number;
    direction: 'up' | 'down' | 'flat';
    period: string;
  };
  progress?: {
    value: number;
    max: number;
    label?: string;
  };
  color?: string;
  onRefresh?: () => void;
  loading?: boolean;
}

const StatsCard: React.FC<StatsCardProps> = ({
  title,
  value,
  subtitle,
  icon,
  trend,
  progress,
  color = securevoxColors.primary,
  onRefresh,
  loading = false,
}) => {
  const getTrendIcon = () => {
    if (!trend) return null;
    
    switch (trend.direction) {
      case 'up':
        return <TrendingUp sx={{ fontSize: 16, color: securevoxColors.success }} />;
      case 'down':
        return <TrendingDown sx={{ fontSize: 16, color: securevoxColors.error }} />;
      case 'flat':
        return <TrendingFlat sx={{ fontSize: 16, color: securevoxColors.textSecondary }} />;
      default:
        return null;
    }
  };

  const getTrendColor = () => {
    if (!trend) return securevoxColors.textSecondary;
    
    switch (trend.direction) {
      case 'up':
        return securevoxColors.success;
      case 'down':
        return securevoxColors.error;
      case 'flat':
        return securevoxColors.textSecondary;
      default:
        return securevoxColors.textSecondary;
    }
  };

  const formatValue = (val: string | number) => {
    if (typeof val === 'number') {
      if (val >= 1000000) {
        return `${(val / 1000000).toFixed(1)}M`;
      } else if (val >= 1000) {
        return `${(val / 1000).toFixed(1)}K`;
      }
      return val.toLocaleString();
    }
    return val;
  };

  return (
    <Card
      sx={{
        height: '100%',
        background: securevoxGradient.card,
        borderRadius: 3,
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.1)',
        border: `1px solid ${securevoxColors.border}`,
        transition: 'all 0.3s ease',
        '&:hover': {
          transform: 'translateY(-4px)',
          boxShadow: '0 8px 30px rgba(0, 0, 0, 0.15)',
        },
      }}
    >
      <CardContent sx={{ p: 3 }}>
        {/* Header */}
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            mb: 2,
          }}
        >
          <Box
            sx={{
              width: 48,
              height: 48,
              borderRadius: 2,
              background: `${color}20`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: color,
            }}
          >
            {icon}
          </Box>
          
          {onRefresh && (
            <Tooltip title="Aggiorna">
              <IconButton
                size="small"
                onClick={onRefresh}
                disabled={loading}
                sx={{
                  color: securevoxColors.textSecondary,
                  '&:hover': {
                    backgroundColor: `${color}10`,
                    color: color,
                  },
                }}
              >
                <Refresh sx={{ fontSize: 18 }} />
              </IconButton>
            </Tooltip>
          )}
        </Box>

        {/* Content */}
        <Box>
          <Typography
            variant="h4"
            sx={{
              fontWeight: 700,
              color: securevoxColors.textPrimary,
              mb: 0.5,
            }}
          >
            {formatValue(value)}
          </Typography>

          <Typography
            variant="body2"
            sx={{
              color: securevoxColors.textSecondary,
              mb: 2,
            }}
          >
            {title}
          </Typography>

          {subtitle && (
            <Typography
              variant="caption"
              sx={{
                color: securevoxColors.textTertiary,
                display: 'block',
                mb: 1,
              }}
            >
              {subtitle}
            </Typography>
          )}

          {/* Progress Bar */}
          {progress && (
            <Box sx={{ mb: 2 }}>
              <Box
                sx={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  mb: 1,
                }}
              >
                <Typography variant="caption" color="textSecondary">
                  {progress.label || 'Progresso'}
                </Typography>
                <Typography variant="caption" color="textSecondary">
                  {progress.value}/{progress.max}
                </Typography>
              </Box>
              <LinearProgress
                variant="determinate"
                value={(progress.value / progress.max) * 100}
                sx={{
                  height: 6,
                  borderRadius: 3,
                  backgroundColor: `${color}20`,
                  '& .MuiLinearProgress-bar': {
                    backgroundColor: color,
                    borderRadius: 3,
                  },
                }}
              />
            </Box>
          )}

          {/* Trend */}
          {trend && (
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: 0.5,
              }}
            >
              {getTrendIcon()}
              <Typography
                variant="caption"
                sx={{
                  color: getTrendColor(),
                  fontWeight: 500,
                }}
              >
                {trend.direction === 'up' ? '+' : ''}{trend.value}% {trend.period}
              </Typography>
            </Box>
          )}
        </Box>
      </CardContent>
    </Card>
  );
};

export default StatsCard;
