#!/bin/sh

# Author:     stablestud <adsorber@stablestud.org>
# Repository: https://github.com/stablestud/adsorber
# License:    MIT, https://opensource.org/licenses/MIT

# Variable naming:
# under_score        - used for global variables which are accessible between functions.
# _extra_under_score - used for local function variables. Should be unset afterwards.
#          (Note the underscore in the beginning of _extra_under_score!)

# shellcheck disable=SC2154

readonly tmp_dir_path="/tmp/adsorber"
readonly debug="false"


############[ DO NOT EDIT ]#####################################################
# NOTE: following values will be changed when installed with
# 'install-to-system.sh', if you want to change them, change them there
readonly executable_dir_path="$(cd "$(dirname "${0}")" && pwd)"
readonly library_dir_path="${executable_dir_path}/../lib/"
readonly shareable_dir_path="${executable_dir_path}/../share/"
readonly config_dir_path="${executable_dir_path}/../../"

############[ End of configuration, script begins now ]#########################

readonly version="0.4.0"
readonly operation="${1}"

if [ "${#}" -ne 0 ]; then
        shift
fi

readonly options="${*}"

checkRoot()
{
        # Changing the hosts file requires root rights!
        if [ "$(id -g)" -ne 0 ]; then
        	echo "$(id -un), I require way more more power then this! How about .. root ..? ;)" 1>&2
                exit 126
        fi

        return 0
}


checkForWrongParameters()
{
        if [ -n "${_wrong_operation}" ] || [ -n "${_wrong_option}" ]; then
                showUsage
        fi

        if [ "${_option_help}" = "true"  ]; then
                showSpecificHelp
        fi

        return 0
}


showUsage()
{
        if [ -n "${_wrong_operation}" ]; then
                echo "Adsorber: Invalid operation: '${_wrong_operation}'" 1>&2
        fi

        if [ -n "${_wrong_option}" ]; then
                echo "Adsorber: Invalid option: '${_wrong_option}'" 1>&2
        fi

        echo "Usage: adsorber <install|update|restore|revert|remove> [<options>]"
        echo "Try '--help' for more information."

        exit 80
}


showHelp()
{
        echo "Usage: adsorber <operation> [<options>]"
        echo ""
        echo "(Ad)sorber blocks ads by 'absorbing' and dumbing them into void."
        echo "           (with the help of the hosts file)"
        echo ""
        echo "Operations:"
        echo "  install - setup necessary things needed for Adsorber"
        echo "              e.g., create backup file of hosts file,"
        echo "                    create scheduler which updates the host file once a week"
        echo "            However this should've been done automatically."
        echo "  update  - update hosts file with newest ad servers"
        echo "  restore - restore hosts file to its original state"
        echo "            (it does not remove the schedule, this should be used temporary)"
        echo "  revert  - reverts the hosts file to the lastest applied host file."
        echo "  remove  - completely remove changes made by Adsorber"
        echo "              e.g., remove scheduler (if set)"
        echo "                    restore hosts file to its original state"
        echo "  version - show version of this shell script"
        echo "  help    - show this help"
        echo ""
        echo "Options: (optional)"
        echo "  -s,  --systemd           - use Systemd ..."
        echo "  -c,  --cron              - use Cronjob as scheduler (use with 'install')"
        echo "  -ns, --no-scheduler      - skip scheduler creation (use with 'install')"
        echo "  -y,  --yes, --assume-yes - answer all prompts with 'yes'"
        echo "  -f,  --force             - force the update if no /etc/hosts backup"
        echo "                             has been created (dangerous)"
        echo "  -h,  --help              - show specific help of specified operations"
        echo
        echo "Documentation: https://github.com/stablestud/adsorber"
        echo "If you encounter any issues please report them to the Github repository."

        exit 0
}


