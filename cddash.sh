# cddash ver 0.1
#
# Maintains a running history of last 10 visited dirs and allows quick naviation.
# Adds the following commands:
# cd-? shows list
# cd-1 cd to last dir (just like "cd -")
# cd-2 cd to 2nd to last dir 
# cd-9 cd to 9th to last dir

# To install, add the following line to your .bashrc
# source cddash.sh

#####################################################

###
#TODO
# Create script for other shells / cross shell compatibilty


### 
# "Private" functions and data

# holds the directory history
declare -i _CDD_LOG_SIZE=10

_CDD_log=()

_CDD_docd() {
	cd "${_CDD_log[$1]}";
}

_CDD_newdirpwd() {
	[[ $PWD == ${_CDD_log[0]} ]] && return 

	local -i i
	for ((i=_CDD_LOG_SIZE-1; i>0; i--)); do
		_CDD_log[i]=${_CDD_log[$i-1]}
	done
	_CDD_log[0]=$PWD
}

COMMANDCOLOR='\033[1;36m'
NC='\033[0m' # No Color

_CDD_listlog() {
	local -i i
	for ((i=1; i<_CDD_LOG_SIZE; i++)); do
		if [ "x${_CDD_log[$i]}" != "x" ]; then
			builtin echo -e ${COMMANDCOLOR}cd-$i${NC} ${_CDD_log[$i]}
		fi
	done
}

#####
# Setup the hook (i.e how the shell notifys the code that a new dir has been reached)
# there several options:

# can substitue cd. either with an alias or like below.
# pros: code runs only at cds. cons: doesnt get other ways of cding like pushd etc
#function cd () { builtin cd "$@" && _CDD_newdirpwd; }

# can hook the prompt.
# pros: captures any change in dir. con (or feature): if many cds happen in the same command, they won't be _CDD_logged. (example: cd aaa; cd bbb; cd-2;) also runs every prompt
export PROMPT_COMMAND=_CDD_newdirpwd;$PROMPT_COMMAND

# in TCSH there is cwdcmd. in zch there is cmpwd()

#####
# Setup public function (i.e the used shell commands)

# setup cd-?
cd-?() { _CDD_listlog; }

# setup cd-{k} functions.
_CDD_setup_funcs() {
	# eval in this format: cd-3() { _CDD_docd 3; }
	local -i i
	for ((i=0; i<_CDD_LOG_SIZE; i++)); do
		eval "cd-$i() { _CDD_docd $i; }"
	done
}
cd-() { cd -; }



### Startup

# setup 
_CDD_setup_funcs;
# start off with PWD
_CDD_newdirpwd;