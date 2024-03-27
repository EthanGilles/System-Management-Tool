#!/bin/bash

# Path to the log file
LOG_FILE="ex3_log.txt"

#HELPER FUNCTIONS --

# Logs a command using the LOG_FILE variable
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ($USER) $@" >> "$LOG_FILE"
}

# -help
help() {
    echo "Usage: $0 [options] [arguments]"
    echo ""
    echo "Options:"
    echo "  -disk                 Show disk usage for all mounted filesystems, indicating available and used space."
    echo "  -mem                  Display a summary of memory usage, including total, used, free, and cached memory."
    echo "  -procs [filter]       Show running processes, optionally filtered by a user or command name."
    echo "  -kill [PID]           Terminate a process by PID"
    echo "  -backup [dir] [dest]  Create a compressed backup of a specified directory, with options for destination path."
    echo "  -find [dir] [pattern] Search for files matching a pattern and a list of their locations"
    echo "  -dupes [dir]          Identify duplicate files in a specified directory or the entire filesystem."
    echo "  -cleanup [dir]        Cleanup a specified directory by removing temporary or unnecessary files."
    echo "  -alertThreshold [MEM%]  Set alert thresholds for memory usage."
    echo "  -help                 Display this help message and exit"
    echo ""
    echo "Examples: "
    echo "  ./ex3.sh -disk"
    echo "  ./ex3.sh -mem"
    echo "  ./ex3.sh -procs sshd"
    echo "  ./ex3.sh -kill 0"
    echo "  ./ex3.sh -backup /path/to/source /path/to/destination"
    echo "  ./ex3.sh -find '*.tmp'"
    echo "  ./ex3.sh -dupes /path/to/check"
    echo "  ./ex3.sh -alertThreshold 75 80"
    echo "  ./ex3.sh -cleanup /path/to/cleanup"
}

# -disk
disk() {
    echo "Disk Usage for All Mounted Filesystems: "
    echo "----------------------------------------"

    #Disk usage removing the disks with none or snapfuse as a name
    df -h | grep -v -E "none|snapfuse" | awk '{print $5 " used on " $1}'
}

# -mem
memory() {
    # Get memory usage information using free
    memory_info=$(free | grep Mem)

    # Get the metrics from the list
    total_memory=$(echo "$memory_info" | awk '{print $2}')
    used_memory=$(echo "$memory_info" | awk '{print $3}')
    free_memory=$(echo "$memory_info" | awk '{print $4}')
    cached_memory=$(echo "$memory_info" | awk '{print $7}')

    #  Print the summary, reducing the values to MB instead of kB
    echo "Memory Usage Summary:"
    echo "---------------------"
    echo "Total:   $((total_memory / 1024)) MB "
    echo "Used:    $((used_memory / 1024 )) MB"
    echo "Free:    $((free_memory / 1024 )) MB"
    echo "Cached:  $((cached_memory / 1024 )) MB"
}

# -procs [filter]
procs() {
    if [ -z "$1" ]; then
        ps -e -o user,pid,ppid,tty,stime,cmd
    else
        ps -e -o user,pid,ppid,tty,stime,cmd | awk -v value="$1" '(value == $1 || value == $2)'
    fi
}

# -kill [PID]
kill_proc() {

    # First, check if a PID was entered. Show usage if not.
    if [ -z "$1" ]; then
        echo "Error:     PLEASE ENTER A [PID]"
        echo ""
        echo "-------------------------------"
        echo "Usage:     ./ex3.sh -kill [PID]"
        echo "Example:   ./ex3.sh -kill 1079"
        exit 1
    fi

    # Then, check if the PID is actually a process.
    if ! ps -p "$1" > /dev/null; then
        echo "Error: Process with PID $1 does not exist."
    else
        # Read their response to the confirmation question
        read -p "Are you sure you want to kill the process $1? (y/n): " maybe

        # If the response is not "y"
        if [ "$maybe" != "y" ]; then
            echo "Process termination cancelled for process $1."
        else
            kill "$1"
            echo "Process $1 terminated."
        fi

    fi
}

# -backup [dir] [dest]
backup() { 
    # If there are not two arguments to the backup command then display the usage
    if [ -z "$1" ] && [ -z "$2" ]; then
        echo "Error: Please enter a source directory and a destination directory"
        echo ""
        echo "----------------------------------------------------------------------"
        echo "Usage:   -backup [source_directory] [destination_directory]"
        echo "         [source_directory]         Source directory that will be backed up"
        echo "         [destination_directory]    Destination directory where the backup will be saved"
        exit 1
    fi

    # The variables needed for the command
    source="$1"
    destination="$2"
    backup="backup_$(date +'%Y-%m-%d_%H-%M-%S').tar.gz"

    # If the source destination is not actually a directory then display error message.
    if [ ! -d "$source" ]; then
        echo "Error: Source directory '$source' does not exist."
        exit 1
    elif [ ! -d "$destination" ]; then #if the destination directory doesnt exist, make it.
        mkdir -p "$destination"
    fi

    # Create the backup and let user know what is happening.
    echo "Creating compressed backup of '$1' at '$2/$backup'."
    tar -czf "$2/$backup" -P "$1"
    echo "Completed."

} 



#EXECUTION OF SCRIPT --

# Log the command.
log "$0 $*"

#Process the command that is input
if [[ $# -gt 0 ]]; then
    case "$1" in
        -help)
            help
            exit 0
            ;;
        -disk)
            disk
            exit 0
            ;;
        -mem)
            memory
            exit 0
            ;;
        -procs)
            procs "$2"
            exit 0
            ;;
        -kill)
            kill_proc "$2"
            exit 0
            ;;
        -backup)
            backup "$2" "$3"
            exit 0
            ;;
        *)  # If an o
            echo "Error: Unknown command '$1'"
            echo ""
            help
            exit 1
            ;;
    esac
fi

# If there are no command, then the script just shows the help page.
if [[ $# -eq 0 ]]; then
    help
    exit 0
fi