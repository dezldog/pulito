#!/bin/bash
# pulito - 'clean' in Italian
# Script to mount S3 buckets, sync data, and scan for viruses
# Improved version with proper error handling and logging
# Usage: pulito S3BUCKETNAME
# Dependencies: clamscan, s3fs-fuse, rsync
# 29JUL25


set -e  # Exit on any error
set -u  # Exit on undefined variables

# Configuration - Update these paths for your environment
LOG_DIR='[LOG DIRECTORY]'
MOUNT_DIR='[MOUNT LOCATION]'
DATA_DIR='[WHERE THE DATA LIVES]'
CACHE_DIR='[WHERE TO STORE DATA CACHE]'

# Script configuration
MOUNT_TIMEOUT=10
REQUIRED_TOOLS=("s3fs" "rsync" "clamscan")

# Logging function with consistent timestamps
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$LOG_DIR/$BUCKET_NAME"
}

# Error handling function
error_exit() {
    log "ERROR" "$1"
    echo "ERROR: $1" >&2
    cleanup_and_exit 1
}

# Cleanup function
cleanup_and_exit() {
    local exit_code=${1:-0}
    if mountpoint -q "$MOUNT_DIR/$BUCKET_NAME" 2>/dev/null; then
        log "INFO" "Unmounting $BUCKET_NAME"
        fusermount -u "$MOUNT_DIR/$BUCKET_NAME" || true
    fi
    exit $exit_code
}

# Trap signals for cleanup
trap 'cleanup_and_exit 130' INT TERM

# Validate S3 bucket name format
validate_bucket_name() {
    local bucket="$1"
    if [[ ! "$bucket" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || [[ ${#bucket} -lt 3 ]] || [[ ${#bucket} -gt 63 ]]; then
        error_exit "Invalid S3 bucket name format: $bucket"
    fi
    if [[ "$bucket" == *".."* ]] || [[ "$bucket" == *".-"* ]] || [[ "$bucket" == *"-."* ]]; then
        error_exit "Invalid S3 bucket name format: $bucket"
    fi
}

# Check if required tools are available
check_dependencies() {
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool '$tool' is not installed or not in PATH"
        fi
    done
}

# Check if directories exist
check_directories() {
    for dir in "$LOG_DIR" "$MOUNT_DIR" "$DATA_DIR" "$CACHE_DIR"; do
        if [[ ! -d "$dir" ]]; then
            error_exit "Directory does not exist: $dir"
        fi
    done
}

# Mount S3 bucket
mount_bucket() {
    local bucket="$1"
    local mount_point="$MOUNT_DIR/$bucket"
    
    # Create mount point if it doesn't exist
    mkdir -p "$mount_point"
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log "INFO" "$bucket is already mounted"
        return 0
    fi
    
    log "INFO" "Mounting $bucket to $mount_point"
    
    # Mount with timeout
    timeout $MOUNT_TIMEOUT s3fs -o allow_other -o use_cache="$CACHE_DIR" "$bucket" "$mount_point"
    
    # Verify mount succeeded
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        error_exit "Failed to mount S3 bucket: $bucket"
    fi
    
    log "INFO" "Successfully mounted $bucket"
}

# Sync data with rsync
sync_data() {
    local bucket="$1"
    local source="$MOUNT_DIR/$bucket/"
    local dest="$DATA_DIR/"
    
    log "INFO" "Starting rsync for $bucket"
    
    if ! rsync -av --progress "$source" "$dest" >> "$LOG_DIR/$bucket" 2>&1; then
        error_exit "rsync failed for $bucket"
    fi
    
    log "INFO" "rsync completed successfully for $bucket"
}

# Run virus scan
virus_scan() {
    local bucket="$1"
    local scan_path="$MOUNT_DIR/$bucket"
    
    log "INFO" "Starting virus scan for $bucket"
    
    # Run clamscan with proper error handling
    if ! clamscan -i -r --log="$LOG_DIR/$bucket.clamscan" "$scan_path" >> "$LOG_DIR/$bucket" 2>&1; then
        # clamscan returns 1 if viruses found, 2 for errors
        local exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            log "WARNING" "Viruses found during scan of $bucket - check clamscan log"
        else
            error_exit "clamscan failed with exit code $exit_code for $bucket"
        fi
    else
        log "INFO" "Virus scan completed - no threats found for $bucket"
    fi
}

# Main function
main() {
    # Check usage
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 S3BUCKETNAME"
        echo "Example: $0 my-s3-bucket"
        exit 1
    fi
    
    local bucket="$1"
    
    # Set global variable for cleanup function
    BUCKET_NAME="$bucket"
    
    # Initialize log file
    touch "$LOG_DIR/$bucket"
    log "INFO" "Starting pulito script for bucket: $bucket"
    
    # Run all checks
    validate_bucket_name "$bucket"
    check_dependencies
    check_directories
    
    # Execute main operations
    mount_bucket "$bucket"
    sync_data "$bucket"
    virus_scan "$bucket"
    
    log "INFO" "All operations completed successfully for $bucket"
    echo "Script completed successfully. Check log: $LOG_DIR/$bucket"
}

# Run main function with all arguments
main "$@"