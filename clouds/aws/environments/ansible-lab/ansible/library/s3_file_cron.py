#!/usr/bin/python3
"""
Ansible module to create a cron job that checks for a file in S3.

This module:
1. Creates a Python script that uses boto3 to check S3
2. Sets up a cron job to run the script on a schedule

Example:
    - name: Set up S3 file check cron
      s3_file_cron:
        bucket: my-bucket
        key: path/to/file.txt
        schedule: "*/5 * * * *"  # Every 5 minutes
        log_file: /var/log/s3-check.log
        state: present
"""

from ansible.module_utils.basic import AnsibleModule
import os

SCRIPT_TEMPLATE = '''#!/usr/bin/python3
"""S3 file check script - managed by Ansible"""
import sys
import logging
from datetime import datetime

logging.basicConfig(
    filename='{log_file}',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    logging.error("boto3 not installed. Run: uv pip install boto3")
    sys.exit(1)

BUCKET = '{bucket}'
KEY = '{key}'

def check_file():
    s3 = boto3.client('s3')
    try:
        s3.head_object(Bucket=BUCKET, Key=KEY)
        logging.info(f"File exists: s3://{{BUCKET}}/{{KEY}}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            logging.warning(f"File not found: s3://{{BUCKET}}/{{KEY}}")
        else:
            logging.error(f"Error checking S3: {{e}}")
        return False

if __name__ == '__main__':
    exists = check_file()
    sys.exit(0 if exists else 1)
'''


def get_script_path(bucket, key):
    """Generate a unique script path based on bucket/key."""
    safe_name = f"{bucket}_{key}".replace("/", "_").replace(".", "_")
    return f"/usr/local/bin/s3_check_{safe_name}.py"


def get_cron_file(bucket, key):
    """Generate cron file path."""
    safe_name = f"{bucket}_{key}".replace("/", "_").replace(".", "_")
    return f"/etc/cron.d/s3_check_{safe_name}"


def main():
    module = AnsibleModule(
        argument_spec=dict(
            bucket=dict(type='str', required=True),
            key=dict(type='str', required=True),
            schedule=dict(type='str', default='*/5 * * * *'),
            log_file=dict(type='str', default='/var/log/s3-check.log'),
            state=dict(type='str', default='present', choices=['present', 'absent']),
            user=dict(type='str', default='ubuntu'),
        )
    )

    bucket = module.params['bucket']
    key = module.params['key']
    schedule = module.params['schedule']
    log_file = module.params['log_file']
    state = module.params['state']
    user = module.params['user']

    script_path = get_script_path(bucket, key)
    cron_file = get_cron_file(bucket, key)

    changed = False

    if state == 'absent':
        # Remove script and cron job
        if os.path.exists(script_path):
            os.remove(script_path)
            changed = True
        if os.path.exists(cron_file):
            os.remove(cron_file)
            changed = True
        module.exit_json(changed=changed, msg="S3 check cron removed")

    # state == 'present'
    # Create the Python script
    script_content = SCRIPT_TEMPLATE.format(
        bucket=bucket,
        key=key,
        log_file=log_file
    )

    # Check if script needs updating
    script_changed = False
    if os.path.exists(script_path):
        with open(script_path, 'r') as f:
            if f.read() != script_content:
                script_changed = True
    else:
        script_changed = True

    if script_changed:
        with open(script_path, 'w') as f:
            f.write(script_content)
        os.chmod(script_path, 0o755)
        changed = True

    # Create cron job
    # Use uv run to execute with the right Python environment
    # Use the target user's home directory, not the current user (might be root)
    uv_path = f"/home/{user}/.local/bin/uv"
    cron_content = f"# Managed by Ansible - S3 file check for {bucket}/{key}\n"
    cron_content += f"{schedule} {user} {uv_path} run --with boto3 python {script_path}\n"

    cron_changed = False
    if os.path.exists(cron_file):
        with open(cron_file, 'r') as f:
            if f.read() != cron_content:
                cron_changed = True
    else:
        cron_changed = True

    if cron_changed:
        with open(cron_file, 'w') as f:
            f.write(cron_content)
        os.chmod(cron_file, 0o644)
        changed = True

    module.exit_json(
        changed=changed,
        msg=f"S3 check cron configured for s3://{bucket}/{key}",
        script_path=script_path,
        cron_file=cron_file,
        schedule=schedule
    )


if __name__ == '__main__':
    main()
