#!/bin/bash
# ============================================================
#  SAP ASE (Sybase) AUTOMATED DATABASE BACKUP SCRIPT
#  Automates "Dump database" with logging, disk checks,
#  and optional cleanup of old backups.
#
#  Usage:
#    1. Copy backup.conf.example to /root/scripts/backup.conf
#    2. Fill in your credentials and paths
#    3. chmod 700 this script
#    4. Run manually or schedule via cron
#
#  Cron example (daily at 2 AM):
#    0 2 * * * /root/scripts/fiori_backup.sh
# ============================================================

# ============ CONFIGURATION ============
CONF_FILE="$(dirname "$0")/backup.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "ERROR: Config file not found: $CONF_FILE"
    echo "Copy backup.conf.example to backup.conf and fill in your values."
    exit 1
fi

source "$CONF_FILE"

# Validate required variables
for VAR in SYB_USER DB_USER DB_PASS SERVER DATABASE BACKUP_DIR ISQL LOG_DIR; do
    if [ -z "${!VAR}" ]; then
        echo "ERROR: $VAR is not set in $CONF_FILE"
        exit 1
    fi
done
# ========================================

mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y-%m-%dT%H-%M-%S)
DUMP_FILE="${BACKUP_DIR}/database-${TIMESTAMP}.dbdmp"
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# ---- Log helper ----
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================"
log "  SAP ASE DATABASE BACKUP - STARTED"
log "========================================"
log "Server     : $SERVER"
log "Database   : $DATABASE"
log "Dump File  : $DUMP_FILE"
log "Backup Dir : $BACKUP_DIR"
log ""

# ---- Check disk space ----
AVAIL_KB=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
log "Available disk space: ${AVAIL_GB} GB"

if [ "$AVAIL_GB" -lt "${MIN_DISK_GB:-5}" ]; then
    log "ERROR: Less than ${MIN_DISK_GB:-5} GB free in $BACKUP_DIR. Aborting!"
    exit 1
fi

# ---- Record start time ----
START_EPOCH=$(date +%s)
log "Backup starting..."
log ""

# ---- Run the dump ----
ISQL_OUTPUT=$(su - "$SYB_USER" -c "echo \"Dump database ${DATABASE} to '${DUMP_FILE}' with compression=${COMPRESSION:-101}\ngo\" | ${ISQL} -U${DB_USER} -P${DB_PASS} -S${SERVER} -X" 2>&1)

EXIT_CODE=$?
END_EPOCH=$(date +%s)
DURATION=$(( END_EPOCH - START_EPOCH ))

# ---- Log isql output ----
log "--- isql output ---"
echo "$ISQL_OUTPUT" >> "$LOG_FILE"
log "--- end isql output ---"
log ""

# ---- Evaluate result ----
log "========================================"

if [ $EXIT_CODE -eq 0 ] && [ -f "$DUMP_FILE" ] && [ $(stat -c%s "$DUMP_FILE") -gt 1000000 ]; then
    FILE_SIZE_BYTES=$(stat -c%s "$DUMP_FILE")
    FILE_SIZE_MB=$((FILE_SIZE_BYTES / 1024 / 1024))
    FILE_SIZE_GB=$(echo "scale=2; $FILE_SIZE_BYTES / 1024 / 1024 / 1024" | bc)

    log "  STATUS       : SUCCESS"
    log "  File         : $DUMP_FILE"
    log "  Size         : ${FILE_SIZE_MB} MB (${FILE_SIZE_GB} GB)"
    log "  Duration     : ${DURATION} seconds ($((DURATION / 60)) min $((DURATION % 60)) sec)"
    log "  Disk Free    : ${AVAIL_GB} GB (before backup)"
    log "  Completed at : $(date '+%Y-%m-%d %H:%M:%S')"
else
    log "  STATUS       : FAILED"
    log "  Exit Code    : $EXIT_CODE"
    log "  Duration     : ${DURATION} seconds"
    log "  Dump File    : $(ls -lh "$DUMP_FILE" 2>/dev/null || echo 'NOT FOUND')"
    log ""
    log "  Check isql output above for errors."

    # Send email alert if configured
    if [ -n "$ALERT_EMAIL" ]; then
        mail -s "BACKUP FAILED - ${DATABASE} on $(hostname)" "$ALERT_EMAIL" < "$LOG_FILE"
    fi
fi

log "========================================"
log ""

# ---- Cleanup old backups ----
if [ -n "$RETENTION_DAYS" ] && [ "$RETENTION_DAYS" -gt 0 ]; then
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    DELETED=$(find "$BACKUP_DIR" -name "database-*.dbdmp" -mtime +${RETENTION_DAYS} -print -delete 2>&1)
    if [ -n "$DELETED" ]; then
        log "Deleted: $DELETED"
    else
        log "No old backups to delete."
    fi
fi
