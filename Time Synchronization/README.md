# 🕒 Automated Time Synchronization (Chrony)

This repository provides an automated solution for standardizing system time and timezones across Linux fleets. As a Senior Systems Engineer, I developed this to ensure log consistency and database synchronization across hybrid environments.

## 🌟 Features
- **Cross-Distribution Support:** Automatically manages service names for both **RHEL/CentOS** (`chronyd`) and **Debian/Ubuntu** (`chrony`).
- **Timezone Standardization:** Ensures all servers are aligned to a specific timezone (default: Africa/Cairo).
- **Modern NTP:** Utilizes `Chrony` for faster synchronization and better handling of intermittent network connections compared to legacy `ntp`.
- **Status Verification:** Includes a built-in check to verify synchronization health after the update.

## 🛠️ Prerequisites
- Ansible 2.9+ installed on the control node.
- SSH access to target servers with `sudo` privileges.

## 📂 Repository Contents
- `time_sync.yml`: The main playbook containing the automation logic and conditional tasks.
- `hosts`: The inventory file where you define your target server groups.
- `README.md`: Project documentation and usage guide.

## 🚀 Quick Start

1. **Configure your Inventory:**
   Edit the `hosts` file to include your server IP addresses:
   ```ini
   [servers]
   192.168.1.10
   192.168.1.11


   Run the Playbook:

   ansible-playbook -i hosts time_sync.yml

   Verify Sync:
   
   chronyc tracking

The playbook will output the synchronization status. You can also run:




📄 Customization
You can modify the vars section in time_sync.yml to change the default timezone or NTP pool servers:


vars:
  timezone: "Africa/Cairo"
  ntp_servers: ["0.pool.ntp.org", "1.pool.ntp.org"]





   




