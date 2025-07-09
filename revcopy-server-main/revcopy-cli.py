#!/usr/bin/env python3
"""
RevCopy CLI - Complete Server Management Tool
============================================

A comprehensive command-line interface for managing RevCopy server deployments.
Supports local development, production deployment, and monitoring.

Usage:
    python revcopy-cli.py [command] [options]

Commands:
    deploy          Deploy to production server
    dev             Start local development environment
    admin           Deploy admin panel only
    status          Check server status
    logs            View server logs
    backup          Create server backup
    restore         Restore from backup
    update          Update server components
    monitor         Start monitoring dashboard
    ssl             Configure SSL certificates
    db              Database management
    users           User management
    config          Configuration management

Examples:
    python revcopy-cli.py deploy --server 37.27.217.240 --full
    python revcopy-cli.py dev --all
    python revcopy-cli.py admin --deploy
    python revcopy-cli.py status --server 37.27.217.240
"""

import argparse
import asyncio
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_header(text: str):
    """Print a formatted header."""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}{Colors.ENDC}\n")

def print_success(text: str):
    """Print success message."""
    print(f"{Colors.OKGREEN}✅ {text}{Colors.ENDC}")

def print_error(text: str):
    """Print error message."""
    print(f"{Colors.FAIL}❌ {text}{Colors.ENDC}")

def print_warning(text: str):
    """Print warning message."""
    print(f"{Colors.WARNING}⚠️  {text}{Colors.ENDC}")

def print_info(text: str):
    """Print info message."""
    print(f"{Colors.OKBLUE}ℹ️  {text}{Colors.ENDC}")

