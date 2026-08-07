#!/usr/bin/env bash 
# server_heath_check.sh
echo "## A Devops capstone project"
echo "## The script  will check the health of multiple
## remote servers via SSH ."

# Usage : ./server_health_check.sh -l <list of servers> -u <remote user>
# ------------- Part 1 : "Strict Mode" ------------------------
# set -e : exit immediately if any command fails .  
# set -o pipefail : if any command in the pipeilne failed treat the whole pipeline as failed .  
# set -u : exit if an undefined command is used . 
set -oue pipefail 

#-------------- part 2 : "Clean-up & secure file " ---------------------------
# We create a temperory log file to record everything . 
# mktemp create a temperory secured file that will not clash with any existing file . 
log_file=$(mktemp /tmp/Server_health.XXXX)

check_server(){
	local server="$1"
	local user="$2"
	log_info "--- Checking server : $server  ------"
	
	# Use ssh here to send to commands in one connection
	ssh -n -o connectTimeout=5 "$user"@"$server" <<'EOF'	
	# Uptime check 
	echo " ------------ System uptime ----------"
	uptime
	# Disk check ( Root partition )
	echo "Disk Usage (Root / )" 
	# 'NR' means to output the second line of df command
	df -h | aws 'NR==2 {print "Used: " $5 " (" $3 "/" $2 ")"}'
	# Memeory check 
	echo " ----- Memory usage --------- "
	free -m | aws 'NR ==2 {
	printf "Used: %sMB / Total: %sMB (%.2f%%)\n",$3,$2,($3/$2)*100
}'
	# Security Check ( SSH brute force failure ) 
	echo "-------- Security check -------"
	auth_log="/var/log/auth.log"
	if [[ -f "$auth_log" ]];then  
	count=$(count -c "Failed password" "$auth_log")
	echo "Failed SSH attempts : $count"
else
	echo "Faild SSH attempts :  auth log not found "
	fi
EOF

log_info "----- Finished Check : $server ------ "

}



cleanup() {
	echo "Cleaning up temp files: $log_file"
	rm -rf "$log_file"
}
# readonly means tthis value cannot be changed 
readonly log_file
# Function Definitions 
# log an informational message for both screen and log file 
# Check server function 

log_error(){
	echo "[ERR] $1" | tee -a $log_file >&2 
}
log_info(){
	echo "[INFO] $1 | tee -a $log_file"
}
print_usage(){
	echo -e "Usage : $0 -l <list of servers> -u <remote user>"
	echo " -l : path to the file conatining list of servers ."
       	echo " -u : list of servers one per line ."
	echo " -h : to show this help message . "
}
main_function(){
	local server_file=""
	local remote_user=""
	# --- Argument parsing -----
	#---- using getopts -------
       	while getopts "h:l:u:" opt ; do 
		case $opt in
			l)	
				server_file=$OPTARG 
				;;
			u)
				remote_user=$OPTARG
				;;
	
			h)
				print_usage
				exit 0
				;;

			/?) # Invalid flag
				log_error = "Invalid option : -$OPTARG"
				print_usage
				exit 1
				;;
			:) # Missing value for a flag 
				log_error "option $OPTARG requires an argument ."
				print_usage
				exit 1 
				;;
		esac
	done 
				

# --------------Input validation ---------------- 
if [[ -z $server_file  || -z $remote_user ]];then
	log_error "Missing required arguments ."
	print_usage
	exit 1
fi
if [[ -f $server_file ]];then 
	echo "Server file not found ."
	exit 1 
fi 

echo "### Configuration Valid . Starting health check ."


# define an empty array to hold the servers 
declare -a servers=()
# read the file server line by line by safe method . 
while IFS= read -r line ; do 
	# Skip empty line 
	if [[ -z "$line" || "$line" == \#* ]];then 
		continue
	fi

# Add the servers to the array 
servers+=("$line")

done < "$server_file"

if [[ ${#servers[@]} -eq 0 ]];then
	log_error " No server found in $server_file . Exiting"
	exit 1	
fi
log_info "Found ${servers[@]} servers to check . Starting ... "
log_info "Configurtion valid . Starting health check ."

# ------------ Add health check logic --------------------- 


# ------- script entry point -----------------

# After reading the servers into the array 
log_info "Found ${#servers[@]} servers to check . starting...  "
# loop through the array properly 
for server_host in "${servers[@]}";do
	check_server "$server_host" "$remote_user"
done
#
log_info "All checks completed ."
}


# Execution of the main function . 
main_function "$@" 
#-------------- part 3 : "Take care" --------------------------
# trap this tail the script to exit whatever
# happened to the it . 
trap cleanup exit int term
echo "script started . log file created at : $log_file"






