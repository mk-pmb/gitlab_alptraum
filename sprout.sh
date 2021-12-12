#!/bin/sh
# -*- coding: utf-8, tab-width: 2 -*-
#
# !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !!
#
#   This script's purpose is to ensure a sane shell environment.
#   Thus, initially we must assume a very dumb shell and almost no tools.
#
# !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !!

# Cannot use "function" keyword because dash doesn't support that.

sprout () {
  local LANG=en_US.UTF-8  # make error messages search engine-friendly
  export LANG
  local LANGUAGE="$LANG"
  export LANGUAGE
  local REPO_PATH="$(readlink -f .)"
  local ALP_RC='.gitlab-alptraum.rc'
  [ ! -f "$ALP_RC" ] || . ./"$ALP_RC" || return $?

  local PKG_MGR=
  sprout_pkgmgr_detect_prepare || return $?
  sprout_alpine_sanity || return $?
  echo
  flowers 'Install extra packages:'
  sprout_pkgmgr_install "$ALPTRAUM_EXTRA_PKG" || return $?
  echo

  local A_EXEC="$ALPTRAUM_EXEC"
  [ -n "$A_EXEC" ] || case "$1" in
    gcu:* )
      [ -n "$GCU_REPO_AUTH" ] || GCU_REPO_AUTH='@@guess'
      A_EXEC="$1"; shift;;
  esac

  local GCU_PATH=
  sprout_maybe_clone_gcu || return $?

  if [ -n "$ALPTRAUM_CWD" ]; then
    mkdir --parents -- "$ALPTRAUM_CWD"
    cd -- "$ALPTRAUM_CWD" || return $?
  fi

  sprout_maybe_clone_custom_git_repo || return $?
  sprout_maybe_create_bin_symlinks || return $?

  case "$A_EXEC" in
    gcu:* )
      [ -d "$GCU_PATH" ] || return 4$(
        echo "E: GCU_PATH is not a directory: '$GCU_PATH'" >&2)
      A_EXEC="$GCU_PATH/with_gcu_rc.sh ${A_EXEC#*:}"
      ;;
    web:* )
      flowers "Download web payload:"
      local ALPTRAUM_PAYLOAD_URL="${A_EXEC#*:}"
      export ALPTRAUM_PAYLOAD_URL
      A_EXEC=/alptraum_payload
      wget --output-document="$A_EXEC" -- "$ALPTRAUM_PAYLOAD_URL" || return $?
      chmod a+x -- "$A_EXEC" || return $?
      sha1sum -b -- "$A_EXEC" || return $?
      ;;
  esac

  local PREP="$ALPTRAUM_PREP_EVAL"
  if [ -n "$PREP" ]; then
    flowers "prep eval: $PREP"
    eval "$PREP" || return $?
  fi

  local CU_MSG="Godspeed! $A_EXEC $*" CU_TRIM=
  for CU_TRIM in dumb shell is dumb; do CU_MSG="${CU_MSG% }"; done
  flowers "$CU_MSG"
  echo
  exec $A_EXEC "$@"
}


flowers () { echo "✿❀❁✿❀❁ $* ❁❀✿❁❀✿"; }


sprout_alpine_sanity () {
  local BUSY="$(which busybox 2>/dev/null)"
  if [ -x /bin/bash ]; then
    if [ /bin/bash -ef "$BUSY" ]; then
      echo "D: Found a busybox bash. That's fishy."
    else
      return 0
    fi
  fi

  [ -x /sbin/apk ] || return 4$(
    echo "E: sprout_alpine_sanity: no sane bash, no apk => giving up." >&2)
    # ^-- no $FUNCNAME in dash!

  flowers "Sprout a sane shell environment:"
  sprout_pkgmgr_install '
    bash
    binutils
    coreutils
    findutils
    git
    grep
    moreutils
    openssh-client    # for git+ssh://… repos
    procps            # for custom format "ps"
    sed
    tar
    unzip
    util-linux
    wget
    zip
    ' || return $?
  echo

  echo 'Install command aliases:'
  sprout_add_command_alias nodejs node || return $?
}


