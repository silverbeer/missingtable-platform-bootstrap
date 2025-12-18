#!/usr/bin/python3
"""
Ansible module to install Python versions using uv.

Example:
    - name: Install Python 3.12
      uv_python:
        version: "3.12"
"""

from ansible.module_utils.basic import AnsibleModule
import os


def get_uv_path():
    """Get the path to uv binary."""
    home = os.path.expanduser("~")
    return os.path.join(home, ".local", "bin", "uv")


def is_python_installed(module, uv_path, version):
    """Check if a Python version is already installed via uv."""
    rc, stdout, stderr = module.run_command([uv_path, "python", "list"])
    if rc != 0:
        return False
    # Check if version appears in the list (e.g., "3.12" matches "cpython-3.12.8-...")
    return version in stdout


def main():
    module = AnsibleModule(
        argument_spec=dict(
            version=dict(type='str', required=True),
        )
    )

    version = module.params['version']
    uv_path = get_uv_path()

    # Check if uv is installed
    if not os.path.exists(uv_path):
        module.fail_json(msg=f"uv not found at {uv_path}. Install uv first.")

    # Check if already installed (idempotency)
    if is_python_installed(module, uv_path, version):
        module.exit_json(changed=False, msg=f"Python {version} is already installed")

    # Install the Python version
    rc, stdout, stderr = module.run_command([uv_path, "python", "install", version])

    if rc != 0:
        module.fail_json(msg=f"Failed to install Python {version}: {stderr}")

    module.exit_json(
        changed=True,
        msg=f"Python {version} installed successfully",
        stdout=stdout
    )


if __name__ == '__main__':
    main()
