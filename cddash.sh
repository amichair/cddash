# cddash ver 0.8
#
# Maintains a running history of last visited directories and allows quick navigation and in-line completion.
# Adds the following commands to the shell:
# cd-    : Shows list of directories seen
# cd-{K} : cd to Kth last dir (for example cd-3, cd-7 etc)
#
# A hotkey is defined (default is F12)
# Pressing the hotkey when the cursor is immediataly after "cd-" or "cd-{K}" expands the token to the 1st (or Kth) directory in the list. Subsuquent presses iterate forward.
# 
# Also defined:
# cd- clear : clears the log
# cd- resize {N} : resets the log history to size {N}
# A reservse-iteration hotkey: Default is Shift+F12
#
# To install, add the following line to your .bashrc
# source cddash.sh
#
#####################################################

###
# Configuration
#
declare -i _CDD_LOG_SIZE=10 # Default size of the directory history
declare _CDD_LISTLOG_COMMAND_COLOR='\033[1;36m' # The color of the command part in "cd-". Currently Cyan
declare _CDD_HOT_KEY="\e[24~" # default is F12
declare _CDD_HOT_KEY_REVERSE="\e[24;2~" # default is shift-F12

declare REMOVE_DUPLICATES=true #Define this to remove duplicates from the log 


### 
# "Private" functions and data
#

# initialize
_CDD_initialize() {
	# start the global array empty
	declare -g -a _CDD_log=()
	
	# remove any prevoiously decleared accessor functions
	for ((i=1; i<_CDD_LOG_SIZE; i++)); do
		unset -f "cd-$i"
	done

	# start stack with currert dir
	_CDD_newdirpwd;
}

# perform the actual cd
_CDD_docd() {
	builtin cd "${_CDD_log[$1]}";
}

# process a potential new directory in $PWD
_CDD_newdirpwd() {
	# if it's not a new dir, nothing to do
	[[ $PWD == ${_CDD_log[0]} ]] && return 

	# perform an unshift to the array
	_CDD_log=("${PWD}" "${_CDD_log[@]}")

	# find duplicate entries to current dir
	declare dup
	for ((i=1; i<_CDD_LOG_SIZE; i++)); do
		[[ $PWD == "${_CDD_log[$i]}" ]] && dup=$i
	done
	# remove dups
	[[ ${REMOVE_DUPLICATES} ]] && [[ ! -z ${dup} ]] && _CDD_log=(${_CDD_log[@]:0:$dup} ${_CDD_log[@]:$(($dup + 1))})
		
	
	# setup accessor commands for defined values
	for ((i=1; i<_CDD_LOG_SIZE; i++)); do
		[[ ! -z "${_CDD_log[$i]}" ]] && eval "cd-$i() { _CDD_docd $i; }"
	done
}

declare NC='\033[0m' # No Color

_CDD_listlog() {
	for ((i=1; i<_CDD_LOG_SIZE; i++)); do
		[[ ! -z "${_CDD_log[$i]}" ]] && builtin echo -e ${_CDD_LISTLOG_COMMAND_COLOR}cd-$i${NC} ${_CDD_log[$i]}
	done
}

###
# Directory iteration in a readline function

# the current iteration index
declare -i _CDD_iterate_index=0

