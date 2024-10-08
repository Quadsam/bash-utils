#!/usr/bin/env bash

source './bash-lib/stdlib.sh'

## Defaults
shellcheck_def_args=('-x')
create_if_missing=false
_run=false

## Check if the file was provided, is executable, needs created, or readable
function check_file()
{
	## Show usage if no file is provided
	if [[ -z $input ]]; then
		stdLog error "Missing input file" >&2
		stdLog info "Use '-h' to show usage"
		exit 1
	fi

	## Is script executable?
	if [[ ! -e $input ]]; then
		## Create file with bash shebang if enabled
		if $create_if_missing; then
#			printf '#!/usr/bin/env bash\n\n' >"$input"
			cat <<EOF >"$input"
#!/usr/bin/env bash

source '/opt/bash-lib/stdlib.sh'

while getopts ':h' OPT; do
	case \$OPT in
	h)
		stdPager help <<EOF
Usage:
 \${self[2]} [-h]

 Template bash script.

Options:
 -h  show this help

%EOF%
		exit 0
		;;
	\?)
		stdLog error "Unrecognised argument -- '\$OPTARG'" >&2
		stdLog info 'Use "-h" to show usage'
		exit 1
		;;
	:)
		stdLog error "Missing argument to option -- '\$OPTARG'" >&2
		stdLog info 'Use "-h" to show usage'
		exit 1
		;;
	esac
done
shift \$((OPTIND-1))
EOF
		sed -i -r 's/%EOF%/EOF/' "$input"
		else
			stdLog error "$input: No such file or directory" >&2
			stdLog info "Use the '-c' option to create a new file" >&2
			exit 1
		fi
	## Is file readable?
	elif [[ ! -r $input ]]; then
		stdLog error "$input: Permission denied" >&2
		exit 1
	fi
}

## Check for and run nano(1) if found
function run_editor()
{
	nano_cmd=$(type -fP nano)
	if [[ -z $nano_cmd ]]; then
		stdLog error "nano: command not found" >&2
		exit 1
	fi
	"$nano_cmd" "$input"
}

## Check for and run shellcheck(1) if found
function check_syntax()
{
	shellcheck_cmd=$(type -fP shellcheck)
	if [[ -z $shellcheck_cmd ]]; then
		stdLog error "shellcheck: command not found" >&2
		exit 1
	fi
	stdLog info "Verifying syntax with shellcheck"
	printf '\e[01;33m========== ShellCheck Output ==========\e[00m\n'
	if "$shellcheck_cmd" "${shellcheck_def_args[@]}" "$input"; then
		printf '\eM\e[K'
		stdLog info "ShellCheck test $(printf '\e[01;32m')PASSED$(printf '\e[00m')"
	else
		printf '\e[01;33m============ End of Output ============\e[00m\n'
		stdLog warn "ShellCheck test $(printf '\e[01;31m')FAILED$(printf '\e[00m')" >&2
		exit 1
	fi
}

## Run the script if enabled
function run_script()
{
	if $_run; then
		if [[ ! -x $input ]]; then
			chmod +x "$input"
		fi
		[[ -z $_pager ]] && stdLog info "Executing 'bash $input ${_run_args[*]}'"
		[[ -n $_pager ]] && stdLog info "Executing 'bash $input ${_run_args[*]} | $_pager'"
		printf '\e[01;33m========== Script Output ==========\e[00m\n'
		[[ -z $_pager ]] && bash "$input" "${_run_args[@]}"
		[[ -n $_pager ]] && bash "$input" "${_run_args[@]}" | "$_pager"
		printf '\e[01;33m========== End of Output ==========\e[00m\n'
		stdLog info "Command exited with code $?"
	else
		stdLog info "Skipping script execution"
	fi
}


## Parse arguments
while getopts ':chrR:x' OPT; do
	case $OPT in
	c) ## Create the file if it doesn't exist
		create_if_missing=true
		;;
	h) ## Show help
		stdPager help <<EOF
Usage:
 ${self[2]} [-hcr] [-R <OPTS>] <file>

 A utility using 'nano(1)' and 'shellcheck(1)' to verify code integrity.

Options:
  -c         if the target file doesn't exist, create it
  -r         execute the script if shellcheck passes
  -R [OPTS]  options to pass to the script when executing with '-r'
  -X         run shellcheck without '-x' argument

  -h         show this help

EOF
		exit 0
		;;
	r) ## Execute after passing tests
		_run=true
		;;
	R) ## Arguments passed to script when executed
		if [[ $OPTARG =~ ^\| ]]; then
			_pager="${OPTARG:1}"
		else
			_run_args+=("$OPTARG")
		fi
		;;
	x) ## Run shellcheck without '-x'
		for arg in "${shellcheck_def_args[@]}"; do
			if [[ ! $arg == '-x' ]]; then
				new_args+=("$arg")
			fi
		done
		shellcheck_def_args=("${new_args[@]}")
		shift
		;;
	\?) ## Unrecognised option
		stdLog error "Unrecognised option -- '$OPTARG'" >&2
		stdLog info "Use '-h' to show usage"
		exit 1
		;;
	:) ## Missing required argument
		stdLog error "Missing argument to option -- '$OPTARG'" >&2
		stdLog info "Use '-h' to show usage"
		exit 1
		;;
	esac
done
shift $((OPTIND-1))


## Script filename should be the last argument remaining
input="$1"

check_file
run_editor
check_syntax
run_script