showSpecificHelp()
{
        case "${operation}" in
                install )
                        printf "\\033[4;37madsorber install [<options>]\\033[0m:\\n"
                        echo
                        echo "You should run this command first."
                        echo "  (e.g. after installation to the system)"
                        echo
                        echo "The command will:"
                        echo " - backup your /etc/hosts file to /etc/hosts.original"
                        echo "   (if not other specified in adsorber.conf)"
                        echo " - install a scheduler which updates your hosts file with ad-server domains"
                        echo "   once a week. (either systemd, cronjob or none)"
                        echo " - install the newest ad-server domains in your hosts file."
                        echo "   (same as 'adsorber update')"
                        echo
                        echo "Note: this is not the same as the install_to_system.sh script."
                        echo "install_to_system.sh will place Adsorbers executable files into the system"
                        echo "so it can run directory independently, but it will not take the actions"
                        echo "described here. The same goes for 'remove'"
                        echo
                        echo "Possible options:"
                        echo " -s,  --systemd            - use Systemd ..."
                        echo " -c,  --cronjob            - use Cronjob as scheduler"
                        echo " -ns, --no-scheduler       - skip scheduler creation"
                        echo " -y,  --yes, --assume-yes  - answer all prompts with 'yes'"
                        echo " -h,  --help               - show this help screen"
                        ;;
                update )
                        printf "\\033[4;37madsorber update [<options>]\\033[0m:\\n"
                        echo
                        echo "To keep the hosts file up-to-date."
                        echo
                        echo "The command will:"
                        echo " - install the newest ad-server domains in your hosts file."
                        echo
                        echo "Possible options:"
                        echo " -f, --force      - force the update if no /etc/hosts backup"
                        echo "                    has been created (dangerous)"
                        echo " -h, --help       - show this help screen"
                        ;;
                restore )
                        printf "\\033[4;37madsorber restore [<options>]\\033[0m:\\n"
                        echo
                        echo "To restore the hosts file temporary, without removing the backup."
                        echo
                        echo "The command will:"
                        echo " - copy /etc/hosts.original to /etc/hosts, overwriting the modified /etc/hosts by adsorber."
                        echo
                        echo "Important: If you have a scheduler installed it'll re-apply ad-server domains to your hosts"
                        echo "file when triggered."
                        echo "For this reason this command is used to temporary disable Adsorber."
                        echo "(e.g. when it's blocking some sites you need access for a short period of time)"
                        echo
                        echo "To re-apply run 'adsorber update'"
                        echo
                        echo "Possible option:"
                        echo " -h, --help       - show this help screen"
                        ;;
                revert )
                        printf "\\033[4;37madsorber revert [<options>]\\033[0m:\\n"
                        echo
                        echo "To revert to the last applied hosts file, good use if the"
                        echo "current host file has been corrupted."
                        echo
                        echo "The command will:"
                        echo " - copy /etc/hosts.previous to /etc/hosts, overwriting the current host file."
                        echo
                        echo "To get the latest ad-domains run 'adsorber update'"
                        echo
                        echo "Possible option:"
                        echo " -h, --help       - show this help screen"
                        ;;
                remove )
                        printf "\\033[4;37madsorber remove [<options>]\\033[0m:\\n"
                        echo
                        echo "To completely remove changes made by Adsorber."
                        echo
                        echo "The command will:"
                        echo " - remove all schedulers (systemd, cronjob)"
                        echo " - restore the hosts file to it's original state"
                        echo " - remove all leftovers (e.g. /tmp/adsorber)"
                        echo
                        echo "Possible options:"
                        echo " -y, --yes, --assume-yes  - answer all prompts with 'yes'"
                        echo " -h, --help               - show this help screen"
                        ;;
        esac

        exit 0
}


showVersion()
{
        echo "(Ad)sorber ${version}"
        echo ""
        echo "  License MIT"
        echo "  Copyright (c) 2017 stablestud <adsorber@stablestud.org>"
        echo "  This is free software: you are free to change and redistribute it."
        echo "  There is NO WARRANTY, to the extent permitted by law."
        echo ""
        echo "Written by stablestud - and hopefully in the future with many others. ;)"
        echo "Repository: https://github.com/stablestud/adsorber"

        exit 0
}


duplicateOption()
{
        if [ "${1}" = "scheduler" ]; then
                echo "Adsorber: Duplicate option for scheduler: '${_option}'" 1>&2
                echo "You may only select one:"
                echo "  -s,  --systemd           - use Systemd ..."
                echo "  -c,  --cron              - use Cronjob as scheduler (use with 'install')"
                echo "  -ns, --no-scheduler      - skip scheduler creation (use with 'install')"
        else
                echo "Adsorber: Duplicate option: '${_option}'" 1>&2
                showUsage
        fi

        exit 80
}


