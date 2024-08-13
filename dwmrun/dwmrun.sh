#!/usr/bin/env bash

# shellcheck disable=SC1090

source "/opt/bash-lib/stdlib.sh"

# Read the configuration file(s)
function readConfig()
{
	local sysConfig userConfig
	sysConfig="/etc/dwmrun.conf"
	userConfig="${XDG_CONFIG_HOME:=$HOME/.config}/dwmrun.conf"

	# Variable initialization
	logfile="$HOME/.cache/${self[2]}.log"
	declare -A programs

	# System config file
	if [[ -f $sysConfig ]]; then
		stdLog debug "Found system config file ('$sysConfig')"
		source "$sysConfig"
	else
		stdLog warn "Unable to find config file ('$sysConfig')"
	fi

	# User config file
	if [[ -f $userConfig ]]; then
		stdLog debug "Found user config file ('$userConfig')"
		source "$userConfig"
	fi


	# Verify items set in config file(s)

	## A display manager must be set
	if [[ -n $displaymgr ]]; then
		stdLog debug "Found config variable displaymgr ('$displaymgr')"
		if type -fP "$displaymgr" &>/dev/null; then
			# Update variable with full path
			displaymgr=$(type -fP "$displaymgr")
			stdLog debug "Updated displaymgr variable ('$displaymgr')"
		else
			stdLog error "Could not find command ('$displaymgr')"
			return 1
		fi
	else
		stdLog error "No display manager defined!"
		return 1
	fi

	## Update programs to full path
	if [[ -n ${programs[*]} ]]; then
		for program in "${!programs[@]}"; do
			if type -fP "$program" &>/dev/null; then
				arg="${programs[$program]}"
				program=$(type -fP "$program")
				fullprograms+=("$program $arg")
			else
				stdLog warn "Program not found ('$program')"
			fi
		done
	fi
}

# Generate a xinitrc
function genxinitrc()
{
	for ((i=0; i<${#fullprograms[@]}; i++)); do
		printf '%s\n' "${fullprograms[i]}" >>"$xinitrc"
	done
	printf 'exec %s\n' "$displaymgr" >>"$xinitrc"
}

function cleanup()
{
	# Remove the xinitrc we generated earlier
	stdLog info "Cleaning up generated files..."
	rm -rf "$xinitrc"

#	# Check for programs that did not exit with startx
#	for ((i=0; i<${#programs[@]}; i++)); do
#		pid=$(pidof "${programs[i]}")
#		if [[ $pid ]]; then
#			log "WARNING: ${programs[i]}($pid) is still running, manually killing"
#			kill "$pid"
#		fi
#	done
}

function log()
{
   local message
   message="$1"
   printf '[ %s ] - %s\n' "$(date +'%x %I:%M:%S')" "$message" | tee -a "$logfile"
}



# Generate a temp file to write our xinitrc to
xinitrc=$(mktemp -t "dwmrun.XXXXXXXXXX")

# Read the config file(s)
if readConfig; then
	log "Using display manager: '$displaymgr'"
	if [[ ${#fullprograms[@]} -gt 0 ]]; then
		log "Additional programs: ${#fullprograms[@]}"
		for ((i=0; i<${#fullprograms[@]}; i++)); do
			log "Program[$i]: '${fullprograms[$i]}'"
		done
	fi

	if genxinitrc; then
		log "Running startx..."
		XINITRC="$xinitrc" startx
		log "startx finished with code '$?'"
		cleanup
	else
		stdLog error "unable to write '$xinitrc'"
		exit 1
	fi
else
	stdLog error "unable to read config file(s)"
	exit 1
fi
