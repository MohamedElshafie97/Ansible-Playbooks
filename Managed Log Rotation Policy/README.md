# 🚀 Automated Log Management (Ansible)

 I developed this playbook to solve a common infrastructure pain point: **Disk Space Exhaustion** caused by unmanaged log files. This solution standardizes log rotation policies across hybrid Linux environments.

## 🌟 Key Features
- **Cross-Platform Support:** Automatically detects OS family (RHEL/CentOS vs. Debian/Ubuntu) to handle service reloads.
- **Pre-Flight Validation:** Executes a syntax check (`logrotate -d`) before finalizing changes to prevent configuration errors.
- **Best Practices:** Implements log compression and delayed compression to optimize CPU and Storage performance.
- **Idempotent Design:** Ensures configurations are consistent without unnecessary file writes.

## 🛠️ Infrastructure Stack
- **Automation:** Ansible
- **Target OS:** - Red Hat Enterprise Linux / CentOS / Rocky Linux
  - Ubuntu / Debian
- **Service:** Logrotate & Systemd

## 📂 Project Structure
logrotate-automation/
├── logrotate_management.yml   # Main Playbook
├── inventory/                 # Server Inventory
└── README.md                  # Documentation