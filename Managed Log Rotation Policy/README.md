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


🚀 How to Use
Define your Variables:
Update the vars section in the playbook to point to your application logs:


vars:
  log_path: "/var/log/myapp/*.log"
  rotation_count: 7

Run the Playbook:


ansible-playbook -i inventory/hosts logrotate_management.yml
Dry Run (Check for errors):


ansible-playbook -i inventory/hosts logrotate_management.yml --check

📄 Configuration Details
The playbook enforces the following policy:

Daily Rotation: Keeps logs fresh.

Compression: Uses gzip to reduce log size by up to 90%.

Retention: Maintains 7 days of history (customizable).

Service Reload: Safely reloads rsyslog post-rotation to ensure logging continuity