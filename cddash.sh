# cddash ver 0.1
#
# Maintains a running history of last 10 visited dirs and allows quick naviation.
# Adds the following commands:
# cd-? shows list
# cd-1 cd to last dir (just like "cd -")
# cd-2 cd to 2nd to last dir 
# cd-9 cd to 9th to last dir
#
# To install, add the following line to your .bashrc
# source cddash.sh
#
#####################################################

###
# Configuration
#
declare -i _CDD_LOG_SIZE=10 # Size of the directory history
declare _CDD_LISTLOG_COMMAND_COLOR='\033[1;36m' # In "cd-?", the color of the command part. Currently Cyan

### 
# "Private" functions and data
#

# the history
declare -a _CDD_log=()

# do the actual cd
_CDD_docd() {
	cd "${_CDD_log[$1]}";
}

# process a potential new directory in $PWD
_CDD_newdirpwd() {
	[[ $PWD == ${_CDD_log[0]} ]] && return 

	local -i i
	for ((i=_CDD_LOG_SIZE-1; i>0; i--)); do
		_CDD_log[i]=${_CDD_log[$i-1]}
	done
	_CDD_log[0]=$PWD
}

declare NC='\033[0m' # No Color

_CDD_listlog() {
	local -i i
	for ((i=1; i<_CDD_LOG_SIZE; i++)); do
		if [ "x${_CDD_log[$i]}" != "x" ]; then
			builtin echo -e ${_CDD_LISTLOG_COMMAND_COLOR}cd-$i${NC} ${_CDD_log[$i]}
		fi
	done
}

# setup cd-{k} functions.
_CDD_setup_funcs() {
	# eval in this format: cd-3() { _CDD_docd 3; }
	local -i i
	for ((i=0; i<_CDD_LOG_SIZE; i++)); do
		eval "cd-$i() { _CDD_docd $i; }"
	done
}

###
# Directory iteration in a readline function

declare -i _CDD_iterate_index=0

_CDD_iterate_readline() {
	if [ ${#READLINE_LINE} != 0 ] && [ "${READLINE_LINE:0:2}" != "cd" ]; then
		return 0
	fi
	
	_CDD_iterate_index=$(( (_CDD_iterate_index+1) % _CDD_LOG_SIZE))
	local dir=${_CDD_log[_CDD_iterate_index]}
	if [ ${#dir} == 0 ]; then
		_CDD_iterate_index=0
	fi
	
	dir2=$(printf '%q' "$dir")
	if (( ${#dir2} > ${#dir} )); then
		dir="\"${dir}\""
	fi

	READLINE_LINE="cd ${dir}"
	
	if (( _CDD_iterate_index == 0 )); then
		READLINE_LINE=""
	fi
	
	READLINE_POINT=${#READLINE_LINE}
}


_CDD_on_prompt() {
	_CDD_iterate_index=0
	_CDD_newdirpwd
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

cd-?() { _CDD_listlog; } # setup cd-?
cd-() { cd -; }          # setup cd- as a shortcut for "cd -"
_CDD_setup_funcs;        # setup all of cd-K

bind -x '"\e[24~":_CDD_iterate_readline' # bind key to history iteration

# start history log with PWD
_CDD_newdirpwd;