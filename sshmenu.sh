#!/bin/bash
# SSHMenu originally called SSHTo by Ivan (https://github.com/vaniacer/sshto) has been an amazing tool for someone who
# handles many VMs or Bare-Metal systems. I have improved a few things with the changelog below:
# * Changed all of the BASH 4.x math functions
# * Allowed for multiple ssh config files
# * Created an install file to allow sshmenu to run from anywhere on the system
# * Built out the sshmenurc configuration
# * Added --list-hosts, --config, and --refresh arguments
# * Built in a configuration editor for SSHMenu
# - TODO: Change the system to no longer require dialog.

# Define required packages
required_packages=("dialog" "gawk")

# Helper message for missing packages
install_help="${BLD}sshmenu$DEF requires that the package '${GRN}%s$DEF' is installed.\nType this into the terminal and press return:\n\n\t${BLD}%s$DEF\n\nThen run ${BLD}sshmenu$DEF again."

refresh_config_files() {
    echo "🔄 Refreshing SSH configuration file list..."
    
    # Always start with the main SSH config file
    CONFILES="$HOME/.ssh/config"
    
    # Debugging: Check if main config file exists
    if [[ ! -f "$HOME/.ssh/config" ]]; then
        echo "⚠️ Warning: $HOME/.ssh/config does not exist!"
        return
    fi
    
    # Extract 'Include' directives and resolve them
    while IFS= read -r include_pattern; do
        echo "🔍 Found Include directive: $include_pattern"

        # Resolve relative paths (e.g., "./config.d/*") by converting to absolute paths
        if [[ "$include_pattern" == ./* ]]; then
            absolute_pattern="$HOME/.ssh/${include_pattern#./}"
        else
            absolute_pattern="$include_pattern"
        fi

        echo "🛠 Resolved pattern: $absolute_pattern"

        # Expand wildcards and append only valid SSH config files
        for file in $absolute_pattern; do
            if [[ -f "$file" ]]; then
                CONFILES+=" $file"
                echo "✅ Added: $file"
            else
                echo "⚠️ Skipped: $file (not found)"
            fi
        done
    done < <(grep -iE '^Include ' "$HOME/.ssh/config" | awk '{print $2}')

    echo "🔄 Updated CONFILES: $CONFILES"
}

check_confile() {
    [[ -e "$confile" ]] || return

    # Ensure correct permissions
    if [[ $(stat -c "%a %U %G" "$confile") != "600 $USER $USER" ]]; then
        chmod 600 "$confile"
        echo "Fixed permissions: $confile set to 600."
    fi

    # Refresh SSH config files **before sourcing the config**
    refresh_config_files

    # Reload the config file after updating SSH Includes
    source "$confile"
}

create_config() {
    echo "Running create_config()..."

    # Refresh SSH config files before creating the config
    refresh_config_files

    # Define base config without hardcoding CONFILES
    config_opts="# sshmenu Configuration File - do not manually edit, use sshmenu --config to make changes\n"
    config_opts+="home=$HOME\n"
    config_opts+="OPT=\n"
    config_opts+="KEY=$HOME/.ssh/id_rsa.pub\n"
    config_opts+="CONFILES=\"$CONFILES\"\n"  # Use dynamically updated CONFILES
    config_opts+="REMOTE=8080\n"
    config_opts+="LOCAL=18080\n"
    config_opts+="GUEST=$USER\n"
    config_opts+="DEST=\"$HOME\"\n"
    config_opts+="TIME=60\n"
    config_opts+="EDITOR=nano\n"
    config_opts+="LSEXIT=true\n"
    config_opts+="sshfsopt=\n"
    config_opts+="group_id=group\n"
    config_opts+="knwhosts=$HOME/.ssh/known_hosts\n"
    config_opts+="confile=$HOME/.sshmenurc\n"
    config_opts+="tmpfile=/tmp/sshmenurc-$USER\n"
    config_opts+="sshmenu_script[0]=$HOME\n"
    config_opts+="sshmenu_script[1]=.sshmenu_script\n"
    config_opts+="sshmenu_script[2]=\"\${sshmenu_script[0]}/\${sshmenu_script[1]}\"\n"

    echo "Checking if config file exists..."

    if [[ ! -f "$HOME/.sshmenurc" ]]; then
        echo "Config file does not exist, creating it now..."
        echo -e "$config_opts" > "$HOME/.sshmenurc" || { echo "Failed to create config file"; exit 1; }
        chmod 600 "$HOME/.sshmenurc" || { echo "Failed to set permissions"; exit 1; }
        echo "Created new configuration file: $HOME/.sshmenurc"
    else
        echo "Config file already exists. Running check_confile..."
        check_confile
    fi
}

sshmenu_config_editor() {
    local config_file="$HOME/.sshmenurc"
    declare -A config_values  # Ensure this is declared as an associative array

    # Ensure the config file exists
    [[ -f "$config_file" ]] || { echo "Error: Configuration file not found. Run sshmenu first."; return 1; }

    # Load configuration into an associative array
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue  # Ignore comments and empty lines
        key=$(echo "$key" | tr -d ' ')  # Remove spaces around keys
        value=$(echo "$value" | sed 's/^"\|"$//g')  # Remove surrounding quotes if any
        config_values["$key"]="$value"
    done < "$config_file"

    # List of options to display in the menu
    local options=(
        "home" "User's Home Directory"
        "OPT" "Options Flag"
        "KEY" "SSH Key Path"
        "REMOTE" "Remote Port"
        "LOCAL" "Local Port"
        "GUEST" "Default SSH User"
        "DEST" "Default Destination Path"
        "TIME" "Tunnel Timeout (seconds)"
        "EDITOR" "Default Editor"
        "LSEXIT" "Perform 'ls' on exit (true/false)"
        "knwhosts" "Known Hosts File"
    )

    # Function to edit configuration
    edit_config_option() {
        while true; do
            echo -e "\n\e[1;34mSSHMenu Configuration Editor\e[0m"
            echo "--------------------------------------"

            # Display options neatly aligned
            local count=1
            for ((i=0; i<${#options[@]}; i+=2)); do
                key="${options[i]}"
                desc="${options[i+1]}"
                printf "%2d) %-30s: %s\n" "$count" "$desc" "${config_values[$key]:-N/A}"  # Use 'N/A' if empty
                count=$((count + 1))
            done

            # Add SAVE and CANCEL options explicitly
            printf "%2d) Exit without saving\n" "$count"
            local exit_option="$count"
            count=$((count + 1))
            printf "%2d) Save changes and exit\n" "$count"
            local save_option="$count"

            # User selects an option
            echo -n "Select an option to edit (or SAVE/CANCEL): "
            read -r selection

            if [[ "$selection" =~ ^[0-9]+$ && "$selection" -gt 0 && "$selection" -lt "$exit_option" ]]; then
                local key_index=$(( (selection - 1) * 2 ))
                local key="${options[key_index]}"
                echo -n "Enter new value for $key (${config_values[$key]:-N/A}): "
                read -r new_value
                [[ -n "$new_value" ]] && config_values["$key"]="$new_value"
            elif [[ "$selection" -eq "$exit_option" ]]; then
                echo "Exiting without saving."
                return
            elif [[ "$selection" -eq "$save_option" ]]; then
                echo "Saving changes..."
                save_config_changes
                return
            else
                echo "Invalid selection, please try again."
            fi
        done
    }

    # Function to save updated configuration back to file
    save_config_changes() {
        local backup_file="$config_file.bak"
        cp "$config_file" "$backup_file"  # Create a backup

        {
            while IFS= read -r line; do
                key=$(echo "$line" | cut -d= -f1 | tr -d ' ')
                if [[ -n "${config_values[$key]}" ]]; then
                    echo "$key=${config_values[$key]}"  # Write updated values
                else
                    echo "$line"  # Preserve comments and formatting
                fi
            done < "$backup_file"
        } > "$config_file"

        chmod 600 "$config_file"
        echo "Configuration updated successfully!"
    }

    # Start the configuration editor
    edit_config_option
}

uninstall_sshmenu() {
    echo "🛑 Uninstalling SSHMenu..."

    # Remove the SSHMenu script from the install directory
    if [[ -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        echo "🔹 Removing SSHMenu script from $INSTALL_DIR..."
        rm -f "$INSTALL_DIR/$SCRIPT_NAME"
    else
        echo "⚠️ SSHMenu script not found in $INSTALL_DIR. Skipping..."
    fi

    # Ask user if they want to remove the configuration file
    if [[ -f "$CONFIG_FILE" ]]; then
        read -p "📝 Do you want to remove your SSHMenu configuration file ($CONFIG_FILE)? (y/N) " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🗑 Removing configuration file..."
            rm -f "$CONFIG_FILE"
        else
            echo "✅ Configuration file retained."
        fi
    fi

    # Check and remove from PATH if it was added during installation
    if grep -q "$INSTALL_DIR" ~/.bashrc ~/.zshrc ~/.profile 2>/dev/null; then
        read -p "⚠️ Do you want to remove $INSTALL_DIR from your PATH in shell profiles? (y/N) " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🔹 Removing PATH modifications from shell profiles..."
            sed -i "/export PATH=\"$INSTALL_DIR:\$PATH\"/d" ~/.bashrc ~/.zshrc ~/.profile 2>/dev/null
        else
            echo "✅ PATH modifications retained."
        fi
    fi

    echo "✅ Uninstallation complete!"
    exit 0
}

#------------------------{ Add some tabs }------------------------------------------------------------------------------
tabbed(){
    target=$target gnome-terminal --title=$target --tab -qe "${1/_target_/$target}";
}

#------------------------{ Add your commands to this lists }------------------------------------------------------------
cmdlist_renew(){
    cmdlist=(
        #Command#    #Description#
        "${slct[@]}" #De/Select command
        "Username"   "Change ssh username to \Z1$GUEST\Z0"
        "Add tab"    "Add terminal tab with \Z1sshmenu\Z0 for \Z4$target\Z0"
        "Ssh tab"    "Add terminal tab with \Z1ssh\Z0 to \Z4$target\Z0"
        ''           ''
        "ls -lah"    "List Files"
        "free -h"    "Show free memory"
        "df  -ih"    "Show free inodes"
        "df   -h"    "Show free disk space"
        "Custom"     "Run custom command on \Z4$target\Z0"
        "Script"     "Run custom script on \Z4$target\Z0"
        ''           ''
        'Yes'        "Say 'yes' to SSH"
        "Info"       "Full system info"
        'Fix_id'     "Update host in known_hosts"
        "Sshkey"     "Add my ssh key to \Z4$target\Z0"
        "Alias"      "Add my useful aliases to \Z4$target\Z0"
        "Copy"       "Copy selected file or dir to \Z4$target\Z0"
        ''           ''
        "Home"       "Change home folder \Z4$home\Z0 on local server"
        "Dest"       "Change destination folder \Z4$DEST\Z0 on \Z4$target\Z0"
        "Upload"     "Upload file or folder from \Z4$home\Z0 to \Z4$target:${DEST}\Z0"
        "Download"   "Download file or folder from \Z4$target:${DEST}\Z0 to \Z4$home\Z0"
        "Mount"      "Mount remote folder \Z4$target:$DEST\Z0 to \Z4$home\Z0"
        "Unmount"    "Unmount remote folder \Z4$target:$DEST\Z0 from \Z4$home\Z0"
        ''           ''
        "Local"      "Change local  port \Z1$LOCAL\Z0"
        "Remote"     "Change remote port \Z1$REMOTE\Z0"
        "Tunnel"     "Start portunneling from \Z4$target:$REMOTE\Z0 to \Z4localhost:$LOCAL\Z0"
        ''           ''
        "ShowConf"   "Show ssh config for this host"
        "EditConf"   "Edit ssh config for this host"
    )
    cmdlist_group=(
        #Command#    #Description#
        "Username"   "Change ssh username to \Z1$GUEST\Z0"
        "Add tabs"   "Add terminal tabs with \Z1sshmenu\Z0 for hosts in \Z4$group\Z0 group"
        "Ssh tabs"   "Add terminal tabs with \Z1ssh\Z0 to hosts from \Z4$group\Z0 group"
        ''           ''
        "ls  -la"    "List Files"
        "free -h"    "Show free memory"
        "df  -ih"    "Show free inodes"
        "df   -h"    "Show free disk space"
        "Custom"     "Run custom command on \Z4$group\Z0"
        "Script"     "Run custom script on \Z4$group\Z0"
        ''           ''
        'Yes'        "Say 'yes' to SSH"
        "Info"       "Full system info"
        "Alias"      "Add my useful aliases to \Z4$group\Z0"
        "Copy"       "Copy selected file or dir to \Z4$group\Z0"
        ''           ''
        "Home"       "Change home folder \Z4$home\Z0 on local server"
        "Dest"       "Change destination folder \Z4$DEST\Z0 on \Z4$group\Z0"
        "Upload"     "Upload file or folder from \Z4$home\Z0 to \Z4$group:${DEST}\Z0"
        ''           ''
        "EditConf"   "Edit ssh config for this group"
    )
}

#--------------------------------------------------------------------+
#Color picker, usage: printf ${BLD}${CUR}${RED}${BBLU}"Hello!)"${DEF}|
#-------------------------+--------------------------------+---------+
#       Text color        |       Background color         |         |
#-----------+-------------+--------------+-----------------+         |
# Base color|Lighter shade|  Base color  | Lighter shade   |         |
#-----------+-------------+--------------+-----------------+         |
BLK='\e[30m'; blk='\e[90m'; BBLK='\e[40m'; bblk='\e[100m' #| Black   |
RED='\e[31m'; red='\e[91m'; BRED='\e[41m'; bred='\e[101m' #| Red     |
GRN='\e[32m'; grn='\e[92m'; BGRN='\e[42m'; bgrn='\e[102m' #| Green   |
YLW='\e[33m'; ylw='\e[93m'; BYLW='\e[43m'; bylw='\e[103m' #| Yellow  |
BLU='\e[34m'; blu='\e[94m'; BBLU='\e[44m'; bblu='\e[104m' #| Blue    |
MGN='\e[35m'; mgn='\e[95m'; BMGN='\e[45m'; bmgn='\e[105m' #| Magenta |
CYN='\e[36m'; cyn='\e[96m'; BCYN='\e[46m'; bcyn='\e[106m' #| Cyan    |
WHT='\e[37m'; wht='\e[97m'; BWHT='\e[47m'; bwht='\e[107m' #| White   |
#----------------------------------------------------------+---------+
# Effects                                                            |
#--------------------------------------------------------------------+
DEF='\e[0m'   #Default color and effects                             |
BLD='\e[1m'   #Bold\brighter                                         |
DIM='\e[2m'   #Dim\darker                                            |
CUR='\e[3m'   #Italic font                                           |
UND='\e[4m'   #Underline                                             |
INV='\e[7m'   #Inverted                                              |
COF='\e[?25l' #Cursor Off                                            |
CON='\e[?25h' #Cursor On                                             |
#--------------------------------------------------------------------+

# Text positioning, usage: XY 10 10 'Hello World!'
XY(){
    printf "\e[$2;
    ${1}H$3";
}

# Print line, usage: line - 10 | line -= 20 | line 'Hello World!' 20
line(){
    printf -v _L %$2s;
    printf -- "${_L// /$1}";
}

# Create sequence like {0..(X-1)}, usage: que 10
que(){
    printf -v _N %$1s; _N=(${_N// / 1});
    printf "${!_N[*]}";
}

# Function to determine the package manager and install missing packages
get_install_command() {
    local package=$1
    local installer=""

    # Detect package manager
    if command -v zypper &>/dev/null; then
        installer="sudo zypper -y install $package"
    elif command -v dnf &>/dev/null; then
        installer="sudo dnf -y install $package"
    elif command -v yum &>/dev/null; then
        installer="sudo yum -y install $package"
    elif command -v pacman &>/dev/null; then
        installer="sudo pacman -Sy --noconfirm $package"
    elif command -v brew &>/dev/null; then
        installer="brew install $package"
    elif command -v apt-get &>/dev/null; then
        installer="sudo apt-get install -y $package"
    else
        echo -e "${RED}Error: Could not detect a supported package manager.${DEF}"
        return 1
    fi

    printf "$installer"
}

# Function to check dependencies
check_dependencies() {
    local missing_packages=()

    for package in "${required_packages[@]}"; do
        if ! command -v "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo -e "${RED}Warning: The following required packages are missing:${DEF}"
        for pkg in "${missing_packages[@]}"; do
            install_cmd=$(get_install_command "$pkg")
            echo -e "${BLD}$pkg${DEF} - Install using: ${GRN}$install_cmd${DEF}"
        done
        echo -e "\n${RED}SSHMenu may not work properly without these dependencies.${DEF}"
        return 1
    else
        echo -e "${GRN}All required dependencies are installed.${DEF}"
        return 0
    fi
}

#-------------{ check bash version }--------------------------------
version=4.2
echo ${BASH_VERSINFO[@]::2} | gawk -vv=$version '{if($1"."$2<v){exit 1}}' || {
    printf "\nBASH version ${BLD}$version+$DEF required to run ${BLD}sshmenu$DEF, your is - $BLD$BASH_VERSION$DEF\n"
    exit 1
}

#-------------{ Waiting animation }----------------------------------
cursor () {
    case $1 in
         on) stty  echo; printf "$CON";;
        off) stty -echo; printf "$COF";;
    esac
}

x=$(( COLUMNS / 2 - 3 ))
y=$(( LINES / 2 - 3 ))
sand=( ⠁  ⠂  ⠄  ' ' )

#  {   small digits    }
sd=(₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉)
bs='⠴⠷⠦' # bottom sand pile
ts='⠖'    #  top  sand pile

WAIT(){
    clear; 
    cursor off; 
    i=0; 
    start=$SECONDS
    
    XY $[x-1]  $y    $UND$BLD$RED'       '$DEF                     # _______
    XY $[x-1] $[y+1]         $RED'╲'$DIM$UND'     '$DEF$red'╱'$DEF # ╲_____╱
    XY  $x    $[y+2]         $BLU'(  '$BLD$WHT'•'$BLD$BLU')'$DEF   #  (  •)
    XY  $x    $[y+3]         $BLU' ╲'$YLW"$ts"$BLD$BLU'╱'$DEF      #   ╲⠖╱
    XY  $x    $[y+4]         $BLU" ╱$YLW${sand[$i]}$BLD$BLU╲"$DEF  #   ╱⠂╲
    XY  $x    $[y+5]         $BLU'('$YLW"$bs"$BLD$BLU')'$DEF       #  (⠴⠷⠦)
    XY $[x-1] $[y+6]         $RED'╱'$RED'‾‾‾‾‾'$BLD$RED'╲'$DEF     # ╱‾‾‾‾‾╲
    XY $[x-1] $[y+7]     $DIM$RED'‾‾‾‾‾‾‾'$DEF                     # ‾‾‾‾‾‾‾
    
    ( while true; do sleep 0.07
        printf -v counter "%03d" $[SECONDS-start]
        small="${sd[${counter:0:1}]}${sd[${counter:1:1}]}${sd[${counter:2:1}]}"
        XY $[x-1] $[y+1] $RED'╲'$DIM$UND" $small "$DEF$red'╱'$DEF
        XY  $x    $[y+4] $BLU" ╱$YLW${sand[$i]}$BLD$BLU╲"$DEF
        ((i++)); (($i==${#sand[@]})) && i=0;
    done ) & waiter=$!
}

GO() { 
    [[ -e /proc/$waiter ]] && kill $waiter; cursor on; clear; 
}

#-------------{ Pause function }------------------------------------
pause(){
    local  mess=${1:-'press any key to continue'}
    printf "\n$COF$BLD$mess\n"
    read   -srn1
    printf "\n$DEF$CON"
}

#-------------{ Yes to ssh }----------------------------------------
ssh_yes(){
    local hostname=${hostnames["$target"]}
    local fprint=($(ssh-keyscan -H "$hostname" 2>/dev/null))
    grep -q "${fprint[2]}" "$knwhosts" || echo "${fprint[@]}" >> "$knwhosts"
}

fix_id(){
    local hostname=${hostnames["$target"]}
    local address=$(dig +short $hostname)
    ssh-keygen -f "$knwhosts" -R "$hostname"
    ssh-keygen -f "$knwhosts" -R "$address"
    ssh_yes
}

#-------------{ System Info commands }------------------------------
system_info(){
    ssh $SSH_OPT $target "
        printf '\n${BLD}Hostname:${DEF}\n'
        hostname

        printf '\n${BLD}Interfaces:${DEF}\n'
        ip a

        printf '\n${BLD}Memory:${DEF}\n'
        LANG=Us free --si -h

        printf '\n${BLD}CPU:${DEF}\n'
        lscpu

        printf '\n${BLD}Disk:${DEF}\n'
        df -h; echo; df -ih; echo; lsblk

        printf '\n${BLD}Software:${DEF}\n'
        uname -a; echo
        [[ -e /usr/bin/lsb_release ]] && { lsb_release -a; echo; }
        [[ -e /usr/bin/java        ]] && { java  -version; echo; }
        [[ -e /usr/bin/psql        ]] && { psql  -V      ; echo; }
        [[ -e /usr/sbin/nginx      ]] && { nginx -v      ; echo; }

        printf '${BLD}Logged in Users:${DEF}\n'
        who

        printf '\n${BLD}Port usage info:${DEF}\n'
        netstat -tulpn 2> /dev/null

        printf '\n${BLD}Processes:${DEF}\n'
        top -bcn1 | head -n30
    "
}

#-------------{ Show\Edit ssh config }------------------------------
show_conf(){
    clear; 
    ssh -G $target; 
    pause;
}

edit_conf(){
    local   confs   search=$target
    [[ $group ]] && search="$group_id[[:space:]]*#$group#"
    confs=($(grep -rilE "Host[[:space:]]*$search" $CONFILES)) || { clear; echo 'Config file not found'; pause; return; }
    $EDITOR "${confs[@]}"
}

#-------------{ SSH to target server }-----------------------------
go_to_target(){
    clear; 
    ssh $SSH_OPT $target || pause;
}

#-------------{ Add aliases }--------------------------------------
add_aliases(){
    scp $SSH_OPT ~/.bash_aliases $target:~
    ssh $SSH_OPT $target "grep '. ~/.bash_aliases' .bashrc || echo '. ~/.bash_aliases' >> .bashrc"
}

#-------------{ Run function on a group of servers }---------------
group_run(){
    local func group_list data
    func="$1"
    group_list=("${list[@]:2}")
    SSH_OPT_CUR="$SSH_OPT"
    SSH_OPT="$SSH_OPT -o ConnectTimeout=10 -o BatchMode=true"
    case $func in tabbed*)
        for ((i=0;  i<${#group_list[@]}; i+=2)); do
              target="${group_list[$i]}"
              tabbed "${2/_target_/$target}"
        done
        return;;
    esac
    WAIT
    data=$(
        for ((i=0;  i<${#group_list[@]}; i+=2)); do
              target="${group_list[$i]}"
          [[ $target =~ ^-+.*-+$ ]] && continue
          (  code="$BLD$GRN"
             data=$( $func 2>&1 | sed ':a;N;$!ba;s/\n/\\n/g'; exit ${PIPESTATUS[0]}) || code="$BLD$RED"
             echo "$code----{ $target }----$DEF\\n${data:-Command did not output anything.}\\n"
          )  &
        done
    )
    GO; printf -- '%b' "$data"
    SSH_OPT="$SSH_OPT_CUR"
}

#-------------{ Run command/script }-------------------------------
run_command(){
    ssh $SSH_OPT $target $command;
}

run_script (){
    scp -r $SSH_OPT "${sshmenu_script[2]}" $target:~/ || return 1
    ssh    $SSH_OPT "$target" "~/${sshmenu_script[1]}"
}

#-------------{ Add ssh key }--------------------------------------
add_sshkey(){
    clear; 
    ssh_yes > /dev/null; 
    ssh-copy-id -i $KEY $SSH_OPT $target;
}

#-------------{ Tunnelling command}--------------------------------
portunneling(){ 
    ssh $SSH_OPT $target -f -L 127.0.0.1:$LOCAL:127.0.0.1:$REMOTE sleep $TIME;
}

#-------------{ Exit function }------------------------------------
bye(){
    printf "\n$DEF$CON"
    clear
    $LSEXIT || exit 0
    lsopts='--color=auto'
    [[ $(uname -s) == "Darwin" ]] && lsopts='-G'
    ls $lsopts
    exit 0
};  trap bye INT

#=============> { Dialog functions } <=============================
do='--output-fd 1 --colors' # dialog common options
eb='--extra-button'         # extra
hb='--help-button'          # buttons
cl='--cancel-label'         # and
el='--extra-label'          # short
hl='--help-label'           # label
ol='--ok-label'             # names

# Dialog buttons order and exit codes
#<OK> <Extra> <Cancel> <Help>
# 0      3       1       2

D(){ # dialog creator
    local opts=()
    [[ $1 ]] && opts+=("$ol" "$1")
    [[ $2 ]] && opts+=("$el" "$2" "$eb")
    [[ $3 ]] && opts+=("$cl" "$3")
    [[ $4 ]] && opts+=("$hl" "$4" "$hb")
    shift 4
    dialog "${opts[@]}" $do  "$@"
}

#-------------{ Change alternative username }-----------------------
username(){
    new_user=$(D "CHANGE" '' "BACK" '' --max-input 20 --inputbox 'Change alternative username' 10 30 $GUEST)
	case $new_user:$? in
                 *:0) GUEST=${new_user:-$GUEST}; SSH_OPT="-oUser=$GUEST"; USERNOTE="Username changed to \Z2$GUEST\Z0.";;
                 *:*) return;;
	esac
}

#-------------{ Create custom command/script }----------------------
custom(){
    local runner=
    [[ $group ]] && runner='group_run'
    new_command=$(D "RUN" '' "BACK" '' --inputbox "Write down your command here:" 8 120 "$new_command")
	case $new_command:$? in
	               '':0) custom;;
                    *:0) command=$new_command; clear; $runner run_command; pause;;
                    *:*) return;;
	esac
}

script(){
    [[ -f ${sshmenu_script[2]} ]] || {
        echo  -e '#!/bin/bash\necho "Running sshmenu script"' > "${sshmenu_script[2]}"
        chmod +x "${sshmenu_script[2]}"
    }

    script_text=$(cat "${sshmenu_script[2]}")
    D "RUN" "EDIT" '' "BACK" --msgbox "$script_text" 40 120
    case $? in
         0) [[ $script_text ]] || script; clear; $runner run_script; pause;;
         3) $EDITOR "${sshmenu_script[2]}"; script;;
         2) second_dialog;;
	esac
}

#-------------{ Change local port for tunnelling }-------------------
local_port(){
    new_local=$(D "CHANGE" '' "BACK" '' --max-input 5 --inputbox 'Change local port' 10 30 $LOCAL)
    LOCAL=${new_local:-$LOCAL}
}

#-------------{ Change remote port for tunnelling }------------------
remote_port(){
    new_remote=$(D "CHANGE" '' "BACK" '' --max-input 5 --inputbox 'Change remote port' 10 30 $REMOTE)
    REMOTE=${new_remote:-$REMOTE}
}

#-------------{ Upload\Download and mount dialogs }------------------
downpath(){
    new_path=$(D "CHANGE" '' "BACK" '' --max-input 100 --inputbox 'Change download folder' 10 50 $DEST)
    DEST=${new_path:-$DEST}
    dfilelist=
}

homepath(){
    new_path=$(D "CHANGE" '' "BACK" '' --max-input 100 --inputbox 'Change home folder' 10 50 $home)
    home=${new_path:-$home}
}

uploader(){
    printf "Uploading $BLD$ufilename$DEF\n"
    scp -r $SSH_OPT $ufilename $target:"$DEST/"
}

mountdest(){
    which  sshfs &> /dev/null || { clear; how_to_install sshfs; pause; return; }
    clear; sshfs $sshfsopt "$target":"$DEST" "$home" || pause
}

unmountdest() {
    mount | grep -q "$home" && umount "$home";
}

copy_files(){
    local runner=
    [[ $group ]] && runner='group_run'
    ufilename=$(D "COPY" '' "BACK" '' --fselect $PWD/ 10 80)
	case $ufilename:$? in
         $PWD|$PWD/:0) return;;
                  *:0) clear; $runner uploader; pause;;
                  *:*) return;;
	esac           ;   copy_files
}

upload(){
    local runner=
    [[ $group ]] && runner='group_run'
    ufilelist=( $(ls -sh1 $home | awk '{print $2,$1}') )
	ufilename=$(D "UPLOAD" '' "BACK" '' --menu "Select file\folder to upload:" 0 0 0 "${ufilelist[@]:2}")
	case $? in
         0) [[ $ufilename ]] || upload
            clear; $runner uploader; pause;;
         *) return;;
	esac;   upload
}

download(){
    [[ $dfilelist ]] || {
        dfilelist=$(ssh $SSH_OPT $target ls -sh1 $DEST 2>&1) \
            && dfilelist=( $(awk '{print $2,$1}' <<< "$dfilelist") ) \
            || {
                clear
                echo "$dfilelist"
                pause
                dfilelist=
                second_dialog
            }
    }
	dfilename=$(D "DOWNLOAD" '' "BACK" '' --menu "Select file\folder to download:" 0 0 0 "${dfilelist[@]:2}")
	case $? in
         0) [[ $dfilename ]] || download
            clear
            printf "Downloading $BLD$dfilename$DEF\n"
            scp -r $SSH_OPT $target:"$DEST/$dfilename" . || pause;;
         *) return;;
	esac;   download
}

#-------------{ Switch menu mode to contents view or full list }-----
save_tmp(){
    echo "$1" > "$tmpfile";
    chmod 600 "$tmpfile";
}

new_list(){
    list=(); match=
    for item in "${selected_list[@]}" "${fullist[@]}"; {
        case         $item:$match    in
                 *{\ *\ }*:1) break  ;;
           *{\ $filter\ }*:*) match=1;;
        esac
        [[ $match ]] && list+=( "$item" )
    }
    [[ $filter =~ Selected ]] && return
    [[ ${list[*]} ]] && save_tmp "filter='$filter'" || { list=( "${fullist[@]}" ); rm "$tmpfile"; }
}

contents_menu(){
    local filter_tmp=$filter selected=
    [[  ${selected_list[@]} ]] && selected='Selected_hosts'

    local btns=('SELECT' 'RUN COMMAND' 'BACK' '')
	filter=$(D "${btns[@]}" --no-items --menu "Select list of hosts:" 0 0 0 "All" $selected "${content[@]}")
	case $filter:$? in
             All:0) list=( "${selected_list[@]}" "${fullist[@]}" )
                    save_tmp       "filter=";;
               *:3) second_dialog "$filter" ;;
               *:1) filter=$filter_tmp;;
               *:0) new_list;;
	esac        ;   first_dialog
}

#-------------{ Selector }--------------------------------------------
declare -A slctd_hosts

gen_selected_list(){
    local k
    selected_list=('-----------{ Selected_hosts }-----------' '_LINE_')
    for k in "${!slctd_hosts[@]}"; { selected_list+=("$k" "${slctd_hosts[$k]}"); }
}

slct_dslct(){
    local desc k v

    # remove from selection
    [[ ${slctd_hosts[$target]} ]] && {
        unset slctd_hosts[$target]
        gen_selected_list
        ((${#selected_list[@]}==2)) && unset selected_list
        return
    }

    # add to selection
    for ((k=0,v=1; k<N; k++,v++)); { [[ ${fullist[k]} =~ $target ]] && { desc=${fullist[v]}; break; }; }
    slctd_hosts[$target]=$desc
    gen_selected_list
}

#-------------{ First dialog - Select target host }-------------------
first_dialog(){
    local btns
    group= dfilelist=
    [[ $OPT =~ name ]] && btns=('GET NAME' '' 'EXIT' 'CONTENTS') || btns=('CONNECT' 'RUN COMMAND' 'EXIT' 'CONTENTS')
	target=$(D "${btns[@]}" --menu "Select host to connect to. $USERNOTE" 0 0 0 "${list[@]//_LINE_/$descline}")
	case $target:$? in
       *{\ *\ }*:0) filter=${target//*\{ }; filter=${filter// \}*}; new_list; first_dialog ;;
       *{\ *\ }*:3) filter=${target//*\{ }; filter=${filter// \}*}; second_dialog "$filter";;
               *:0) [[ $OPT =~ name ]] && return || { go_to_target; first_dialog; };;
      	       *:1) bye;;
               *:2) contents_menu;;
      	       *:3) second_dialog;;
               *:*) contents_menu;;
  	esac
}

#-------------{ Second dialog - Select command }-----------------------
second_dialog(){
    local headings    commands                    singleornot         runner             connect
          group="$1"  commands='cmdlist[@]'       singleornot='host'  runner=''          connect='CONNECT'
      [[ $group ]] && commands='cmdlist_group[@]' singleornot='group' runner='group_run' connect=''  filter="$group"
          headings="Select command to run on $singleornot \Z4${group:-$target}\Z0. $USERNOTE"

                                       slct=(Select   "Add \Z4$target\Z0 to tmp group \Z4Selected_hosts\Z0" '' '')
    [[ ${slctd_hosts["$target"]} ]] && slct=(Deselect "Remove \Z4$target\Z0 from tmp group \Z4Selected_hosts\Z0" '' '')

    new_list; cmdlist_renew
	command=$(D 'RUN' "$connect" 'BACK' '' --menu "$headings" 0 0 0 "${!commands}")
	case $command:$? in
	           '':0) :;;
	     *'elect':0) slct_dslct  ;;
       "Add tab"*:0) $runner tabbed "$0";;
       "Ssh tab"*:0) $runner tabbed "ssh $SSH_OPT _target_";;
            Alias:0) clear; $runner add_aliases; pause;;
             Info:0) clear; $runner system_info; pause;;
              Yes:0) clear; $runner ssh_yes    ; pause;;
           Fix_id:0) fix_id      ;;
           Sshkey:0) add_sshkey  ;;
             Copy:0) copy_files  ;;
           Upload:0) upload      ;;
           Custom:0) custom      ;;
           Script:0) script      ;;
         Username:0) username    ;;
             Dest:0) downpath    ;;
             Home:0) homepath    ;;
            Mount:0) mountdest   ;;
          Unmount:0) unmountdest ;;
         Download:0) download    ;;
            Local:0) local_port  ;;
           Remote:0) remote_port ;;
           Tunnel:0) portunneling;;
         ShowConf:0) show_conf   ;;
         EditConf:0) edit_conf   ;;
                *:0) clear; $runner run_command; pause;;
                *:3) go_to_target;;
                *:*) first_dialog;;
	esac         ;   second_dialog "$group"
}

# Handle command-line arguments
case "$1" in
    --config) 
        sshmenu_config_editor || { echo -e "${RED}Error: Failed to open configuration editor.${DEF}"; exit 1; }
        exit 0
        ;;
    --refresh) 
        refresh_config_files || { echo -e "${RED}Error: Failed to refresh SSH configuration files.${DEF}"; exit 1; }
        exit 0
        ;;
    --check-deps)
        check_dependencies || { echo -e "${RED}Error: Some dependencies are missing.${DEF}"; exit 1; }
        exit 0
        ;;
    --list-hosts) 
        if [[ -z "$CONFILES" ]]; then
            echo -e "${RED}Error: No SSH config files found. Try running --refresh first.${DEF}"
            exit 1
        fi
        grep -iE '^Host ' $CONFILES || { echo -e "${RED}No hosts found in SSH configuration.${DEF}"; exit 1; }
        exit 0
        ;;
    --uninstall)
        uninstall_sshmenu
        exit 0
        ;;
    --help)
        echo -e "Usage: sshmenu.sh [OPTIONS]"
        echo -e "  ${grn}--config${DEF}       Open the SSHMenu configuration editor"
        echo -e "  ${grn}--refresh${DEF}      Refresh the list of SSH configuration files"
        echo -e "  ${grn}--check-deps${DEF}   Check if all required dependencies are installed"
        echo -e "  ${grn}--list-hosts${DEF}   List all SSH hosts from config files"
        echo -e "  ${grn}--uninstall${DEF}    Remove sshmenu from this system"
        echo -e "  ${grn}--help${DEF}         Shows this help"
        exit 1
        ;;
esac

#-------------{ Check for and create the ~/.sshmenurc }------------------------------
create_config

#-------------{ Create the list of hosts. Get hosts and descriptions from ~/.ssh/config* }------------------------------
# Parse SSH Config Files for Hosts
declare -A hostnames
fullist=()   # Store all hostnames and descriptions
content=()   # Store group names

for file in $CONFILES; do
    [[ ! -f "$file" ]] && continue  # Skip missing files

    while read -r name hostname desc; do
        case ${name,,} in
            'group_name') 
                name="{ $desc }"
                name_length=${#name}
                name_left=$(( (40 - name_length) / 2 ))
                name_right=$(( 40 - (name_left + name_length) ))
                printf -v tmp "%${name_left}s_NAME_%${name_right}s"
                tmp=${tmp// /-}
                name=${tmp//_NAME_/$name}
                content+=( "$desc" )
                desc='_LINE_'
                ;;
            '#'*) continue ;;  # Ignore comment lines
        esac
        (( ${#desc} > desclength )) && desclength=${#desc}
        hostnames["$name"]=$hostname
        fullist+=("$name" "$desc")  # Add host and description to the list
    done < <(gawk '
    BEGIN { IGNORECASE=1 }
    /Host / {
        strt=1
        host=$2
        desc=gensub(/^.*Host .* #(.*)/, "\\1", "g", $0)
        desc=gensub(/(.*)#.*/, "\\1", "g", desc)
        next
    }
    strt && /HostName / {
        hostname=$2
        print host, hostname, desc
        strt=0
    }' "$file")
done

descline=$(printf '%*s' "$desclength" | tr ' ' '-')
list=( "${fullist[@]}" )  # Final list of parsed hosts
N=${#fullist[@]}

[[ -e $tmpfile ]] && . "$tmpfile"
[[    $filter  ]] &&    new_list

#--{ Go baby, GO!) }--
[[ $target      ]] || first_dialog
[[ $OPT =~ name ]] && { echo $target; exit; }
[[ $target      ]] && second_dialog

bye