class RevCopyCLI:
    """Main CLI class for RevCopy server management."""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.server_dir = Path(__file__).parent
        self.config = self.load_config()
    
    def load_config(self) -> Dict:
        """Load configuration from file or create default."""
        config_file = self.server_dir / "cli-config.json"
        
        default_config = {
            "default_server": "37.27.217.240",
            "default_user": "root",
            "admin_port": 3001,
            "backend_port": 8000,
            "frontend_port": 5173,
            "database": {
                "host": "localhost",
                "port": 5432,
                "name": "revcopy",
                "user": "postgres"
            },
            "monitoring": {
                "grafana_port": 3000,
                "prometheus_port": 9090
            }
        }
        
        if config_file.exists():
            try:
                with open(config_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print_warning(f"Could not load config: {e}")
                return default_config
        else:
            # Save default config
            with open(config_file, 'w') as f:
                json.dump(default_config, f, indent=2)
            return default_config
    
    def save_config(self):
        """Save current configuration."""
        config_file = self.server_dir / "cli-config.json"
        with open(config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def run_command(self, command: str, cwd: Optional[Path] = None) -> Tuple[int, str, str]:
        """Run a shell command and return exit code, stdout, stderr."""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                cwd=cwd or self.project_root
            )
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            return 1, "", str(e)
    
    def deploy_to_server(self, server: str, user: str = "root", full: bool = False, ssl: bool = False, monitoring: bool = False):
        """Deploy RevCopy to production server."""
        print_header("🚀 Deploying RevCopy to Production Server")
        
        print_info(f"Server: {server}")
        print_info(f"User: {user}")
        print_info(f"Full deployment: {full}")
        print_info(f"SSL: {ssl}")
        print_info(f"Monitoring: {monitoring}")
        
        # Check server connectivity
        print_info("Checking server connectivity...")
        code, stdout, stderr = self.run_command(f"ssh -o ConnectTimeout=10 {user}@{server} 'echo Connection successful'")
        
        if code != 0:
            print_error(f"Could not connect to server {server}")
            print_error(f"Error: {stderr}")
            return False
        
        print_success("Server connection established")
        
        # Create deployment script
        deploy_script = self.create_deployment_script(server, user, full, ssl, monitoring)
        
        # Upload and execute deployment
        print_info("Uploading deployment files...")
        
        # Upload project files
        code, stdout, stderr = self.run_command(
            f"rsync -av --exclude='.git' --exclude='node_modules' --exclude='__pycache__' "
            f"--exclude='*.pyc' --exclude='.env' {self.project_root}/ {user}@{server}:/opt/revcopy/"
        )
        
        if code != 0:
            print_error("Failed to upload project files")
            print_error(stderr)
            return False
        
        print_success("Project files uploaded")
        
        # Execute deployment on server
        print_info("Executing deployment on server...")
        
        deploy_commands = [
            "cd /opt/revcopy",
            "chmod +x deploy.sh",
            "./deploy.sh"
        ]
        
        if full:
            deploy_commands.extend([
                "cd SERVER",
                "docker-compose down",
                "docker-compose build --no-cache",
                "docker-compose up -d"
            ])
        
        if ssl:
            deploy_commands.append("bash scripts/setup-ssl.sh")
        
        if monitoring:
            deploy_commands.extend([
                "cd /opt/revcopy/SERVER",
                "docker-compose -f docker-compose.production.yml up -d"
            ])
        
        deploy_script_content = "\n".join(deploy_commands)
        
        # Execute deployment
        code, stdout, stderr = self.run_command(
            f"ssh {user}@{server} 'bash -s' << 'EOF'\n{deploy_script_content}\nEOF"
        )
        
        if code != 0:
            print_error("Deployment failed")
            print_error(stderr)
            return False
        
        print_success("Deployment completed successfully!")
        
        # Show deployment info
        self.show_deployment_info(server)
        
        return True
    
    def create_deployment_script(self, server: str, user: str, full: bool, ssl: bool, monitoring: bool) -> str:
        """Create deployment script content."""
        script = f"""#!/bin/bash
set -e

echo "🚀 Starting RevCopy deployment on {server}"

# Update system
apt-get update -y
apt-get upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $USER
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create project directory
mkdir -p /opt/revcopy
cd /opt/revcopy

# Set up environment
if [ ! -f .env ]; then
    cp SERVER/env-template.txt .env
    echo "⚠️  Please configure your .env file with proper values"
fi

# Deploy services
cd SERVER

if [ "{full}" = "True" ]; then
    echo "📦 Building all services..."
    docker-compose build --no-cache
    docker-compose up -d
fi

if [ "{ssl}" = "True" ]; then
    echo "🔒 Setting up SSL..."
    bash scripts/setup-ssl.sh
fi

if [ "{monitoring}" = "True" ]; then
    echo "📊 Setting up monitoring..."
    docker-compose -f docker-compose.production.yml up -d
fi

echo "✅ Deployment completed!"
"""
        return script
    
    def show_deployment_info(self, server: str):
        """Show deployment information."""
        print_header("📋 Deployment Information")
        
        print_info("Services deployed:")
        print(f"  🌐 Frontend: http://{server}")
        print(f"  🔧 Backend API: http://{server}/api")
        print(f"  👨‍💼 Admin Panel: http://{server}:{self.config['admin_port']}")
        print(f"  📊 Monitoring: http://{server}:{self.config['monitoring']['grafana_port']}")
        
        print_info("\nDefault admin credentials:")
        print("  📧 Email: admin@revcopy.com")
        print("  🔑 Password: admin123")
        
        print_warning("\n⚠️  Important:")
        print("  - Change default admin password after first login")
        print("  - Configure SSL certificates for production")
        print("  - Set up proper firewall rules")
        print("  - Configure backup strategy")
    
    def start_dev_environment(self, all_services: bool = False):
        """Start local development environment."""
        print_header("🔧 Starting Local Development Environment")
        
        services = []
        
        if all_services or input("Start backend? (y/n): ").lower() == 'y':
            services.append("backend")
        
        if all_services or input("Start frontend? (y/n): ").lower() == 'y':
            services.append("frontend")
        
        if all_services or input("Start admin panel? (y/n): ").lower() == 'y':
            services.append("admin")
        
        for service in services:
            self.start_service(service)
    
    def start_service(self, service: str):
        """Start a specific service."""
        print_info(f"Starting {service}...")
        
        if service == "backend":
            self.run_command("cd backend && python run.py", cwd=self.project_root)
        elif service == "frontend":
            self.run_command("cd frontend && npm run dev", cwd=self.project_root)
        elif service == "admin":
            self.run_command("cd admin && npm run dev -- --port 3001", cwd=self.project_root)
        else:
            print_error(f"Unknown service: {service}")
    
    def deploy_admin_only(self, server: str, user: str = "root"):
        """Deploy only the admin panel."""
        print_header("👨‍💼 Deploying Admin Panel Only")
        
        print_info(f"Deploying admin panel to {server}...")
        
        # Run admin deployment script
        code, stdout, stderr = self.run_command(f"./deploy-admin.sh")
        
        if code != 0:
            print_error("Admin deployment failed")
            print_error(stderr)
            return False
        
        print_success("Admin panel deployed successfully!")
        print_info(f"Admin panel available at: http://{server}:{self.config['admin_port']}")
        
        return True
    
    def check_server_status(self, server: str, user: str = "root"):
        """Check server status and health."""
        print_header("📊 Server Status Check")
        
        # Check basic connectivity
        print_info("Checking server connectivity...")
        code, stdout, stderr = self.run_command(f"ssh {user}@{server} 'echo OK'")
        
        if code != 0:
            print_error(f"Cannot connect to server {server}")
            return False
        
        print_success("Server is reachable")
        
        # Check Docker containers
        print_info("Checking Docker containers...")
        code, stdout, stderr = self.run_command(f"ssh {user}@{server} 'docker ps'")
        
        if code == 0:
            print_success("Docker containers status:")
            print(stdout)
        else:
            print_warning("Docker not running or no containers found")
        
        # Check service health
        print_info("Checking service health...")
        
        services = [
            ("Frontend", f"http://{server}"),
            ("Backend API", f"http://{server}/api/health"),
            ("Admin Panel", f"http://{server}:{self.config['admin_port']}")
        ]
        
        for name, url in services:
            try:
                import requests
                response = requests.get(url, timeout=5)
                if response.status_code == 200:
                    print_success(f"{name}: OK")
                else:
                    print_warning(f"{name}: Status {response.status_code}")
            except:
                print_error(f"{name}: Not responding")
    
    def view_logs(self, server: str, user: str = "root", service: str = "all"):
        """View server logs."""
        print_header("📋 Server Logs")
        
        if service == "all":
            services = ["backend", "frontend", "admin", "database", "redis"]
        else:
            services = [service]
        
        for svc in services:
            print_info(f"Fetching {svc} logs...")
            code, stdout, stderr = self.run_command(
                f"ssh {user}@{server} 'docker logs revcopy-{svc} --tail 50'"
            )
            
            if code == 0:
                print(f"\n{Colors.OKCYAN}=== {svc.upper()} LOGS ==={Colors.ENDC}")
                print(stdout)
            else:
                print_warning(f"No logs found for {svc}")
    
    def create_backup(self, server: str, user: str = "root"):
        """Create server backup."""
        print_header("💾 Creating Server Backup")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"revcopy_backup_{timestamp}.tar.gz"
        
        print_info(f"Creating backup: {backup_name}")
        
        # Create backup on server
        backup_commands = [
            "cd /opt/revcopy",
            f"tar czf /tmp/{backup_name} .",
            "docker exec revcopy-database pg_dump -U postgres revcopy > /tmp/database_backup.sql"
        ]
        
        for cmd in backup_commands:
            code, stdout, stderr = self.run_command(f"ssh {user}@{server} '{cmd}'")
            if code != 0:
                print_error(f"Backup command failed: {cmd}")
                print_error(stderr)
                return False
        
        # Download backup
        print_info("Downloading backup...")
        code, stdout, stderr = self.run_command(
            f"scp {user}@{server}:/tmp/{backup_name} ./backups/"
        )
        
        if code == 0:
            print_success(f"Backup created: ./backups/{backup_name}")
        else:
            print_error("Failed to download backup")
        
        return True
    
    def restore_backup(self, backup_file: str, server: str, user: str = "root"):
        """Restore from backup."""
        print_header("🔄 Restoring from Backup")
        
        if not os.path.exists(backup_file):
            print_error(f"Backup file not found: {backup_file}")
            return False
        
        print_info(f"Restoring from: {backup_file}")
        
        # Upload backup to server
        code, stdout, stderr = self.run_command(
            f"scp {backup_file} {user}@{server}:/tmp/"
        )
        
        if code != 0:
            print_error("Failed to upload backup")
            return False
        
        # Restore on server
        restore_commands = [
            "cd /opt/revcopy",
            "docker-compose down",
            f"tar xzf /tmp/{os.path.basename(backup_file)}",
            "docker-compose up -d"
        ]
        
        for cmd in restore_commands:
            code, stdout, stderr = self.run_command(f"ssh {user}@{server} '{cmd}'")
            if code != 0:
                print_error(f"Restore command failed: {cmd}")
                return False
        
        print_success("Backup restored successfully!")
        return True
    
    def update_server(self, server: str, user: str = "root"):
        """Update server components."""
        print_header("🔄 Updating Server Components")
        
        update_commands = [
            "cd /opt/revcopy",
            "git pull origin main",
            "cd SERVER",
            "docker-compose down",
            "docker-compose build --no-cache",
            "docker-compose up -d"
        ]
        
        for cmd in update_commands:
            print_info(f"Running: {cmd}")
            code, stdout, stderr = self.run_command(f"ssh {user}@{server} '{cmd}'")
            
            if code != 0:
                print_error(f"Update failed at: {cmd}")
                print_error(stderr)
                return False
        
        print_success("Server updated successfully!")
        return True
    
    def start_monitoring(self, server: str, user: str = "root"):
        """Start monitoring dashboard."""
        print_header("📊 Starting Monitoring Dashboard")
        
        print_info("Starting monitoring services...")
        
        code, stdout, stderr = self.run_command(
            f"ssh {user}@{server} 'cd /opt/revcopy/SERVER && docker-compose -f docker-compose.production.yml up -d'"
        )
        
        if code == 0:
            print_success("Monitoring started successfully!")
            print_info(f"Grafana: http://{server}:{self.config['monitoring']['grafana_port']}")
            print_info(f"Prometheus: http://{server}:{self.config['monitoring']['prometheus_port']}")
        else:
            print_error("Failed to start monitoring")
            print_error(stderr)
    
    def configure_ssl(self, server: str, user: str = "root", domain: str = None):
        """Configure SSL certificates."""
        print_header("🔒 Configuring SSL Certificates")
        
        if not domain:
            domain = input("Enter domain name: ")
        
        print_info(f"Configuring SSL for domain: {domain}")
        
        ssl_commands = [
            "cd /opt/revcopy/SERVER",
            f"bash scripts/setup-ssl.sh {domain}"
        ]
        
        for cmd in ssl_commands:
            code, stdout, stderr = self.run_command(f"ssh {user}@{server} '{cmd}'")
            
            if code != 0:
                print_error(f"SSL configuration failed: {cmd}")
                print_error(stderr)
                return False
        
        print_success("SSL configured successfully!")
        print_info(f"HTTPS available at: https://{domain}")
    
    def manage_database(self, server: str, user: str = "root", action: str = "status"):
        """Database management."""
        print_header("🗄️  Database Management")
        
        if action == "status":
            code, stdout, stderr = self.run_command(
                f"ssh {user}@{server} 'docker exec revcopy-database psql -U postgres -d revcopy -c \"SELECT version();\"'"
            )
            if code == 0:
                print_success("Database is running")
                print(stdout)
            else:
                print_error("Database is not accessible")
        
        elif action == "backup":
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = f"database_backup_{timestamp}.sql"
            
            code, stdout, stderr = self.run_command(
                f"ssh {user}@{server} 'docker exec revcopy-database pg_dump -U postgres revcopy > /tmp/{backup_file}'"
            )
            
            if code == 0:
                print_success(f"Database backup created: {backup_file}")
            else:
                print_error("Database backup failed")
        
        elif action == "restore":
            backup_file = input("Enter backup file path: ")
            
            code, stdout, stderr = self.run_command(
                f"ssh {user}@{server} 'docker exec -i revcopy-database psql -U postgres revcopy < /tmp/{backup_file}'"
            )
            
            if code == 0:
                print_success("Database restored successfully")
            else:
                print_error("Database restore failed")
    
    def manage_users(self, server: str, user: str = "root", action: str = "list"):
        """User management."""
        print_header("👥 User Management")
        
        if action == "list":
            code, stdout, stderr = self.run_command(
                f"ssh {user}@{server} 'docker exec revcopy-backend python -c \"import asyncio; from app.core.database import get_async_session; from app.models.user import User; from sqlalchemy import select; async def list_users(): async for db in get_async_session(): result = await db.execute(select(User)); users = result.scalars().all(); print(f\"Found {{len(users)}} users:\"); [print(f\"  - {{u.email}} ({{u.role}})\") for u in users]; break; asyncio.run(list_users())\"'"
            )
            
            if code == 0:
                print(stdout)
            else:
                print_error("Failed to list users")
        
        elif action == "create":
            email = input("Enter email: ")
            password = input("Enter password: ")
            role = input("Enter role (USER/ADMIN): ")
            
            create_script = f"""
import asyncio
from app.core.database import get_async_session
from app.models.user import User, UserRole
from app.core.security import get_password_hash

async def create_user():
    async for db in get_async_session():
        user = User(
            email='{email}',
            username='{email.split('@')[0]}',
            hashed_password=get_password_hash('{password}'),
            role=UserRole.{role.upper()},
            is_verified=True
        )
        db.add(user)
        await db.commit()
        print(f"User {email} created successfully!")
        break

asyncio.run(create_user())
"""
            
            code, stdout, stderr = self.run_command(
                f"ssh {user}@{server} 'docker exec revcopy-backend python -c \"{create_script}\"'"
            )
            
            if code == 0:
                print_success(f"User {email} created successfully")
            else:
                print_error("Failed to create user")
    
    def manage_config(self, action: str = "show"):
        """Configuration management."""
        print_header("⚙️  Configuration Management")
        
        if action == "show":
            print_info("Current configuration:")
            for key, value in self.config.items():
                print(f"  {key}: {value}")
        
        elif action == "edit":
            print_info("Available configuration options:")
            print("  1. default_server")
            print("  2. admin_port")
            print("  3. backend_port")
            print("  4. frontend_port")
            
            option = input("Select option to edit (1-4): ")
            
            if option == "1":
                self.config["default_server"] = input("Enter new server IP: ")
            elif option == "2":
                self.config["admin_port"] = int(input("Enter new admin port: "))
            elif option == "3":
                self.config["backend_port"] = int(input("Enter new backend port: "))
            elif option == "4":
                self.config["frontend_port"] = int(input("Enter new frontend port: "))
            
            self.save_config()
            print_success("Configuration updated")
        
        elif action == "reset":
            self.config = self.load_config()
            self.save_config()
            print_success("Configuration reset to defaults")

def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="RevCopy CLI - Complete Server Management Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python revcopy-cli.py deploy --server 37.27.217.240 --full
  python revcopy-cli.py dev --all
  python revcopy-cli.py admin --deploy
  python revcopy-cli.py status --server 37.27.217.240
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Deploy command
    deploy_parser = subparsers.add_parser('deploy', help='Deploy to production server')
    deploy_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    deploy_parser.add_argument('--user', default='root', help='SSH user')
    deploy_parser.add_argument('--full', action='store_true', help='Full deployment with all services')
    deploy_parser.add_argument('--ssl', action='store_true', help='Configure SSL certificates')
    deploy_parser.add_argument('--monitoring', action='store_true', help='Enable monitoring')
    
    # Dev command
    dev_parser = subparsers.add_parser('dev', help='Start local development environment')
    dev_parser.add_argument('--all', action='store_true', help='Start all services')
    
    # Admin command
    admin_parser = subparsers.add_parser('admin', help='Admin panel management')
    admin_parser.add_argument('--deploy', action='store_true', help='Deploy admin panel')
    admin_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    admin_parser.add_argument('--user', default='root', help='SSH user')
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Check server status')
    status_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    status_parser.add_argument('--user', default='root', help='SSH user')
    
    # Logs command
    logs_parser = subparsers.add_parser('logs', help='View server logs')
    logs_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    logs_parser.add_argument('--user', default='root', help='SSH user')
    logs_parser.add_argument('--service', default='all', help='Service name (backend/frontend/admin/all)')
    
    # Backup command
    backup_parser = subparsers.add_parser('backup', help='Create server backup')
    backup_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    backup_parser.add_argument('--user', default='root', help='SSH user')
    
    # Restore command
    restore_parser = subparsers.add_parser('restore', help='Restore from backup')
    restore_parser.add_argument('backup_file', help='Backup file path')
    restore_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    restore_parser.add_argument('--user', default='root', help='SSH user')
    
    # Update command
    update_parser = subparsers.add_parser('update', help='Update server components')
    update_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    update_parser.add_argument('--user', default='root', help='SSH user')
    
    # Monitor command
    monitor_parser = subparsers.add_parser('monitor', help='Start monitoring dashboard')
    monitor_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    monitor_parser.add_argument('--user', default='root', help='SSH user')
    
    # SSL command
    ssl_parser = subparsers.add_parser('ssl', help='Configure SSL certificates')
    ssl_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    ssl_parser.add_argument('--user', default='root', help='SSH user')
    ssl_parser.add_argument('--domain', help='Domain name')
    
    # Database command
    db_parser = subparsers.add_parser('db', help='Database management')
    db_parser.add_argument('action', choices=['status', 'backup', 'restore'], help='Database action')
    db_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    db_parser.add_argument('--user', default='root', help='SSH user')
    
    # Users command
    users_parser = subparsers.add_parser('users', help='User management')
    users_parser.add_argument('action', choices=['list', 'create'], help='User action')
    users_parser.add_argument('--server', default='37.27.217.240', help='Server IP address')
    users_parser.add_argument('--user', default='root', help='SSH user')
    
    # Config command
    config_parser = subparsers.add_parser('config', help='Configuration management')
    config_parser.add_argument('action', choices=['show', 'edit', 'reset'], help='Config action')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    cli = RevCopyCLI()
    
    try:
        if args.command == 'deploy':
            cli.deploy_to_server(args.server, args.user, args.full, args.ssl, args.monitoring)
        elif args.command == 'dev':
            cli.start_dev_environment(args.all)
        elif args.command == 'admin':
            if args.deploy:
                cli.deploy_admin_only(args.server, args.user)
        elif args.command == 'status':
            cli.check_server_status(args.server, args.user)
        elif args.command == 'logs':
            cli.view_logs(args.server, args.user, args.service)
        elif args.command == 'backup':
            cli.create_backup(args.server, args.user)
        elif args.command == 'restore':
            cli.restore_backup(args.backup_file, args.server, args.user)
        elif args.command == 'update':
            cli.update_server(args.server, args.user)
        elif args.command == 'monitor':
            cli.start_monitoring(args.server, args.user)
        elif args.command == 'ssl':
            cli.configure_ssl(args.server, args.user, args.domain)
        elif args.command == 'db':
            cli.manage_database(args.server, args.user, args.action)
        elif args.command == 'users':
            cli.manage_users(args.server, args.user, args.action)
        elif args.command == 'config':
            cli.manage_config(args.action)
        else:
            print_error(f"Unknown command: {args.command}")
            parser.print_help()
    
    except KeyboardInterrupt:
        print("\n\n⚠️  Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 