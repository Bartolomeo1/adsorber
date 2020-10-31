#!/bin/sh

# Author:     stablestud <adsorber@stablestud.org>
# Repository: https://github.com/stablestud/adsorber
# License:    MIT, https://opensource.org/licenses/MIT

# Variable naming:
# under_score        - used for global variables which are accessible between functions.
# _extra_under_score - used for local function variables. Should be unset afterwards.
#          (Note the underscore in the beginning of _extra_under_score!)

# The following variables are declared globally.
# If you run this file independently following variables need to be set:
# ---variable:----------  ---default value:--  ---defined in:-------------------
# cache_dir_path          /var/cache7adsorber  src/bin/adsorber
# hosts_file_path         /etc/hosts           src/lib/config.sh, adsorber.conf
# hosts_file_backup_path  /etc/hosts.original  src/lib/config.sh, adsorber.conf
# prefix                  '  ' (two spaces)    src/lib/colours.sh
# prefix_fatal            '\033[0;91mE '       src/lib/colours.sh
# prefix_input            '  ' (two spaces)    src/lib/colours.sh
# prefix_reset            \033[0m              src/lib/colours.sh
# prefix_title            \033[1;37m           src/lib/colours.sh
# prefix_warning          '- '                 src/lib/colours.sh
# reply_to_prompt         Null (not set)       src/bin/adsorber

# The following functions are defined in different files.
# If you run this file independently following functions need to be emulated:
# --function:--     ---function defined in:---
# cleanUp           src/lib/cleanup.sh
# errorCleanUp      src/lib/cleanup.sh
# systemdRemove     src/lib/systemd/systemd.sh
# crontabRemove     src/lib/cron/cron.sh
# restore_HostsFile src/lib/restore.sh

# shellcheck disable=SC2154

disable_Prompt()
{
        # Ask if the user is sure about to remove Adsorber
        if [ -z "${reply_to_prompt}" ]; then
                printf "%bDo you really want to disable Adsorber? [y/N] %b" "${prefix_input}" "${prefix_reset}"
                read -r reply_to_prompt
        fi

        case "${reply_to_prompt}" in
                [Yy] | [Yy][Ee][Ss] )
                        : # Do nothing
                        ;;
                * )
                        # If other input then Yes, abort and call error clean-up function
                        printf "%bDisable cancelled.\\n" "${prefix_warning}" 1>&2
                        errorCleanUp
                        exit 130
                        ;;
        esac
}


disable_HostsFile()
{
        restore_HostsFile
        if restore_HostsFile
        then
                echo "${prefix}Successfully restored ${hosts_file_path}"
        else
                errorCleanUp
                exit 1
        fi
}


disable_RemoveCache()
{
        if [ -d "${cache_dir_path}" ]; then
                echo "${prefix}Removing cache ${cache_dir_path}"
                rm -rf "${cache_dir_path}"
        fi
}


# Main function of disable.sh
disable()
{
        printf "%bDisabling Adsorber ...%b\\n"  "${prefix_title}" "${prefix_reset}"
        disable_Prompt
        systemdRemove
        crontabRemove
        disable_RemoveCache
        disable_HostsFile
        cleanUp
}
