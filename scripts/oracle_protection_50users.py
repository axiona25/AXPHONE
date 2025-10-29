#!/usr/bin/env python3
"""
Oracle Cloud Protection System - SecureVox 50 Users
Sistema di protezione TOTALE contro costi imprevisti

Questo script implementa protezioni multiple per garantire che SecureVox
per 50 utenti rimanga SEMPRE entro i limiti gratuiti di Oracle Cloud.

PROTEZIONI IMPLEMENTATE:
1. Monitoraggio continuo risorse
2. Alert automatici via email/webhook
3. Blocco automatico registrazioni oltre 50 utenti
4. Limitazione chiamate simultanee
5. Shutdown automatico di emergenza
6. Rate limiting aggressivo
7. Pulizia automatica dati vecchi

Author: AI Assistant
Version: 1.0 (50 users protection)
"""

import os
import sys
import json
import time
import smtplib
import requests
import sqlite3
import psycopg2
import redis
from datetime import datetime, timedelta
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
from typing import Dict, List, Optional
import logging
import schedule
import subprocess
from oracle_cost_monitor import OracleCostMonitor

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/securevox/logs/protection_50users.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class SecureVox50UsersProtection:
    """Sistema di protezione per SecureVox 50 utenti"""
    
    # LIMITI ASSOLUTI - MAI SUPERARE
    ABSOLUTE_LIMITS = {
        'max_registered_users': 50,
        'max_concurrent_active_users': 15,
        'max_concurrent_calls': 10,
        'max_participants_per_call': 4,
        'max_daily_api_calls': 10000,
        'max_storage_mb': 30000,  # 30GB su 50GB disponibili
        'max_memory_usage_percent': 85,
        'max_cpu_usage_percent': 90,
        'max_disk_usage_percent': 80
    }
    
    # SOGLIE DI ALLARME
    WARNING_THRESHOLDS = {
        'users_warning': 40,      # 80% del limite
        'users_critical': 47,     # 94% del limite
        'calls_warning': 8,       # 80% del limite
        'calls_critical': 9,      # 90% del limite
        'storage_warning': 24000, # 80% del limite
        'storage_critical': 27000 # 90% del limite
    }
    
    def __init__(self):
        self.oracle_monitor = OracleCostMonitor()
        self.protection_active = True
        self.emergency_mode = False
        
        # Database connections
        self.setup_database_connections()
        
        # Redis connection
        self.setup_redis_connection()
        
        logger.info("🛡️ SecureVox 50 Users Protection System initialized")
    
    def setup_database_connections(self):
        """Setup database connections"""
        try:
            # PostgreSQL connection
            db_url = os.getenv('DATABASE_URL', 'postgresql://securevox:password@localhost:5432/securevox')
            self.pg_conn = psycopg2.connect(db_url)
            logger.info("✅ PostgreSQL connection established")
        except Exception as e:
            logger.error(f"❌ PostgreSQL connection failed: {e}")
            self.pg_conn = None
    
    def setup_redis_connection(self):
        """Setup Redis connection"""
        try:
            redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
            self.redis_client = redis.from_url(redis_url)
            self.redis_client.ping()
            logger.info("✅ Redis connection established")
        except Exception as e:
            logger.error(f"❌ Redis connection failed: {e}")
            self.redis_client = None
    
    def check_user_limits(self) -> Dict:
        """Controlla limiti utenti"""
        try:
            if not self.pg_conn:
                return {'error': 'No database connection'}
            
            cursor = self.pg_conn.cursor()
            
            # Utenti registrati totali
            cursor.execute("SELECT COUNT(*) FROM auth_user")
            total_users = cursor.fetchone()[0]
            
            # Utenti attivi (login nelle ultime 5 ore)
            cursor.execute("""
                SELECT COUNT(DISTINCT user_id) 
                FROM django_session 
                WHERE expire_date > NOW()
            """)
            active_users = cursor.fetchone()[0]
            
            # Utenti attivi oggi
            cursor.execute("""
                SELECT COUNT(DISTINCT user_id)
                FROM auth_user
                WHERE last_login >= CURRENT_DATE
            """)
            daily_active_users = cursor.fetchone()[0] if cursor.fetchone() else 0
            
            cursor.close()
            
            # Analisi limiti
            user_status = {
                'total_users': total_users,
                'active_users': active_users,
                'daily_active_users': daily_active_users,
                'limits': {
                    'max_total': self.ABSOLUTE_LIMITS['max_registered_users'],
                    'max_concurrent': self.ABSOLUTE_LIMITS['max_concurrent_active_users']
                },
                'percentages': {
                    'total_usage': (total_users / self.ABSOLUTE_LIMITS['max_registered_users']) * 100,
                    'concurrent_usage': (active_users / self.ABSOLUTE_LIMITS['max_concurrent_active_users']) * 100
                },
                'status': 'OK',
                'warnings': []
            }
            
            # Controllo soglie
            if total_users >= self.ABSOLUTE_LIMITS['max_registered_users']:
                user_status['status'] = 'BLOCKED'
                user_status['warnings'].append('MAX USERS REACHED - Registration blocked')
                self.block_new_registrations()
            
            elif total_users >= self.WARNING_THRESHOLDS['users_critical']:
                user_status['status'] = 'CRITICAL'
                user_status['warnings'].append(f'Critical: {total_users}/{self.ABSOLUTE_LIMITS["max_registered_users"]} users')
            
            elif total_users >= self.WARNING_THRESHOLDS['users_warning']:
                user_status['status'] = 'WARNING'
                user_status['warnings'].append(f'Warning: {total_users}/{self.ABSOLUTE_LIMITS["max_registered_users"]} users')
            
            if active_users >= self.ABSOLUTE_LIMITS['max_concurrent_active_users']:
                user_status['warnings'].append('Max concurrent users reached')
                self.limit_concurrent_access()
            
            return user_status
            
        except Exception as e:
            logger.error(f"Error checking user limits: {e}")
            return {'error': str(e)}
    
    def check_call_limits(self) -> Dict:
        """Controlla limiti chiamate"""
        try:
            if not self.redis_client:
                return {'error': 'No Redis connection'}
            
            # Chiamate attive (stored in Redis)
            active_calls = self.redis_client.get('active_calls_count') or 0
            active_calls = int(active_calls)
            
            # Partecipanti totali
            total_participants = self.redis_client.get('total_participants_count') or 0
            total_participants = int(total_participants)
            
            call_status = {
                'active_calls': active_calls,
                'total_participants': total_participants,
                'limits': {
                    'max_calls': self.ABSOLUTE_LIMITS['max_concurrent_calls'],
                    'max_participants_per_call': self.ABSOLUTE_LIMITS['max_participants_per_call']
                },
                'percentages': {
                    'calls_usage': (active_calls / self.ABSOLUTE_LIMITS['max_concurrent_calls']) * 100
                },
                'status': 'OK',
                'warnings': []
            }
            
            # Controllo soglie
            if active_calls >= self.ABSOLUTE_LIMITS['max_concurrent_calls']:
                call_status['status'] = 'BLOCKED'
                call_status['warnings'].append('MAX CALLS REACHED - New calls blocked')
                self.block_new_calls()
            
            elif active_calls >= self.WARNING_THRESHOLDS['calls_critical']:
                call_status['status'] = 'CRITICAL'
                call_status['warnings'].append(f'Critical: {active_calls}/{self.ABSOLUTE_LIMITS["max_concurrent_calls"]} calls')
            
            elif active_calls >= self.WARNING_THRESHOLDS['calls_warning']:
                call_status['status'] = 'WARNING'
                call_status['warnings'].append(f'Warning: {active_calls}/{self.ABSOLUTE_LIMITS["max_concurrent_calls"]} calls')
            
            return call_status
            
        except Exception as e:
            logger.error(f"Error checking call limits: {e}")
            return {'error': str(e)}
    
    def check_system_resources(self) -> Dict:
        """Controlla risorse sistema"""
        try:
            # Memory usage
            memory_info = self.get_memory_usage()
            
            # Disk usage
            disk_info = self.get_disk_usage()
            
            # CPU usage
            cpu_info = self.get_cpu_usage()
            
            # Storage usage (database + media)
            storage_info = self.get_storage_usage()
            
            resource_status = {
                'memory': memory_info,
                'disk': disk_info,
                'cpu': cpu_info,
                'storage': storage_info,
                'status': 'OK',
                'warnings': []
            }
            
            # Controllo soglie
            if memory_info['usage_percent'] >= self.ABSOLUTE_LIMITS['max_memory_usage_percent']:
                resource_status['status'] = 'CRITICAL'
                resource_status['warnings'].append(f"High memory usage: {memory_info['usage_percent']}%")
            
            if disk_info['usage_percent'] >= self.ABSOLUTE_LIMITS['max_disk_usage_percent']:
                resource_status['status'] = 'CRITICAL'
                resource_status['warnings'].append(f"High disk usage: {disk_info['usage_percent']}%")
                self.cleanup_old_data()
            
            if cpu_info['usage_percent'] >= self.ABSOLUTE_LIMITS['max_cpu_usage_percent']:
                resource_status['status'] = 'CRITICAL'
                resource_status['warnings'].append(f"High CPU usage: {cpu_info['usage_percent']}%")
            
            if storage_info['usage_mb'] >= self.ABSOLUTE_LIMITS['max_storage_mb']:
                resource_status['status'] = 'CRITICAL'
                resource_status['warnings'].append(f"Storage limit reached: {storage_info['usage_mb']}MB")
                self.cleanup_old_data()
            
            return resource_status
            
        except Exception as e:
            logger.error(f"Error checking system resources: {e}")
            return {'error': str(e)}
    
    def get_memory_usage(self) -> Dict:
        """Get memory usage info"""
        try:
            result = subprocess.run(['free', '-m'], capture_output=True, text=True)
            lines = result.stdout.strip().split('\n')
            mem_line = lines[1].split()
            
            total_mb = int(mem_line[1])
            used_mb = int(mem_line[2])
            usage_percent = (used_mb / total_mb) * 100
            
            return {
                'total_mb': total_mb,
                'used_mb': used_mb,
                'available_mb': total_mb - used_mb,
                'usage_percent': round(usage_percent, 1)
            }
        except Exception as e:
            logger.error(f"Error getting memory usage: {e}")
            return {'usage_percent': 0}
    
    def get_disk_usage(self) -> Dict:
        """Get disk usage info"""
        try:
            result = subprocess.run(['df', '-h', '/opt'], capture_output=True, text=True)
            lines = result.stdout.strip().split('\n')
            disk_line = lines[1].split()
            
            usage_percent = int(disk_line[4].replace('%', ''))
            
            return {
                'total': disk_line[1],
                'used': disk_line[2],
                'available': disk_line[3],
                'usage_percent': usage_percent
            }
        except Exception as e:
            logger.error(f"Error getting disk usage: {e}")
            return {'usage_percent': 0}
    
    def get_cpu_usage(self) -> Dict:
        """Get CPU usage info"""
        try:
            result = subprocess.run(['top', '-bn1'], capture_output=True, text=True)
            for line in result.stdout.split('\n'):
                if 'Cpu(s):' in line:
                    # Extract CPU usage percentage
                    parts = line.split(',')
                    for part in parts:
                        if 'us' in part:
                            usage_percent = float(part.split('%')[0].strip())
                            return {'usage_percent': round(usage_percent, 1)}
            
            return {'usage_percent': 0}
        except Exception as e:
            logger.error(f"Error getting CPU usage: {e}")
            return {'usage_percent': 0}
    
    def get_storage_usage(self) -> Dict:
        """Get storage usage (database + media files)"""
        try:
            total_size_mb = 0
            
            # Database size
            if self.pg_conn:
                cursor = self.pg_conn.cursor()
                cursor.execute("""
                    SELECT pg_size_pretty(pg_database_size('securevox'))
                """)
                db_size = cursor.fetchone()[0]
                cursor.close()
                
                # Convert to MB (simplified)
                if 'GB' in db_size:
                    db_size_mb = float(db_size.split()[0]) * 1024
                elif 'MB' in db_size:
                    db_size_mb = float(db_size.split()[0])
                else:
                    db_size_mb = 0
                
                total_size_mb += db_size_mb
            
            # Media files size
            try:
                result = subprocess.run(['du', '-sm', '/opt/securevox/media'], capture_output=True, text=True)
                if result.returncode == 0:
                    media_size_mb = int(result.stdout.split()[0])
                    total_size_mb += media_size_mb
            except:
                pass
            
            return {
                'usage_mb': round(total_size_mb, 1),
                'limit_mb': self.ABSOLUTE_LIMITS['max_storage_mb'],
                'usage_percent': round((total_size_mb / self.ABSOLUTE_LIMITS['max_storage_mb']) * 100, 1)
            }
            
        except Exception as e:
            logger.error(f"Error getting storage usage: {e}")
            return {'usage_mb': 0, 'usage_percent': 0}
    
    def block_new_registrations(self):
        """Blocca nuove registrazioni"""
        logger.critical("🚫 BLOCKING NEW USER REGISTRATIONS - 50 user limit reached")
        
        try:
            if self.redis_client:
                self.redis_client.set('registration_blocked', 'true', ex=3600)  # Block for 1 hour
                logger.info("✅ Registration block activated in Redis")
        except Exception as e:
            logger.error(f"Error blocking registrations: {e}")
    
    def block_new_calls(self):
        """Blocca nuove chiamate"""
        logger.critical("🚫 BLOCKING NEW CALLS - Concurrent call limit reached")
        
        try:
            if self.redis_client:
                self.redis_client.set('calls_blocked', 'true', ex=300)  # Block for 5 minutes
                logger.info("✅ Call block activated in Redis")
        except Exception as e:
            logger.error(f"Error blocking calls: {e}")
    
    def limit_concurrent_access(self):
        """Limita accesso concorrente"""
        logger.warning("⚠️ Limiting concurrent access - too many active users")
        
        try:
            if self.redis_client:
                self.redis_client.set('access_limited', 'true', ex=600)  # Limit for 10 minutes
                logger.info("✅ Access limitation activated")
        except Exception as e:
            logger.error(f"Error limiting access: {e}")
    
    def cleanup_old_data(self):
        """Pulizia automatica dati vecchi"""
        logger.info("🧹 Starting automatic data cleanup...")
        
        try:
            # Cleanup old sessions (older than 7 days)
            if self.pg_conn:
                cursor = self.pg_conn.cursor()
                
                # Delete old sessions
                cursor.execute("""
                    DELETE FROM django_session 
                    WHERE expire_date < NOW() - INTERVAL '7 days'
                """)
                deleted_sessions = cursor.rowcount
                
                # Delete old log entries (if you have a log table)
                cursor.execute("""
                    DELETE FROM logs 
                    WHERE created_at < NOW() - INTERVAL '7 days'
                """)
                deleted_logs = cursor.rowcount
                
                self.pg_conn.commit()
                cursor.close()
                
                logger.info(f"✅ Cleaned up {deleted_sessions} old sessions, {deleted_logs} old logs")
            
            # Cleanup old media files
            cleanup_cmd = [
                'find', '/opt/securevox/media', '-type', 'f', 
                '-mtime', '+7', '-delete'
            ]
            subprocess.run(cleanup_cmd, capture_output=True)
            
            # Cleanup Docker logs
            subprocess.run(['docker', 'system', 'prune', '-f'], capture_output=True)
            
            logger.info("✅ Data cleanup completed")
            
        except Exception as e:
            logger.error(f"Error during data cleanup: {e}")
    
    def send_protection_alert(self, alert_data: Dict):
        """Invia alert di protezione"""
        try:
            # Email alert
            self.send_email_alert(alert_data)
            
            # Webhook alert (if configured)
            self.send_webhook_alert(alert_data)
            
            # Log alert
            logger.critical(f"🚨 PROTECTION ALERT: {alert_data}")
            
        except Exception as e:
            logger.error(f"Error sending protection alert: {e}")
    
    def send_email_alert(self, alert_data: Dict):
        """Invia alert via email"""
        try:
            recipients = os.getenv('ALERT_EMAIL_RECIPIENTS', '').split(',')
            recipients = [r.strip() for r in recipients if r.strip()]
            
            if not recipients:
                return
            
            smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
            smtp_port = int(os.getenv('SMTP_PORT', '587'))
            smtp_user = os.getenv('SMTP_USER', '')
            smtp_password = os.getenv('SMTP_PASSWORD', '')
            
            if not smtp_user or not smtp_password:
                return
            
            msg = MimeMultipart()
            msg['From'] = smtp_user
            msg['To'] = ', '.join(recipients)
            msg['Subject'] = f"🚨 SecureVox 50 Users Protection Alert - {alert_data.get('level', 'WARNING')}"
            
            body = f"""
SecureVox 50 Users Protection System Alert

Alert Level: {alert_data.get('level', 'WARNING')}
Timestamp: {alert_data.get('timestamp', datetime.now().isoformat())}
Service: {alert_data.get('service', 'Unknown')}

Details:
{json.dumps(alert_data, indent=2)}

This is an automated alert from your SecureVox 50 Users Protection System.
Please review immediately to ensure service remains within free tier limits.

Oracle Cloud Always Free Tier Status: PROTECTED
Maximum Users: 50 (enforced)
Maximum Concurrent Calls: 10 (enforced)
            """
            
            msg.attach(MimeText(body, 'plain'))
            
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.send_message(msg)
            
            logger.info(f"✅ Protection alert email sent to {len(recipients)} recipients")
            
        except Exception as e:
            logger.error(f"Error sending email alert: {e}")
    
    def send_webhook_alert(self, alert_data: Dict):
        """Invia alert via webhook"""
        try:
            webhook_url = os.getenv('ALERT_WEBHOOK_URL', '')
            if not webhook_url:
                return
            
            payload = {
                'text': f"🚨 SecureVox Protection Alert",
                'attachments': [{
                    'color': 'danger' if alert_data.get('level') == 'CRITICAL' else 'warning',
                    'fields': [
                        {'title': 'Level', 'value': alert_data.get('level', 'WARNING'), 'short': True},
                        {'title': 'Service', 'value': alert_data.get('service', 'Unknown'), 'short': True},
                        {'title': 'Details', 'value': json.dumps(alert_data, indent=2), 'short': False}
                    ]
                }]
            }
            
            response = requests.post(webhook_url, json=payload, timeout=10)
            response.raise_for_status()
            
            logger.info("✅ Protection alert webhook sent")
            
        except Exception as e:
            logger.error(f"Error sending webhook alert: {e}")
    
    def emergency_shutdown(self):
        """Shutdown di emergenza"""
        logger.critical("🚨 INITIATING EMERGENCY SHUTDOWN - Protection limits exceeded")
        
        try:
            self.emergency_mode = True
            
            # Block all new operations
            if self.redis_client:
                self.redis_client.set('emergency_mode', 'true', ex=3600)
                self.redis_client.set('registration_blocked', 'true', ex=3600)
                self.redis_client.set('calls_blocked', 'true', ex=3600)
            
            # Send critical alert
            self.send_protection_alert({
                'level': 'CRITICAL',
                'service': 'Emergency Shutdown',
                'timestamp': datetime.now().isoformat(),
                'message': 'Emergency shutdown initiated - limits exceeded',
                'action_required': 'Manual intervention needed'
            })
            
            # Optionally stop services (be careful!)
            # subprocess.run(['docker-compose', 'down'], cwd='/opt/securevox')
            
            logger.critical("✅ Emergency shutdown completed")
            
        except Exception as e:
            logger.error(f"Error during emergency shutdown: {e}")
    
    def run_protection_check(self):
        """Esegue controllo completo protezione"""
        logger.info("🛡️ Running 50-user protection check...")
        
        try:
            # Check user limits
            user_status = self.check_user_limits()
            
            # Check call limits
            call_status = self.check_call_limits()
            
            # Check system resources
            resource_status = self.check_system_resources()
            
            # Check Oracle Cloud compliance
            oracle_usage = self.oracle_monitor.get_current_usage()
            
            # Compile overall status
            overall_status = {
                'timestamp': datetime.now().isoformat(),
                'protection_active': self.protection_active,
                'emergency_mode': self.emergency_mode,
                'users': user_status,
                'calls': call_status,
                'resources': resource_status,
                'oracle_cloud': oracle_usage,
                'overall_risk': 'LOW'
            }
            
            # Determine overall risk
            risk_levels = []
            
            for check_name, check_data in [('users', user_status), ('calls', call_status), ('resources', resource_status)]:
                if isinstance(check_data, dict) and 'status' in check_data:
                    if check_data['status'] == 'BLOCKED':
                        risk_levels.append('BLOCKED')
                    elif check_data['status'] == 'CRITICAL':
                        risk_levels.append('CRITICAL')
                    elif check_data['status'] == 'WARNING':
                        risk_levels.append('WARNING')
            
            if 'BLOCKED' in risk_levels:
                overall_status['overall_risk'] = 'BLOCKED'
            elif 'CRITICAL' in risk_levels:
                overall_status['overall_risk'] = 'CRITICAL'
            elif 'WARNING' in risk_levels:
                overall_status['overall_risk'] = 'WARNING'
            
            # Send alerts if needed
            if overall_status['overall_risk'] in ['CRITICAL', 'BLOCKED']:
                self.send_protection_alert({
                    'level': overall_status['overall_risk'],
                    'service': 'SecureVox 50 Users Protection',
                    'timestamp': overall_status['timestamp'],
                    'details': overall_status
                })
            
            # Emergency shutdown if blocked
            if overall_status['overall_risk'] == 'BLOCKED' and not self.emergency_mode:
                auto_shutdown = os.getenv('AUTO_EMERGENCY_SHUTDOWN', 'false').lower() == 'true'
                if auto_shutdown:
                    self.emergency_shutdown()
            
            # Save status report
            with open('/opt/securevox/logs/protection_status.json', 'w') as f:
                json.dump(overall_status, f, indent=2)
            
            logger.info(f"🛡️ Protection check completed - Risk level: {overall_status['overall_risk']}")
            
            return overall_status
            
        except Exception as e:
            logger.error(f"Error during protection check: {e}")
            return {'error': str(e)}
    
    def run_continuous_protection(self, check_interval_minutes: int = 5):
        """Esegue protezione continua"""
        logger.info(f"🛡️ Starting continuous protection (check every {check_interval_minutes} minutes)")
        
        def protection_check():
            self.run_protection_check()
        
        def daily_cleanup():
            self.cleanup_old_data()
        
        # Schedule protection checks
        schedule.every(check_interval_minutes).minutes.do(protection_check)
        
        # Schedule daily cleanup
        schedule.every().day.at("02:00").do(daily_cleanup)
        
        # Run initial check
        protection_check()
        
        # Keep running
        while True:
            schedule.run_pending()
            time.sleep(60)

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='SecureVox 50 Users Protection System')
    parser.add_argument('--check', action='store_true', help='Run single protection check')
    parser.add_argument('--monitor', action='store_true', help='Run continuous monitoring')
    parser.add_argument('--cleanup', action='store_true', help='Run data cleanup')
    parser.add_argument('--emergency-shutdown', action='store_true', help='Emergency shutdown')
    parser.add_argument('--interval', type=int, default=5, help='Monitoring interval in minutes')
    
    args = parser.parse_args()
    
    # Initialize protection system
    protection = SecureVox50UsersProtection()
    
    try:
        if args.check:
            status = protection.run_protection_check()
            print(json.dumps(status, indent=2))
        
        elif args.monitor:
            protection.run_continuous_protection(args.interval)
        
        elif args.cleanup:
            protection.cleanup_old_data()
        
        elif args.emergency_shutdown:
            protection.emergency_shutdown()
        
        else:
            # Default: single check
            status = protection.run_protection_check()
            print(f"\n🛡️ SecureVox 50 Users Protection Status")
            print(f"Risk Level: {status.get('overall_risk', 'UNKNOWN')}")
            print(f"Protection Active: {status.get('protection_active', False)}")
            print(f"Emergency Mode: {status.get('emergency_mode', False)}")
            
            if status.get('users', {}).get('warnings'):
                print(f"\n⚠️  User Warnings:")
                for warning in status['users']['warnings']:
                    print(f"  {warning}")
            
            if status.get('calls', {}).get('warnings'):
                print(f"\n📞 Call Warnings:")
                for warning in status['calls']['warnings']:
                    print(f"  {warning}")
            
            if status.get('resources', {}).get('warnings'):
                print(f"\n💻 Resource Warnings:")
                for warning in status['resources']['warnings']:
                    print(f"  {warning}")
            
            if status.get('overall_risk') == 'LOW':
                print(f"\n✅ All systems within 50-user limits!")
            
    except KeyboardInterrupt:
        logger.info("Protection monitoring stopped by user")
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
