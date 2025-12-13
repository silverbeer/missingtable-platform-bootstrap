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
    
    # Get ACM region from event, environment variable, Lambda context, or default
    acm_region = (
        event.get("acm_region") or
        event.get("region") or
        os.environ.get("ACM_REGION") or
        os.environ.get("AWS_REGION") or
        (context.invoked_function_arn.split(":")[3] if context and hasattr(context, "invoked_function_arn") else None) or
        "us-east-1"  # Default to us-east-1 for CloudFront/ALB compatibility
    )

    # Create temp directory for certbot
    work_dir = tempfile.mkdtemp()
    config_dir = os.path.join(work_dir, "config")
    work_path = os.path.join(work_dir, "work")
    logs_dir = os.path.join(work_dir, "logs")

    try:
        # Run certbot with Route 53 DNS plugin
        # Include wildcard subdomain for services like argocd.domain.com
        cmd = [
            "certbot", "certonly",
            "--non-interactive",
            "--agree-tos",
            "--email", email,
            "--dns-route53",
            "--domains", domain,
            "--domains", f"*.{domain}",
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

        # Also import to ACM for EKS Load Balancers
        acm_client = boto3.client('acm', region_name=acm_region)

        # Read the certificate chain for ACM
        with open(os.path.join(cert_path, "chain.pem")) as f:
            chain = f.read()

        # Import certificate to ACM
        response = acm_client.import_certificate(
            Certificate=cert.encode(),
            PrivateKey=key.encode(),
            CertificateChain=chain.encode()
        )

        certificate_arn = response['CertificateArn']
        print(f"Certificate imported to ACM in region {acm_region}: {certificate_arn}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": f"Certificate for {domain} renewed and stored",
                "secrets_manager": secret_id,
                "acm_arn": certificate_arn,
                "acm_region": acm_region
            })
        }

    finally:
        # Cleanup temp directory
        shutil.rmtree(work_dir, ignore_errors=True)
