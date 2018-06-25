# cddash ver 0.8
#
# Cddash maintains a running history of previously visited directories and allows quick navigation and in-line completion.
#
### Main Functionality
# cd-    : Shows list of recently visited directories and their shortcut tokens
# cd-{K} : cd to Kth last dir (for example cd-3, cd-7 etc)
#
### Aliases
# It is possible to give the current directory a static alias with cd- alias <name>.
# Subsequently, running cd-<name> would change to that directory.
#
# An alias can be removed with cd- unalias <name>.
#
### In-Place Translation
# Cddash tokens (numbers or aliases) can be translated in place using a hotkey or tab completion.
# There are two distinct completions: If the token appears at the beginning of the command line( i.e ">cd-1") it would be expanded with a "cd" prefix (i.e ">cd /path/to/dir").
# If the token appears at a position other than the beginning, (i.e ">cp foo cd-1) it would be expanded without the "cd" prefix (i.e ">cp foo /path/to/dir")
#
# Translation can be done using a hotkey (default F12) immediately after the token. Subsequent presses iterate the directory forward in the list.
# A reserve-order hotkey is also defined (default shift-F12).
#
# Translation can also partially be achieved using tab completion.
# 
### Configuation
# Some aspects of cddash can be configured at the beginning top of this file, after this intro comment.
# _CDD_LOG_SIZE: The maximal size of the directory history log. History beyond this number is discarded. Default 10
# _CDD_LISTLOG_COMMAND_COLOR: The color of the token names when listed using cd-.
# _CDD_HOT_KEY & _CDD_HOT_KEY_REVERSE: Hotkey definitions.
# REMOVE_DUPLICATES: Flag indicating whether duplicate directories (i.e vising the same directory twice) should appear only once. If true, the older entries are removed from the log.
#
### Also defined
# cd- clear : clears the log
#
#
### Installation
# Add the following line to your .bashrc
#  source cddash.sh
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

#translate a cddash token (number or alias) to directory
_CDD_translate() {
        _CDD_TRANSLATE_DIR='';
        for ((i=0; i<${#_CDD_aliases[@]}; i+=2)); do
	      [[ ${_CDD_aliases[$i]} == $1 ]] && _CDD_TRANSLATE_DIR=${_CDD_aliases[$i+1]}
        done

	[[ $_CDD_TRANSLATE_DIR == '' ]] && [[ $1 =~ [0-9]+ ]] && _CDD_TRANSLATE_DIR=${_CDD_log[$1]};
}

_CDD_unalias() {
        # find index of alias
        declare ind
        for ((i=0; i<${#_CDD_aliases[@]}; i+=2)); do
                [[ $1 == ${_CDD_aliases[$i]} ]] && ind=$i
        done
        # remove alias if found
        [[ ! -z ${ind} ]] && _CDD_aliases=(${_CDD_aliases[@]:0:$ind} ${_CDD_aliases[@]:$(($ind + 2))})
}

# perform a cd to the cddash token (number or alias)
_CDD_docd() {
	_CDD_translate $1;
	[[ $_CDD_TRANSLATE_DIR != '' ]] && builtin cd $_CDD_TRANSLATE_DIR;
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
        for ((i=0; i<${#_CDD_aliases[@]}; i+=2)); do
                builtin echo -e ${_CDD_LISTLOG_COMMAND_COLOR}cd-${_CDD_aliases[$i]}${NC} ${_CDD_aliases[$i+1]}
        done

	# starts from 1 because cd-0 is the current directory.
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
	case $1 in
	"clear")
		_CDD_initialize
		;;
    "alias")
		if [[ -z $2 ]]; then
			echo "Usage: cd- alias <name_for_current_directory>"
		else
			_CDD_aliases=("${_CDD_aliases[@]}" $2 $PWD)
			eval "cd-$2() { cd \"$PWD\"; }"
		fi
		;;
	"unalias")
        if [[ -z $2 ]]; then
            echo "Usage: cd- unalias <alias_name_to_remove>"
        else
            _CDD_unalias "$2";
        fi
		;;
	*)				
		_CDD_listlog;
		;;
	esac	
}

function _CDD_complete_()
{
    local word=${COMP_WORDS[COMP_CWORD]}

    if [[ $word =~ cd-.* ]]; then
        _CDD_translate ${word:3};
        [[ $_CDD_TRANSLATE_DIR != '' ]] && COMPREPLY=$_CDD_TRANSLATE_DIR;
    fi

#    COMPREPLY=($(compgen -f -X "$xpat" -- "${word}"))
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
complete -W "clear alias unalias" "cd-"

# setup tab completion that translates cddash tokens on the fly
complete -D -F _CDD_complete_ -o default

# bind hotkeys
bind -x '"'${_CDD_HOT_KEY}'":_CDD_iterate_readline' # bind key to history iteration
bind -x '"'${_CDD_HOT_KEY_REVERSE}'":_CDD_iterate_readline_back' # bind key to history iteration


# start history log with PWD
_CDD_initialize;
