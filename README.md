# SAP ASE (Sybase) Automated Database Backup

Automated backup script for SAP ASE/Sybase databases with detailed logging, disk space checks, and optional cleanup of old backups.

## Features

- **Automated database dumps** using `isql` and `Dump database` command
- **Detailed logging** - status, file size, duration, disk space, timestamps
- **Disk space check** - aborts if free space is below threshold
- **Old backup cleanup** - configurable retention period
- **Email alerts** - optional notification on failure
- **Secure config** - credentials stored in a separate config file (not in the script)
- **Cron-ready** - schedule and forget

## Setup

1. Clone this repo:
   ```bash
   git clone https://github.com/yourusername/sap-ase-backup.git
   cd sap-ase-backup
   ```

2. Create your config file:
   ```bash
   cp backup.conf.example backup.conf
   vi backup.conf    # fill in your actual values
   chmod 600 backup.conf
   ```

3. Make the script executable:
   ```bash
   chmod 700 fiori_backup.sh
   ```

4. Test it:
   ```bash
   ./fiori_backup.sh
   ```

5. Check the log:
   ```bash
   cat /var/log/fiori_backup/backup_*.log
   ```

## Schedule with Cron

```bash
crontab -e

# Daily at 2 AM
0 2 * * * /path/to/fiori_backup.sh
```

## Configuration

Edit `backup.conf` with your environment details:

| Variable | Description | Example |
|---|---|---|
| `SYB_USER` | Sybase OS user | `sybgwd` |
| `DB_USER` | Database login | `sapsa` |
| `DB_PASS` | Database password | `yourpassword` |
| `SERVER` | ASE server name | `GWD` |
| `DATABASE` | Database to back up | `GWD` |
| `BACKUP_DIR` | Where dump files are saved | `/backup` |
| `ISQL` | Path to isql binary | `/sybase/GWD/OCS-16_0/bin/isql` |
| `LOG_DIR` | Where log files are saved | `/var/log/fiori_backup` |
| `COMPRESSION` | Compression level | `101` |
| `MIN_DISK_GB` | Minimum free GB to proceed | `5` |
| `RETENTION_DAYS` | Delete backups older than X days | `30` |
| `ALERT_EMAIL` | Email for failure alerts | `admin@company.com` |

## Sample Log Output

```
[2026-04-07 02:00:01] ========================================
[2026-04-07 02:00:01]   SAP ASE DATABASE BACKUP - STARTED
[2026-04-07 02:00:01] ========================================
[2026-04-07 02:00:01] Server     : GWD
[2026-04-07 02:00:01] Database   : GWD
[2026-04-07 02:00:01] Dump File  : /backup/database-2026-04-07T02-00-01.dbdmp
[2026-04-07 02:00:01] Backup Dir : /backup
[2026-04-07 02:00:01] Available disk space: 8800 GB
[2026-04-07 02:00:01] Backup starting...
[2026-04-07 02:08:35] ========================================
[2026-04-07 02:08:35]   STATUS       : SUCCESS
[2026-04-07 02:08:35]   File         : /backup/database-2026-04-07T02-00-01.dbdmp
[2026-04-07 02:08:35]   Size         : 18432 MB (18.00 GB)
[2026-04-07 02:08:35]   Duration     : 514 seconds (8 min 34 sec)
[2026-04-07 02:08:35]   Completed at : 2026-04-07 02:08:35
[2026-04-07 02:08:35] ========================================
```


