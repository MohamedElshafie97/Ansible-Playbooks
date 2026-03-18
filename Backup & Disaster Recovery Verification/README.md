# 💾 Automated Backup & Integrity Verification

A production-ready Ansible playbook designed for Senior Systems Administrators to automate the lifecycle of system backups and data integrity validation.

## 🚀 Overview
In a high-stakes environment, a backup is only as good as its last successful verification. This playbook automates:
1. **Config Archival:** Compresses critical service configurations into versioned backups.
2. **Database Dumps:** Safely exports MariaDB/MySQL databases.
3. **Integrity Checks:** Generates MD5 checksums to ensure backups aren't corrupted during transfer or storage.
4. **Retention Policy:** Automatically purges backups older than 7 days to manage storage capacity.

## 📂 Repository Structure
- `backup_and_verify.yml`: Core logic with conditional database detection.
- `hosts`: Inventory file for targeting production or staging nodes.
- `README.md`: Documentation and setup guide.

## 🛠️ Configuration
Edit the `vars` section in the playbook to match your environment:
- `backup_dir`: Destination for backup files.
- `db_name`: The database you wish to export.
- `config_paths`: List of files/directories to include in the archive.

## 📖 Usage
Run the playbook against your inventory:
```bash
ansible-playbook -i hosts backup_and_verify.yml