# Modify READLINE. Expand "cd-" pointed to by cursor to first dir in list.
# Subsequent invocation iterate dir
_CDD_iterate_readline() {
	# direction of iteration. default is forward. If func has a parameter, its backward
	declare step=1
	[[ ! -z $1 ]] && step=-1
	
	declare token_start=-1
	# if first run, only accept if cursor is pointing to "cd-"
	if ((_CDD_iterate_index == 0 ))
	then
		if [[ "${READLINE_LINE}" == "" ]]
		then
			token_start=0
		fi
		if [[ "${READLINE_LINE:READLINE_POINT-3:3}" == "cd-" ]]
		then
			token_start=$((READLINE_POINT-3))
		fi
		if [[ "${READLINE_LINE:READLINE_POINT-4:4}" =~ cd-[0-9] ]]
		then
			token_start=$((READLINE_POINT-4))
			_CDD_iterate_index=${READLINE_LINE:READLINE_POINT-1:1}
			_CDD_iterate_index=$((_CDD_iterate_index-step))
		fi
		if [[ "${READLINE_LINE:READLINE_POINT-5:5}" =~ cd-[0-9]{2} ]]
		then
			token_start=$((READLINE_POINT-5))
			_CDD_iterate_index=${READLINE_LINE:READLINE_POINT-2:2}
			_CDD_iterate_index=$((_CDD_iterate_index-step))
		fi
		
		(( token_start<0 )) && return;
		
		#store prefix and suffix for later invocations. store original token for when we finish log
		_CDD_rl_prefix="${READLINE_LINE:0:token_start}"
		_CDD_rl_suffix="${READLINE_LINE:READLINE_POINT}"
		_CDD_rl_original="${READLINE_LINE:token_start:READLINE_POINT-token_start}"
	fi	
	
	# get next entry, looping from the end back to the start
	declare logsize=${#_CDD_log[@]}		
	_CDD_iterate_index=$(( (_CDD_iterate_index+step) % logsize))
	# get dir string
	local dir=${_CDD_log[_CDD_iterate_index]}	
	# add quotes to the directory only if needed. Check if there are any escaped charecters
	dire=$(printf '%q' "$dir")
	(( ${#dire} > ${#dir} )) &&	dir="\"${dir}\""

	# if we have finished and are starting a new loop, return the original token
	(( _CDD_iterate_index == 0 )) && dir=${_CDD_rl_original} 

	# set READLINE to contain the directory
	READLINE_LINE="${_CDD_rl_prefix}${dir}"

	# if we started on a blank line, and this is an expantion, prefix with "cd "
	(( _CDD_iterate_index > 0 )) && (( ${#_CDD_rl_original} == 0 )) && READLINE_LINE="cd ${READLINE_LINE}"
	
	# set cursor to just after the dir
	READLINE_POINT=${#READLINE_LINE}

	# add suffix
	READLINE_LINE="${READLINE_LINE}${_CDD_rl_suffix}"

}

# iterate backwards
_CDD_iterate_readline_back() {
	_CDD_iterate_readline BACKWARD
}



# event handler for each prompt
_CDD_on_prompt() {
	_CDD_iterate_index=0 # reset the iterator index
	_CDD_newdirpwd       # add current dir if new
}


_CDD_main() {
	if [[ $1 == "clear"  ]]; then
		_CDD_initialize
	else
		if [[ $1 == "resize" ]]; then
			if [[ -z $2 ]]; then
				echo "usage: cd- resize <size_of_log>"
			else
				_CDD_LOG_SIZE=$2	
			fi
				
		else
			_CDD_listlog
		fi
	fi
}

#####
# Setup the hook (i.e how the shell notifys the code that a new dir has been reached)
# there several options:

# can substitue cd. either with an alias or like below.
# pros: code runs only at cds. cons: doesnt get other ways of cding like pushd etc
#function cd () { builtin cd "$@" && _CDD_newdirpwd; }

# can hook the prompt.
# pros: captures any change in dir. con (or feature): if many cds happen in the same command, they won't be _CDD_logged. (example: cd aaa; cd bbb; cd-2;) also runs every prompt
export PROMPT_COMMAND=_CDD_on_prompt;$PROMPT_COMMAND

# in TCSH there is cwdcmd. in zch there is cmpwd()

#####
# Setup public function (i.e the actual shell commands)

cd-() { _CDD_main $@; } # setup cd-

# setup tab completion for commands
complete -W "clear resize" "cd-"

# bind hotkeys
bind -x '"'${_CDD_HOT_KEY}'":_CDD_iterate_readline' # bind key to history iteration
bind -x '"'${_CDD_HOT_KEY_REVERSE}'":_CDD_iterate_readline_back' # bind key to history iteration

# start history log with PWD
_CDD_initialize;