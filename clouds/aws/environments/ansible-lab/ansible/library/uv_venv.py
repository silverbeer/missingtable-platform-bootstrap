#!/usr/bin/python3
"""
Ansible module to create a Python virtual environment using uv.

Example:
    - name: Create venv with dependencies
      uv_venv:
        path: /opt/myapp/.venv
        python_version: "3.12"
        dependencies:
          - boto3
          - requests
"""

from ansible.module_utils.basic import AnsibleModule
import os


def get_uv_path():
    """Get the path to uv binary - check multiple locations."""
    # Check common locations
    locations = [
        os.path.expanduser("~/.local/bin/uv"),
        "/home/ubuntu/.local/bin/uv",
        "/usr/local/bin/uv",
    ]
    for path in locations:
        if os.path.exists(path):
            return path
    return locations[0]  # Return default for error message


def main():
    module = AnsibleModule(
        argument_spec=dict(
            path=dict(type='str', required=True),
            python_version=dict(type='str', default='3.12'),
            dependencies=dict(type='list', elements='str', default=[]),
        )
    )

    path = module.params['path']
    python_version = module.params['python_version']
    dependencies = module.params['dependencies']

    uv_path = get_uv_path()

    # Check if uv is installed
    if not os.path.exists(uv_path):
        module.fail_json(msg=f"uv not found at {uv_path}. Install uv first.")

    changed = False
    venv_created = False

    # Check if venv already exists
    venv_python = os.path.join(path, "bin", "python")
    if not os.path.exists(venv_python):
        # Create the venv
        rc, stdout, stderr = module.run_command([
            uv_path, "venv", path, "--python", python_version
        ])
        if rc != 0:
            module.fail_json(msg=f"Failed to create venv: {stderr}")
        changed = True
        venv_created = True

    # Install dependencies if any
    if dependencies:
        # Use uv pip install within the venv
        rc, stdout, stderr = module.run_command([
            uv_path, "pip", "install",
            "--python", venv_python,
            *dependencies
        ])
        if rc != 0:
            module.fail_json(msg=f"Failed to install dependencies: {stderr}")
        # Check if anything was installed (not "already satisfied")
        if "Successfully installed" in stdout:
            changed = True

    module.exit_json(
        changed=changed,
        msg=f"Venv at {path} configured with Python {python_version}",
        path=path,
        python_version=python_version,
        dependencies=dependencies,
        venv_created=venv_created
    )


if __name__ == '__main__':
    main()
