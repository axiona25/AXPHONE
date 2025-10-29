#!/usr/bin/env python3
"""
Script di diagnostica per la dashboard SecureVOX
"""

import os
import sys
import subprocess
import requests
from pathlib import Path

def print_status(message, status="INFO"):
    colors = {
        "INFO": "\033[94m",
        "SUCCESS": "\033[92m", 
        "WARNING": "\033[93m",
        "ERROR": "\033[91m"
    }
    print(f"{colors.get(status, '')}[{status}]\033[0m {message}")

def check_python():
    """Verifica se Python è disponibile"""
    print_status("Verificando Python...")
    
    python_commands = ['python3', 'python', 'py']
    for cmd in python_commands:
        try:
            result = subprocess.run([cmd, '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                print_status(f"Python trovato: {cmd} - {result.stdout.strip()}", "SUCCESS")
                return cmd
        except FileNotFoundError:
            continue
    
    print_status("Python non trovato!", "ERROR")
    return None

def check_node():
    """Verifica se Node.js è disponibile"""
    print_status("Verificando Node.js...")
    
    try:
        result = subprocess.run(['node', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print_status(f"Node.js trovato: {result.stdout.strip()}", "SUCCESS")
            return True
    except FileNotFoundError:
        pass
    
    print_status("Node.js non trovato!", "ERROR")
    return False

def check_npm():
    """Verifica se npm è disponibile"""
    print_status("Verificando npm...")
    
    try:
        result = subprocess.run(['npm', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print_status(f"npm trovato: {result.stdout.strip()}", "SUCCESS")
            return True
    except FileNotFoundError:
        pass
    
    print_status("npm non trovato!", "ERROR")
    return False

def check_directories():
    """Verifica che le directory esistano"""
    print_status("Verificando directory...")
    
    base_dir = Path(__file__).parent
    admin_dir = base_dir / "admin"
    server_dir = base_dir / "server"
    
    if admin_dir.exists():
        print_status(f"Directory admin: {admin_dir}", "SUCCESS")
    else:
        print_status(f"Directory admin non trovata: {admin_dir}", "ERROR")
        return False
    
    if server_dir.exists():
        print_status(f"Directory server: {server_dir}", "SUCCESS")
    else:
        print_status(f"Directory server non trovata: {server_dir}", "ERROR")
        return False
    
    return True

def check_django_server():
    """Verifica se il server Django è in esecuzione"""
    print_status("Verificando server Django...")
    
    try:
        response = requests.get("http://localhost:8001/health/", timeout=5)
        if response.status_code == 200:
            print_status("Server Django attivo su porta 8001", "SUCCESS")
            return True
    except requests.exceptions.ConnectionError:
        print_status("Server Django non raggiungibile su porta 8001", "WARNING")
    except Exception as e:
        print_status(f"Errore nel verificare il server Django: {e}", "ERROR")
    
    return False

def check_react_build():
    """Verifica se la build React esiste"""
    print_status("Verificando build React...")
    
    base_dir = Path(__file__).parent
    dist_dir = base_dir / "admin" / "dist"
    index_file = dist_dir / "index.html"
    
    if dist_dir.exists() and index_file.exists():
        print_status(f"Build React trovata: {dist_dir}", "SUCCESS")
        return True
    else:
        print_status(f"Build React non trovata: {dist_dir}", "WARNING")
        return False

def check_dependencies():
    """Verifica le dipendenze"""
    print_status("Verificando dipendenze...")
    
    # Verifica package.json
    package_json = Path(__file__).parent / "admin" / "package.json"
    if package_json.exists():
        print_status("package.json trovato", "SUCCESS")
    else:
        print_status("package.json non trovato", "ERROR")
        return False
    
    # Verifica node_modules
    node_modules = Path(__file__).parent / "admin" / "node_modules"
    if node_modules.exists():
        print_status("node_modules trovato", "SUCCESS")
    else:
        print_status("node_modules non trovato - esegui 'npm install'", "WARNING")
    
    return True

def main():
    """Funzione principale"""
    print("🛡️  Diagnostica SecureVOX Dashboard")
    print("=" * 40)
    
    issues = []
    
    # Verifiche
    python_cmd = check_python()
    if not python_cmd:
        issues.append("Python non installato")
    
    if not check_node():
        issues.append("Node.js non installato")
    
    if not check_npm():
        issues.append("npm non installato")
    
    if not check_directories():
        issues.append("Directory mancanti")
    
    if not check_dependencies():
        issues.append("Dipendenze mancanti")
    
    django_running = check_django_server()
    if not django_running:
        issues.append("Server Django non in esecuzione")
    
    react_built = check_react_build()
    if not react_built:
        issues.append("Build React non disponibile")
    
    # Riepilogo
    print("\n" + "=" * 40)
    print("📊 RIEPILOGO DIAGNOSTICA")
    print("=" * 40)
    
    if not issues:
        print_status("Tutto funziona correttamente! 🎉", "SUCCESS")
        print_status("Dashboard disponibile su: http://localhost:8001/admin", "SUCCESS")
    else:
        print_status(f"Trovati {len(issues)} problemi:", "WARNING")
        for i, issue in enumerate(issues, 1):
            print_status(f"{i}. {issue}", "ERROR")
        
        print("\n🔧 SOLUZIONI:")
        
        if "Python non installato" in issues:
            print_status("Installa Python 3.8+", "INFO")
        
        if "Node.js non installato" in issues:
            print_status("Installa Node.js 18+", "INFO")
        
        if "npm non installato" in issues:
            print_status("Installa npm", "INFO")
        
        if "Directory mancanti" in issues:
            print_status("Verifica la struttura del progetto", "INFO")
        
        if "Dipendenze mancanti" in issues:
            print_status("Esegui: cd admin && npm install", "INFO")
        
        if "Server Django non in esecuzione" in issues:
            print_status(f"Esegui: cd server && {python_cmd or 'python3'} manage.py runserver 8001", "INFO")
        
        if "Build React non disponibile" in issues:
            print_status("Esegui: cd admin && npm run build", "INFO")
    
    print("\n🚀 COMANDI RAPIDI:")
    print("1. Build dashboard: ./build_admin_dashboard.sh")
    print("2. Avvia server: ./start_server_8001.sh")
    print("3. Test connessione: python test_dashboard_connection.py")

if __name__ == "__main__":
    main()