checkPaths()
{
        # Check if essential files for adsorber exists, if not, try to fix or abort

        _not_found=false

        if [ ! -e "${library_dir_path}" ]; then
                printf "\\033[0;91mE Invalid library_dir_path, can't access %s\\033[0m\\n" "${library_dir_path}"
                _not_found=true
        fi

        if [ ! -e "${config_dir_path}" ]; then
                mkdir -p "${config_dir_path}"
        fi

        if [ ! -e "${shareable_dir_path}" ]; then
                printf "\\033[0;91mE Invalid shareable_dir_path, can't access %s\\033[0m\\n" "${shareable_dir_path}"
                _not_found=true
        fi

        if [ "${_not_found}" = "true" ]; then
                echo "  To fix: completely remove Adsorber from the system and re-install it again."
                echo "  Please fix the problem(s) and try again."
                exit 1
        fi

        unset _not_found

        return 0
}


sourceFiles()
{
        # shellcheck source=../src/lib/install.sh
        . "${library_dir_path}/install.sh"
        # shellcheck source=../src/lib/remove.sh
        . "${library_dir_path}/remove.sh"
        # shellcheck source=../src/lib/update.sh
        . "${library_dir_path}/update.sh"
        # shellcheck source=../src/lib/restore.sh
        . "${library_dir_path}/restore.sh"
        # shellcheck source=../src/lib/revert.sh
        . "${library_dir_path}/revert.sh"
        # shellcheck source=../src/lib/config.sh
        . "${library_dir_path}/config.sh"
        # shellcheck source=../src/lib/colours.sh
        . "${library_dir_path}/colours.sh"

        # Maybe source them only when needed?
        # shellcheck source=../src/lib/cron/cron.sh
        . "${library_dir_path}/cron/cron.sh"
        # shellcheck source=../src/lib/systemd/systemd.sh
        . "${library_dir_path}/systemd/systemd.sh"

        return 0
}

checkPaths
sourceFiles

for _option in "${@}"; do

        case "${_option}" in
                -[Ss] | --systemd )
                        if [ -z "${reply_to_scheduler_prompt}" ]; then
                                readonly reply_to_scheduler_prompt="systemd"
                        else
                                duplicateOption "scheduler"
                        fi
                        ;;
                -[Cc] | --cron )
                        if [ -z "${reply_to_scheduler_prompt}" ]; then
                                readonly reply_to_scheduler_prompt="cronjob"
                        else
                                duplicateOption "scheduler"
                        fi
                        ;;
                -[Nn][Ss] | --no-scheduler )
                        if [ -z "${reply_to_scheduler_prompt}" ]; then
                                readonly reply_to_scheduler_prompt="no-scheduler"
                        else
                                duplicateOption "scheduler"
                        fi
                        ;;
                -[Yy] | --[Yy][Ee][Ss] | --assume-yes )
                        if [ -z "${reply_to_prompt}" ]; then
                                readonly reply_to_prompt="yes"
                        else
                                duplicateOption
                        fi
                        ;;
                -[Ff] | --force )
                        if [ -z "${reply_to_force_prompt}" ]; then
                                readonly reply_to_force_prompt="yes"
                        else
                                duplicateOption
                        fi
                        ;;
                "" )
                        : # Do nothing
                        ;;
                -[Hh] | --help | help )
                        _option_help="true"
                        ;;
                * )
                        _wrong_option="${_option}" 2>/dev/null
                        ;;
        esac

done

case "${operation}" in
        install )
                checkForWrongParameters
                checkRoot
                config
                install
                update
                ;;
        remove )
                checkForWrongParameters
                checkRoot
                config
                remove
                ;;
        update )
                checkForWrongParameters
                checkRoot
                config
                update
                ;;
        restore )
                checkForWrongParameters
                checkRoot
                config
                restore
                ;;
        revert )
                checkForWrongParameters
                checkRoot
                config
                revert
                ;;
        -[Hh] | help | --help )
                showHelp
                ;;
        -[Vv] | version | --version )
                showVersion
                ;;
        "" )
                showUsage
                ;;
        * )
                readonly _wrong_operation="${operation}"
                showUsage
                ;;
esac

printf "\\033[1;37mFinished successfully.\\033[0m\\n"

exit 0