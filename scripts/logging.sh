#!/bin/bash
#
# logging.sh - Centralized Logging System
#
# This script provides a unified logging system with different log levels
# and the ability to control verbosity through environment variables.
#
# Log levels:
# - ERROR (0): Critical errors that prevent normal operation
# - WARN  (1): Warnings that don't prevent operation but indicate issues
# - INFO  (2): Informational messages about normal operation
# - DEBUG (3): Detailed information for debugging purposes
#

# Default log level is INFO (2) if not specified
LOG_LEVEL=${LOG_LEVEL:-2}

# Log file path
LOG_FILE=${LOG_FILE:-"/var/log/torzvpn.log"}

# Whether to output logs to stdout in addition to the log file
LOG_TO_STDOUT=${LOG_TO_STDOUT:-"true"}

# Log level names for better readability
declare -A LOG_LEVEL_NAMES
LOG_LEVEL_NAMES[0]="ERROR"
LOG_LEVEL_NAMES[1]="WARN"
LOG_LEVEL_NAMES[2]="INFO"
LOG_LEVEL_NAMES[3]="DEBUG"

# Log function with timestamp and log level
# Usage: log <level> <message>
# Example: log 0 "Critical error occurred"
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level_name=${LOG_LEVEL_NAMES[$level]}
    
    # Only log if the current level is >= the specified level
    if [ "$level" -le "$LOG_LEVEL" ]; then
        # Format the log message
        local log_message="[$timestamp] [$level_name] $message"
        
        # Write to log file
        echo "$log_message" >> "$LOG_FILE"
        
        # Output to stdout if enabled
        if [ "$LOG_TO_STDOUT" = "true" ]; then
            # For ERROR and WARN, output to stderr
            if [ "$level" -le 1 ]; then
                echo "$log_message" >&2
            else
                echo "$log_message"
            fi
        fi
    fi
}

# Convenience functions for different log levels
log_error() {
    log 0 "$1"
}

log_warn() {
    log 1 "$1"
}

log_info() {
    log 2 "$1"
}

log_debug() {
    log 3 "$1"
}

# Initialize log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    log_info "Log file initialized at $LOG_FILE"
    log_info "Logging level set to ${LOG_LEVEL_NAMES[$LOG_LEVEL]}"
fi

# Export functions so they can be used in other scripts
export -f log
export -f log_error
export -f log_warn
export -f log_info
export -f log_debug