sprout_pkgmgr_detect_prepare () {
  # Unfortunately, we can't just "apk add apt" because on 2019-06-15,
  # alpine had no apk package for apt. :-(

  echo
  flowers 'Detect and prepare package manager:'
  PKG_MGR="$(which apt-get apk | grep -m 1 -Ee '^/')"
  echo "Found '$PKG_MGR'."
  PKG_MGR="$(basename "$PKG_MGR")"

  case "$PKG_MGR" in
    apt-get )
      "$PKG_MGR" update || return $?
      echo "Enable support for config triggers:"
      sprout_pkgmgr_install apt-utils || return $?
      echo "Now ready to install packages that may use config triggers."
      ;;
    apk )
      "$PKG_MGR" update || return $?;;
    * )
      echo "E: can't find a supported package manager!" >&2
      return 8;;
  esac
  echo
}


sprout_pkgmgr_install () {
  [ -n "$*" ] || return 0
  local PKGS="$(echo "$*" | sed -nre '
    s~\s*#.*$~~
    s~^\s*([a-z])~\1~p
    ' | tr -s ' \n' '\n' | sort -u | tr -s ' \n' ' ')"
  PKGS="${PKGS% }"
  echo "D: sprout_pkgmgr_install: [$PKGS]" # no $FUNCNAME in dash!
  [ -n "$PKGS" ] || return 0

  case "$PKG_MGR" in
    apt-get )
      DEBIAN_FRONTEND=noninteractive \
        "$PKG_MGR" install \
        --assume-yes \
        --no-install-recommends \
        $PKGS; return $?;;
    apk )
      apk add $PKGS; return $?;;
  esac

  echo "E: unsupported package manager: '$PKG_MGR'" >&2
  return 8
}


sprout_add_command_alias () {
  local WANT_CMD="$1"; shift
  local PROVIDER="$(which "$@" 2>/dev/null | grep -m 1 -Ee '^/')"
  if [ -x "$PROVIDER" ]; then
    ln -vsT -- "$PROVIDER" /usr/bin/"$WANT_CMD" || return $?
  else
    # Message alignment reference: ln -s would print
    # ___"'/usr/bin/$WANT_CMD' -> '…'"
    echo "# skip    $WANT_CMD: found none of [$*]"
  fi
}


sprout_maybe_clone_custom_git_repo () {
  local REPO="$ALPTRAUM_CLONE_REPO"
  [ -n "$REPO" ] || return 0
  flowers "Clone your git repo:"
  local INTO="${ALPTRAUM_CLONE_INTO:-.}"
  git clone "$REPO" "$INTO" || return $?
  cd -- "$INTO" || return $?
  echo
}


sprout_maybe_create_bin_symlinks () {
  local SYM= TGT="$ALPTRAUM_BIN_SYM"
  [ -n "$TGT" ] || return 0
  flowers "Create /bin symlinks:"
  for TGT in $TGT; do
    case "$TGT" in
      /* ) ;;
      * ) TGT="$REPO_PATH/$TGT";;
    esac
    SYM="/bin/$(basename -- "$TGT" | sed -re '
      s~\.[a-z0-9]{1,5}$~~
      ')"
    ln -svT -- "$TGT" "$SYM" || return $?
  done
}


sprout_maybe_clone_gcu () {
  local AUTH="$GCU_REPO_AUTH"
  # ^-- may be configured via $ALP_RC; GCU will later read it from git config

  case "$AUTH" in
    '' ) return 0;;
    @@guess ) sprout_guess_gcu_repo_auth || return $?;;
  esac

  local REPO_NAME='GitLabCIUtilities'
  flowers "Install $REPO_NAME:"
  GCU_PATH="/usr/share/instaffo-util/$REPO_NAME"
  local GCU_UPDATER="$GCU_PATH/force_update_self.sh"
  [ -x "$GCU_UPDATER" ] || git clone "https://${AUTH#\
    }@example.net/git/$REPO_NAME.git" "$GCU_PATH" || return $?
  [ -d ./"$REPO_NAME" ] || ln -s -- "$GCU_PATH" . || return $?
  "$GCU_UPDATER" "$GCU_REPO_BRANCH" || return $?
  echo
}


sprout_guess_gcu_repo_auth () {
  local PW_FN='instaffo_gitlab_ci_utilities_auth.txt'
  AUTH="$(grep -vFe '#' -- \
    ".git/$PW_FN" \
    "$HOME/.config/git/$PW_FN" \
    "$HOME/.$PW_FN" \
    2>/dev/null | grep -Fe : -m 1)"
  [ -n "$AUTH" ] && return 0

  echo "E: failed to guess GCU repo auth" >&2
  return 3
}








[ "$1" = --lib ] && return 0; sprout "$@"; exit $?
