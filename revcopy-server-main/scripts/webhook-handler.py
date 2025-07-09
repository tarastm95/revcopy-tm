#!/usr/bin/env python3
"""
RevCopy Webhook Handler
Automatic deployment trigger for Git repository updates
"""

import os
import sys
import json
import hmac
import hashlib
import subprocess
import logging
from datetime import datetime
from flask import Flask, request, jsonify
from threading import Thread
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/revcopy/logs/webhook.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class DeploymentManager:
    """Manages automated deployments triggered by webhooks"""
    
    def __init__(self):
        self.deployment_secret = os.environ.get('WEBHOOK_SECRET', 'your-webhook-secret')
        self.deployment_lock = False
        self.cli_path = '/opt/revcopy/revcopy-server/revcopy-cli.py'
        
        # Repository configuration
        self.repositories = {
            'revcopy-server': {
                'deployment_type': 'full',
                'priority': 1,
                'requires_restart': True
            },
            'revcopy-backend': {
                'deployment_type': 'update',
                'priority': 2,
                'requires_restart': True
            },
            'revcopy-frontend': {
                'deployment_type': 'update', 
                'priority': 3,
                'requires_restart': False
            },
            'revcopy-admin': {
                'deployment_type': 'update',
                'priority': 4,
                'requires_restart': False
            },
            'revcopy-crawlers-api': {
                'deployment_type': 'update',
                'priority': 5,
                'requires_restart': True
            }
        }
    
    def verify_signature(self, payload_body: bytes, signature_header: str) -> bool:
        """Verify GitHub webhook signature"""
        if not signature_header:
            return False
            
        try:
            hash_object = hmac.new(
                self.deployment_secret.encode('utf-8'),
                msg=payload_body,
                digestmod=hashlib.sha256
            )
            expected_signature = "sha256=" + hash_object.hexdigest()
            return hmac.compare_digest(expected_signature, signature_header)
        except Exception as e:
            logger.error(f"Signature verification failed: {e}")
            return False
    
    def extract_repository_info(self, payload: dict) -> tuple:
        """Extract repository information from webhook payload"""
        try:
            repo_name = payload['repository']['name']
            branch = payload['ref'].split('/')[-1] if 'ref' in payload else 'main'
            commits = payload.get('commits', [])
            pusher = payload.get('pusher', {}).get('name', 'unknown')
            
            return repo_name, branch, commits, pusher
        except KeyError as e:
            logger.error(f"Failed to extract repository info: {e}")
            return None, None, None, None
    
    def should_deploy(self, repo_name: str, branch: str, commits: list) -> bool:
        """Determine if deployment should be triggered"""
        # Only deploy on main/master branch
        if branch not in ['main', 'master']:
            logger.info(f"Skipping deployment for branch: {branch}")
            return False
        
        # Check if repository is configured for auto-deployment
        if repo_name not in self.repositories:
            logger.info(f"Repository {repo_name} not configured for auto-deployment")
            return False
        
        # Skip deployment if no commits
        if not commits:
            logger.info("No commits found, skipping deployment")
            return False
        
        # Check for deployment skip keywords in commit messages
        skip_keywords = ['[skip deploy]', '[no deploy]', '[skip ci]']
        for commit in commits:
            message = commit.get('message', '').lower()
            if any(keyword in message for keyword in skip_keywords):
                logger.info(f"Deployment skipped due to commit message: {message}")
                return False
        
        return True
    
    def execute_deployment(self, repo_name: str, deployment_info: dict) -> bool:
        """Execute deployment for specific repository"""
        try:
            deployment_type = deployment_info['deployment_type']
            
            logger.info(f"Starting {deployment_type} deployment for {repo_name}")
            
            # Build deployment command
            cmd = [
                'python3', self.cli_path, 'deploy',
                '--server', '37.27.217.240'
            ]
            
            if deployment_type == 'full':
                cmd.append('--full')
                cmd.append('--ssl')
                cmd.append('--monitoring')
            
            # Execute deployment
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=1800  # 30 minutes timeout
            )
            
            if result.returncode == 0:
                logger.info(f"✅ Deployment successful for {repo_name}")
                logger.info(f"Output: {result.stdout}")
                return True
            else:
                logger.error(f"❌ Deployment failed for {repo_name}")
                logger.error(f"Error: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            logger.error(f"❌ Deployment timeout for {repo_name}")
            return False
        except Exception as e:
            logger.error(f"❌ Deployment error for {repo_name}: {e}")
            return False
    
    def run_health_check(self) -> bool:
        """Run post-deployment health check"""
        try:
            cmd = ['python3', self.cli_path, 'health', '--server', '37.27.217.240']
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                logger.info("✅ Health check passed")
                return True
            else:
                logger.warning("⚠️ Health check failed")
                logger.warning(f"Output: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Health check error: {e}")
            return False
    
    def send_notification(self, repo_name: str, success: bool, pusher: str, commits: list):
        """Send deployment notification"""
        try:
            webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
            if not webhook_url:
                return
            
            status_emoji = "✅" if success else "❌"
            status_text = "Success" if success else "Failed"
            
            commit_list = "\n".join([
                f"• {commit['message'][:50]}... ({commit['author']['name']})"
                for commit in commits[:3]
            ])
            
            message = {
                "text": f"{status_emoji} Deployment {status_text}",
                "attachments": [{
                    "color": "good" if success else "danger",
                    "fields": [
                        {"title": "Repository", "value": repo_name, "short": True},
                        {"title": "Pushed by", "value": pusher, "short": True},
                        {"title": "Server", "value": "37.27.217.240", "short": True},
                        {"title": "Time", "value": datetime.now().isoformat(), "short": True},
                        {"title": "Recent Commits", "value": commit_list, "short": False}
                    ]
                }]
            }
            
            import requests
            requests.post(webhook_url, json=message, timeout=10)
            
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
    
    def deploy_async(self, repo_name: str, pusher: str, commits: list):
        """Run deployment in background thread"""
        def deployment_worker():
            try:
                self.deployment_lock = True
                deployment_info = self.repositories[repo_name]
                
                # Execute deployment
                success = self.execute_deployment(repo_name, deployment_info)
                
                # Run health check if deployment succeeded
                if success:
                    health_ok = self.run_health_check()
                    success = success and health_ok
                
                # Send notification
                self.send_notification(repo_name, success, pusher, commits)
                
            finally:
                self.deployment_lock = False
        
        # Start deployment in background
        thread = Thread(target=deployment_worker)
        thread.daemon = True
        thread.start()

# Initialize deployment manager
deployment_manager = DeploymentManager()

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    """Handle GitHub webhook requests"""
    try:
        # Verify signature
        signature = request.headers.get('X-Hub-Signature-256')
        if not deployment_manager.verify_signature(request.data, signature):
            logger.warning("Invalid webhook signature")
            return jsonify({'error': 'Invalid signature'}), 403
        
        # Parse payload
        payload = request.get_json()
        if not payload:
            return jsonify({'error': 'Invalid JSON payload'}), 400
        
        # Extract repository information
        repo_name, branch, commits, pusher = deployment_manager.extract_repository_info(payload)
        
        if not repo_name:
            return jsonify({'error': 'Failed to extract repository information'}), 400
        
        logger.info(f"Webhook received for {repo_name}:{branch} by {pusher}")
        
        # Check if deployment should be triggered
        if not deployment_manager.should_deploy(repo_name, branch, commits):
            return jsonify({'status': 'deployment skipped'}), 200
        
        # Check if deployment is already in progress
        if deployment_manager.deployment_lock:
            logger.warning("Deployment already in progress, skipping")
            return jsonify({'status': 'deployment in progress'}), 429
        
        # Trigger deployment
        deployment_manager.deploy_async(repo_name, pusher, commits)
        
        return jsonify({
            'status': 'deployment triggered',
            'repository': repo_name,
            'branch': branch,
            'pusher': pusher
        }), 200
        
    except Exception as e:
        logger.error(f"Webhook handling error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/status', methods=['GET'])
def get_status():
    """Get deployment status"""
    return jsonify({
        'status': 'running',
        'deployment_lock': deployment_manager.deployment_lock,
        'configured_repositories': list(deployment_manager.repositories.keys()),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    # Ensure log directory exists
    os.makedirs('/opt/revcopy/logs', exist_ok=True)
    
    # Start webhook server
    port = int(os.environ.get('WEBHOOK_PORT', 8080))
    logger.info(f"Starting webhook handler on port {port}")
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    ) 