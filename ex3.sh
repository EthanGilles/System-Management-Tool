#!/bin/bash

# Path to the log file
LOG_FILE="ex3_log.txt"

#HELPER FUNCTIONS --

# Logs a command using the LOG_FILE variable
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ($USER) $@" >> "$LOG_FILE"
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
        echo "Showing processes that match '$1':"
        echo ""
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

# -find [dir] [pattern]
find_it() {
    # If there are not two arguments to the backup command then display the usage
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Error: Please enter a directory to search and a pattern to find in filenames"
        echo ""
        echo "----------------------------------------------------------------------"
        echo "Usage:   -find [directory] [pattern]"
        echo "         [directory]      Directory (and all of its subdirectories) to be searched."
        echo "         [pattern]        The pattern to match to the file names."
        exit 1
    fi
    
    # Error handling
    if [ ! -d "$1" ]; then
        echo "Error: Directory '$1' does not exist."
        exit 1
    fi
    

    echo "Searching in '$1' for files matching the pattern '$2':"
    echo ""
    find "$1" -type f -name "$2"
}

# -dupes [dir]
dupes() {
    # When no directory is entered.
    if [ -z "$1" ]; then
        echo "Error: Please enter a directory to search for duplicate files"
        echo ""
        echo "----------------------------------------------------------------------"
        echo "Usage:   -dupes [directory]"
        echo "         [directory]      Directory (and all of its subdirectories) to be searched."
        exit 1
    fi

    echo "Identifying duplicate files in '$1'. This might take a while ... "
    # find files in the directory, sort by checksum, then print the duplicate checksum values
    find "$1" -type f -exec md5sum {} + | sort | uniq -w32 --all-repeated=separate
}

# -cleanup [dir]
cleanup() {
    # When no directory is entered.
    if [ -z "$1" ]; then
        echo "Error: Please enter a directory to remove all temporary files"
        echo "       Temporary files are files marked with '.tmp' or '.bak'"
        echo ""
        echo "----------------------------------------------------------------------"
        echo "Usage:   -cleanup [directory]"
        echo "         [directory]      Directory to remove temporary files"
        exit 1
    fi

    # Print temp files
    echo "Cleaning up files in '$1'..."
    find "$1" -type f \( -name "*.tmp" -o -name "*.bak" \) -print

    # Read their response to the confirmation question
    read -p "Are you sure you want to delete these files? (y/n): " maybe
    
    # If the response is not "y"
    if [ "$maybe" != "y" ]; then
        echo "Files will not be deleted."
    else # If the response is "y" find and delete the files again.
        find "$1" -type f \( -name "*.tmp" -o -name "*.bak" \) -delete
        echo "Cleanup complete."
    fi
    
}

# alertThreshold [MEM%]
alertThresh() {
    # When no directory is entered.
    if [ -z "$1" ]; then
        echo "Error: Please enter a memory percentage to act as a threshold for alerts"
        echo ""
        echo "----------------------------------------------------------------------"
        echo "Usage:   -alertThreshold [MEM%]"
        echo "         [MEM%]      Memory percentage (0-100) threshold."
        echo "         Any value > MEM% will trigger an alert."
        exit 1
    fi

    # Get total memory and free memory
    total_mem=$(free -m | awk 'NR==2 {print $2}')
    free_mem=$(free -m | awk 'NR==2 {print $4}')

    # Calculate used memory percentage
    used_mem=$((100 * ($total_mem - $free_mem) / $total_mem))

    echo "Current Memory Usage: $used_mem%"
    if [ "$used_mem" -gt "$1" ]; then
        echo "Warning: Memory usage ($used_mem%) exceeds threshold ($1%)!"
    fi
}

# -help
help() {
    # Displays help screen

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
    echo "  ./ex3.sh -find . '*.tmp'"
    echo "  ./ex3.sh -dupes /path/to/check"
    echo "  ./ex3.sh -alertThreshold 75"
    echo "  ./ex3.sh -cleanup /path/to/cleanup"
}

#EXECUTION --

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
        -find)
            find_it "$2" "$3"
            exit 0
            ;;
        -dupes)
            dupes "$2"
            exit 0
            ;;
        -cleanup)
            cleanup "$2"
            exit 0
            ;;
        -alertThreshold)
            alertThresh "$2"
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

# If there are no command, then just show the help page.
if [[ $# -eq 0 ]]; then
    help
    exit 0
fi