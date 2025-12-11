"""
Certbot Lambda - Generates Let's Encrypt certificates using DNS-01 challenge
Stores certificate and key in AWS Secrets Manager
"""

import json
import boto3
import subprocess
import os
import tempfile
import shutil


def handler(event, context):
    domain = os.environ["DOMAIN_NAME"]
    email = os.environ["LETSENCRYPT_EMAIL"]
    secret_id = os.environ["SECRET_ID"]
    hosted_zone_id = os.environ["HOSTED_ZONE_ID"]

    # Create temp directory for certbot
    work_dir = tempfile.mkdtemp()
    config_dir = os.path.join(work_dir, "config")
    work_path = os.path.join(work_dir, "work")
    logs_dir = os.path.join(work_dir, "logs")

    try:
        # Run certbot with Route 53 DNS plugin
        cmd = [
            "certbot", "certonly",
            "--non-interactive",
            "--agree-tos",
            "--email", email,
            "--dns-route53",
            "--domains", domain,
            "--config-dir", config_dir,
            "--work-dir", work_path,
            "--logs-dir", logs_dir,
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"certbot stderr: {result.stderr}")
            print(f"certbot stdout: {result.stdout}")
            raise Exception(f"Certbot failed: {result.stderr}")

        # Read the generated certificate and key
        cert_path = os.path.join(config_dir, "live", domain)

        with open(os.path.join(cert_path, "fullchain.pem")) as f:
            cert = f.read()

        with open(os.path.join(cert_path, "privkey.pem")) as f:
            key = f.read()

        # Store in Secrets Manager (format for K8s TLS secret)
        secrets_client = boto3.client("secretsmanager")
        secret_value = json.dumps({
            "fullchain": cert,
            "private_key": key,
            "certificate": cert
        })

        secrets_client.put_secret_value(
            SecretId=secret_id,
            SecretString=secret_value
        )

        return {
            "statusCode": 200,
            "body": f"Certificate for {domain} renewed and stored"
        }

    finally:
        # Cleanup temp directory
        shutil.rmtree(work_dir, ignore_errors=True)
