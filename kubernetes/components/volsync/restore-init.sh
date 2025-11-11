#!/bin/sh
set -e

NAMESPACE="${NAMESPACE:-media}"
APP="${APP:-radarr}"
DATA_PATH="${DATA_PATH:-/data}"
RESTORE_TIMEOUT="${RESTORE_TIMEOUT:-600}"  # 10 minutes default

echo "=== VolSync Auto-Restore Init Container ==="
echo "Namespace: $NAMESPACE"
echo "App: $APP"
echo "Data path: $DATA_PATH"
echo ""

# Check if data directory is empty
check_empty() {
    if [ ! -d "$DATA_PATH" ]; then
        echo "Data directory $DATA_PATH does not exist - needs restore"
        return 0
    fi
    
    # Check if directory is empty (ignoring hidden files like .gitkeep)
    file_count=$(find "$DATA_PATH" -mindepth 1 -not -name '.*' 2>/dev/null | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "Data directory $DATA_PATH is empty - needs restore"
        return 0
    fi
    
    echo "Data directory $DATA_PATH has $file_count files - restore not needed"
    return 1
}

# Trigger restore
trigger_restore() {
    echo "Triggering VolSync restore..."
    RESTORE_ID="restore-$(date +%s)"
    
    kubectl patch replicationdestination "${APP}-dst" -n "$NAMESPACE" \
        --type merge \
        -p "{\"spec\":{\"trigger\":{\"manual\":\"$RESTORE_ID\"}}}" || {
        echo "ERROR: Failed to trigger restore"
        exit 1
    }
    
    echo "Restore triggered with ID: $RESTORE_ID"
}

# Wait for restore to complete
wait_for_restore() {
    echo "Waiting for restore to complete (timeout: ${RESTORE_TIMEOUT}s)..."
    start_time=$(date +%s)
    
    while true; do
        elapsed=$(($(date +%s) - start_time))
        if [ $elapsed -gt $RESTORE_TIMEOUT ]; then
            echo "ERROR: Restore timeout after ${RESTORE_TIMEOUT}s"
            exit 1
        fi
        
        status=$(kubectl get replicationdestination "${APP}-dst" -n "$NAMESPACE" \
            -o jsonpath='{.status.conditions[?(@.type=="Synchronizing")].status}' 2>/dev/null || echo "Unknown")
        result=$(kubectl get replicationdestination "${APP}-dst" -n "$NAMESPACE" \
            -o jsonpath='{.status.latestMoverStatus.result}' 2>/dev/null || echo "Unknown")
        
        if [ "$status" = "False" ] && [ "$result" = "Successful" ]; then
            echo "✅ Restore completed successfully!"
            return 0
        elif [ "$result" = "Failed" ]; then
            echo "ERROR: Restore failed"
            exit 1
        fi
        
        echo "  Restore in progress... (${elapsed}s elapsed)"
        sleep 5
    done
}

# Main logic
if check_empty; then
    echo ""
    echo "=== Starting automatic restore ==="
    trigger_restore
    wait_for_restore
    echo ""
    echo "=== Restore complete - proceeding with app startup ==="
else
    echo ""
    echo "=== Data exists - skipping restore ==="
fi

exit 0

