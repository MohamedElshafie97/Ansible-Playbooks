# 🔒 SSH Security Hardening (Ansible)

This repository contains a production-grade Ansible playbook designed to harden the **Secure Shell (SSH)** daemon. It follows security best practices to reduce the attack surface of Linux servers in hybrid environments.

## 🛡️ Security Enhancements
- **Disable Root Login:** Prevents direct brute-force attacks against the root user.
- **Key-Based Authentication:** Disables password authentication, enforcing the use of SSH keys.
- **Service Validation:** Uses `sshd -t` to validate configuration syntax before restarting the service (preventing lockout).
- **Firewall Integration:** Automatically updates `ufw` or `firewalld` based on the detected OS distribution.
- **Session Limits:** Restricts `MaxAuthTries` to mitigate automated credential stuffing.

## 🚀 Deployment
1. **Update Variables:** Set your preferred port and allowed users in the `vars` section.
   ```yaml
   vars:
     ssh_port: "22"
     allow_users: "mohamed"




Execute Playbook:


ansible-playbook -i inventory/hosts ssh_hardening.yml


⚠️ Important Note
Before running this playbook: Ensure you have already copied your public SSH key to the target server for the user defined in allow_users. Failure to do so will result in being locked out of the server once password authentication is disabled.