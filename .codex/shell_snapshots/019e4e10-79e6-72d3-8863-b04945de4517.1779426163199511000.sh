# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
→za-readurl-help-null-handler () {
	:
}
+zi-log () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	local opt msg
	[[ $1 = -* ]] && {
		local opt=$1 
		shift
	}
	ZINIT[__last-formatter-code]= 
	msg=${${(j: :)${@:#--}}//\%/%%} 
	if [[ -z $ZINIT[DEBUG] ]] && [[ "$msg" = (#s){dbg}* ]]
	then
		return
	fi
	msg=${${msg//(#b)(([\\]|(%F))([\{]([^\}]##)[\}])|([\{]([^\}]##)[\}])([^\%\{\\]#))/${match[4]:+${${match[3]:-$ZINIT[col-${ZINIT[__last-formatter-code]}]}:#%F}}$match[3]$match[4]${${functions[.zinit-formatter-$match[7]]:+${$(.zinit-formatter-$match[7] "$match[8]"; builtin print -rn -- $REPLY):-←→}}:-$(.zinit-main-message-formatter "$match[6]" "$match[7]" "$match[8]"; \
  builtin print -rn -- "$REPLY"
 )${${ZINIT[__last-formatter-code]::=${${${match[7]:#(…|ndsh|mdsh|mmdsh|-…|lr)}:+$match[7]}:-${ZINIT[__last-formatter-code]}}}:+}}}//←→} 
	[[ -z $msg ]] && return
	msg=$msg$ZINIT[col-rst] 
	builtin print -Pr ${opt:#--} -- $msg
	if [[ -n ${opt:#*n*} || -z $opt ]]
	then
		print -n $'\015'
	fi
}
+zinit-deploy-message () {
	[[ $1 = <-> && ( ${#} = 1 || ( $2 = (hup|nval|err) && ${#} = 2 ) ) ]] && {
		zle && {
			local alltext text IFS=$'\n' nl=$'\n' 
			repeat 25
			do
				read -r -u"$1" text
				alltext+="${text:+$text$nl}" 
			done
			[[ $alltext = @rst$nl ]] && {
				builtin zle reset-prompt
				((1))
			} || {
				[[ -n $alltext ]] && builtin zle -M "$alltext"
			}
		}
		builtin zle -F "$1"
		exec {1}<&-
		return 0
	}
	local THEFD=13371337 hasw 
	exec {THEFD}< <(LANG=C sleep $(( 0.01 + ${${${(M)1#@sleep:}:+${1#@sleep:}}:-0} )); builtin print -r -- ${1:#(@msg|@sleep:*)} "${@[2,-1]}"; )
	command true
	builtin zle -F "$THEFD" +zinit-deploy-message
}
+zinit-message () {
	+zi-log $@
}
+zinit-prehelp-usage-message () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	local cmd=$1 allowed=$2 sep="$ZINIT[col-msg2], $ZINIT[col-ehi]" sep2="$ZINIT[col-msg2], $ZINIT[col-opt]" bcol 
	if (( OPTS[opt_-h,--help] ))
	then
		+zi-log "{lhi}HELP FOR {apo}\`{cmd}$cmd{apo}\`{lhi} subcommand {mdsh}" "the available {b-lhi}options{ehi}:{rst}"
		local opt
		for opt in ${(kos:|:)allowed}
		do
			[[ $opt == --* ]] && continue
			local msg=${___opt_map[$opt]#*:} txt=${___opt_map[(r)opt_$opt,--[^:]##]} 
			if [[ $msg == *":["* ]]
			then
				msg=${${(MS)msg##$cmd:\[[^]]##}:-${(MS)msg##\*:\[[^]]##}} 
				msg=${msg#($cmd|\*):\[} 
			fi
			local pre_msg=`+zi-log -n {opt}${(r:14:)${txt#opt_}}` 
			+zi-log ${(r:35:: :)pre_msg}{rst}{ehi}→{rst}"  $msg"
		done
	elif [[ -n $allowed ]]
	then
		shift 2
		+zi-log "{b}{u-warn}ERROR{b-warn}:{rst}{msg2} Incorrect options given{ehi}:" "${(Mpj:$sep:)@:#-*}{rst}{msg2}. Allowed for the subcommand{ehi}:{rst}" "{apo}\`{cmd}$cmd{apo}\`{msg2} are{ehi}:{rst}" "{nl}{mmdsh} {opt}${allowed//\|/$sep2}{msg2}." "{nl}{…} Aborting.{rst}"
	else
		local -a cmds
		cmds=(load snippet update delete) 
		local bcol="{$cmd}" sep="${ZINIT[col-rst]}${ZINIT[col-$cmd]}\`, \`${ZINIT[col-cmd]}" 
		+zi-log "$bcol(it should be one of, e.g.{ehi}:" "{nb}$bcol\`{cmd}${(pj:$sep:)cmds}$bcol\`," "{cmd}{…}$bcol, e.g.{ehi}: {nb}$bcol\`{lhi}zinit {b}{cmd}load" "{pid}username/reponame$bcol\`) or a {b}{hi}for{nb}$bcol-based" "command body (i.e.{ehi}:{rst}$bcol e.g.{ehi}: {rst}$bcol\`{lhi}zinit" "{…}{b}ice-spec{nb}{…} {hi}for{nb}{lhi} {…}({b}plugin" "{nb}or{b} snippet) {pname}ID-1 ID-2 {-…} {lhi}{…}$bcol\`)." "See \`{cmd}help$bcol\` for a more detailed usage information and" "the list of the {cmd}subcommands$bcol.{rst}"
	fi
}
-zinit_scheduler_add_sh () {
	local idx="$1" in_wait="$___ar2" in_abc="$___ar3" ver_wait="$___ar4" ver_abc="$___ar5" 
	if [[ ( $in_wait = $ver_wait || $in_wait -ge 4 ) && $in_abc = $ver_abc ]]
	then
		ZINIT_RUN+=("${ZINIT_TASKS[$idx]}") 
		return 1
	else
		return idx
	fi
}
.za-bgn-bin-or-src-function-body () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
.za-bgn-bin-or-src-function-body-cygwin () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
.za-bgn-mod-function-body () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
.za-rust-bin-or-src-function-body () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-rust" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
.zinit-add-fpath () {
	[[ $1 = (-f|--front) ]] && {
		shift
		integer front=1 
	}
	.zinit-any-to-user-plugin "$1" ""
	local id_as="$1" add_dir="$2" user="${reply[-2]}" plugin="${reply[-1]}" 
	if (( front ))
	then
		fpath[1,0]=${${${(M)user:#%}:+$plugin}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}}${add_dir:+/$add_dir} 
	else
		fpath+=(${${${(M)user:#%}:+$plugin}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}}${add_dir:+/$add_dir}) 
	fi
}
.zinit-add-report () {
	[[ -n $1 ]] && {
		(( ${+builtins[zpmod]} && 0 )) && zpmod report-append "$1" "$2"$'\n' || ZINIT_REPORTS[$1]+="$2"$'\n' 
	}
	[[ ${ZINIT[DTRACE]} = 1 ]] && {
		(( ${+builtins[zpmod]} )) && zpmod report-append _dtrace/_dtrace "$2"$'\n' || ZINIT_REPORTS[_dtrace/_dtrace]+="$2"$'\n' 
	}
	return 0
}
.zinit-any-to-pid () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+REPLY}:#0}:+warncreateglobal}
	1=${~1} 2=${~2} 
	if [[ -n $2 ]]
	then
		if [[ $1 == (%|/)* || ( -z $1 && $2 == /* ) ]]
		then
			.zinit-util-shands-path $1${${(M)1#(%/?|%[^/]|/?)}:+/}$2
			REPLY=${${REPLY:#%*}:+%}$REPLY 
		else
			REPLY=$1${1:+/}$2 
		fi
		return 0
	fi
	if [[ $1 = (%|/|\~)* ]]
	then
		.zinit-util-shands-path $1
		REPLY=${${REPLY:#%*}:+%}$REPLY 
		return 0
	fi
	REPLY=${1//---//} 
	return 0
}
.zinit-any-to-user-plugin () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+reply}:#0}:+warncreateglobal}
	if [[ -n $2 ]]
	then
		2=${~2} 
		reply=(${1:-${${(M)2#/}:+%}} ${${${(M)1#%}:+$2}:-${2//---//}}) 
		return 0
	fi
	if [[ $1 = /* ]]
	then
		reply=(% $1) 
		return 0
	fi
	if [[ $1 = %* ]]
	then
		local -A map
		map=(ZPFX "$ZPFX" HOME $HOME SNIPPETS $ZINIT[SNIPPETS_DIR] PLUGINS $ZINIT[PLUGINS_DIR]) 
		reply=(% ${${1/(#b)(#s)%(${(~j:|:)${(@k)map}}|)/$map[$match[1]]}}) 
		reply[2]=${~reply[2]} 
		return 0
	fi
	1=${1//---//} 
	if [[ $1 = */* ]]
	then
		reply=(${1%%/*} ${1#*/}) 
		return 0
	fi
	reply=("" "${1:-_unknown}") 
	return 0
}
.zinit-compdef-clear () {
	local quiet="$1" count="${#ZINIT_COMPDEF_REPLAY}" 
	ZINIT_COMPDEF_REPLAY=() 
	[[ $quiet = -q ]] || +zi-log "Compdef-replay cleared (it had {num}${count}{rst} entries)."
}
.zinit-compdef-replay () {
	local quiet="$1" 
	typeset -a pos
	if [[ ${+functions[compdef]} = 0 ]]
	then
		+zi-log "{u-warn}Error{b-warn}:{rst} The {func}compinit{rst}" "function hasn't been loaded, cannot do {it}{cmd}compdef replay{rst}."
		return 1
	fi
	local cdf
	for cdf in "${ZINIT_COMPDEF_REPLAY[@]}"
	do
		pos=("${(z)cdf}") 
		[[ ${#pos[@]} = 1 && -z ${pos[-1]} ]] && continue
		pos=("${(Q)pos[@]}") 
		[[ $quiet = -q ]] || +zi-log "Running compdef: {cmd}${pos[*]}{rst}"
		compdef "${pos[@]}"
	done
	return 0
}
.zinit-diff () {
	.zinit-diff-functions "$1" "$2"
	.zinit-diff-options "$1" "$2"
	.zinit-diff-env "$1" "$2"
	.zinit-diff-parameter "$1" "$2"
}
.zinit-diff-env () {
	typeset -a tmp
	local IFS=" " 
	[[ $2 = begin ]] && {
		{
			[[ -z ${ZINIT[PATH_BEFORE__$uspl2]} ]] && tmp=("${(q)path[@]}") 
			ZINIT[PATH_BEFORE__$1]="${tmp[*]}" 
		}
		{
			[[ -z ${ZINIT[FPATH_BEFORE__$uspl2]} ]] && tmp=("${(q)fpath[@]}") 
			ZINIT[FPATH_BEFORE__$1]="${tmp[*]}" 
		}
	} || {
		tmp=("${(q)path[@]}") 
		ZINIT[PATH_AFTER__$1]+=" ${tmp[*]}" 
		tmp=("${(q)fpath[@]}") 
		ZINIT[FPATH_AFTER__$1]+=" ${tmp[*]}" 
	}
}
.zinit-diff-functions () {
	local uspl2="$1" 
	local cmd="$2" 
	[[ $cmd = begin ]] && {
		[[ -z ${ZINIT[FUNCTIONS_BEFORE__$uspl2]} ]] && ZINIT[FUNCTIONS_BEFORE__$uspl2]="${(j: :)${(qk)functions[@]}}" 
	} || ZINIT[FUNCTIONS_AFTER__$uspl2]+=" ${(j: :)${(qk)functions[@]}}" 
}
.zinit-diff-options () {
	local IFS=" " 
	[[ $2 = begin ]] && {
		[[ -z ${ZINIT[OPTIONS_BEFORE__$uspl2]} ]] && ZINIT[OPTIONS_BEFORE__$1]="${(kv)options[@]}" 
	} || ZINIT[OPTIONS_AFTER__$1]+=" ${(kv)options[@]}" 
}
.zinit-diff-parameter () {
	typeset -a tmp
	[[ $2 = begin ]] && {
		{
			[[ -z ${ZINIT[PARAMETERS_BEFORE__$uspl2]} ]] && ZINIT[PARAMETERS_BEFORE__$1]="${(j: :)${(qkv)parameters[@]}}" 
		}
	} || {
		ZINIT[PARAMETERS_AFTER__$1]+=" ${(j: :)${(qkv)parameters[@]}}" 
	}
}
.zinit-find-other-matches () {
	local pdir_path="$1" pbase="$2" limit="$3" 
	if [[ $limit == 1 ]]
	then
		reply=("$pdir_path"/*.plugin.zsh(DN)) 
	elif [[ $limit == 0 ]]
	then
		reply=("$pdir_path"/*.service.zsh(DN)) 
	else
		if [[ -e $pdir_path/init.zsh ]]
		then
			reply=("$pdir_path"/init.zsh) 
		elif [[ -e $pdir_path/$pbase.zsh-theme ]]
		then
			reply=("$pdir_path/$pbase".zsh-theme) 
		elif [[ -e $pdir_path/$pbase.theme.zsh ]]
		then
			reply=("$pdir_path/$pbase".theme.zsh) 
		else
			reply=("$pdir_path"/*.plugin.zsh(DN) "$pdir_path"/*.zsh-theme(DN) "$pdir_path"/*.lib.zsh(DN) "$pdir_path"/*.zsh(DN) "$pdir_path"/*.sh(DN) "$pdir_path"/.zshrc(DN)) 
		fi
	fi
	reply=("${(u)reply[@]}") 
	return $(( ${#reply} > 0 ? 0 : 1 ))
}
.zinit-formatter-auto () {
	emulate -L zsh -o extendedglob -o warncreateglobal -o typesetsilent
	local out in=$1 i wrk match spaces rest 
	integer mbegin mend
	local -a ice_order ecmds
	ice_order=(${(As:|:)ZINIT[ice-list]} ${(@)${(A@kons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}) 
	ecmds=(${ZINIT_EXTS[(I)z-annex subcommand:*]#z-annex subcommand:}) 
	in=${(j: :)${${(Z+Cn+)in}//[$'\t ']/$'\u00a0'}} 
	wrk=$in 
	while [[ $in == (#b)([[:space:]]#)([^[:space:]]##)(*) ]]
	do
		spaces=$match[1] 
		rest=$match[3] 
		wrk=${match[2]//---//} 
		REPLY=$wrk 
		if [[ ( $wrk == ([[:space:]]##|(#s))[0-9.]##([[:space:]]##|(#e)) && $rest == ([[:space:]]#|(#s))[sm]([[:space:]]##*|(#e)) ) || $wrk == ([[:space:]]##|(#s))[0-9.]##[sm]([[:space:]]##|(#e)) ]]
		then
			REPLY=$ZINIT[col-time]$wrk$ZINIT[col-rst] 
			if [[ $wrk != *[sm]* ]]
			then
				rest=$ZINIT[col-time]${(M)rest##[[:space:]]#[sm]}$ZINIT[col-rst]${rest##[[:space:]]#[sm]} 
			fi
		elif [[ $wrk == ([[:space:]]##|(#s))[0-9.]##([[:space:]]##|(#e)) ]]
		then
			REPLY=$ZINIT[col-num]$wrk$ZINIT[col-rst] 
		elif [[ $wrk == (#b)(((http|ftp)(|s)|ssh|scp|ntp|file)://[[:alnum:].:+/]##) ]]
		then
			.zinit-formatter-url $wrk
		elif [[ $wrk == (--|)(${(~j:|:)ice_order})[:=\"\'\!a-zA-Z0-9-]* ]]
		then
			REPLY=$ZINIT[col-ice]$wrk$ZINIT[col-rst] 
		elif [[ $wrk == (OMZ([PLT]|)|PZT([MLT]|)):* || $wrk == [^/]##/[^/]## || -d $ZINIT[PLUGINS_DIR]/${wrk//\//---} ]]
		then
			.zinit-formatter-pid $wrk
		elif [[ $wrk == (${~ZINIT[cmds]}|${(~j:|:)ecmds}) ]]
		then
			REPLY=$ZINIT[col-cmd]$wrk$ZINIT[col-rst] 
		elif type $1 &> /dev/null
		then
			REPLY=$ZINIT[col-bcmd]$wrk$ZINIT[col-rst] 
		elif [[ $wrk == (#b)(*)('<->'|'<–>'|'<—>')(*) || $wrk == (#b)(*)(…|–|—|↔|...)(*) ]]
		then
			local -A map=(… … - dsh – ndsh — mdsh '<->' ↔ '<–>' ↔ '<—>' ↔ ↔ ↔ ... …) 
			REPLY=$match[1]$ZINIT[col-$map[$wrk]]$match[3] 
		elif [[ $wrk == (#b)(*)([\'\`\"])([^\'\`\"]##)([\'\`\"])(*) ]]
		then
			local -A map=(\` bapo \' apo \" quo x\` baps x\' aps x\" quos) 
			local openq=$match[2] str=$match[3] closeq=$match[4] RST=$ZINIT[col-rst] 
			REPLY=$match[1]$ZINIT[col-$map[$openq]]$openq$RST$ZINIT[col-$map[x$openq]]$str$RST$ZINIT[col-$map[$closeq]]$closeq$RST$match[5] 
		fi
		in=$rest 
		out+=${spaces//$'\n'/$'\013\015'}$REPLY 
	done
	REPLY=${out//$'\u00a0'/ } 
}
.zinit-formatter-bar () {
	.zinit-formatter-bar-util ─ bar
}
.zinit-formatter-bar-util () {
	if [[ $LANG == (#i)*utf-8* ]]
	then
		ch=$1 
	else
		ch=- 
	fi
	REPLY=$ZINIT[col-$2]${(pl:COLUMNS-1::$ch:):-}$ZINIT[col-rst] 
}
.zinit-formatter-pid () {
	builtin emulate -L zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	local pbz=${(M)1##(#s)[[:space:]]##} 
	local kbz=${(M)1%%[[:space:]]##(#e)} 
	1=${1//((#s)[[:space:]]##|[[:space:]]##(#e))/} 
	((${+functions[.zinit-first]})) || source ${ZINIT[BIN_DIR]}/zinit-side.zsh
	.zinit-any-colorify-as-uspl2 "$1"
	pbz=${pbz/[[:blank:]]/ } 
	local kbz_rev="${(j::)${(@Oas::)kbz}}" 
	kbz="${(j::)${(@Oas::)${kbz_rev/[[:blank:]]/ }}}" 
	REPLY=$pbz$REPLY$kbz 
}
.zinit-formatter-th-bar () {
	.zinit-formatter-bar-util ━ th-bar
}
.zinit-formatter-url () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	if [[ $1 = (#b)([^:]#)(://|::)((([[:alnum:]._+-]##).([[:alnum:]_+-]##))|([[:alnum:].+_-]##))(|/(*)) ]]
	then
		match[9]=${match[9]//\//"%F{227}%B"/"%F{81}%b"} 
		if [[ -n $match[4] ]]
		then
			REPLY="$(builtin print -Pr -- %F{220}$match[1]%F{227}$match[2]\
%B%F{82}$match[5]\
%B%F{227}.\
%B%F{183}$match[6]%f%b)" 
		else
			REPLY="$(builtin print -Pr -- %F{220}$match[1]%F{227}$match[2]\
%B%F{82}$match[7]%f%b)" 
		fi
		if [[ -n $match[9] ]]
		then
			REPLY+="$(print -Pr -- \
%F{227}%B/%F{81}%b$match[9]%f%b)" 
		fi
	else
		REPLY=$ZINIT[col-url]$1$ZINIT[col-rst] 
	fi
}
.zinit-get-mtime-into () {
	if (( ZINIT[HAVE_ZSTAT] ))
	then
		local -a arr
		{
			zstat +mtime -A arr "$1"
		} 2> /dev/null
		: ${(P)2::="${arr[1]}"}
	else
		{
			: ${(P)2::="$(stat -c %Y "$1")"}
		} 2> /dev/null
	fi
}
.zinit-get-object-path () {
	local type="$1" id_as="$2" local_dir dirname 
	integer exists
	id_as="${ICE[id-as]:-$id_as}" 
	id_as="${${id_as#"${id_as%%[! $'\t']*}"}%/}" 
	for type in ${=${${(M)type:#AUTO}:+snippet plugin}:-$type}
	do
		if [[ $type == snippet ]]
		then
			dirname="${${id_as%%\?*}:t}" 
			local_dir="${${${id_as%%\?*}/:\/\//--}:h}" 
			[[ $local_dir = . ]] && local_dir=  || local_dir="${${${${${local_dir#/}//\//--}//=/-EQ-}//\?/-QM-}//\&/-AMP-}" 
			local_dir="${ZINIT[SNIPPETS_DIR]}${local_dir:+/$local_dir}" 
		else
			.zinit-any-to-user-plugin "$id_as"
			local_dir=${${${(M)reply[-2]:#%}:+${reply[2]}}:-${ZINIT[PLUGINS_DIR]}/${id_as//\//---}} 
			[[ $id_as == _local/* && -d $local_dir && ! -d $local_dir/._zinit ]] && command mkdir -p "$local_dir"/._zinit
			dirname="" 
		fi
		[[ -e $local_dir/${dirname:+$dirname/}._zinit || -e $local_dir/${dirname:+$dirname/}._zplugin ]] && exists=1 
		(( exists )) && break
	done
	reply=("$local_dir" "$dirname" "$exists") 
	REPLY="$local_dir${dirname:+/$dirname}" 
	return $(( 1 - exists ))
}
.zinit-ice () {
	builtin setopt localoptions noksharrays extendedglob warncreateglobal typesetsilent noshortloops
	integer retval
	local bit exts="${(j:|:)${(@)${(@Akons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}}" 
	for bit
	do
		[[ $bit = (#b)(--|)(${~ZINIT[ice-list]}${~exts})(*) ]] && ZINIT_ICES[${match[2]}]+="${ZINIT_ICES[${match[2]}]:+;}${match[3]#(:|=)}"  || break
		retval+=1 
	done
	[[ ${ZINIT_ICES[as]} = program ]] && ZINIT_ICES[as]=command 
	[[ -n ${ZINIT_ICES[on-update-of]} ]] && ZINIT_ICES[subscribe]="${ZINIT_ICES[subscribe]:-${ZINIT_ICES[on-update-of]}}" 
	[[ -n ${ZINIT_ICES[pick]} ]] && ZINIT_ICES[pick]="${ZINIT_ICES[pick]//\$ZPFX/${ZPFX%/}}" 
	if (( $+ZINIT_ICES[build] ))
	then
		+zi-log -- "{dbg} {ice}build{rst}: setting configure & make ices"
		ZINIT_ICES[configure]= 
		ZINIT_ICES[make]= 
	fi
	if (( $+ZINIT_ICES[configure] || $+ZINIT_ICES[cmake] || $+ZINIT_ICES[make] ))
	then
		ZINIT_ICES[null]= 
	fi
	(( $+ZINIT_ICES[configure] )) && ZINIT_ICES[configure]="${ZINIT_ICES[configure]}" 
	(( $+ZINIT_ICES[make] )) && ZINIT_ICES[make]="${ZINIT_ICES[make]:-install}" 
	return retval
}
.zinit-load () {
	typeset -F 3 SECONDS=0 
	local ___mode="$3" ___limit="$4" ___rst=0 ___retval=0 ___key 
	.zinit-any-to-user-plugin "$1" "$2"
	local ___user="${reply[-2]}" ___plugin="${reply[-1]}" ___id_as="${ICE[id-as]:-${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}}" 
	local ___pdir_path="${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}" 
	local ___pdir_orig="$___pdir_path" 
	ZINIT[CUR_USR]="$___user" ZINIT[CUR_PLUGIN]="$___plugin" ZINIT[CUR_USPL2]="$___id_as" 
	if [[ -n ${ICE[teleid]} ]]
	then
		.zinit-any-to-user-plugin "${ICE[teleid]}"
		___user="${reply[-2]}" ___plugin="${reply[-1]}" 
	else
		ICE[teleid]="$___user${${___user:#%}:+/}$___plugin" 
	fi
	.zinit-set-m-func set
	local -a ___arr
	reply=(${(on)ZINIT_EXTS2[(I)zinit hook:preinit-pre <->]} ${(on)ZINIT_EXTS[(I)z-annex hook:preinit-<-> <->]} ${(on)ZINIT_EXTS2[(I)zinit hook:preinit-post <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]:-$ZINIT_EXTS2[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" "${${___key##(zinit|z-annex) hook:}%% <->}" load || return $(( 10 - $? ))
	done
	if [[ $___user != % && ! -d ${ZINIT[PLUGINS_DIR]}/${___id_as//\//---} ]]
	then
		(( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		reply=("$___user" "$___plugin") REPLY=github 
		if (( ${+ICE[pack]} ))
		then
			if ! .zinit-get-package "$___user" "$___plugin" "$___id_as" "${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}" "${ICE[pack]:-default}"
			then
				zle && {
					builtin print
					zle .reset-prompt
				}
				return 1
			fi
			___id_as="${ICE[id-as]:-${___user}${${___user:#(%|/)*}:+/}$___plugin}" 
		fi
		___user="${reply[-2]}" ___plugin="${reply[-1]}" 
		ICE[teleid]="$___user${${___user:#(%|/)*}:+/}$___plugin" 
		[[ $REPLY = snippet ]] && {
			ICE[id-as]="${ICE[id-as]:-$___id_as}" 
			.zinit-load-snippet $___plugin "" $___limit && return
			zle && {
				builtin print
				zle .reset-prompt
			}
			return 1
		}
		.zinit-setup-plugin-dir "$___user" "$___plugin" "$___id_as" "$REPLY"
		local rc="$?" 
		if [[ "$rc" -ne 0 ]]
		then
			zle && {
				builtin print
				zle .reset-prompt
			}
			return "$rc"
		fi
		zle && ___rst=1 
	fi
	ZINIT_SICE[$___id_as]= 
	.zinit-pack-ice "$___id_as"
	(( ${+ICE[cloneonly]} )) && return 0
	.zinit-register-plugin "$___id_as" "$___mode" "${ICE[teleid]}"
	if [[ -n ${ICE[param]} ]]
	then
		.zinit-setup-params && local -x ${(Q)reply[@]}
	fi
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atinit-<-> <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}" \!atinit || return $(( 10 - $? ))
	done
	[[ ${+ICE[atinit]} = 1 && $ICE[atinit] != '!'* ]] && {
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}"
			} && eval "${ICE[atinit]}"
			((1))
		} || eval "${ICE[atinit]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atinit-<-> <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}" atinit || return $(( 10 - $? ))
	done
	.zinit-load-plugin "$___user" "$___plugin" "$___id_as" "$___mode" "$___rst" "$___limit"
	___retval=$? 
	(( ${+ICE[notify]} == 1 )) && {
		[[ $___retval -eq 0 || -n ${(M)ICE[notify]#\!} ]] && {
			local msg
			eval "msg=\"${ICE[notify]#\!}\""
			+zinit-deploy-message @msg "$msg"
		} || +zinit-deploy-message @msg "notify: Plugin not loaded / loaded with problem, the return code: $___retval"
	}
	(( ${+ICE[reset-prompt]} == 1 )) && +zinit-deploy-message @___rst
	.zinit-set-m-func unset
	ZINIT[CUR_USR]= ZINIT[CUR_PLUGIN]= ZINIT[CUR_USPL2]= 
	ZINIT[TIME_INDEX]=$(( ${ZINIT[TIME_INDEX]:-0} + 1 )) 
	ZINIT[TIME_${ZINIT[TIME_INDEX]}_${___id_as//\//---}]=$SECONDS 
	ZINIT[AT_TIME_${ZINIT[TIME_INDEX]}_${___id_as//\//---}]=$EPOCHREALTIME 
	return ___retval
}
.zinit-load-ices () {
	local id_as="$1" ___key ___path 
	local -a ice_order
	ice_order=(${(As:|:)ZINIT[ice-list]} ${(@)${(A@kons:|:)${ZINIT_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}) 
	___path="${ZINIT[PLUGINS_DIR]}/${id_as//\//---}"/._zinit 
	if [[ ! -d $___path ]]
	then
		if ! .zinit-get-object-path snippet "${id_as//\//---}"
		then
			return 1
		fi
		___path="$REPLY"/._zinit 
	fi
	for ___key in "${ice_order[@]}"
	do
		(( ${+ICE[$___key]} )) && [[ ${ICE[$___key]} != +* ]] && continue
		[[ -e $___path/$___key ]] && ICE[$___key]="$(<$___path/$___key)" 
	done
	[[ -n ${ICE[on-update-of]} ]] && ICE[subscribe]="${ICE[subscribe]:-${ICE[on-update-of]}}" 
	[[ ${ICE[as]} = program ]] && ICE[as]=command 
	[[ -n ${ICE[pick]} ]] && ICE[pick]="${ICE[pick]//\$ZPFX/${ZPFX%/}}" 
	return 0
}
.zinit-load-object () {
	local ___type="$1" ___id=$2 
	local -a ___opt
	___opt=(${@[3,-1]}) 
	if [[ $___type == snippet ]]
	then
		.zinit-load-snippet $___opt "$___id"
	elif [[ $___type == plugin ]]
	then
		.zinit-load "$___id" "" $___opt
	fi
	___retval+=$? 
	return __retval
}
.zinit-load-plugin () {
	local ___user="$1" ___plugin="$2" ___id_as="$3" ___mode="$4" ___rst="$5" ___limit="$6" ___correct=0 ___retval=0 
	local ___pbase="${${___plugin:t}%(.plugin.zsh|.zsh|.git)}" ___key 
	builtin set --
	[[ -o ksharrays ]] && ___correct=1 
	[[ -n ${ICE[(i)(\!|)(sh|bash|ksh|csh)]}${ICE[opts]} ]] && {
		local -a ___precm
		___precm=(builtin emulate ${${(M)${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:+-R} ${${${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:-zsh} ${${ICE[(i)(\!|)bash]}:+-${(s: :):-o noshglob -o braceexpand -o kshglob}} ${(s: :):-${${:-${(@s: :):--o}" "${(s: :)^ICE[opts]}}:#-o }} -c) 
	}
	[[ -z ${ICE[subst]} ]] && local ___builtin=builtin 
	[[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]="${ICE[pick]:-/dev/null}" 
	if [[ -n ${ICE[autoload]} ]]
	then
		:zinit-tmp-subst-autoload -Uz ${(s: :)${${${(s.;.)ICE[autoload]#[\!\#]}#[\!\#]}//(#b)((*)(->|=>|→)(*)|(*))/${match[2]:+$match[2] -S $match[4]}${match[5]:+${match[5]} -S ${match[5]}}}} ${${(M)ICE[autoload]:#*(->|=>|→)*}:+-C} ${${(M)ICE[autoload]#(?\!|\!)}:+-C} ${${(M)ICE[autoload]#(?\#|\#)}:+-I}
	fi
	if [[ ${ICE[as]} = command ]]
	then
		[[ ${+ICE[pick]} = 1 && -z ${ICE[pick]} ]] && ICE[pick]="${___id_as:t}" 
		reply=() 
		if [[ -n ${ICE[pick]} && ${ICE[pick]} != /dev/null ]]
		then
			reply=(${(M)~ICE[pick]##/*}(DN) $___pdir_path/${~ICE[pick]}(DN)) 
			[[ -n ${reply[1-correct]} ]] && ___pdir_path="${reply[1-correct]:h}" 
		fi
		[[ -z ${path[(er)$___pdir_path]} ]] && {
			[[ $___mode != light ]] && .zinit-diff-env "${ZINIT[CUR_USPL2]}" begin
			path=("${___pdir_path%/}" ${path[@]}) 
			[[ $___mode != light ]] && .zinit-diff-env "${ZINIT[CUR_USPL2]}" end
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "$ZINIT[col-info2]$___pdir_path$ZINIT[col-rst] added to \$PATH"
		}
		[[ -n ${reply[1-correct]} && ! -x ${reply[1-correct]} ]] && command chmod a+x ${reply[@]}
		[[ ${ICE[atinit]} = '!'* || -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			if [[ ${ZINIT[TMP_SUBST]} = inactive ]]
			then
				(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}"  || builtin unset "ZINIT[bkp-compdef]"
				functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
				ZINIT[TMP_SUBST]=1 
			else
				(( ++ ZINIT[TMP_SUBST] ))
			fi
		}
		local ZERO
		[[ $ICE[atinit] = '!'* ]] && {
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}"
				} && eval "${ICE[atinit#!]}"
				((1))
			} || eval "${ICE[atinit]#!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		[[ -n ${ICE[src]} ]] && {
			ZERO="${${(M)ICE[src]##/*}:-$___pdir_orig/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( ___retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				}
				(( ___retval += $? ))
			}
		}
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___pdir_orig"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			local ___fname
			for ___fname in "${reply[@]}"
			do
				ZERO="${${(M)___fname:#/*}:-$___pdir_orig/$___fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( ___retval += $? ))
					((1))
				} || {
					((1))
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					}
					(( ___retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for ___key in "${reply[@]}"
		do
			___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
			"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$___user" "$___plugin" "$___id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$___id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$___pdir_orig/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$___pdir_orig"
				} && builtin eval "${ICE[atload]#\!}"
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		[[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			(( -- ZINIT[TMP_SUBST] == 0 )) && {
				ZINIT[TMP_SUBST]=inactive 
				builtin setopt noaliases
				(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
				(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
			}
		}
	elif [[ ${ICE[as]} = completion ]]
	then
		((1))
	else
		if [[ -n ${ICE[pick]} ]]
		then
			[[ ${ICE[pick]} = /dev/null ]] && reply=(/dev/null)  || reply=(${(M)~ICE[pick]##/*}(DN) $___pdir_path/${~ICE[pick]}(DN)) 
		elif [[ -e $___pdir_path/$___pbase.plugin.zsh && $___limit -ne 0 ]]
		then
			reply=("$___pdir_path/$___pbase".plugin.zsh) 
		else
			.zinit-find-other-matches "$___pdir_path" "$___pbase" "$___limit"
		fi
		local ___fname="${reply[1-correct]:t}" 
		___pdir_path="${reply[1-correct]:h}" 
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Source $___fname ${${${(M)___mode:#light}:+(no reporting)}:-$ZINIT[col-info2](reporting enabled)$ZINIT[col-rst]}"
		[[ $___mode != light(|-b) ]] && .zinit-diff "${ZINIT[CUR_USPL2]}" begin
		.zinit-tmp-subst-on "${___mode:-load}"
		(( ${+ICE[blockf]} )) && {
			local -a fpath_bkp
			fpath_bkp=("${fpath[@]}") 
		}
		local ZERO="$___pdir_path/$___fname" 
		(( ${+ICE[aliases]} )) || builtin setopt noaliases
		[[ $ICE[atinit] = '!'* ]] && {
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}}"
				} && eval "${ICE[atinit]#!}"
				((1))
			} || eval "${ICE[atinit]#1}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		(( ${+ICE[silent]} )) && {
			{
				[[ -n $___precm ]] && {
					builtin ${___precm[@]} 'source "$ZERO"'
					((1))
				} || {
					((1))
					$___builtin source "$ZERO"
				}
			} 2> /dev/null >&2
			(( ___retval += $? ))
			((1))
		} || {
			((1))
			{
				[[ -n $___precm ]] && {
					builtin ${___precm[@]} 'source "$ZERO"'
					((1))
				} || {
					((1))
					$___builtin source "$ZERO"
				}
			}
			(( ___retval += $? ))
		}
		[[ -n ${ICE[src]} ]] && {
			ZERO="${${(M)ICE[src]##/*}:-$___pdir_orig/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( ___retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $___precm ]] && {
						builtin ${___precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						$___builtin source "$ZERO"
					}
				}
				(( ___retval += $? ))
			}
		}
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___pdir_orig"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			for ___fname in "${reply[@]}"
			do
				ZERO="${${(M)___fname:#/*}:-$___pdir_orig/$___fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( ___retval += $? ))
					((1))
				} || {
					{
						[[ -n $___precm ]] && {
							builtin ${___precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							$___builtin source "$ZERO"
						}
					}
					(( ___retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for ___key in "${reply[@]}"
		do
			___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
			"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$___user" "$___plugin" "$___id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$___id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$___pdir_orig/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$___pdir_orig"
				} && builtin eval "${ICE[atload]#\!}"
				((1))
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
		(( ${+ICE[blockf]} )) && {
			fpath=("${fpath_bkp[@]}") 
		}
		.zinit-tmp-subst-off "${___mode:-load}"
		[[ $___mode != light(|-b) ]] && .zinit-diff "${ZINIT[CUR_USPL2]}" end
	fi
	[[ ${+ICE[atload]} = 1 && ${ICE[atload][1]} != "!" ]] && {
		ZERO="$___pdir_orig/-atload-" 
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___pdir_orig"
			} && builtin eval "${ICE[atload]}"
			((1))
		} || eval "${ICE[atload]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atload-<-> <->]}) 
	for ___key in "${reply[@]}"
	do
		___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]}[@]}") 
		"${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" atload
	done
	(( ___rst )) && {
		builtin print
		zle .reset-prompt
	}
	return ___retval
}
.zinit-load-snippet () {
	typeset -F 3 SECONDS=0 
	local -a opts
	zparseopts -E -D -a opts f -command || {
		+zi-log "{u-warn}Error{b-warn}:{rst} Incorrect options (accepted ones: {opt}-f{rst}, {opt}--command{rst})."
		return 1
	}
	local url="$1" limit="$3" 
	[[ -n ${ICE[teleid]} ]] && url="${ICE[teleid]}" 
	builtin set --
	integer correct retval exists
	[[ -o ksharrays ]] && correct=1 
	[[ -n ${ICE[(i)(\!|)(sh|bash|ksh|csh)]}${ICE[opts]} ]] && {
		local -a precm
		precm=(builtin emulate ${${(M)${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:+-R} ${${${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:-zsh} ${${ICE[(i)(\!|)bash]}:+-${(s: :):-o noshglob -o braceexpand -o kshglob}} ${(s: :):-${${:-${(@s: :):--o}" "${(s: :)^ICE[opts]}}:#-o }} -c) 
	}
	url="${${url#"${url%%[! $'\t']*}"}%/}" 
	ICE[teleid]="${ICE[teleid]:-$url}" 
	[[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]="${ICE[pick]:-/dev/null}" 
	local local_dir dirname filename save_url="$url" 
	eval "url=\"$url\""
	local id_as="${ICE[id-as]:-$url}" 
	.zinit-set-m-func set
	if [[ -n ${ICE[param]} ]]
	then
		.zinit-setup-params && local -x ${(Q)reply[@]}
	fi
	.zinit-pack-ice "$id_as" ""
	[[ $url = *(${(~kj.|.)${(Mk)ZINIT_1MAP:#OMZ*}}|robbyrussell*oh-my-zsh|ohmyzsh/ohmyzsh)* ]] && local ZSH="${ZINIT[SNIPPETS_DIR]}" 
	.zinit-get-object-path snippet "$id_as"
	filename="${reply[-2]}" dirname="${reply[-2]}" 
	local_dir="${reply[-3]}" exists=${reply[-1]} 
	local -a arr
	local key
	reply=(${(on)ZINIT_EXTS2[(I)zinit hook:preinit-pre <->]} ${(on)ZINIT_EXTS[(I)z-annex hook:preinit-<-> <->]} ${(on)ZINIT_EXTS2[(I)zinit hook:preinit-post <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]:-$ZINIT_EXTS2[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zinit|z-annex) hook:}%% <->}" load || return $(( 10 - $? ))
	done
	if [[ -n ${opts[(r)-f]} || $exists -eq 0 ]]
	then
		(( ${+functions[.zinit-download-snippet]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		.zinit-download-snippet "$save_url" "$url" "$id_as" "$local_dir" "$dirname" "$filename"
		retval=$? 
	fi
	(( ${+ICE[cloneonly]} || retval )) && return 0
	ZINIT_SNIPPETS[$id_as]="$id_as <${${ICE[svn]+svn}:-single file}>" 
	ZINIT[CUR_USPL2]="$id_as" ZINIT_REPORTS[$id_as]= 
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atinit-<-> <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atinit || return $(( 10 - $? ))
	done
	(( ${+ICE[atinit]} )) && {
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			} && eval "${ICE[atinit]}"
			((1))
		} || eval "${ICE[atinit]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atinit-<-> <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" atinit || return $(( 10 - $? ))
	done
	local -a list
	local ZERO
	if [[ -z ${opts[(r)--command]} && ( -z ${ICE[as]} || ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ) ]]
	then
		if [[ ${ZINIT[TMP_SUBST]} = inactive ]]
		then
			(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}"  || builtin unset "ZINIT[bkp-compdef]"
			functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
			ZINIT[TMP_SUBST]=1 
		else
			(( ++ ZINIT[TMP_SUBST] ))
		fi
		if [[ -d $local_dir/$dirname/functions ]]
		then
			[[ -z ${fpath[(r)$local_dir/$dirname/functions]} ]] && fpath+=("$local_dir/$dirname/functions") 
			() {
				builtin setopt localoptions extendedglob
				autoload $local_dir/$dirname/functions/^([_.]*|prompt_*_setup|README*)(D-.N:t)
			}
		fi
		if (( ${+ICE[svn]} == 0 ))
		then
			[[ ${+ICE[pick]} = 0 ]] && list=("$local_dir/$dirname/$filename") 
			[[ -n ${ICE[pick]} ]] && list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
		else
			if [[ -n ${ICE[pick]} ]]
			then
				list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
			elif (( ${+ICE[pick]} == 0 ))
			then
				.zinit-find-other-matches "$local_dir/$dirname" "$filename" "$limit"
				list=(${reply[@]}) 
			fi
		fi
		if [[ -f ${list[1-correct]} ]]
		then
			ZERO="${list[1-correct]}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				}
				(( retval += $? ))
			}
			(( 0 == retval )) && [[ $url = PZT::* || $url = https://github.com/sorin-ionescu/prezto/* ]] && zstyle ":prezto:module:${${id_as%/init.zsh}:t}" loaded 'yes'
		else
			[[ ${+ICE[silent]} -eq 1 || ( ${+ICE[pick]} -eq 1 && -z ${ICE[pick]} ) || ${ICE[pick]} = /dev/null ]] || {
				+zi-log "Snippet not loaded ({url}${id_as}{rst})"
				retval=1 
			}
		fi
		[[ -n ${ICE[src]} ]] && {
			ZERO="${${(M)ICE[src]##/*}:-$local_dir/$dirname/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				}
				(( retval += $? ))
			}
		}
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			local fname
			for fname in "${reply[@]}"
			do
				ZERO="${${(M)fname:#/*}:-$local_dir/$dirname/$fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( retval += $? ))
					((1))
				} || {
					((1))
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					}
					(( retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for key in "${reply[@]}"
		do
			arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
			"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$save_url" "" "$id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$local_dir/$dirname/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$local_dir/$dirname"
				} && builtin eval "${ICE[atload]#\!}"
				((1))
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		(( -- ZINIT[TMP_SUBST] == 0 )) && {
			ZINIT[TMP_SUBST]=inactive 
			builtin setopt noaliases
			(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
			(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
		}
	elif [[ -n ${opts[(r)--command]} || ${ICE[as]} = command ]]
	then
		[[ ${+ICE[pick]} = 1 && -z ${ICE[pick]} ]] && ICE[pick]="${id_as:t}" 
		if (( ${+ICE[svn]} ))
		then
			if [[ -n ${ICE[pick]} ]]
			then
				list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
				[[ -n ${list[1-correct]} ]] && local xpath="${list[1-correct]:h}" xfilepath="${list[1-correct]}" 
			else
				local xpath="$local_dir/$dirname" 
			fi
		else
			local xpath="$local_dir/$dirname" xfilepath="$local_dir/$dirname/$filename" 
			[[ -n ${ICE[pick]} ]] && {
				list=(${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN)) 
				[[ -n ${list[1-correct]} ]] && xpath="${list[1-correct]:h}" xfilepath="${list[1-correct]}" 
			}
		fi
		[[ -n $xpath && -z ${path[(er)$xpath]} ]] && path=("${xpath%/}" ${path[@]}) 
		[[ -n $xfilepath && -f $xfilepath && ! -x "$xfilepath" ]] && command chmod a+x "$xfilepath" ${list[@]:#$xfilepath}
		[[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			if [[ ${ZINIT[TMP_SUBST]} = inactive ]]
			then
				(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}"  || builtin unset "ZINIT[bkp-compdef]"
				functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
				ZINIT[TMP_SUBST]=1 
			else
				(( ++ ZINIT[TMP_SUBST] ))
			fi
		}
		if [[ -n ${ICE[src]} ]]
		then
			ZERO="${${(M)ICE[src]##/*}:-$local_dir/$dirname/${ICE[src]}}" 
			(( ${+ICE[silent]} )) && {
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				} 2> /dev/null >&2
				(( retval += $? ))
				((1))
			} || {
				((1))
				{
					[[ -n $precm ]] && {
						builtin ${precm[@]} 'source "$ZERO"'
						((1))
					} || {
						((1))
						builtin source "$ZERO"
					}
				}
				(( retval += $? ))
			}
		fi
		[[ -n ${ICE[multisrc]} ]] && {
			local ___oldcd="$PWD" 
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			}
			eval "reply=(${ICE[multisrc]})"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
			local fname
			for fname in "${reply[@]}"
			do
				ZERO="${${(M)fname:#/*}:-$local_dir/$dirname/$fname}" 
				(( ${+ICE[silent]} )) && {
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					} 2> /dev/null >&2
					(( retval += $? ))
					((1))
				} || {
					((1))
					{
						[[ -n $precm ]] && {
							builtin ${precm[@]} 'source "$ZERO"'
							((1))
						} || {
							((1))
							builtin source "$ZERO"
						}
					}
					(( retval += $? ))
				}
			done
		}
		reply=(${(on)ZINIT_EXTS[(I)z-annex hook:\!atload-<-> <->]}) 
		for key in "${reply[@]}"
		do
			arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
			"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atload
		done
		if [[ -n ${ICE[wrap]} ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			.zinit-wrap-functions "$save_url" "" "$id_as"
		fi
		[[ ${ICE[atload][1]} = "!" ]] && {
			.zinit-add-report "$id_as" "Note: Starting to track the atload'!…' ice…"
			ZERO="$local_dir/$dirname/-atload-" 
			local ___oldcd="$PWD" 
			(( ${+ICE[nocd]} == 0 )) && {
				() {
					setopt localoptions noautopushd
					builtin cd -q "$local_dir/$dirname"
				} && builtin eval "${ICE[atload]#\!}"
				((1))
			} || eval "${ICE[atload]#\!}"
			() {
				setopt localoptions noautopushd
				builtin cd -q "$___oldcd"
			}
		}
		[[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
			(( -- ZINIT[TMP_SUBST] == 0 )) && {
				ZINIT[TMP_SUBST]=inactive 
				builtin setopt noaliases
				(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
				(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
			}
		}
	elif [[ ${ICE[as]} = completion ]]
	then
		((1))
	fi
	(( ${+ICE[atload]} )) && [[ ${ICE[atload][1]} != "!" ]] && {
		ZERO="$local_dir/$dirname/-atload-" 
		local ___oldcd="$PWD" 
		(( ${+ICE[nocd]} == 0 )) && {
			() {
				setopt localoptions noautopushd
				builtin cd -q "$local_dir/$dirname"
			} && builtin eval "${ICE[atload]}"
			((1))
		} || eval "${ICE[atload]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldcd"
		}
	}
	reply=(${(on)ZINIT_EXTS[(I)z-annex hook:atload-<-> <->]}) 
	for key in "${reply[@]}"
	do
		arr=("${(Q)${(z@)ZINIT_EXTS[$key]}[@]}") 
		"${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" atload
	done
	(( ${+ICE[notify]} == 1 )) && {
		[[ $retval -eq 0 || -n ${(M)ICE[notify]#\!} ]] && {
			local msg
			eval "msg=\"${ICE[notify]#\!}\""
			+zinit-deploy-message @msg "$msg"
		} || +zinit-deploy-message @msg "notify: Plugin not loaded / loaded with problem, the return code: $retval"
	}
	(( ${+ICE[reset-prompt]} == 1 )) && +zinit-deploy-message @rst
	ZINIT[CUR_USPL2]= 
	ZINIT[TIME_INDEX]=$(( ${ZINIT[TIME_INDEX]:-0} + 1 )) 
	ZINIT[TIME_${ZINIT[TIME_INDEX]}_${id_as}]=$SECONDS 
	ZINIT[AT_TIME_${ZINIT[TIME_INDEX]}_${id_as}]=$EPOCHREALTIME 
	.zinit-set-m-func unset
	return retval
}
.zinit-main-message-formatter () {
	if [[ -z $1 && -z $2 && -z $3 ]]
	then
		REPLY="" 
		return
	fi
	local append influx in_prepend
	if [[ $2 == (b|u|it|st|nb|nu|nit|nst) ]]
	then
		append=$ZINIT[col-$2] 
	elif [[ $2 == (…|ndsh|mdsh|mmdsh|-…|lr|) || -z $2 || -z $ZINIT[col-$2] ]]
	then
		if [[ $ZINIT[__last-formatter-code] != (…|ndsh|mdsh|mmdsh|-…|lr|rst|nl|) ]]
		then
			in_prepend=$ZINIT[col-$ZINIT[__last-formatter-code]] 
			influx=$ZINIT[col-$ZINIT[__last-formatter-code]] 
		fi
	else
		append=$ZINIT[col-rst] 
	fi
	REPLY=$in_prepend${ZINIT[col-$2]:-$1}$influx$3$append 
	local nl=$'\n' vertical=$'\013' carriager=$'\015' 
	REPLY=${REPLY//$nl/$vertical$carriager} 
}
.zinit-pack-ice () {
	ZINIT_SICE[$1${1:+${2:+/}}$2]+="${(j: :)${(qkv)ICE[@]}} " 
	ZINIT_SICE[$1${1:+${2:+/}}$2]="${ZINIT_SICE[$1${1:+${2:+/}}$2]# }" 
	return 0
}
.zinit-parse-opts () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	reply=("${(@)${@[2,-1]//([  $'\t']##|(#s))(#b)(${(~j.|.)${(@s.|.)___opt_map[$1]}})(#B)([  $'\t']##|(#e))/${OPTS[${___opt_map[${match[1]}]%%:*}]::=1}ß←↓→}:#1ß←↓→}") 
}
.zinit-prepare-home () {
	[[ -n ${ZINIT[HOME_READY]} ]] && return
	ZINIT[HOME_READY]=1 
	[[ ! -d ${ZINIT[HOME_DIR]} ]] && {
		command mkdir -p "${ZINIT[HOME_DIR]}"
		command chmod go-w "${ZINIT[HOME_DIR]}"
		command mkdir -p "${ZPFX:-ZINIT[HOME_DIR]/polaris}/bin"
	}
	[[ ! -d ${ZINIT[PLUGINS_DIR]}/_local---zinit ]] && {
		command rm -rf "${ZINIT[PLUGINS_DIR]:-${TMPDIR:-/tmp}/132bcaCAB}/_local---zplugin"
		command mkdir -p "${ZINIT[PLUGINS_DIR]}/_local---zinit"
		command chmod go-w "${ZINIT[PLUGINS_DIR]}"
		command ln -s "${ZINIT[BIN_DIR]}/_zinit" "${ZINIT[PLUGINS_DIR]}/_local---zinit"
		command mkdir -p "${ZPFX:-ZINIT[HOME_DIR]/polaris}/bin"
		(( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		(( ${+functions[.zinit-confirm]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
		.zinit-clear-completions &> /dev/null
		.zinit-compinit &> /dev/null
	}
	[[ ! -d ${ZINIT[COMPLETIONS_DIR]} ]] && {
		command mkdir "${ZINIT[COMPLETIONS_DIR]}"
		command chmod go-w "${ZINIT[COMPLETIONS_DIR]}"
		command ln -s "${ZINIT[PLUGINS_DIR]}/_local---zinit/_zinit" "${ZINIT[COMPLETIONS_DIR]}"
		command mkdir -p "${ZPFX:-ZINIT[HOME_DIR]/polaris}/bin"
		(( ${+functions[.zinit-setup-plugin-dir]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
		.zinit-compinit &> /dev/null
	}
	[[ ! -d ${ZINIT[SNIPPETS_DIR]} ]] && {
		command mkdir -p "${ZINIT[SNIPPETS_DIR]}/OMZ::plugins"
		command chmod go-w "${ZINIT[SNIPPETS_DIR]}"
		(
			builtin cd ${ZINIT[SNIPPETS_DIR]}
			command ln -s OMZ::plugins plugins
		)
		command mkdir -p "${ZINIT[SERVICES_DIR]}"
		command chmod go-w "${ZINIT[SERVICES_DIR]}"
		command mkdir -p "${ZPFX:-ZINIT[HOME_DIR]/polaris}/bin"
	}
	[[ ! -d ${~ZINIT[MAN_DIR]}/man9 ]] && {
		command mkdir -p ${~ZINIT[MAN_DIR]}/man{1..9} 2> /dev/null
	}
	[[ ! -f $ZINIT[MAN_DIR]/man1/zinit.1 || $ZINIT[MAN_DIR]/man1/zinit.1 -ot $ZINIT[BIN_DIR]/doc/zinit.1 ]] && {
		command mkdir -p $ZINIT[MAN_DIR]/man1
		command cp -f $ZINIT[BIN_DIR]/doc/zinit.1 $ZINIT[MAN_DIR]/man1
	}
}
.zinit-register-plugin () {
	local uspl2="$1" mode="$2" teleid="$3" 
	integer ret=0 
	if [[ -z ${ZINIT_REGISTERED_PLUGINS[(r)$uspl2]} ]]
	then
		ZINIT_REGISTERED_PLUGINS+=("$uspl2") 
	else
		[[ -z ${ZINIT[TEST]}${${+ICE[wait]}:#0}${ICE[load]}${ICE[subscribe]} && ${ZINIT[MUTE_WARNINGS]} != (1|true|on|yes) ]] && +zi-log "{u-warn}Warning{b-warn}:{rst} plugin {apo}\`{pid}${uspl2}{apo}\`{rst} already registered, will overwrite-load."
		ret=1 
	fi
	zsh_loaded_plugins+=("$teleid") 
	[[ $mode == light ]] && ZINIT[STATES__$uspl2]=1  || ZINIT[STATES__$uspl2]=2 
	ZINIT_REPORTS[$uspl2]= ZINIT_CUR_BIND_MAP=(empty 1) 
	ZINIT[FUNCTIONS_BEFORE__$uspl2]= ZINIT[FUNCTIONS_AFTER__$uspl2]= 
	ZINIT[FUNCTIONS__$uspl2]= 
	ZINIT[ZSTYLES__$uspl2]= ZINIT[BINDKEYS__$uspl2]= 
	ZINIT[ALIASES__$uspl2]= 
	ZINIT[WIDGETS_SAVED__$uspl2]= ZINIT[WIDGETS_DELETE__$uspl2]= 
	ZINIT[OPTIONS__$uspl2]= ZINIT[PATH__$uspl2]= 
	ZINIT[OPTIONS_BEFORE__$uspl2]= ZINIT[OPTIONS_AFTER__$uspl2]= 
	ZINIT[FPATH__$uspl2]= 
	return ret
}
.zinit-run () {
	if [[ $1 = (-l|--last) ]]
	then
		{
			set -- "${ZINIT[last-run-plugin]:-$(<${ZINIT[BIN_DIR]}/last-run-object.txt)}" "${@[2-correct,-1]}"
		} &> /dev/null
		[[ -z $1 ]] && {
			+zi-log "{u-warn}Error{b-warn}:{rst} No recent plugin-ID saved on the disk yet, please specify" "it as the first argument, i.e.{ehi}: {cmd}zi run {pid}usr/plg{slight} {…}the code to run{…} "
			return 1
		}
	else
		integer ___nolast=1 
	fi
	.zinit-any-to-user-plugin "$1" ""
	local ___id_as="$1" ___user="${reply[-2]}" ___plugin="${reply[-1]}" ___oldpwd="$PWD" 
	() {
		builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
		builtin cd -q ${${${(M)___user:#%}:+$___plugin}:-${ZINIT[PLUGINS_DIR]}/${___id_as//\//---}} &> /dev/null || {
			.zinit-get-object-path snippet "$___id_as"
			builtin cd -q $REPLY &> /dev/null
		}
	}
	if (( $? == 0 ))
	then
		(( ___nolast )) && {
			builtin print -r "$1" >| ${ZINIT[BIN_DIR]}/last-run-object.txt
		}
		ZINIT[last-run-plugin]="$1" 
		eval "${@[2-correct,-1]}"
		() {
			setopt localoptions noautopushd
			builtin cd -q "$___oldpwd"
		}
	else
		+zi-log "{u-warn}Error{b-warn}:{rst} no such plugin or snippet."
	fi
}
.zinit-run-task () {
	local ___pass="$1" ___t="$2" ___tpe="$3" ___idx="$4" ___mode="$5" ___id="${(Q)6}" ___opt="${(Q)7}" ___action ___s=1 ___retval=0 
	local -A ICE ZINIT_ICE
	ICE=("${(@Q)${(z@)ZINIT[WAIT_ICE_${___idx}]}}") 
	ZINIT_ICE=("${(kv)ICE[@]}") 
	local ___id_as=${ICE[id-as]:-$___id} 
	if [[ $___pass = 1 && ${${ICE[wait]#\!}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)} = <-> ]]
	then
		___action="${(M)ICE[wait]#\!}load" 
	elif [[ $___pass = 1 && -n ${ICE[wait]#\!} ]] && {
			eval "${ICE[wait]#\!}" || [[ $(( ___s=0 )) = 1 ]]
		}
	then
		___action="${(M)ICE[wait]#\!}load" 
	elif [[ -n ${ICE[load]#\!} && -n $(( ___s=0 )) && $___pass = 3 && -z ${ZINIT_REGISTERED_PLUGINS[(r)$___id_as]} ]] && eval "${ICE[load]#\!}"
	then
		___action="${(M)ICE[load]#\!}load" 
	elif [[ -n ${ICE[unload]#\!} && -n $(( ___s=0 )) && $___pass = 2 && -n ${ZINIT_REGISTERED_PLUGINS[(r)$___id_as]} ]] && eval "${ICE[unload]#\!}"
	then
		___action="${(M)ICE[unload]#\!}remove" 
	elif [[ -n ${ICE[subscribe]#\!} && -n $(( ___s=0 )) && $___pass = 3 ]] && {
			local -a fts_arr
			eval "fts_arr=( ${ICE[subscribe]}(DNms-$(( EPOCHSECONDS -
                 ZINIT[fts-${ICE[subscribe]}] ))) ); (( \${#fts_arr} ))" && {
				ZINIT[fts-${ICE[subscribe]}]="$EPOCHSECONDS" 
				___s=${+ICE[once]} 
			} || (( 0 ))
		}
	then
		___action="${(M)ICE[subscribe]#\!}load" 
	fi
	if [[ $___action = *load ]]
	then
		if [[ $___tpe = p* ]]
		then
			.zinit-load "${(@)=___id}" "" "$___mode" ${___tpe#p}
			(( ___retval += $? ))
		elif [[ $___tpe = s* ]]
		then
			.zinit-load-snippet $___opt "$___id" "" ${___tpe#s}
			(( ___retval += $? ))
		fi
		if [[ $___tpe = p1 || $___tpe = s1 ]]
		then
			(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
			zpty -b "${___id//\//:} / ${ICE[service]}" '.zinit-service '"${(M)___tpe#?}"' "$___mode" "$___id"'
		fi
		(( ${+ICE[silent]} == 0 && ${+ICE[lucid]} == 0 && ___retval == 0 )) && zle && zle -M "Loaded $___id"
	elif [[ $___action = *remove ]]
	then
		(( ${+functions[.zinit-confirm]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
		[[ $___tpe = p ]] && .zinit-unload "$___id_as" "" -q
		(( ${+ICE[silent]} == 0 && ${+ICE[lucid]} == 0 && ___retval == 0 )) && zle && zle -M "Unloaded $___id_as"
	fi
	[[ ${REPLY::=$___action} = \!* ]] && zle && zle .reset-prompt
	return ___s
}
.zinit-set-m-func () {
	if [[ $1 == set ]]
	then
		ZINIT[___m_bkp]="${functions[m]}" 
		setopt noaliases
		functions[m]="${functions[+zi-log]}" 
		setopt aliases
	elif [[ $1 == unset ]]
	then
		if [[ -n ${ZINIT[___m_bkp]} ]]
		then
			setopt noaliases
			functions[m]="${ZINIT[___m_bkp]}" 
			setopt aliases
		else
			noglob unset functions[m]
		fi
	else
		+zi-log "{error}ERROR #1"
		return 1
	fi
}
.zinit-setup-params () {
	builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
	reply=(${(@)${(@s.;.)ICE[param]}/(#m)*/${${MATCH%%(-\>|→|=\>)*}//((#s)[[:space:]]##|[[:space:]]##(#e))}${${(M)MATCH#*(-\>|→|=\>)}:+\=${${MATCH#*(-\>|→|=\>)}//((#s)[[:space:]]##|[[:space:]]##(#e))}}}) 
	(( ${#reply} )) && return 0 || return 1
}
.zinit-submit-turbo () {
	local tpe="$1" mode="$2" opt_uspl2="$3" opt_plugin="$4" 
	ICE[wait]="${ICE[wait]%%.[0-9]##}" 
	ZINIT[WAIT_IDX]=$(( ${ZINIT[WAIT_IDX]:-0} + 1 )) 
	ZINIT[WAIT_ICE_${ZINIT[WAIT_IDX]}]="${(j: :)${(qkv)ICE[@]}}" 
	ZINIT[fts-${ICE[subscribe]}]="${ICE[subscribe]:+$EPOCHSECONDS}" 
	[[ $tpe = s* ]] && local id="${${opt_plugin:+$opt_plugin}:-$opt_uspl2}"  || local id="${${opt_plugin:+$opt_uspl2${${opt_uspl2:#%*}:+/}$opt_plugin}:-$opt_uspl2}" 
	if [[ ${${ICE[wait]}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)} = (\!|.|)<-> ]]
	then
		ZINIT_TASKS+=("$EPOCHSECONDS+${${ICE[wait]#(\!|.)}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)}+${${${(M)ICE[wait]%a}:+1}:-${${${(M)ICE[wait]%b}:+2}:-${${${(M)ICE[wait]%c}:+3}:-1}}} $tpe ${ZINIT[WAIT_IDX]} ${mode:-_} ${(q)id} ${opt_plugin:+${(q)opt_uspl2}}") 
	elif [[ -n ${ICE[wait]}${ICE[load]}${ICE[unload]}${ICE[subscribe]} ]]
	then
		ZINIT_TASKS+=("${${ICE[wait]:+0}:-1}+0+1 $tpe ${ZINIT[WAIT_IDX]} ${mode:-_} ${(q)id} ${opt_plugin:+${(q)opt_uspl2}}") 
	fi
}
.zinit-tmp-subst-off () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset noaliases
	local mode="$1" 
	[[ ${ZINIT[TMP_SUBST]} = inactive || ${ZINIT[TMP_SUBST]} != $mode ]] && return 0
	ZINIT[TMP_SUBST]=inactive 
	if [[ $mode != compdef ]]
	then
		(( ${+ZINIT[bkp-autoload]} )) && functions[autoload]="${ZINIT[bkp-autoload]}"  || unfunction autoload
	fi
	(( ${+ZINIT[bkp-compdef]} )) && functions[compdef]="${ZINIT[bkp-compdef]}"  || unfunction compdef
	(( ${+ZINIT[bkp-source]} )) && functions[source]="${ZINIT[bkp-source]}"  || unfunction source 2> /dev/null
	(( ${+ZINIT[bkp-.]} )) && functions[.]="${ZINIT[bkp-.]}"  || unfunction . 2> /dev/null
	[[ ( $mode = light && ${+ICE[trackbinds]} -eq 0 ) || $mode = compdef ]] && return 0
	(( ${+ZINIT[bkp-bindkey]} )) && functions[bindkey]="${ZINIT[bkp-bindkey]}"  || unfunction bindkey
	[[ $mode = light-b || ( $mode = light && ${+ICE[trackbinds]} -eq 1 ) ]] && return 0
	(( ${+ZINIT[bkp-zstyle]} )) && functions[zstyle]="${ZINIT[bkp-zstyle]}"  || unfunction zstyle
	(( ${+ZINIT[bkp-alias]} )) && functions[alias]="${ZINIT[bkp-alias]}"  || unfunction alias
	(( ${+ZINIT[bkp-zle]} )) && functions[zle]="${ZINIT[bkp-zle]}"  || unfunction zle
	return 0
}
.zinit-tmp-subst-on () {
	local mode="$1" 
	[[ ${ZINIT[TMP_SUBST]} != inactive ]] && builtin return 0
	ZINIT[TMP_SUBST]="$mode" 
	builtin unset "ZINIT[bkp-autoload]" "ZINIT[bkp-compdef]"
	if [[ $mode != compdef ]]
	then
		(( ${+functions[autoload]} )) && ZINIT[bkp-autoload]="${functions[autoload]}" 
		functions[autoload]=':zinit-tmp-subst-autoload "$@";' 
	fi
	(( ${+functions[compdef]} )) && ZINIT[bkp-compdef]="${functions[compdef]}" 
	functions[compdef]=':zinit-tmp-subst-compdef "$@";' 
	if [[ -n ${ICE[subst]} ]]
	then
		(( ${+functions[source]} )) && ZINIT[bkp-source]="${functions[source]}" 
		(( ${+functions[.]} )) && ZINIT[bkp-.]="${functions[.]}" 
		(( ${+functions[.zinit-service]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
		functions[source]=':zinit-tmp-subst-source "$@";' 
		functions[.]=':zinit-tmp-subst-source "$@";' 
	fi
	[[ ( $mode = light && ${+ICE[trackbinds]} -eq 0 ) || $mode = compdef ]] && return 0
	builtin unset "ZINIT[bkp-bindkey]" "ZINIT[bkp-zstyle]" "ZINIT[bkp-alias]" "ZINIT[bkp-zle]"
	(( ${+functions[bindkey]} )) && ZINIT[bkp-bindkey]="${functions[bindkey]}" 
	functions[bindkey]=':zinit-tmp-subst-bindkey "$@";' 
	[[ $mode = light-b || ( $mode = light && ${+ICE[trackbinds]} -eq 1 ) ]] && return 0
	(( ${+functions[zstyle]} )) && ZINIT[bkp-zstyle]="${functions[zstyle]}" 
	functions[zstyle]=':zinit-tmp-subst-zstyle "$@";' 
	(( ${+functions[alias]} )) && ZINIT[bkp-alias]="${functions[alias]}" 
	functions[alias]=':zinit-tmp-subst-alias "$@";' 
	(( ${+functions[zle]} )) && ZINIT[bkp-zle]="${functions[zle]}" 
	functions[zle]=':zinit-tmp-subst-zle "$@";' 
	builtin return 0
}
.zinit-util-shands-path () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+REPLY}:#0}:+warncreateglobal}
	local -A map
	map=(\~ %HOME $HOME %HOME $ZINIT[SNIPPETS_DIR] %SNIPPETS $ZINIT[PLUGINS_DIR] %PLUGINS "$ZPFX" %ZPFX HOME %HOME SNIPPETS %SNIPPETS PLUGINS %PLUGINS "" "") 
	REPLY=${${1/(#b)(#s)(%|)(${(~j:|:)${(@k)map:#$HOME}}|$HOME|)/$map[$match[2]]}} 
	return 0
}
:zinit-reload-and-run () {
	local fpath_prefix="$1" autoload_opts="$2" func="$3" 
	shift 3
	unfunction -- "$func"
	local -a ___fpath
	___fpath=(${fpath[@]}) 
	local -a +h fpath
	[[ $FPATH != *${${(@0)fpath_prefix}[1]}* ]] && fpath=(${(@0)fpath_prefix} ${___fpath[@]}) 
	builtin autoload ${(s: :)autoload_opts} -- "$func"
	"$func" "$@"
}
:zinit-tmp-subst-alias () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Alias $*"
	typeset -a pos
	pos=("$@") 
	local -a opts
	zparseopts -a opts -D ${(s::):-gs}
	local a quoted tmp
	for a in "$@"
	do
		local aname="${a%%[=]*}" 
		local avalue="${a#*=}" 
		(( ${+aliases[$aname]} )) && .zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: redefining alias \`${aname}', previous value: ${aliases[$aname]}"
		local bname=${(q)aliases[$aname]} 
		aname="${(q)aname}" 
		if (( ${+opts[(r)-s]} ))
		then
			tmp=-s 
			tmp="${(q)tmp}" 
			quoted="$aname $bname $tmp" 
		elif (( ${+opts[(r)-g]} ))
		then
			tmp=-g 
			tmp="${(q)tmp}" 
			quoted="$aname $bname $tmp" 
		else
			quoted="$aname $bname" 
		fi
		quoted="${(q)quoted}" 
		[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[ALIASES__${ZINIT[CUR_USPL2]}]+="$quoted " 
		[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[ALIASES___dtrace/_dtrace]+="$quoted " 
	done
	builtin alias "${pos[@]}"
	return $?
}
:zinit-tmp-subst-autoload () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob warncreateglobal typesetsilent rcquotes
	local -a opts opts2 custom reply
	local func
	zparseopts -D -E -M -a opts ${(s::):-RTUXdkmrtWzwC} I+=opts2 S+:=custom
	builtin set -- ${@:#--}
	.zinit-any-to-user-plugin $ZINIT[CUR_USPL2]
	[[ $reply[1] = % ]] && local PLUGIN_DIR="$reply[2]"  || local PLUGIN_DIR="$ZINIT[PLUGINS_DIR]/${reply[1]:+$reply[1]---}${reply[2]//\//---}" 
	local -a fpath_elements
	fpath_elements=(${fpath[(r)$PLUGIN_DIR/*]}) 
	[[ -d $PLUGIN_DIR/functions ]] && fpath_elements+=("$PLUGIN_DIR"/functions) 
	if (( ${+opts[(r)-X]} ))
	then
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: Failed autoload ${(j: :)opts[@]} $*"
		+zi-log -u2 "{error}builtin autoload required for {obj}${(j: :)opts[@]}{error} option(s)"
		return 1
	fi
	if (( ${+opts[(r)-w]} ))
	then
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "-w-Autoload ${(j: :)opts[@]} ${(j: :)@}"
		fpath+=($PLUGIN_DIR) 
		builtin autoload ${opts[@]} "$@"
		return $?
	fi
	if [[ -n ${(M)@:#+X} ]]
	then
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Autoload +X ${opts:+${(j: :)opts[@]} }${(j: :)${@:#+X}}"
		local +h FPATH=$PLUGINS_DIR${fpath_elements:+:${(j.:.)fpath_elements[@]}}:$FPATH 
		local +h -a fpath
		fpath=($PLUGIN_DIR $fpath_elements $fpath) 
		builtin autoload +X ${opts[@]} "${@:#+X}"
		return $?
	fi
	for func
	do
		.zinit-add-report "${ZINIT[CUR_USPL2]}" "Autoload $func${opts:+ with options ${(j: :)opts[@]}}"
	done
	integer count retval
	for func
	do
		if (( ${+functions[$func]} != 1 ))
		then
			builtin setopt noaliases
			if [[ $func == /* ]] && is-at-least 5.4
			then
				builtin autoload ${opts[@]} $func
				return $?
			elif [[ $func == /* ]]
			then
				if [[ $ZINIT[MUTE_WARNINGS] != (1|true|on|yes) && -z $ZINIT[WARN_SHOWN_FOR_$ZINIT[CUR_USPL2]] ]]
				then
					+zi-log "{u-warn}Warning{b-warn}: {rst}the plugin {pid}$ZINIT[CUR_USPL2]" "{rst}is using autoload functions specified by their absolute path," "which is not supported by this Zsh version ({↔} {version}$ZSH_VERSION{rst}," "required is Zsh >= {version}5.4{rst})." "{nl}A fallback mechanism has been applied, which works well only" "for functions in the plugin {u}{slight}main{rst} directory." "{nl}(To mute this message, set" "{var}\$ZINIT[MUTE_WARNINGS]{rst} to a truth value.)"
					ZINIT[WARN_SHOWN_FOR_$ZINIT[CUR_USPL2]]=1 
				fi
				func=$func:t 
			fi
			if [[ ${ZINIT[NEW_AUTOLOAD]} = 2 ]]
			then
				builtin autoload ${opts[@]} "$PLUGIN_DIR/$func"
				retval=$? 
			elif [[ ${ZINIT[NEW_AUTOLOAD]} = 1 ]]
			then
				if (( ${+opts[(r)-C]} ))
				then
					local pth nl=$'\n' sel="" 
					for pth in $PLUGIN_DIR $fpath_elements $fpath
					do
						[[ -f $pth/$func ]] && {
							sel=$pth 
							break
						}
					done
					if [[ -z $sel ]]
					then
						+zi-log '{u-warn}zinit{b-warn}:{error} Couldn''t find autoload function{ehi}:' "{apo}\`{file}${func}{apo}\`{error} anywhere in {var}\$fpath{error}."
						retval=1 
					else
						eval "function ${(q)${custom[++count*2]}:-$func} {
                            local body=\"\$(<${(qqq)sel}/${(qqq)func})\" body2
                            () { setopt localoptions extendedglob
                                 body2=\"\${body##[[:space:]]#${func}[[:blank:]]#\(\)[[:space:]]#\{}\"
                                 [[ \$body2 != \$body ]] &&                                     body2=\"\${body2%\}[[:space:]]#([$nl]#([[:blank:]]#\#[^$nl]#((#e)|[$nl]))#)#}\"
                            }

                            functions[${${(q)custom[count*2]}:-$func}]=\"\$body2\"
                            ${(q)${custom[count*2]}:-$func} \"\$@\"
                        }"
						retval=$? 
					fi
				else
					functions[$func]="
                        local -a fpath
                        fpath=( ${(qqq)PLUGIN_DIR} ${(qqq@)fpath_elements} ${(qqq@)fpath} )
                        builtin autoload -X ${(j: :)${(q-)opts[@]}}
                    " 
					retval=$? 
				fi
			else
				eval "function ${(q)func} {
                    :zinit-reload-and-run ${(qqq)PLUGIN_DIR}"$'\0'"${(pj,\0,)${(qqq)fpath_elements[@]}} ${(qq)opts[*]} ${(q)func} "'"$@"
                }'
				retval=$? 
			fi
			(( ZINIT[ALIASES_OPT] )) && builtin setopt aliases
		fi
		if (( ${+opts2[(r)-I]} ))
		then
			${custom[count*2]:-$func}
			retval=$? 
		fi
	done
	return $retval
}
:zinit-tmp-subst-bindkey () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob warncreateglobal typesetsilent noshortloops
	is-at-least 5.3 && .zinit-add-report "${ZINIT[CUR_USPL2]}" "Bindkey ${(j: :)${(q+)@}}" || .zinit-add-report "${ZINIT[CUR_USPL2]}" "Bindkey ${(j: :)${(q)@}}"
	typeset -a pos
	pos=("$@") 
	local -A opts
	zparseopts -A opts -D ${(s::):-lLdDAmrsevaR} M: N:
	if (( ${#opts} == 0 ||
        ( ${#opts} == 1 && ${+opts[-M]} ) ||
        ( ${#opts} == 1 && ${+opts[-R]} ) ||
        ( ${#opts} == 1 && ${+opts[-s]} ) ||
        ( ${#opts} <= 2 && ${+opts[-M]} && ${+opts[-s]} ) ||
        ( ${#opts} <= 2 && ${+opts[-M]} && ${+opts[-R]} )
    ))
	then
		local string="${(q)1}" widget="${(q)2}" 
		local quoted
		if [[ -n ${ICE[bindmap]} && ${ZINIT_CUR_BIND_MAP[empty]} -eq 1 ]]
		then
			local -a pairs
			pairs=("${(@s,;,)ICE[bindmap]}") 
			if [[ -n ${(M)pairs:#*\\(#e)} ]]
			then
				local prev
				pairs=(${pairs[@]//(#b)((*)\\(#e)|(*))/${match[3]:+${prev:+$prev\;}}${match[3]}${${prev::=${match[2]:+${prev:+$prev\;}}${match[2]}}:+}}) 
			fi
			pairs=("${(@)${(@)${(@s:->:)pairs}##[[:space:]]##}%%[[:space:]]##}") 
			ZINIT_CUR_BIND_MAP=(empty 0) 
			(( ${#pairs} > 1 && ${#pairs[@]} % 2 == 0 )) && ZINIT_CUR_BIND_MAP+=("${pairs[@]}") 
		fi
		local bmap_val="${ZINIT_CUR_BIND_MAP[${1}]}" 
		if (( !ZINIT_CUR_BIND_MAP[empty] ))
		then
			[[ -z $bmap_val ]] && bmap_val="${ZINIT_CUR_BIND_MAP[${(qqq)1}]}" 
			[[ -z $bmap_val ]] && bmap_val="${ZINIT_CUR_BIND_MAP[${(qqq)${(Q)1}}]}" 
			[[ -z $bmap_val ]] && {
				bmap_val="${ZINIT_CUR_BIND_MAP[!${(qqq)1}]}" 
				integer val=1 
			}
			[[ -z $bmap_val ]] && bmap_val="${ZINIT_CUR_BIND_MAP[!${(qqq)${(Q)1}}]}" 
		fi
		if [[ -n $bmap_val ]]
		then
			string="${(q)bmap_val}" 
			if (( val ))
			then
				[[ ${pos[1]} = "-M" ]] && pos[4]="$bmap_val"  || pos[2]="$bmap_val" 
			else
				[[ ${pos[1]} = "-M" ]] && pos[3]="${(Q)bmap_val}"  || pos[1]="${(Q)bmap_val}" 
			fi
			.zinit-add-report "${ZINIT[CUR_USPL2]}" ":::Bindkey: combination <$1> changed to <$bmap_val>${${(M)bmap_val:#hold}:+, i.e. ${ZINIT[col-error]}unmapped${ZINIT[col-rst]}}"
			((1))
		elif [[ ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[UPAR]}} && -n ${${ZINIT[UPAR]}[(r);:${(q)1};:]} ) || ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[DOWNAR]}} && -n ${${ZINIT[DOWNAR]}[(r);:${(q)1};:]} ) || ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[RIGHTAR]}} && -n ${${ZINIT[RIGHTAR]}[(r);:${(q)1};:]} ) || ( -n ${bmap_val::=${ZINIT_CUR_BIND_MAP[LEFTAR]}} && -n ${${ZINIT[LEFTAR]}[(r);:${(q)1};:]} ) ]]
		then
			string="${(q)bmap_val}" 
			if (( val ))
			then
				[[ ${pos[1]} = "-M" ]] && pos[4]="$bmap_val"  || pos[2]="$bmap_val" 
			else
				[[ ${pos[1]} = "-M" ]] && pos[3]="${(Q)bmap_val}"  || pos[1]="${(Q)bmap_val}" 
			fi
			.zinit-add-report "${ZINIT[CUR_USPL2]}" ":::Bindkey: combination <$1> recognized as cursor-key and changed to <${bmap_val}>${${(M)bmap_val:#hold}:+, i.e. ${ZINIT[col-error]}unmapped${ZINIT[col-rst]}}"
		fi
		[[ $bmap_val = hold ]] && return 0
		local prev="${(q)${(s: :)$(builtin bindkey ${(Q)string})}[-1]#undefined-key}" 
		if (( ${+opts[-M]} ))
		then
			local Mopt=-M 
			local Marg="${opts[-M]}" 
			Mopt="${(q)Mopt}" 
			Marg="${(q)Marg}" 
			quoted="$string $widget $prev $Mopt $Marg" 
		else
			quoted="$string $widget $prev" 
		fi
		if (( ${+opts[-R]} ))
		then
			local Ropt=-R 
			Ropt="${(q)Ropt}" 
			if (( ${+opts[-M]} ))
			then
				quoted="$quoted $Ropt" 
			else
				local space=_ 
				space="${(q)space}" 
				quoted="$quoted $space $space $Ropt" 
			fi
		fi
		quoted="${(q)quoted}" 
		[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[BINDKEYS__${ZINIT[CUR_USPL2]}]+="$quoted " 
		[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[BINDKEYS___dtrace/_dtrace]+="$quoted " 
	else
		if [[ ${#opts} -eq 1 && ${+opts[-A]} = 1 && ${#pos} = 3 && ${pos[-1]} = main && ${pos[-2]} != -A ]]
		then
			(( ZINIT[BINDKEY_MAIN_IDX] = ${ZINIT[BINDKEY_MAIN_IDX]:-0} + 1 ))
			local pname="${ZINIT[CUR_PLUGIN]:-_dtrace}" 
			local name="${(q)pname}-main-${ZINIT[BINDKEY_MAIN_IDX]}" 
			builtin bindkey -N "$name" main
			local keys=_ widget=_ prev= optA=-A mapname="${name}" optR=_ 
			local quoted="${(q)keys} ${(q)widget} ${(q)prev} ${(q)optA} ${(q)mapname} ${(q)optR}" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[BINDKEYS__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[BINDKEYS___dtrace/_dtrace]+="$quoted " 
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: keymap \`main' copied to \`${name}' because of \`${pos[-2]}' substitution"
		elif [[ ${#opts} -eq 1 && ${+opts[-N]} = 1 ]]
		then
			local Nopt=-N 
			local Narg="${opts[-N]}" 
			local keys=_ widget=_ prev= optN=-N mapname="${Narg}" optR=_ 
			local quoted="${(q)keys} ${(q)widget} ${(q)prev} ${(q)optN} ${(q)mapname} ${(q)optR}" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[BINDKEYS__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[BINDKEYS___dtrace/_dtrace]+="$quoted " 
		else
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: last bindkey used non-typical options: ${(kv)opts[*]}"
		fi
	fi
	builtin bindkey "${pos[@]}"
	return $?
}
:zinit-tmp-subst-compdef () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Saving \`compdef $*' for replay"
	ZINIT_COMPDEF_REPLAY+=("${(j: :)${(q)@}}") 
	return 0
}
:zinit-tmp-subst-zle () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Zle $*"
	typeset -a pos
	pos=("$@") 
	builtin set -- "${@:#--}"
	if [[ ( $1 = -N && ( $# = 2 || $# = 3 ) ) || ( $1 = -C && $# = 4 ) ]]
	then
		if [[ ${ZINIT_ZLE_HOOKS_LIST[$2]} = 1 ]]
		then
			local quoted="$2" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[WIDGETS_DELETE__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[WIDGETS_DELETE___dtrace/_dtrace]+="$quoted " 
		elif (( ${+widgets[$2]} ))
		then
			local widname="$2" targetfun="${${${(M)1:#-C}:+$4}:-$3}" 
			local completion_widget="${${(M)1:#-C}:+$3}" 
			local saved_widcontents="${widgets[$widname]}" 
			widname="${(q)widname}" 
			completion_widget="${(q)completion_widget}" 
			targetfun="${(q)targetfun}" 
			saved_widcontents="${(q)saved_widcontents}" 
			local quoted="$1 $widname $completion_widget $targetfun $saved_widcontents" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[WIDGETS_SAVED__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[WIDGETS_SAVED___dtrace/_dtrace]+="$quoted " 
		else
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Note: a new widget created via zle -N: \`$2'"
			local quoted="$2" 
			quoted="${(q)quoted}" 
			[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[WIDGETS_DELETE__${ZINIT[CUR_USPL2]}]+="$quoted " 
			[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[WIDGETS_DELETE___dtrace/_dtrace]+="$quoted " 
		fi
	fi
	builtin zle "${pos[@]}"
	return $?
}
:zinit-tmp-subst-zstyle () {
	builtin setopt localoptions noerrreturn noerrexit extendedglob nowarncreateglobal typesetsilent noshortloops unset
	.zinit-add-report "${ZINIT[CUR_USPL2]}" "Zstyle $*"
	typeset -a pos
	pos=("$@") 
	local -a opts
	zparseopts -a opts -D ${(s::):-eLdgabsTtm}
	if [[ ${#opts} -eq 0 || ( ${#opts} -eq 1 && ${+opts[(r)-e]} = 1 ) ]]
	then
		local pattern="${(q)1}" style="${(q)2}" 
		local ps="$pattern $style" 
		ps="${(q)ps}" 
		[[ -n ${ZINIT[CUR_USPL2]} ]] && ZINIT[ZSTYLES__${ZINIT[CUR_USPL2]}]+="$ps " 
		[[ ${ZINIT[DTRACE]} = 1 ]] && ZINIT[ZSTYLES___dtrace/_dtrace]+=$ps 
	else
		if [[ ! ${#opts[@]} = 1 && ( ${+opts[(r)-s]} = 1 || ${+opts[(r)-b]} = 1 || ${+opts[(r)-a]} = 1 || ${+opts[(r)-t]} = 1 || ${+opts[(r)-T]} = 1 || ${+opts[(r)-m]} = 1 ) ]]
		then
			.zinit-add-report "${ZINIT[CUR_USPL2]}" "Warning: last zstyle used non-typical options: ${opts[*]}"
		fi
	fi
	builtin zstyle "${pos[@]}"
	return $?
}
@autoload () {
	:zinit-tmp-subst-autoload -Uz ${(s: :)${${(j: :)${@#\!}}//(#b)((*)(->|=>|→)(*)|(*))/${match[2]:+$match[2]       -S $match[4]}${match[5]:+${match[5]}       -S ${match[5]}}}} ${${${(@M)${@#\!}:#*(->|=>|→)*}}:+-C} ${${@#\!}:+-C}
}
@zinit-register-annex () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt nobanghist
	local name="$1" type="$2" handler="$3" helphandler="$4" icemods="$5" key="z-annex ${(q)2}" 
	ZINIT_EXTS[seqno]=$(( ${ZINIT_EXTS[seqno]:-0} + 1 )) 
	ZINIT_EXTS[$key${${(M)type#hook:}:+ ${ZINIT_EXTS[seqno]}}]="${ZINIT_EXTS[seqno]} z-annex-data: ${(q)name} ${(q)type} ${(q)handler} ${(q)helphandler} ${(q)icemods}" 
	() {
		builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
		builtin setopt nobanghist
		integer index="${type##[%a-zA-Z:_!-]##}" 
		ZINIT_EXTS[ice-mods]="${ZINIT_EXTS[ice-mods]}${icemods:+|}${(j:|:)${(@)${(@s:|:)icemods}/(#b)(#s)(?)/$index-$match[1]}}" 
	}
}
@zinit-register-hook () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob nobanghist noshortloops typesetsilent warncreateglobal
	local name="$1" type="$2" handler="$3" icemods="$4" key="zinit ${(q)2}" 
	ZINIT_EXTS2[seqno]=$(( ${ZINIT_EXTS2[seqno]:-0} + 1 )) 
	ZINIT_EXTS2[$key${${(M)type#hook:}:+ ${ZINIT_EXTS2[seqno]}}]="${ZINIT_EXTS2[seqno]} z-annex-data: ${(q)name} ${(q)type} ${(q)handler} '' ${(q)icemods}" 
	ZINIT_EXTS2[ice-mods]="${ZINIT_EXTS2[ice-mods]}${icemods:+|}$icemods" 
}
@zinit-scheduler () {
	integer ___ret="${${ZINIT[lro-data]%:*}##*:}" 
	[[ $1 = following ]] && sched +1 'ZINIT[lro-data]="$_:$?:${options[printexitvalue]}"; @zinit-scheduler following "${ZINIT[lro-data]%:*:*}"'
	[[ -n $1 && $1 != (following*|burst) ]] && {
		local THEFD="$1" 
		zle -F "$THEFD"
		exec {THEFD}<&-
	}
	[[ $1 = burst ]] && local -h EPOCHSECONDS=$(( EPOCHSECONDS+10000 )) 
	ZINIT[START_TIME]="${ZINIT[START_TIME]:-$EPOCHREALTIME}" 
	integer ___t=EPOCHSECONDS ___i correct 
	local -a match mbegin mend reply
	local MATCH REPLY AFD
	integer MBEGIN MEND
	[[ -o ksharrays ]] && correct=1 
	if [[ -n $1 ]]
	then
		if [[ ${#ZINIT_RUN} -le 1 || $1 = following ]]
		then
			() {
				builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
				builtin setopt extendedglob
				integer ___idx1 ___idx2
				local ___ar2 ___ar3 ___ar4 ___ar5
				for ((___idx1 = 0; ___idx1 <= 4; ___idx1 ++ )) do
					for ((___idx2 = 1; ___idx2 <= (___idx >= 4 ? 1 : 3); ___idx2 ++ )) do
						___i=2 
						ZINIT_TASKS=(${ZINIT_TASKS[@]/(#b)([0-9]##)+([0-9]##)+([1-3])(*)/${ZINIT_TASKS[
                        $(( (___ar2=${match[2]}+1) ? (
                            (___ar3=${(M)match[3]%[1-3]}) ? (
                            (___ar4=___idx1+1) ? (
                            (___ar5=___idx2) ? (
                (${match[1]}+${match[2]}) <= $___t ?
                zinit_scheduler_add(___i++) : ___i++ )
                            : 1 )
                            : 1 )
                            : 1 )
                            : 1  ))]}}) 
						ZINIT_TASKS=("<no-data>" ${ZINIT_TASKS[@]:#<no-data>}) 
					done
				done
			}
		fi
	else
		add-zsh-hook -d -- precmd @zinit-scheduler
		add-zsh-hook -- chpwd @zinit-scheduler
		() {
			builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
			builtin setopt extendedglob
			ZINIT_TASKS=(${ZINIT_TASKS[@]/(#b)([0-9]##)(*)/$(( ${match[1]} <= 1 ? ${match[1]} : ___t ))${match[2]}}) 
		}
		sched +1 'ZINIT[lro-data]="$_:$?:${options[printexitvalue]}"; @zinit-scheduler following ${ZINIT[lro-data]%:*:*}'
		AFD=13371337 
		exec {AFD}< <(LANG=C command sleep 0.002; builtin print run;)
		command true
		zle -F "$AFD" @zinit-scheduler
	fi
	local ___task ___idx=0 ___count=0 ___idx2 
	for ___task in "${ZINIT_RUN[@]}"
	do
		.zinit-run-task 1 "${(@z)___task}" && ZINIT_TASKS+=("$___task") 
		if [[ $(( ++___idx, ___count += ${${REPLY:+1}:-0} )) -gt 0 && $1 != burst ]]
		then
			AFD=13371337 
			exec {AFD}< <(LANG=C command sleep 0.0002; builtin print run;)
			command true
			zle -F "$AFD" @zinit-scheduler
			break
		fi
	done
	for ((___idx2=1; ___idx2 <= ___idx; ++ ___idx2 )) do
		.zinit-run-task 2 "${(@z)ZINIT_RUN[___idx2-correct]}"
	done
	for ((___idx2=1; ___idx2 <= ___idx; ++ ___idx2 )) do
		.zinit-run-task 3 "${(@z)ZINIT_RUN[___idx2-correct]}"
	done
	ZINIT_RUN[1-correct,___idx-correct]=() 
	[[ ${ZINIT[lro-data]##*:} = on ]] && return 0 || return ___ret
}
@zinit-substitute () {
	builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
	builtin setopt extendedglob warncreateglobal typesetsilent noshortloops
	local -A ___subst_map
	___subst_map=("%ID%" "${id_as_clean:-$id_as}" "%USER%" "$user" "%PLUGIN%" "${plugin:-$save_url}" "%URL%" "${save_url:-${user:+$user/}$plugin}" "%DIR%" "${local_path:-$local_dir${dirname:+/$dirname}}" '$ZPFX' "$ZPFX" '${ZPFX}' "$ZPFX" '%OS%' "${OSTYPE%(-gnu|[0-9]##)}" '%MACH%' "$MACHTYPE" '%CPU%' "$CPUTYPE" '%VENDOR%' "$VENDOR" '%HOST%' "$HOST" '%UID%' "$UID" '%GID%' "$GID") 
	if [[ -n ${ICE[param]} && ${ZINIT[SUBST_DONE_FOR]} != ${ICE[param]} ]]
	then
		ZINIT[SUBST_DONE_FOR]=${ICE[param]} 
		ZINIT[PARAM_SUBST]= 
		local -a ___params
		___params=(${(s.;.)ICE[param]}) 
		local ___param ___from ___to
		for ___param in ${___params[@]}
		do
			local ___from=${${___param%%([[:space:]]|)(->|→)*}##[[:space:]]##} ___to=${${___param#*(->|→)([[:space:]]|)}%[[:space:]]} 
			___from=${___from//((#s)[[:space:]]##|[[:space:]]##(#e))/} 
			___to=${___to//((#s)[[:space:]]##|[[:space:]]##(#e))/} 
			ZINIT[PARAM_SUBST]+="%${(q)___from}% ${(q)___to} " 
		done
	fi
	local -a ___add
	___add=("${ICE[param]:+${(@Q)${(@z)ZINIT[PARAM_SUBST]}}}") 
	(( ${#___add} % 2 == 0 )) && ___subst_map+=("${___add[@]}") 
	local ___var_name
	for ___var_name
	do
		local ___value=${(P)___var_name} 
		___value=${___value//(#m)(%[a-zA-Z0-9]##%|\$ZPFX|\$\{ZPFX\})/${___subst_map[$MATCH]}} 
		: ${(P)___var_name::=$___value}
	done
}
@zsh-plugin-run-on-unload () {
	ICE[ps-on-unload]="${(j.; .)@}" 
	.zinit-pack-ice "$id_as" ""
}
@zsh-plugin-run-on-update () {
	ICE[ps-on-update]="${(j.; .)@}" 
	.zinit-pack-ice "$id_as" ""
}
VCS_INFO_formats () {
	setopt localoptions noksharrays NO_shwordsplit
	local msg tmp
	local -i i
	local -A hook_com
	hook_com=(action "$1" action_orig "$1" branch "$2" branch_orig "$2" base "$3" base_orig "$3" staged "$4" staged_orig "$4" unstaged "$5" unstaged_orig "$5" revision "$6" revision_orig "$6" misc "$7" misc_orig "$7" vcs "${vcs}" vcs_orig "${vcs}") 
	hook_com[base-name]="${${hook_com[base]}:t}" 
	hook_com[base-name_orig]="${hook_com[base-name]}" 
	hook_com[subdir]="$(VCS_INFO_reposub ${hook_com[base]})" 
	hook_com[subdir_orig]="${hook_com[subdir]}" 
	: vcs_info-patch-9b9840f2-91e5-4471-af84-9e9a0dc68c1b
	for tmp in base base-name branch misc revision subdir
	do
		hook_com[$tmp]="${hook_com[$tmp]//\%/%%}" 
	done
	VCS_INFO_hook 'post-backend'
	if [[ -n ${hook_com[action]} ]]
	then
		zstyle -a ":vcs_info:${vcs}:${usercontext}:${rrn}" actionformats msgs
		(( ${#msgs} < 1 )) && msgs[1]=' (%s)-[%b|%a]%u%c-' 
	else
		zstyle -a ":vcs_info:${vcs}:${usercontext}:${rrn}" formats msgs
		(( ${#msgs} < 1 )) && msgs[1]=' (%s)-[%b]%u%c-' 
	fi
	if [[ -n ${hook_com[staged]} ]]
	then
		zstyle -s ":vcs_info:${vcs}:${usercontext}:${rrn}" stagedstr tmp
		[[ -z ${tmp} ]] && hook_com[staged]='S'  || hook_com[staged]=${tmp} 
	fi
	if [[ -n ${hook_com[unstaged]} ]]
	then
		zstyle -s ":vcs_info:${vcs}:${usercontext}:${rrn}" unstagedstr tmp
		[[ -z ${tmp} ]] && hook_com[unstaged]='U'  || hook_com[unstaged]=${tmp} 
	fi
	if [[ ${quiltmode} != 'standalone' ]] && VCS_INFO_hook "pre-addon-quilt"
	then
		local REPLY
		VCS_INFO_quilt addon
		hook_com[quilt]="${REPLY}" 
		unset REPLY
	elif [[ ${quiltmode} == 'standalone' ]]
	then
		hook_com[quilt]=${hook_com[misc]} 
	fi
	(( ${#msgs} > maxexports )) && msgs[$(( maxexports + 1 )),-1]=() 
	for i in {1..${#msgs}}
	do
		if VCS_INFO_hook "set-message" $(( $i - 1 )) "${msgs[$i]}"
		then
			zformat -f msg ${msgs[$i]} a:${hook_com[action]} b:${hook_com[branch]} c:${hook_com[staged]} i:${hook_com[revision]} m:${hook_com[misc]} r:${hook_com[base-name]} s:${hook_com[vcs]} u:${hook_com[unstaged]} Q:${hook_com[quilt]} R:${hook_com[base]} S:${hook_com[subdir]}
			msgs[$i]=${msg} 
		else
			msgs[$i]=${hook_com[message]} 
		fi
	done
	hook_com=() 
	backend_misc=() 
	return 0
}
_SUSEconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
__arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
__bun_dynamic_comp () {
	local comp="" 
	for arg in scripts
	do
		local line
		while read -r line
		do
			local name="$line" 
			local desc="$line" 
			name="${name%$'\t'*}" 
			desc="${desc/*$'\t'/}" 
			echo
		done <<< "$arg"
	done
	return $comp
}
__git_prompt_git () {
	GIT_OPTIONAL_LOCKS=0 command git "$@"
}
_a2ps () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_a2utils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_aap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_abcde () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_absolute_command_paths () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ack () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_acpi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_acpitool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_acroread () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_adb () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_add-zle-hook-widget () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_add-zsh-hook () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_alias () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_aliases () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_all_labels () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_all_matches () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_alsa-utils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_alternative () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_analyseplugin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ansible () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ant () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_antiword () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_apachectl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_apm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_approximate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_apt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_apt-file () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_apt-move () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_apt-show-versions () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_aptitude () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arch_archives () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arch_namespace () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arg_compile () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arping () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_arrays () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_asciidoctor () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_asciinema () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_assign () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_at () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_attr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_augeas () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_auto-apt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_autocd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_avahi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_awk () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_axi-cache () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_base64 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_basename () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_basenc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bash () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bash_complete () {
	local ret=1 
	local -a suf matches
	local -x COMP_POINT COMP_CWORD
	local -a COMP_WORDS COMPREPLY BASH_VERSINFO
	local -x COMP_LINE="$words" 
	local -A savejobstates savejobtexts
	(( COMP_POINT = 1 + ${#${(j. .)words[1,CURRENT-1]}} + $#QIPREFIX + $#IPREFIX + $#PREFIX ))
	(( COMP_CWORD = CURRENT - 1))
	COMP_WORDS=("${words[@]}") 
	BASH_VERSINFO=(2 05b 0 1 release) 
	savejobstates=(${(kv)jobstates}) 
	savejobtexts=(${(kv)jobtexts}) 
	[[ ${argv[${argv[(I)nospace]:-0}-1]} = -o ]] && suf=(-S '') 
	matches=(${(f)"$(compgen $@ -- ${words[CURRENT]})"}) 
	if [[ -n $matches ]]
	then
		if [[ ${argv[${argv[(I)filenames]:-0}-1]} = -o ]]
		then
			compset -P '*/' && matches=(${matches##*/}) 
			compset -S '/*' && matches=(${matches%%/*}) 
			compadd -f "${suf[@]}" -a matches && ret=0 
		else
			compadd "${suf[@]}" - "${(@)${(Q@)matches}:#*\ }" && ret=0 
			compadd -S ' ' - ${${(M)${(Q)matches}:#*\ }% } && ret=0 
		fi
	fi
	if (( ret ))
	then
		if [[ ${argv[${argv[(I)default]:-0}-1]} = -o ]]
		then
			_default "${suf[@]}" && ret=0 
		elif [[ ${argv[${argv[(I)dirnames]:-0}-1]} = -o ]]
		then
			_directories "${suf[@]}" && ret=0 
		fi
	fi
	return ret
}
_bash_completions () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_baudrates () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_baz () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_be_name () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_beadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_beep () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bibtex () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bind_addresses () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bindkey () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bison () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bittorrent () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bogofilter () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bpf_filters () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bpython () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bq_completer () {
	_completer "CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=1 bq help | grep '^[^ ][^ ]*  ' | sed 's/ .*//'" bq
}
_brace_parameter () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_brctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_brew () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_brew_services () {
	# undefined
	builtin autoload -XUz /usr/local/share/zsh/site-functions
}
_bsd_disks () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bsd_pkg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bsdconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bsdinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_btrfs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_buf () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_bug () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_builtin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bun () {
	zstyle ':completion:*:*:bun:*' group-name ''
	zstyle ':completion:*:*:bun-grouped:*' group-name ''
	zstyle ':completion:*:*:bun::descriptions' format '%F{green}-- %d --%f'
	zstyle ':completion:*:*:bun-grouped:*' format '%F{green}-- %d --%f'
	local program=bun 
	typeset -A opt_args
	local curcontext="$curcontext" state line context 
	_arguments -s '1: :->cmd' '*: :->args' && ret=0 
	case $state in
		(cmd) local -a scripts_list
			IFS=$'\n' scripts_list=($(SHELL=zsh bun getcompletes i)) 
			scripts="scripts:scripts:((${scripts_list//:/\\\\:}))" 
			IFS=$'\n' files_list=($(SHELL=zsh bun getcompletes j)) 
			main_commands=('run\:"Run JavaScript with Bun, a package.json script, or a bin" ' 'test\:"Run unit tests with Bun" ' 'x\:"Install and execute a package bin (bunx)" ' 'repl\:"Start a REPL session with Bun" ' 'init\:"Start an empty Bun project from a blank template" ' 'create\:"Create a new project from a template (bun c)" ' 'install\:"Install dependencies for a package.json (bun i)" ' 'add\:"Add a dependency to package.json (bun a)" ' 'remove\:"Remove a dependency from package.json (bun rm)" ' 'update\:"Update outdated dependencies & save to package.json" ' 'outdated\:"Display the latest versions of outdated dependencies" ' 'link\:"Link an npm package globally" ' 'unlink\:"Globally unlink an npm package" ' 'pm\:"More commands for managing packages" ' 'build\:"Bundle TypeScript & JavaScript into a single file" ' 'upgrade\:"Get the latest version of bun" ' 'help\:"Show all supported flags and commands" ') 
			main_commands=($main_commands) 
			_alternative "$scripts" "args:command:(($main_commands))" "files:files:(($files_list))" ;;
		(args) case $line[1] in
				(add | a) _bun_add_completion ;;
				(unlink) _bun_unlink_completion ;;
				(link) _bun_link_completion ;;
				(bun) _bun_bun_completion ;;
				(init) _bun_init_completion ;;
				(create | c) _bun_create_completion ;;
				(x) _arguments -s -C '1: :->cmd' '2: :->cmd2' '*: :->args' && ret=0  ;;
				(pm) _bun_pm_completion ;;
				(install | i) _bun_install_completion ;;
				(remove | rm) _bun_remove_completion ;;
				(run) _bun_run_completion ;;
				(upgrade) _bun_upgrade_completion ;;
				(build) _bun_build_completion ;;
				(update) _bun_update_completion ;;
				(outdated) _bun_outdated_completion ;;
				('test') _bun_test_completion ;;
				(help) _arguments -s -C '1: :->cmd' '2: :->cmd2' '*: :->args' && ret=0 
					case $state in
						(cmd2) curcontext="${curcontext%:*:*}:bun-grouped" 
							_alternative "args:command:(($main_commands))" ;;
						(args) case $line[2] in
								(add) _bun_add_completion ;;
								(unlink) _bun_unlink_completion ;;
								(link) _bun_link_completion ;;
								(bun) _bun_bun_completion ;;
								(init) _bun_init_completion ;;
								(create) _bun_create_completion ;;
								(x) _arguments -s -C '1: :->cmd' '2: :->cmd2' '*: :->args' && ret=0  ;;
								(pm) _bun_pm_completion ;;
								(install) _bun_install_completion ;;
								(remove) _bun_remove_completion ;;
								(run) _bun_run_completion ;;
								(upgrade) _bun_upgrade_completion ;;
								(build) _bun_build_completion ;;
								(update) _bun_update_completion ;;
								(outdated) _bun_outdated_completion ;;
								('test') _bun_test_completion ;;
							esac ;;
					esac ;;
			esac ;;
	esac
}
_bun_add_completion () {
	_arguments -s -C '1: :->cmd1' '*: :->package' '--config[Load config(bunfig.toml)]: :->config' '-c[Load config(bunfig.toml)]: :->config' '--yarn[Write a yarn.lock file (yarn v1)]' '-y[Write a yarn.lock file (yarn v1)]' '--production[Don'"'"'t install devDependencies]' '-p[Don'"'"'t install devDependencies]' '--no-save[Don'"'"'t save a lockfile]' '--save[Save to package.json]' '--dry-run[Don'"'"'t install anything]' '--frozen-lockfile[Disallow changes to lockfile]' '--force[Always request the latest versions from the registry & reinstall all dependencies]' '-f[Always request the latest versions from the registry & reinstall all dependencies]' '--cache-dir[Store & load cached data from a specific directory path]:cache-dir' '--no-cache[Ignore manifest cache entirely]' '--silent[Don'"'"'t log anything]' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--no-summary[Don'"'"'t print a summary]' '--no-verify[Skip verifying integrity of newly downloaded packages]' '--ignore-scripts[Skip lifecycle scripts in the package.json (dependency scripts are never run)]' '--global[Add a package globally]' '-g[Add a package globally]' '--cwd[Set a specific cwd]:cwd' '--backend[Platform-specific optimizations for installing dependencies]:backend:("copyfile" "hardlink" "symlink")' '--link-native-bins[Link "bin" from a matching platform-specific dependency instead. Default: esbuild, turbo]:link-native-bins' '--help[Print this help menu]' '--dev[Add dependence to "devDependencies]' '-d[Add dependence to "devDependencies]' '-D[]' '--development[]' '--optional[Add dependency to "optionalDependencies]' '--peer[Add dependency to "peerDependencies]' '--exact[Add the exact version instead of the ^range]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
		(package) _bun_add_param_package_completion ;;
	esac
}
_bun_add_param_package_completion () {
	IFS=$'\n' inexact=($(history -n bun | grep -E "^bun add " | cut -c 9- | uniq)) 
	IFS=$'\n' exact=($($inexact | grep -E "^$words[$CURRENT]")) 
	IFS=$'\n' packages=($(SHELL=zsh bun getcompletes a $words[$CURRENT])) 
	to_print=$inexact 
	if [ ! -z "$exact" -a "$exact" != " " ]
	then
		to_print=$exact 
	fi
	if [ ! -z "$to_print" -a "$to_print" != " " ]
	then
		if [ ! -z "$packages" -a "$packages" != " " ]
		then
			_describe -1 -t to_print 'History' to_print
			_describe -1 -t packages "Popular" packages
			return
		fi
		_describe -1 -t to_print 'History' to_print
		return
	fi
	if [ ! -z "$packages" -a "$packages" != " " ]
	then
		_describe -1 -t packages "Popular" packages
		return
	fi
}
_bun_build_completion () {
	_arguments -s -C '1: :->cmd' '*: :->file' '--outfile[Write the output to a specific file (default: stdout)]:outfile' '--outdir[Write the output to a directory (required for splitting)]:outdir' '--minify[Enable all minification flags]' '--minify-whitespace[Remove unneeded whitespace]' '--minify-syntax[Transform code to use less syntax]' '--minify-identifiers[Shorten variable names]' '--sourcemap[Generate sourcemaps]: :->sourcemap' '--target[The intended execution environment for the bundle. "browser", "bun" or "node"]: :->target' '--splitting[Whether to enable code splitting (requires --outdir)]' '--compile[generating a standalone binary from a TypeScript or JavaScript file]' '--format[Specifies the module format to be used in the generated bundles]: :->format' && ret=0 
	case $state in
		(file) _files ;;
		(target) _alternative 'args:cmd3:((browser bun node))' ;;
		(sourcemap) _alternative 'args:cmd3:((none external inline))' ;;
		(format) _alternative 'args:cmd3:((esm cjs iife))' ;;
	esac
}
_bun_bun_completion () {
	_arguments -s -C '1: :->cmd' '*: :->file' '--version[Show version and exit]' '-V[Show version and exit]' '--cwd[Change directory]:cwd' '--help[Show command help]' '-h[Show command help]' '--use[Use a framework, e.g. "next"]:use' && ret=0 
	case $state in
		(file) _files ;;
	esac
}
_bun_create_completion () {
	_arguments -s -C '1: :->cmd' '2: :->cmd2' '*: :->args' && ret=0 
	case $state in
		(cmd2) _alternative 'args:create:((next-app\:"Next.js app" react-app\:"React app"))' ;;
		(args) case $line[2] in
				(next) pmargs=('1: :->cmd' '2: :->cmd2' '3: :->file' '--force[Overwrite existing files]' '--no-install[Don'"'"'t install node_modules]' '--no-git[Don'"'"'t create a git repository]' '--verbose[verbose]' '--no-package-json[Disable package.json transforms]' '--open[On finish, start bun & open in-browser]') 
					_arguments -s -C $pmargs && ret=0 
					case $state in
						(file) _files ;;
					esac ;;
				(react) _arguments -s -C $pmargs && ret=0 
					case $state in
						(file) _files ;;
					esac ;;
				(*) _arguments -s -C $pmargs && ret=0 
					case $state in
						(file) _files ;;
					esac ;;
			esac ;;
	esac
}
_bun_init_completion () {
	_arguments -s -C '1: :->cmd' '-y[Answer yes to all prompts]:' '--yes[Answer yes to all prompts]:' && ret=0 
}
_bun_install_completion () {
	_arguments -s -C '1: :->cmd1' '--config[Load config(bunfig.toml)]: :->config' '-c[Load config(bunfig.toml)]: :->config' '--yarn[Write a yarn.lock file (yarn v1)]' '-y[Write a yarn.lock file (yarn v1)]' '--production[Don'"'"'t install devDependencies]' '-p[Don'"'"'t install devDependencies]' '--no-save[Don'"'"'t save a lockfile]' '--save[Save to package.json]' '--dry-run[Don'"'"'t install anything]' '--frozen-lockfile[Disallow changes to lockfile]' '--force[Always request the latest versions from the registry & reinstall all dependencies]' '-f[Always request the latest versions from the registry & reinstall all dependencies]' '--cache-dir[Store & load cached data from a specific directory path]:cache-dir' '--no-cache[Ignore manifest cache entirely]' '--silent[Don'"'"'t log anything]' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--no-summary[Don'"'"'t print a summary]' '--no-verify[Skip verifying integrity of newly downloaded packages]' '--ignore-scripts[Skip lifecycle scripts in the package.json (dependency scripts are never run)]' '--global[Add a package globally]' '-g[Add a package globally]' '--cwd[Set a specific cwd]:cwd' '--backend[Platform-specific optimizations for installing dependencies]:backend:("copyfile" "hardlink" "symlink")' '--link-native-bins[Link "bin" from a matching platform-specific dependency instead. Default: esbuild, turbo]:link-native-bins' '--help[Print this help menu]' '--dev[Add dependence to "devDependencies]' '-d[Add dependence to "devDependencies]' '--development[]' '-D[]' '--optional[Add dependency to "optionalDependencies]' '--peer[Add dependency to "peerDependencies]' '--exact[Add the exact version instead of the ^range]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
	esac
}
_bun_link_completion () {
	_arguments -s -C '1: :->cmd1' '*: :->package' '--config[Load config(bunfig.toml)]: :->config' '-c[Load config(bunfig.toml)]: :->config' '--yarn[Write a yarn.lock file (yarn v1)]' '-y[Write a yarn.lock file (yarn v1)]' '--production[Don'"'"'t install devDependencies]' '-p[Don'"'"'t install devDependencies]' '--no-save[Don'"'"'t save a lockfile]' '--save[Save to package.json]' '--dry-run[Don'"'"'t install anything]' '--frozen-lockfile[Disallow changes to lockfile]' '--force[Always request the latest versions from the registry & reinstall all dependencies]' '-f[Always request the latest versions from the registry & reinstall all dependencies]' '--cache-dir[Store & load cached data from a specific directory path]:cache-dir' '--no-cache[Ignore manifest cache entirely]' '--silent[Don'"'"'t log anything]' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--no-summary[Don'"'"'t print a summary]' '--no-verify[Skip verifying integrity of newly downloaded packages]' '--ignore-scripts[Skip lifecycle scripts in the package.json (dependency scripts are never run)]' '--global[Add a package globally]' '-g[Add a package globally]' '--cwd[Set a specific cwd]:cwd' '--backend[Platform-specific optimizations for installing dependencies]:backend:("copyfile" "hardlink" "symlink")' '--link-native-bins[Link "bin" from a matching platform-specific dependency instead. Default: esbuild, turbo]:link-native-bins' '--help[Print this help menu]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
		(package) _bun_link_param_package_completion ;;
	esac
}
_bun_link_param_package_completion () {
	install_env=$BUN_INSTALL 
	install_dir=${(P)install_env:-$HOME/.bun} 
	global_node_modules=$install_dir/install/global/node_modules 
	local -a packages_full_path=(${global_node_modules}/*(N)) 
	packages=$(echo $packages_full_path | tr ' ' '\n' | xargs  basename) 
	_alternative "dirs:directory:(($packages))"
}
_bun_list_bunfig_toml () {
	_files
}
_bun_outdated_completion () {
	_arguments -s -C '--cwd[Set a specific cwd]:cwd' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--help[Print this help menu]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
	esac
}
_bun_pm_completion () {
	_arguments -s -C '1: :->cmd' '2: :->cmd2' '*: :->args' && ret=0 
	case $state in
		(cmd2) sub_commands=('bin\:"print the path to bin folder" ' 'ls\:"list the dependency tree according to the current lockfile" ' 'hash\:"generate & print the hash of the current lockfile" ' 'hash-string\:"print the string used to hash the lockfile" ' 'hash-print\:"print the hash stored in the current lockfile" ' 'cache\:"print the path to the cache folder" ') 
			_alternative "args:cmd3:(($sub_commands))" ;;
		(args) case $line[2] in
				(cache) _arguments -s -C '1: :->cmd' '2: :->cmd2' ':::(rm)' && ret=0  ;;
				(bin) pmargs=("-g[print the global path to bin folder]") 
					_arguments -s -C '1: :->cmd' '2: :->cmd2' $pmargs && ret=0  ;;
				(ls) pmargs=("--all[list the entire dependency tree according to the current lockfile]") 
					_arguments -s -C '1: :->cmd' '2: :->cmd2' $pmargs && ret=0  ;;
			esac ;;
	esac
}
_bun_remove_completion () {
	_arguments -s -C '1: :->cmd1' '*: :->package' '--config[Load config(bunfig.toml)]: :->config' '-c[Load config(bunfig.toml)]: :->config' '--yarn[Write a yarn.lock file (yarn v1)]' '-y[Write a yarn.lock file (yarn v1)]' '--production[Don'"'"'t install devDependencies]' '-p[Don'"'"'t install devDependencies]' '--no-save[Don'"'"'t save a lockfile]' '--save[Save to package.json]' '--dry-run[Don'"'"'t install anything]' '--frozen-lockfile[Disallow changes to lockfile]' '--force[Always request the latest versions from the registry & reinstall all dependencies]' '-f[Always request the latest versions from the registry & reinstall all dependencies]' '--cache-dir[Store & load cached data from a specific directory path]:cache-dir' '--no-cache[Ignore manifest cache entirely]' '--silent[Don'"'"'t log anything]' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--no-summary[Don'"'"'t print a summary]' '--no-verify[Skip verifying integrity of newly downloaded packages]' '--ignore-scripts[Skip lifecycle scripts in the package.json (dependency scripts are never run)]' '--global[Add a package globally]' '-g[Add a package globally]' '--cwd[Set a specific cwd]:cwd' '--backend[Platform-specific optimizations for installing dependencies]:backend:("copyfile" "hardlink" "symlink")' '--link-native-bins[Link "bin" from a matching platform-specific dependency instead. Default: esbuild, turbo]:link-native-bins' '--help[Print this help menu]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
		(package) _bun_remove_param_package_completion ;;
	esac
}
_bun_remove_param_package_completion () {
	if ! command -v jq &> /dev/null
	then
		return
	fi
	if [ -f "package.json" ]
	then
		local dependencies=$(jq -r '.dependencies | keys[]' package.json) 
		local dev_dependencies=$(jq -r '.devDependencies | keys[]' package.json) 
		_alternative "deps:dependency:(($dependencies))"
		_alternative "deps:dependency:(($dev_dependencies))"
	fi
}
_bun_run_completion () {
	_arguments -s -C '1: :->cmd' '2: :->script' '*: :->other' '--help[Display this help and exit]' '-h[Display this help and exit]' '--bun[Force a script or package to use Bun'"'"'s runtime instead of Node.js (via symlinking node)]' '-b[Force a script or package to use Bun'"'"'s runtime instead of Node.js (via symlinking node)]' '--cwd[Absolute path to resolve files & entry points from. This just changes the process cwd]:cwd' '--config[Config file to load bun from (e.g. -c bunfig.toml]: :->config' '-c[Config file to load bun from (e.g. -c bunfig.toml]: :->config' '--env-file[Load environment variables from the specified file(s)]:env-file' '--extension-order[Defaults to: .tsx,.ts,.jsx,.js,.json]:extension-order' '--jsx-factory[Changes the function called when compiling JSX elements using the classic JSX runtime]:jsx-factory' '--jsx-fragment[Changes the function called when compiling JSX fragments]:jsx-fragment' '--jsx-import-source[Declares the module specifier to be used for importing the jsx and jsxs factory functions. Default: "react"]:jsx-import-source' '--jsx-runtime["automatic" (default) or "classic"]: :->jsx-runtime' '--preload[Import a module before other modules are loaded]:preload' '-r[Import a module before other modules are loaded]:preload' '--main-fields[Main fields to lookup in package.json. Defaults to --target dependent]:main-fields' '--no-summary[Don'"'"'t print a summary]' '--version[Print version and exit]' '-v[Print version and exit]' '--revision[Print version with revision and exit]' '--tsconfig-override[Load tsconfig from path instead of cwd/tsconfig.json]:tsconfig-override' '--define[Substitute K:V while parsing, e.g. --define process.env.NODE_ENV:"development". Values are parsed as JSON.]:define' '-d[Substitute K:V while parsing, e.g. --define process.env.NODE_ENV:"development". Values are parsed as JSON.]:define' '--external[Exclude module from transpilation (can use * wildcards). ex: -e react]:external' '-e[Exclude module from transpilation (can use * wildcards). ex: -e react]:external' '--loader[Parse files with .ext:loader, e.g. --loader .js:jsx. Valid loaders: js, jsx, ts, tsx, json, toml, text, file, wasm, napi]:loader' '--packages[Exclude dependencies from bundle, e.g. --packages external. Valid options: bundle, external]:packages' '-l[Parse files with .ext:loader, e.g. --loader .js:jsx. Valid loaders: js, jsx, ts, tsx, json, toml, text, file, wasm, napi]:loader' '--origin[Rewrite import URLs to start with --origin. Default: ""]:origin' '-u[Rewrite import URLs to start with --origin. Default: ""]:origin' '--port[Port to serve bun'"'"'s dev server on. Default: '"'"'3000'"'"']:port' '-p[Port to serve bun'"'"'s dev server on. Default: '"'"'3000'"'"']:port' '--smol[Use less memory, but run garbage collection more often]' '--minify[Minify (experimental)]' '--minify-syntax[Minify syntax and inline data (experimental)]' '--minify-whitespace[Minify Whitespace (experimental)]' '--minify-identifiers[Minify identifiers]' '--no-macros[Disable macros from being executed in the bundler, transpiler and runtime]' '--target[The intended execution environment for the bundle. "browser", "bun" or "node"]: :->target' '--inspect[Activate Bun'"'"'s Debugger]:inspect' '--inspect-wait[Activate Bun'"'"'s Debugger, wait for a connection before executing]:inspect-wait' '--inspect-brk[Activate Bun'"'"'s Debugger, set breakpoint on first line of code and wait]:inspect-brk' '--hot[Enable auto reload in bun'"'"'s JavaScript runtime]' '--watch[Automatically restart bun'"'"'s JavaScript runtime on file change]' '--no-install[Disable auto install in bun'"'"'s JavaScript runtime]' '--install[Install dependencies automatically when no node_modules are present, default: "auto". "force" to ignore node_modules, fallback to install any missing]: :->install_' '-i[Automatically install dependencies and use global cache in bun'"'"'s runtime, equivalent to --install=fallback'] '--prefer-offline[Skip staleness checks for packages in bun'"'"'s JavaScript runtime and resolve from disk]' '--prefer-latest[Use the latest matching versions of packages in bun'"'"'s JavaScript runtime, always checking npm]' '--silent[Don'"'"'t repeat the command for bun run]' '--dump-environment-variables[Dump environment variables from .env and process as JSON and quit. Useful for debugging]' '--dump-limits[Dump system limits. Userful for debugging]' && ret=0 
	case $state in
		(script) curcontext="${curcontext%:*:*}:bun-grouped" 
			_bun_run_param_script_completion ;;
		(jsx-runtime) _alternative 'args:cmd3:((classic automatic))' ;;
		(target) _alternative 'args:cmd3:((browser bun node))' ;;
		(install_) _alternative 'args:cmd3:((auto force fallback))' ;;
		(other) _files ;;
	esac
}
_bun_run_param_script_completion () {
	local -a scripts_list
	IFS=$'\n' scripts_list=($(SHELL=zsh bun getcompletes s)) 
	IFS=$'\n' bins=($(SHELL=zsh bun getcompletes b)) 
	_alternative "scripts:scripts:((${scripts_list//:/\\\\:}))"
	_alternative "bin:bin:((${bins//:/\\\\:}))"
	_alternative "files:file:_files -g '*.(js|ts|jsx|tsx|wasm)'"
}
_bun_test_completion () {
	_arguments -s -C '1: :->cmd1' '*: :->file' '-h[Display this help and exit]' '--help[Display this help and exit]' '-b[Force a script or package to use Bun.js instead of Node.js (via symlinking node)]' '--bun[Force a script or package to use Bun.js instead of Node.js (via symlinking node)]' '--cwd[Set a specific cwd]:cwd' '-c[Load config(bunfig.toml)]: :->config' '--config[Load config(bunfig.toml)]: :->config' '--env-file[Load environment variables from the specified file(s)]:env-file' '--extension-order[Defaults to: .tsx,.ts,.jsx,.js,.json]:extension-order' '--jsx-factory[Changes the function called when compiling JSX elements using the classic JSX runtime]:jsx-factory' '--jsx-fragment[Changes the function called when compiling JSX fragments]:jsx-fragment' '--jsx-import-source[Declares the module specifier to be used for importing the jsx and jsxs factory functions. Default: "react"]:jsx-import-source' '--jsx-runtime["automatic" (default) or "classic"]: :->jsx-runtime' '--preload[Import a module before other modules are loaded]:preload' '-r[Import a module before other modules are loaded]:preload' '--main-fields[Main fields to lookup in package.json. Defaults to --target dependent]:main-fields' '--no-summary[Don'"'"'t print a summary]' '--version[Print version and exit]' '-v[Print version and exit]' '--revision[Print version with revision and exit]' '--tsconfig-override[Load tsconfig from path instead of cwd/tsconfig.json]:tsconfig-override' '--define[Substitute K:V while parsing, e.g. --define process.env.NODE_ENV:"development". Values are parsed as JSON.]:define' '-d[Substitute K:V while parsing, e.g. --define process.env.NODE_ENV:"development". Values are parsed as JSON.]:define' '--external[Exclude module from transpilation (can use * wildcards). ex: -e react]:external' '-e[Exclude module from transpilation (can use * wildcards). ex: -e react]:external' '--loader[Parse files with .ext:loader, e.g. --loader .js:jsx. Valid loaders: js, jsx, ts, tsx, json, toml, text, file, wasm, napi]:loader' '-l[Parse files with .ext:loader, e.g. --loader .js:jsx. Valid loaders: js, jsx, ts, tsx, json, toml, text, file, wasm, napi]:loader' '--origin[Rewrite import URLs to start with --origin. Default: ""]:origin' '-u[Rewrite import URLs to start with --origin. Default: ""]:origin' '--port[Port to serve bun'"'"'s dev server on. Default: '"'"'3000'"'"']:port' '-p[Port to serve bun'"'"'s dev server on. Default: '"'"'3000'"'"']:port' '--smol[Use less memory, but run garbage collection more often]' '--minify[Minify (experimental)]' '--minify-syntax[Minify syntax and inline data (experimental)]' '--minify-identifiers[Minify identifiers]' '--no-macros[Disable macros from being executed in the bundler, transpiler and runtime]' '--target[The intended execution environment for the bundle. "browser", "bun" or "node"]: :->target' '--inspect[Activate Bun'"'"'s Debugger]:inspect' '--inspect-wait[Activate Bun'"'"'s Debugger, wait for a connection before executing]:inspect-wait' '--inspect-brk[Activate Bun'"'"'s Debugger, set breakpoint on first line of code and wait]:inspect-brk' '--watch[Automatically restart bun'"'"'s JavaScript runtime on file change]' '--timeout[Set the per-test timeout in milliseconds, default is 5000.]:timeout' '--update-snapshots[Update snapshot files]' '--rerun-each[Re-run each test file <NUMBER> times, helps catch certain bugs]:rerun' '--only[Only run tests that are marked with "test.only()"]' '--todo[Include tests that are marked with "test.todo()"]' '--coverage[Generate a coverage profile]' '--bail[Exit the test suite after <NUMBER> failures. If you do not specify a number, it defaults to 1.]:bail' '--test-name-pattern[Run only tests with a name that matches the given regex]:pattern' '-t[Run only tests with a name that matches the given regex]:pattern' && ret=0 
	case $state in
		(file) _bun_test_param_script_completion ;;
		(config) _files ;;
	esac
}
_bun_test_param_script_completion () {
	local -a scripts_list
	_alternative "files:file:_files -g '*(_|.)(test|spec).(js|ts|jsx|tsx)'"
}
_bun_unlink_completion () {
	_arguments -s -C '1: :->cmd1' '*: :->package' '--config[Load config(bunfig.toml)]: :->config' '-c[Load config(bunfig.toml)]: :->config' '--yarn[Write a yarn.lock file (yarn v1)]' '-y[Write a yarn.lock file (yarn v1)]' '--production[Don'"'"'t install devDependencies]' '-p[Don'"'"'t install devDependencies]' '--no-save[Don'"'"'t save a lockfile]' '--save[Save to package.json]' '--dry-run[Don'"'"'t install anything]' '--frozen-lockfile[Disallow changes to lockfile]' '--force[Always request the latest versions from the registry & reinstall all dependencies]' '-f[Always request the latest versions from the registry & reinstall all dependencies]' '--cache-dir[Store & load cached data from a specific directory path]:cache-dir' '--no-cache[Ignore manifest cache entirely]' '--silent[Don'"'"'t log anything]' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--no-summary[Don'"'"'t print a summary]' '--no-verify[Skip verifying integrity of newly downloaded packages]' '--ignore-scripts[Skip lifecycle scripts in the package.json (dependency scripts are never run)]' '--global[Add a package globally]' '-g[Add a package globally]' '--cwd[Set a specific cwd]:cwd' '--backend[Platform-specific optimizations for installing dependencies]:backend:("copyfile" "hardlink" "symlink")' '--link-native-bins[Link "bin" from a matching platform-specific dependency instead. Default: esbuild, turbo]:link-native-bins' '--help[Print this help menu]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
		(package)  ;;
	esac
}
_bun_update_completion () {
	_arguments -s -C '1: :->cmd1' '-c[Load config(bunfig.toml)]: :->config' '--config[Load config(bunfig.toml)]: :->config' '-y[Write a yarn.lock file (yarn v1)]' '--yarn[Write a yarn.lock file (yarn v1)]' '-p[Don'"'"'t install devDependencies]' '--production[Don'"'"'t install devDependencies]' '--no-save[Don'"'"'t save a lockfile]' '--save[Save to package.json]' '--dry-run[Don'"'"'t install anything]' '--frozen-lockfile[Disallow changes to lockfile]' '-f[Always request the latest versions from the registry & reinstall all dependencies]' '--force[Always request the latest versions from the registry & reinstall all dependencies]' '--cache-dir[Store & load cached data from a specific directory path]:cache-dir' '--no-cache[Ignore manifest cache entirely]' '--silent[Don'"'"'t log anything]' '--verbose[Excessively verbose logging]' '--no-progress[Disable the progress bar]' '--no-summary[Don'"'"'t print a summary]' '--no-verify[Skip verifying integrity of newly downloaded packages]' '--ignore-scripts[Skip lifecycle scripts in the package.json (dependency scripts are never run)]' '-g[Add a package globally]' '--global[Add a package globally]' '--cwd[Set a specific cwd]:cwd' '--backend[Platform-specific optimizations for installing dependencies]:backend:("copyfile" "hardlink" "symlink")' '--link-native-bins[Link "bin" from a matching platform-specific dependency instead. Default: esbuild, turbo]:link-native-bins' '--help[Print this help menu]' && ret=0 
	case $state in
		(config) _bun_list_bunfig_toml ;;
	esac
}
_bun_upgrade_completion () {
	_arguments -s -C '1: :->cmd' '--canary[Upgrade to canary build]' && ret=0 
}
_bzip2 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_bzr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cabal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cache_invalid () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_caffeinate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_calendar () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_call_function () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_call_program () {
	local -xi COLUMNS=999 
	local curcontext="${curcontext}" tmp err_fd=-1 clocale='_comp_locale;' 
	local -a prefix
	if [[ "$1" = -p ]]
	then
		shift
		if (( $#_comp_priv_prefix ))
		then
			curcontext="${curcontext%:*}/${${(@M)_comp_priv_prefix:#^*[^\\]=*}[1]}:" 
			zstyle -t ":completion:${curcontext}:${1}" gain-privileges && prefix=($_comp_priv_prefix) 
		fi
	elif [[ "$1" = -l ]]
	then
		shift
		clocale='' 
	fi
	if (( ${debug_fd:--1} > 2 )) || [[ ! -t 2 ]]
	then
		exec {err_fd}>&2
	else
		exec {err_fd}> /dev/null
	fi
	{
		if zstyle -s ":completion:${curcontext}:${1}" command tmp
		then
			if [[ "$tmp" = -* ]]
			then
				eval $clocale "$tmp[2,-1]" "$argv[2,-1]"
			else
				eval $clocale $prefix "$tmp"
			fi
		else
			eval $clocale $prefix "$argv[2,-1]"
		fi 2>&$err_fd
	} always {
		exec {err_fd}>&-
	}
}
_canonical_paths () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_capabilities () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_carthage () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_cat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ccal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cdbs-edit-patch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cdcd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cdr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cdrdao () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cdrecord () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chattr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chcon () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chflags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chkconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chmod () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_choom () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chown () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chroot () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chrt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_chsh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cksum () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_clay () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cmdambivalent () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cmdstring () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cmp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_code () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_column () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_combination () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_comm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_command () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_command_names () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_comp_locale () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_compadd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_compdef () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_complete () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_complete_debug () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_complete_help () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_complete_help_generic () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_complete_tag () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_completer () {
	command=$1 
	name=$2 
	eval '[[ -n "$'"${name}"'_COMMANDS" ]] || '"${name}"'_COMMANDS="$('"${command}"')"'
	set -- $COMP_LINE
	shift
	while [[ $1 == -* ]]
	do
		shift
	done
	[[ -n "$2" ]] && return
	grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -q "${name}\s*$" <<< $COMP_LINE && eval 'COMPREPLY=($'"${name}"'_COMMANDS)' && return
	[[ "$COMP_LINE" == *" " ]] && return
	[[ -n "$1" ]] && eval 'COMPREPLY=($(echo "$'"${name}"'_COMMANDS" | grep ^'"$1"'))'
}
_completers () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_composer () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_compress () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_condition () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_configure () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_coreadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_correct () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_correct_filename () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_correct_word () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cowsay () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cpio () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cplay () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cpupower () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_crontab () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cryptsetup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cscope () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_csplit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cssh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_csup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ctags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ctags_tags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cu () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_curl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cut () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cvs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cvsup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cygcheck () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cygpath () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cygrunsrv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cygserver () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_cygstart () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dak () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_darcs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_date () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_date_formats () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dates () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dbus () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dchroot () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dchroot-dsa () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dconf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dcop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dcut () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_deb_architectures () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_deb_codenames () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_deb_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_deb_packages () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debbugs_bugnumber () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debchange () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debcheckout () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debdiff () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debfoster () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_deborphan () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debsign () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debsnap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_debuild () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_default () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_defaults () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_delimiters () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_deno () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_describe () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_description () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_devtodo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_df () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dhclient () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dhcpinfo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dict () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dict_words () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_diff () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_diff3 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_diff_options () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_diffstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dir_list () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_directories () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_directory_stack () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dirs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_disable () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dispatch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_django () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dkms () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dladm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dlocate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dmesg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dmidecode () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dnf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dns_types () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_doas () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_docker () {
	# undefined
	builtin autoload -XUz /Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh
}
_domains () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dos2unix () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dpatch-edit-patch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dpkg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dpkg-buildpackage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dpkg-cross () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dpkg-repack () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dpkg_source () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dput () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_drill () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dropbox () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dscverify () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dsh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dtrace () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dtruss () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_du () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dumpadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dumper () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dupload () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dvi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_dynamic_directory_name () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_e2label () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ecasound () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_echotc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_echoti () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ed () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_elfdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_elinks () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_email_addresses () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_emulate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_enable () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_enscript () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_entr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_env () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_eog () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_equal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_espeak () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_etags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ethtool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_evince () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_exec () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_expand () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_expand_alias () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_expand_word () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_extensions () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_external_pwds () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fakeroot () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fbsd_architectures () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fbsd_device_types () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_feh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fetch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fetchmail () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ffmpeg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_figlet () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_file_descriptors () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_file_flags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_file_modes () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_file_systems () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_find () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_find_net_interfaces () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_findmnt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_finger () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fink () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_first () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_flac () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_flex () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_floppy () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_flowadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fmadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fmt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fold () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fortune () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_free () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_freebsd-update () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_freespace () {
	local -a disks
	disks=("${(@f)"$(df | awk '/^\/dev\/disk/{ printf $1 ":"; for (i=9; i<=NF; i++) printf $i FS; print "" }')"}") 
	_describe disks disks
}
_fs_usage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fsh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_functions () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fuse_arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fuse_values () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fuser () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fusermount () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_fw_update () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gcc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gcore () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gdb () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_geany () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gem () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_generic () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_genisoimage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_getclip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_getconf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_getent () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_getfacl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_getmail () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_getopt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gh () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_ghostscript () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_git () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_git-buildpackage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_git-lfs () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_git_log_prettily () {
	if ! [ -z $1 ]
	then
		git log --pretty=$1
	fi
}
_global () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_global_tags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_globflags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_globqual_delims () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_globquals () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gnome-gv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gnu_generic () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gnupod () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gnutls () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_go () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gpasswd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gpg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gphoto2 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gprof () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gqview () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gradle () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_graphicsmagick () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_grep () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_grep-excuses () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_groff () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_groups () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_growisofs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gsettings () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_guard () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_guilt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_gzip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_hash () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_have_glob_qual () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_hdiutil () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_head () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_helm () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_hexdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_history () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_history_complete_word () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_history_modifiers () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_host () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_hostname () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_hosts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_htop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_hugo () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_hwinfo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_iconv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_iconvconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_id () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ifconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_iftop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ignored () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_imagemagick () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_in_vared () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_inetadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_init_d () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_initctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_install () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_invoke-rc.d () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ionice () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_iostat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ipadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ipfw () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ipsec () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ipset () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_iptables () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_irssi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ispell () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_iwconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_j () {
	# undefined
	builtin autoload -XUz /Users/yangeok/.autojump/functions
}
_jail () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jails () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_java () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_java_class () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jenv_export_hook () {
	export JAVA_HOME=$(jenv javahome) 
	export JENV_FORCEJAVAHOME=true 
	if [ -e "$JAVA_HOME/bin/javac" ]
	then
		export JDK_HOME="$JAVA_HOME" 
		export JENV_FORCEJDKHOME=true 
	fi
}
_jexec () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jls () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jobs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jobs_bg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jobs_builtin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jobs_fg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_joe () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_join () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jot () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_jq () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_k9s () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_k_bsd_to_ansi () {
	local foreground=$1 background=$2 foreground_ansi background_ansi 
	case $foreground in
		(a) foreground_ansi=30  ;;
		(b) foreground_ansi=31  ;;
		(c) foreground_ansi=32  ;;
		(d) foreground_ansi=33  ;;
		(e) foreground_ansi=34  ;;
		(f) foreground_ansi=35  ;;
		(g) foreground_ansi=36  ;;
		(h) foreground_ansi=37  ;;
		(x) foreground_ansi=0  ;;
	esac
	case $background in
		(a) background_ansi=40  ;;
		(b) background_ansi=41  ;;
		(c) background_ansi=42  ;;
		(d) background_ansi=43  ;;
		(e) background_ansi=44  ;;
		(f) background_ansi=45  ;;
		(g) background_ansi=46  ;;
		(h) background_ansi=47  ;;
		(x) background_ansi=0  ;;
	esac
	printf "%s;%s" $background_ansi $foreground_ansi
}
_kdeconnect () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_kdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_kfmclient () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_kill () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_killall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_kld () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_knock () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_kpartx () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ktrace () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ktrace_points () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_kubectl () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_kvno () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_last () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ld_debug () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ldap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ldconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ldd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_less () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lha () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_libvirt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lighttpd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_limit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_limits () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_links () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lintian () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_list () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_list_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lldb () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ln () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_loadkeys () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_locale () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_localedef () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_locales () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_locate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_logger () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_logical_volumes () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_login_classes () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_look () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_losetup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ls () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsattr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsblk () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lscfg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsdev () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lslv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsns () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsof () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lspv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsusb () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lsvg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ltrace () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lua () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_luarocks () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lynx () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lz4 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_lzop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mac_applications () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mac_files_for_application () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_madison () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mail () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mailboxes () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_main_complete () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_make () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_make-kpkg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_man () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mat2 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_match () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_math () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_math_params () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_matlab () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_md5sum () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mdadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mdfind () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mdls () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mdutil () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_members () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mencal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_menu () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mere () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mergechanges () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_message () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mii-tool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mime_types () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_minikube () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_mixerctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mkdir () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mkfifo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mknod () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mkshortcut () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mktemp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mkzsh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_module () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_module-assistant () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_module_math_func () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_modutils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mondo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_monotone () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_moosic () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mosh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_most_recent_file () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mount () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mozilla () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mpc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mplayer () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mtools () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mtr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_multi_parts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mupdf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_music () {
	local app_name
	case "$words[1]" in
		(itunes) app_name="iTunes"  ;;
		(music | *) app_name="Music"  ;;
	esac
	local -a cmds subcmds
	cmds=("launch:Launch the ${app_name} app" "play:Play ${app_name}" "pause:Pause ${app_name}" "stop:Stop ${app_name}" "rewind:Rewind ${app_name}" "resume:Resume ${app_name}" "quit:Quit ${app_name}" "mute:Mute the ${app_name} app" "unmute:Unmute the ${app_name} app" "next:Skip to the next song" "previous:Skip to the previous song" "vol:Change the volume" "playlist:Play a specific playlist" {playing,status}":Show what song is currently playing" {shuf,shuff,shuffle}":Set shuffle mode" {-h,--help}":Show usage") 
	if (( CURRENT == 2 ))
	then
		_describe 'command' cmds
	elif (( CURRENT == 3 ))
	then
		case "$words[2]" in
			(vol) subcmds=('up:Raise the volume' 'down:Lower the volume') 
				_describe 'command' subcmds ;;
			(shuf | shuff | shuffle) subcmds=('on:Switch on shuffle mode' 'off:Switch off shuffle mode' 'toggle:Toggle shuffle mode (default)') 
				_describe 'command' subcmds ;;
		esac
	elif (( CURRENT == 4 ))
	then
		case "$words[2]" in
			(playlist) subcmds=('play:Play the playlist (default)' 'stop:Stop the playlist') 
				_describe 'command' subcmds ;;
		esac
	fi
	return 0
}
_mutt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_my_accounts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_myrepos () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mysql_utils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_mysqldiff () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nautilus () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nbsd_architectures () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ncftp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nedit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_net_interfaces () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_netcat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_netscape () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_netstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_networkmanager () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_networksetup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_newsgroups () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_next_label () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_next_tags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nginx () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ngrep () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nice () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nkf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nmap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_normal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nothing () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_npm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nsenter () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nslookup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_numbers () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_numfmt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_nvram () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_objdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_object_classes () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_object_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_obsd_architectures () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_oci () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_od () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_okular () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_oldlist () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_omz () {
	local -a cmds subcmds
	cmds=('changelog:Print the changelog' 'help:Usage information' 'plugin:Manage plugins' 'pr:Manage Oh My Zsh Pull Requests' 'reload:Reload the current zsh session' 'theme:Manage themes' 'update:Update Oh My Zsh' 'version:Show the version') 
	if (( CURRENT == 2 ))
	then
		_describe 'command' cmds
	elif (( CURRENT == 3 ))
	then
		case "$words[2]" in
			(changelog) local -a refs
				refs=("${(@f)$(builtin cd -q "$ZSH"; command git for-each-ref --format="%(refname:short):%(subject)" refs/heads refs/tags)}") 
				_describe 'command' refs ;;
			(plugin) subcmds=('disable:Disable plugin(s)' 'enable:Enable plugin(s)' 'info:Get plugin information' 'list:List plugins' 'load:Load plugin(s)') 
				_describe 'command' subcmds ;;
			(pr) subcmds=('clean:Delete all Pull Request branches' 'test:Test a Pull Request') 
				_describe 'command' subcmds ;;
			(theme) subcmds=('list:List themes' 'set:Set a theme in your .zshrc file' 'use:Load a theme') 
				_describe 'command' subcmds ;;
		esac
	elif (( CURRENT == 4 ))
	then
		case "${words[2]}::${words[3]}" in
			(plugin::(disable|enable|load)) local -aU valid_plugins
				if [[ "${words[3]}" = disable ]]
				then
					valid_plugins=($plugins) 
				else
					valid_plugins=("$ZSH"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t) "$ZSH_CUSTOM"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t)) 
					[[ "${words[3]}" = enable ]] && valid_plugins=(${valid_plugins:|plugins}) 
				fi
				_describe 'plugin' valid_plugins ;;
			(plugin::info) local -aU plugins
				plugins=("$ZSH"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t) "$ZSH_CUSTOM"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t)) 
				_describe 'plugin' plugins ;;
			(theme::(set|use)) local -aU themes
				themes=("$ZSH"/themes/*.zsh-theme(-.N:t:r) "$ZSH_CUSTOM"/**/*.zsh-theme(-.N:r:gs:"$ZSH_CUSTOM"/themes/:::gs:"$ZSH_CUSTOM"/:::)) 
				_describe 'theme' themes ;;
		esac
	elif (( CURRENT > 4 ))
	then
		case "${words[2]}::${words[3]}" in
			(plugin::(enable|disable|load)) local -aU valid_plugins
				if [[ "${words[3]}" = disable ]]
				then
					valid_plugins=($plugins) 
				else
					valid_plugins=("$ZSH"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t) "$ZSH_CUSTOM"/plugins/*/{_*,*.plugin.zsh}(-.N:h:t)) 
					[[ "${words[3]}" = enable ]] && valid_plugins=(${valid_plugins:|plugins}) 
				fi
				local -a args
				args=(${words[4,$(( CURRENT - 1))]}) 
				valid_plugins=(${valid_plugins:|args}) 
				_describe 'plugin' valid_plugins ;;
		esac
	fi
	return 0
}
_omz::changelog () {
	local version=${1:-HEAD} format=${3:-"--text"} 
	if (
			builtin cd -q "$ZSH"
			! command git show-ref --verify refs/heads/$version && ! command git show-ref --verify refs/tags/$version && ! command git rev-parse --verify "${version}^{commit}"
		) &> /dev/null
	then
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} [version]

NOTE: <version> must be a valid branch, tag or commit.
EOF
		return 1
	fi
	"$ZSH/tools/changelog.sh" "$version" "${2:-}" "$format"
}
_omz::confirm () {
	if [[ -n "$1" ]]
	then
		_omz::log prompt "$1" "${${functrace[1]#_}%:*}"
	fi
	read -r -k 1
	if [[ "$REPLY" != $'\n' ]]
	then
		echo
	fi
}
_omz::help () {
	cat >&2 <<EOF
Usage: omz <command> [options]

Available commands:

  help                Print this help message
  changelog           Print the changelog
  plugin <command>    Manage plugins
  pr     <command>    Manage Oh My Zsh Pull Requests
  reload              Reload the current zsh session
  theme  <command>    Manage themes
  update              Update Oh My Zsh
  version             Show the version

EOF
}
_omz::log () {
	setopt localoptions nopromptsubst
	local logtype=$1 
	local logname=${3:-${${functrace[1]#_}%:*}} 
	if [[ $logtype = debug && -z $_OMZ_DEBUG ]]
	then
		return
	fi
	case "$logtype" in
		(prompt) print -Pn "%S%F{blue}$logname%f%s: $2" ;;
		(debug) print -P "%F{white}$logname%f: $2" ;;
		(info) print -P "%F{green}$logname%f: $2" ;;
		(warn) print -P "%S%F{yellow}$logname%f%s: $2" ;;
		(error) print -P "%S%F{red}$logname%f%s: $2" ;;
	esac >&2
}
_omz::plugin () {
	(( $# > 0 && $+functions[$0::$1] )) || {
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} <command> [options]

Available commands:

  disable <plugin> Disable plugin(s)
  enable <plugin>  Enable plugin(s)
  info <plugin>    Get information of a plugin
  list             List all available Oh My Zsh plugins
  load <plugin>    Load plugin(s)

EOF
		return 1
	}
	local command="$1" 
	shift
	$0::$command "$@"
}
_omz::plugin::disable () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin> [...]" >&2
		return 1
	fi
	local -a dis_plugins
	for plugin in "$@"
	do
		if [[ ${plugins[(Ie)$plugin]} -eq 0 ]]
		then
			_omz::log warn "plugin '$plugin' is not enabled."
			continue
		fi
		dis_plugins+=("$plugin") 
	done
	if [[ ${#dis_plugins} -eq 0 ]]
	then
		return 1
	fi
	local awk_subst_plugins="  gsub(/\s+(${(j:|:)dis_plugins})/, \"\") # with spaces before
  gsub(/(${(j:|:)dis_plugins})\s+/, \"\") # with spaces after
  gsub(/\((${(j:|:)dis_plugins})\)/, \"\") # without spaces (only plugin)
" 
	local awk_script="
# if plugins=() is in oneline form, substitute disabled plugins and go to next line
/^\s*plugins=\([^#]+\).*\$/ {
  $awk_subst_plugins
  print \$0
  next
}

# if plugins=() is in multiline form, enable multi flag and disable plugins if they're there
/^\s*plugins=\(/ {
  multi=1
  $awk_subst_plugins
  print \$0
  next
}

# if multi flag is enabled and we find a valid closing parenthesis, remove plugins and disable multi flag
multi == 1 && /^[^#]*\)/ {
  multi=0
  $awk_subst_plugins
  print \$0
  next
}

multi == 1 && length(\$0) > 0 {
  $awk_subst_plugins
  if (length(\$0) > 0) print \$0
  next
}

{ print \$0 }
" 
	local zdot="${ZDOTDIR:-$HOME}" 
	awk "$awk_script" "$zdot/.zshrc" > "$zdot/.zshrc.new" && command mv -f "$zdot/.zshrc" "$zdot/.zshrc.bck" && command mv -f "$zdot/.zshrc.new" "$zdot/.zshrc"
	[[ $? -eq 0 ]] || {
		local ret=$? 
		_omz::log error "error disabling plugins."
		return $ret
	}
	if ! command zsh -n "$zdot/.zshrc"
	then
		_omz::log error "broken syntax in '"${zdot/#$HOME/\~}/.zshrc"'. Rolling back changes..."
		command mv -f "$zdot/.zshrc" "$zdot/.zshrc.new"
		command mv -f "$zdot/.zshrc.bck" "$zdot/.zshrc"
		return 1
	fi
	_omz::log info "plugins disabled: ${(j:, :)dis_plugins}."
	[[ ! -o interactive ]] || _omz::reload
}
_omz::plugin::enable () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin> [...]" >&2
		return 1
	fi
	local -a add_plugins
	for plugin in "$@"
	do
		if [[ ${plugins[(Ie)$plugin]} -ne 0 ]]
		then
			_omz::log warn "plugin '$plugin' is already enabled."
			continue
		fi
		add_plugins+=("$plugin") 
	done
	if [[ ${#add_plugins} -eq 0 ]]
	then
		return 1
	fi
	local awk_script="
# if plugins=() is in oneline form, substitute ) with new plugins and go to the next line
/^\s*plugins=\([^#]+\).*\$/ {
  sub(/\)/, \" $add_plugins&\")
  print \$0
  next
}

# if plugins=() is in multiline form, enable multi flag
/^\s*plugins=\(/ {
  multi=1
}

# if multi flag is enabled and we find a valid closing parenthesis,
# add new plugins and disable multi flag
multi == 1 && /^[^#]*\)/ {
  multi=0
  sub(/\)/, \" $add_plugins&\")
  print \$0
  next
}

{ print \$0 }
" 
	local zdot="${ZDOTDIR:-$HOME}" 
	awk "$awk_script" "$zdot/.zshrc" > "$zdot/.zshrc.new" && command mv -f "$zdot/.zshrc" "$zdot/.zshrc.bck" && command mv -f "$zdot/.zshrc.new" "$zdot/.zshrc"
	[[ $? -eq 0 ]] || {
		local ret=$? 
		_omz::log error "error enabling plugins."
		return $ret
	}
	if ! command zsh -n "$zdot/.zshrc"
	then
		_omz::log error "broken syntax in '"${zdot/#$HOME/\~}/.zshrc"'. Rolling back changes..."
		command mv -f "$zdot/.zshrc" "$zdot/.zshrc.new"
		command mv -f "$zdot/.zshrc.bck" "$zdot/.zshrc"
		return 1
	fi
	_omz::log info "plugins enabled: ${(j:, :)add_plugins}."
	[[ ! -o interactive ]] || _omz::reload
}
_omz::plugin::info () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin>" >&2
		return 1
	fi
	local readme
	for readme in "$ZSH_CUSTOM/plugins/$1/README.md" "$ZSH/plugins/$1/README.md"
	do
		if [[ -f "$readme" ]]
		then
			(( ${+commands[less]} )) && less "$readme" || cat "$readme"
			return 0
		fi
	done
	if [[ -d "$ZSH_CUSTOM/plugins/$1" || -d "$ZSH/plugins/$1" ]]
	then
		_omz::log error "the '$1' plugin doesn't have a README file"
	else
		_omz::log error "'$1' plugin not found"
	fi
	return 1
}
_omz::plugin::list () {
	local -a custom_plugins builtin_plugins
	custom_plugins=("$ZSH_CUSTOM"/plugins/*(-/N:t)) 
	builtin_plugins=("$ZSH"/plugins/*(-/N:t)) 
	if [[ ! -t 1 ]]
	then
		print -l ${(q-)custom_plugins} ${(q-)builtin_plugins}
		return
	fi
	if (( ${#custom_plugins} ))
	then
		print -P "%U%BCustom plugins%b%u:"
		print -l ${(q-)custom_plugins} | column -x
	fi
	if (( ${#builtin_plugins} ))
	then
		(( ${#custom_plugins} )) && echo
		print -P "%U%BBuilt-in plugins%b%u:"
		print -l ${(q-)builtin_plugins} | column -x
	fi
}
_omz::plugin::load () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <plugin> [...]" >&2
		return 1
	fi
	local plugin base has_completion=0 
	for plugin in "$@"
	do
		if [[ -d "$ZSH_CUSTOM/plugins/$plugin" ]]
		then
			base="$ZSH_CUSTOM/plugins/$plugin" 
		elif [[ -d "$ZSH/plugins/$plugin" ]]
		then
			base="$ZSH/plugins/$plugin" 
		else
			_omz::log warn "plugin '$plugin' not found"
			continue
		fi
		if [[ ! -f "$base/_$plugin" && ! -f "$base/$plugin.plugin.zsh" ]]
		then
			_omz::log warn "'$plugin' is not a valid plugin"
			continue
		elif (( ! ${fpath[(Ie)$base]} ))
		then
			fpath=("$base" $fpath) 
		fi
		local -a comp_files
		comp_files=($base/_*(N)) 
		has_completion=$(( $#comp_files > 0 )) 
		if [[ -f "$base/$plugin.plugin.zsh" ]]
		then
			source "$base/$plugin.plugin.zsh"
		fi
	done
	if (( has_completion ))
	then
		compinit -D -d "$_comp_dumpfile"
	fi
}
_omz::pr () {
	(( $# > 0 && $+functions[$0::$1] )) || {
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} <command> [options]

Available commands:

  clean                       Delete all PR branches (ohmyzsh/pull-*)
  test <PR_number_or_URL>     Fetch PR #NUMBER and rebase against master

EOF
		return 1
	}
	local command="$1" 
	shift
	$0::$command "$@"
}
_omz::pr::clean () {
	(
		set -e
		builtin cd -q "$ZSH"
		local fmt branches
		fmt="%(color:bold blue)%(align:18,right)%(refname:short)%(end)%(color:reset) %(color:dim bold red)%(objectname:short)%(color:reset) %(color:yellow)%(contents:subject)" 
		branches="$(command git for-each-ref --sort=-committerdate --color --format="$fmt" "refs/heads/ohmyzsh/pull-*")" 
		if [[ -z "$branches" ]]
		then
			_omz::log info "there are no Pull Request branches to remove."
			return
		fi
		echo "$branches\n"
		_omz::confirm "do you want remove these Pull Request branches? [Y/n] "
		[[ "$REPLY" != [yY$'\n'] ]] && return
		_omz::log info "removing all Oh My Zsh Pull Request branches..."
		command git branch --list 'ohmyzsh/pull-*' | while read branch
		do
			command git branch -D "$branch"
		done
	)
}
_omz::pr::test () {
	if [[ "$1" = https://* ]]
	then
		1="${1:t}" 
	fi
	if ! [[ -n "$1" && "$1" =~ ^[[:digit:]]+$ ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <PR_NUMBER_or_URL>" >&2
		return 1
	fi
	local branch
	branch=$(builtin cd -q "$ZSH"; git symbolic-ref --short HEAD)  || {
		_omz::log error "error when getting the current git branch. Aborting..."
		return 1
	}
	(
		set -e
		builtin cd -q "$ZSH"
		command git remote -v | while read remote url _
		do
			case "$url" in
				(https://github.com/ohmyzsh/ohmyzsh(|.git)) found=1 
					break ;;
				(git@github.com:ohmyzsh/ohmyzsh(|.git)) found=1 
					break ;;
			esac
		done
		(( $found )) || {
			_omz::log error "could not found the ohmyzsh git remote. Aborting..."
			return 1
		}
		_omz::log info "fetching PR #$1 to ohmyzsh/pull-$1..."
		command git fetch -f "$remote" refs/pull/$1/head:ohmyzsh/pull-$1 || {
			_omz::log error "error when trying to fetch PR #$1."
			return 1
		}
		_omz::log info "rebasing PR #$1..."
		local ret gpgsign
		{
			gpgsign=$(command git config --local commit.gpgsign 2>/dev/null)  || ret=$? 
			[[ $ret -ne 129 ]] || gpgsign=$(command git config commit.gpgsign 2>/dev/null) 
			command git config commit.gpgsign false
			command git rebase master ohmyzsh/pull-$1 || {
				command git rebase --abort &> /dev/null
				_omz::log warn "could not rebase PR #$1 on top of master."
				_omz::log warn "you might not see the latest stable changes."
				_omz::log info "run \`zsh\` to test the changes."
				return 1
			}
		} always {
			case "$gpgsign" in
				("") command git config --unset commit.gpgsign ;;
				(*) command git config commit.gpgsign "$gpgsign" ;;
			esac
		}
		_omz::log info "fetch of PR #${1} successful."
	)
	[[ $? -eq 0 ]] || return 1
	_omz::log info "running \`zsh\` to test the changes. Run \`exit\` to go back."
	command zsh -l
	_omz::confirm "do you want to go back to the previous branch? [Y/n] "
	[[ "$REPLY" != [yY$'\n'] ]] && return
	(
		set -e
		builtin cd -q "$ZSH"
		command git checkout "$branch" -- || {
			_omz::log error "could not go back to the previous branch ('$branch')."
			return 1
		}
	)
}
_omz::reload () {
	command rm -f $_comp_dumpfile $ZSH_COMPDUMP
	local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}" 
	[[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
}
_omz::theme () {
	(( $# > 0 && $+functions[$0::$1] )) || {
		cat >&2 <<EOF
Usage: ${(j: :)${(s.::.)0#_}} <command> [options]

Available commands:

  list            List all available Oh My Zsh themes
  set <theme>     Set a theme in your .zshrc file
  use <theme>     Load a theme

EOF
		return 1
	}
	local command="$1" 
	shift
	$0::$command "$@"
}
_omz::theme::list () {
	local -a custom_themes builtin_themes
	custom_themes=("$ZSH_CUSTOM"/**/*.zsh-theme(-.N:r:gs:"$ZSH_CUSTOM"/themes/:::gs:"$ZSH_CUSTOM"/:::)) 
	builtin_themes=("$ZSH"/themes/*.zsh-theme(-.N:t:r)) 
	if [[ ! -t 1 ]]
	then
		print -l ${(q-)custom_themes} ${(q-)builtin_themes}
		return
	fi
	if [[ -n "$ZSH_THEME" ]]
	then
		print -Pn "%U%BCurrent theme%b%u: "
		[[ $ZSH_THEME = random ]] && echo "$RANDOM_THEME (via random)" || echo "$ZSH_THEME"
		echo
	fi
	if (( ${#custom_themes} ))
	then
		print -P "%U%BCustom themes%b%u:"
		print -l ${(q-)custom_themes} | column -x
		echo
	fi
	print -P "%U%BBuilt-in themes%b%u:"
	print -l ${(q-)builtin_themes} | column -x
}
_omz::theme::set () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <theme>" >&2
		return 1
	fi
	if [[ ! -f "$ZSH_CUSTOM/$1.zsh-theme" ]] && [[ ! -f "$ZSH_CUSTOM/themes/$1.zsh-theme" ]] && [[ ! -f "$ZSH/themes/$1.zsh-theme" ]]
	then
		_omz::log error "%B$1%b theme not found"
		return 1
	fi
	local awk_script='
!set && /^\s*ZSH_THEME=[^#]+.*$/ {
  set=1
  sub(/^\s*ZSH_THEME=[^#]+.*$/, "ZSH_THEME=\"'$1'\" # set by `omz`")
  print $0
  next
}

{ print $0 }

END {
  # If no ZSH_THEME= line was found, return an error
  if (!set) exit 1
}
' 
	local zdot="${ZDOTDIR:-$HOME}" 
	awk "$awk_script" "$zdot/.zshrc" > "$zdot/.zshrc.new" || {
		cat <<EOF
ZSH_THEME="$1" # set by \`omz\`

EOF
		cat "$zdot/.zshrc"
	} > "$zdot/.zshrc.new" && command mv -f "$zdot/.zshrc" "$zdot/.zshrc.bck" && command mv -f "$zdot/.zshrc.new" "$zdot/.zshrc"
	[[ $? -eq 0 ]] || {
		local ret=$? 
		_omz::log error "error setting theme."
		return $ret
	}
	if ! command zsh -n "$zdot/.zshrc"
	then
		_omz::log error "broken syntax in '"${zdot/#$HOME/\~}/.zshrc"'. Rolling back changes..."
		command mv -f "$zdot/.zshrc" "$zdot/.zshrc.new"
		command mv -f "$zdot/.zshrc.bck" "$zdot/.zshrc"
		return 1
	fi
	_omz::log info "'$1' theme set correctly."
	[[ ! -o interactive ]] || _omz::reload
}
_omz::theme::use () {
	if [[ -z "$1" ]]
	then
		echo "Usage: ${(j: :)${(s.::.)0#_}} <theme>" >&2
		return 1
	fi
	if [[ -f "$ZSH_CUSTOM/$1.zsh-theme" ]]
	then
		source "$ZSH_CUSTOM/$1.zsh-theme"
	elif [[ -f "$ZSH_CUSTOM/themes/$1.zsh-theme" ]]
	then
		source "$ZSH_CUSTOM/themes/$1.zsh-theme"
	elif [[ -f "$ZSH/themes/$1.zsh-theme" ]]
	then
		source "$ZSH/themes/$1.zsh-theme"
	else
		_omz::log error "%B$1%b theme not found"
		return 1
	fi
	ZSH_THEME="$1" 
	[[ $1 = random ]] || unset RANDOM_THEME
}
_omz::update () {
	local last_commit=$(builtin cd -q "$ZSH"; git rev-parse HEAD) 
	if [[ "$1" != --unattended ]]
	then
		ZSH="$ZSH" command zsh -f "$ZSH/tools/upgrade.sh" --interactive || return $?
	else
		ZSH="$ZSH" command zsh -f "$ZSH/tools/upgrade.sh" || return $?
	fi
	zmodload zsh/datetime
	echo "LAST_EPOCH=$(( EPOCHSECONDS / 60 / 60 / 24 ))" >| "${ZSH_CACHE_DIR}/.zsh-update"
	command rm -rf "$ZSH/log/update.lock"
	if [[ "$1" != --unattended && "$(builtin cd -q "$ZSH"; git rev-parse HEAD)" != "$last_commit" ]]
	then
		local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}" 
		[[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
	fi
}
_omz::version () {
	(
		builtin cd -q "$ZSH"
		local version
		version=$(command git describe --tags HEAD 2>/dev/null)  || version=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)  || version=$(command git name-rev --no-undefined --name-only --exclude="remotes/*" HEAD 2>/dev/null)  || version="<detached>" 
		local commit=$(command git rev-parse --short HEAD 2>/dev/null) 
		printf "%s (%s)\n" "$version" "$commit"
	)
}
_omz_diag_dump_check_core_commands () {
	builtin echo "Core command check:"
	local redefined name builtins externals reserved_words
	redefined=() 
	reserved_words=(do done esac then elif else fi for case if while function repeat time until select coproc nocorrect foreach end '!' '[[' '{' '}') 
	builtins=(alias autoload bg bindkey break builtin bye cd chdir command comparguments compcall compctl compdescribe compfiles compgroups compquote comptags comptry compvalues continue dirs disable disown echo echotc echoti emulate enable eval exec exit false fc fg functions getln getopts hash jobs kill let limit log logout noglob popd print printf pushd pushln pwd r read rehash return sched set setopt shift source suspend test times trap true ttyctl type ulimit umask unalias unfunction unhash unlimit unset unsetopt vared wait whence where which zcompile zle zmodload zparseopts zregexparse zstyle) 
	if is-at-least 5.1
	then
		reserved_word+=(declare export integer float local readonly typeset) 
	else
		builtins+=(declare export integer float local readonly typeset) 
	fi
	builtins_fatal=(builtin command local) 
	externals=(zsh) 
	for name in $reserved_words
	do
		if [[ $(builtin whence -w $name) != "$name: reserved" ]]
		then
			builtin echo "reserved word '$name' has been redefined"
			builtin which $name
			redefined+=$name 
		fi
	done
	for name in $builtins
	do
		if [[ $(builtin whence -w $name) != "$name: builtin" ]]
		then
			builtin echo "builtin '$name' has been redefined"
			builtin which $name
			redefined+=$name 
		fi
	done
	for name in $externals
	do
		if [[ $(builtin whence -w $name) != "$name: command" ]]
		then
			builtin echo "command '$name' has been redefined"
			builtin which $name
			redefined+=$name 
		fi
	done
	if [[ -n "$redefined" ]]
	then
		builtin echo "SOME CORE COMMANDS HAVE BEEN REDEFINED: $redefined"
	else
		builtin echo "All core commands are defined normally"
	fi
}
_omz_diag_dump_echo_file_w_header () {
	local file=$1 
	if [[ -f $file || -h $file ]]
	then
		builtin echo "========== $file =========="
		if [[ -h $file ]]
		then
			builtin echo "==========    ( => ${file:A} )   =========="
		fi
		command cat $file
		builtin echo "========== end $file =========="
		builtin echo
	elif [[ -d $file ]]
	then
		builtin echo "File '$file' is a directory"
	elif [[ ! -e $file ]]
	then
		builtin echo "File '$file' does not exist"
	else
		command ls -lad "$file"
	fi
}
_omz_diag_dump_one_big_text () {
	local program programs progfile md5
	builtin echo oh-my-zsh diagnostic dump
	builtin echo
	builtin echo $outfile
	builtin echo
	command date
	command uname -a
	builtin echo OSTYPE=$OSTYPE
	builtin echo ZSH_VERSION=$ZSH_VERSION
	builtin echo User: $USERNAME
	builtin echo umask: $(umask)
	builtin echo
	_omz_diag_dump_os_specific_version
	builtin echo
	programs=(sh zsh ksh bash sed cat grep ls find git posh) 
	local progfile="" extra_str="" sha_str="" 
	for program in $programs
	do
		extra_str="" sha_str="" 
		progfile=$(builtin which $program) 
		if [[ $? == 0 ]]
		then
			if [[ -e $progfile ]]
			then
				if builtin whence shasum &> /dev/null
				then
					sha_str=($(command shasum $progfile)) 
					sha_str=$sha_str[1] 
					extra_str+=" SHA $sha_str" 
				fi
				if [[ -h "$progfile" ]]
				then
					extra_str+=" ( -> ${progfile:A} )" 
				fi
			fi
			builtin printf '%-9s %-20s %s\n' "$program is" "$progfile" "$extra_str"
		else
			builtin echo "$program: not found"
		fi
	done
	builtin echo
	builtin echo Command Versions:
	builtin echo "zsh: $(zsh --version)"
	builtin echo "this zsh session: $ZSH_VERSION"
	builtin echo "bash: $(bash --version | command grep bash)"
	builtin echo "git: $(git --version)"
	builtin echo "grep: $(grep --version)"
	builtin echo
	_omz_diag_dump_check_core_commands || return 1
	builtin echo
	builtin echo Process state:
	builtin echo pwd: $PWD
	if builtin whence pstree &> /dev/null
	then
		builtin echo Process tree for this shell:
		pstree -p $$
	else
		ps -fT
	fi
	builtin set | command grep -a '^\(ZSH\|plugins\|TERM\|LC_\|LANG\|precmd\|chpwd\|preexec\|FPATH\|TTY\|DISPLAY\|PATH\)\|OMZ'
	builtin echo
	builtin echo Exported:
	builtin echo $(builtin export | command sed 's/=.*//')
	builtin echo
	builtin echo Locale:
	command locale
	builtin echo
	builtin echo Zsh configuration:
	builtin echo setopt: $(builtin setopt)
	builtin echo
	builtin echo zstyle:
	builtin zstyle
	builtin echo
	builtin echo 'compaudit output:'
	compaudit
	builtin echo
	builtin echo '$fpath directories:'
	command ls -lad $fpath
	builtin echo
	builtin echo oh-my-zsh installation:
	command ls -ld ~/.z*
	command ls -ld ~/.oh*
	builtin echo
	builtin echo oh-my-zsh git state:
	(
		builtin cd $ZSH && builtin echo "HEAD: $(git rev-parse HEAD)" && git remote -v && git status | command grep "[^[:space:]]"
	)
	if [[ $verbose -ge 1 ]]
	then
		(
			builtin cd $ZSH && git reflog --date=default | command grep pull
		)
	fi
	builtin echo
	if [[ -e $ZSH_CUSTOM ]]
	then
		local custom_dir=$ZSH_CUSTOM 
		if [[ -h $custom_dir ]]
		then
			custom_dir=$(builtin cd $custom_dir && pwd -P) 
		fi
		builtin echo "oh-my-zsh custom dir:"
		builtin echo "   $ZSH_CUSTOM ($custom_dir)"
		(
			builtin cd ${custom_dir:h} && command find ${custom_dir:t} -name .git -prune -o -print
		)
		builtin echo
	fi
	if [[ $verbose -ge 1 ]]
	then
		builtin echo "bindkey:"
		builtin bindkey
		builtin echo
		builtin echo "infocmp:"
		command infocmp -L
		builtin echo
	fi
	local zdotdir=${ZDOTDIR:-$HOME} 
	builtin echo "Zsh configuration files:"
	local cfgfile cfgfiles
	cfgfiles=(/etc/zshenv /etc/zprofile /etc/zshrc /etc/zlogin /etc/zlogout $zdotdir/.zshenv $zdotdir/.zprofile $zdotdir/.zshrc $zdotdir/.zlogin $zdotdir/.zlogout ~/.zsh.pre-oh-my-zsh /etc/bashrc /etc/profile ~/.bashrc ~/.profile ~/.bash_profile ~/.bash_logout) 
	command ls -lad $cfgfiles 2>&1
	builtin echo
	if [[ $verbose -ge 1 ]]
	then
		for cfgfile in $cfgfiles
		do
			_omz_diag_dump_echo_file_w_header $cfgfile
		done
	fi
	builtin echo
	builtin echo "Zsh compdump files:"
	local dumpfile dumpfiles
	command ls -lad $zdotdir/.zcompdump*
	dumpfiles=($zdotdir/.zcompdump*(N)) 
	if [[ $verbose -ge 2 ]]
	then
		for dumpfile in $dumpfiles
		do
			_omz_diag_dump_echo_file_w_header $dumpfile
		done
	fi
}
_omz_diag_dump_os_specific_version () {
	local osname osver version_file version_files
	case "$OSTYPE" in
		(darwin*) osname=$(command sw_vers -productName) 
			osver=$(command sw_vers -productVersion) 
			builtin echo "OS Version: $osname $osver build $(sw_vers -buildVersion)" ;;
		(cygwin) command systeminfo | command head -n 4 | command tail -n 2 ;;
	esac
	if builtin which lsb_release > /dev/null
	then
		builtin echo "OS Release: $(command lsb_release -s -d)"
	fi
	version_files=(/etc/*-release(N) /etc/*-version(N) /etc/*_version(N)) 
	for version_file in $version_files
	do
		builtin echo "$version_file:"
		command cat "$version_file"
		builtin echo
	done
}
_omz_macos_get_frontmost_app () {
	osascript 2> /dev/null <<EOF
    tell application "System Events"
      name of first item of (every process whose frontmost is true)
    end tell
EOF
}
_open () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_openstack () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_opkg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_options () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_options_set () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_options_unset () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_opustools () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_orb () {
	# undefined
	builtin autoload -XUz /Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh
}
_orbctl () {
	# undefined
	builtin autoload -XUz /Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh
}
_osascript () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_osc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_other_accounts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_otool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_p11-kit () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_pack () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pandoc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_parameter () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_parameters () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_paste () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_patch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_patchutils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_path_commands () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_path_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pax () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pbcopy () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pbm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pbuilder () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pdf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pdftk () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_perf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_perforce () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_perl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_perl_basepods () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_perl_modules () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_perldoc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pfctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pfexec () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pgids () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pgrep () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_php () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_physical_volumes () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pick_variant () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_picocom () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pidof () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pids () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pine () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ping () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pipx () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_piuparts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkg-config () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkg5 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkg_instance () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkgadd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkgin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkginfo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkgrm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pkgtool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_plutil () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pmap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pnpm () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_pon () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_portaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_portlint () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_portmaster () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ports () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_portsnap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_postfix () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_postgresql () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_postscript () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_powerd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_precommand () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_prefix () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_print () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_printenv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_printers () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_process_names () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_procs () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_procstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_prompt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_prove () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_prstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ps () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ps1234 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pscp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pspdf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_psutils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ptree () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ptx () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_putclip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pwgen () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_pydoc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_python () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_python_argcomplete () {
	local prefix= 
	if [[ $COMP_LINE == 'gcloud '* ]]
	then
		if [[ $3 == ssh && $2 == *@* ]]
		then
			prefix=${2%@*}@ 
			COMP_LINE=${COMP_LINE%$2}"${2#*@}" 
		elif [[ $2 == *'='* ]]
		then
			prefix=${2%=*}'=' 
			COMP_LINE=${COMP_LINE%$2}${2/'='/' '} 
		fi
	fi
	local IFS='' 
	COMPREPLY=($(IFS="$IFS"                   COMP_LINE="$COMP_LINE"                   COMP_POINT="$COMP_POINT"                   _ARGCOMPLETE_COMP_WORDBREAKS="$COMP_WORDBREAKS"                   _ARGCOMPLETE=1                   "$1" 8>&1 9>&2 1>/dev/null 2>/dev/null)) 
	if [[ $? != 0 ]]
	then
		unset COMPREPLY
		return
	fi
	if [[ ${#COMPREPLY[@]} == 1 && $COMPREPLY != *[=' '] ]]
	then
		COMPREPLY+=' ' 
	fi
	if [[ $prefix != '' ]]
	then
		typeset -i n
		for ((n=0; n < ${#COMPREPLY[@]}; n++)) do
			COMPREPLY[$n]=$prefix${COMPREPLY[$n]} 
		done
	fi
}
_python_modules () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_qdbus () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_qemu () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_qiv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_qtplay () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_quilt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rake () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ranlib () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rar () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rbenv () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_rcctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rclone () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rcs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rdesktop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_read () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_read_comp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_readelf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_readlink () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_readshortcut () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rebootin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_redirect () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_regex_arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_regex_words () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_remote_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_renice () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_reprepro () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_requested () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_retrieve_cache () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_retrieve_mac_apps () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rg () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_ri () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rlogin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rmdir () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_route () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_routing_domains () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_routing_tables () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rpm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rrdtool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rsync () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_rubber () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ruby () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_run-help () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_runit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_samba () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_savecore () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_say () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sbuild () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sc_usage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sccs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sched () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_schedtool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_schroot () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_scl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_scons () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_scrcpy () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_screen () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_script () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_scselect () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_scutil () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_seafile () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_security () {
	# undefined
	builtin autoload -XUz /Users/yangeok/.oh-my-zsh/plugins/macos
}
_sed () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_selinux_contexts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_selinux_roles () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_selinux_types () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_selinux_users () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sep_parts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_seq () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sequence () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_service () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_services () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_set () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_set_command () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_set_remove () {
	comm -23 <(echo $1 | sort | tr " " "\n") <(echo $2 | sort | tr " " "\n") 2> /dev/null
}
_setfacl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_setopt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_setpriv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_setsid () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_setup () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_setxkbmap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_shasum () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_showmount () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_shred () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_shuf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_shutdown () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_signals () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_signify () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sisu () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_slabtop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_slrn () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_smartmontools () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_smit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_snoop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_socket () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sockstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_softwareupdate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sort () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_source () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_spamassassin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_split () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_spring () {
	# undefined
	builtin autoload -XUz /usr/local/share/zsh/site-functions
}
_sqlite () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sqsh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ss () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ssh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ssh_hosts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sshfs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_stat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_stdbuf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_stgit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_store_cache () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_stow () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_strace () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_strftime () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_strings () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_strip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_stty () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_su () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sub_commands () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sublimetext () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_subscript () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_subversion () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sudo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_suffix_alias_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_surfraw () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_svcadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_svccfg () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_svcprop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_svcs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_svcs_fmri () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_svn-buildpackage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sw_vers () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_swaks () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_swanctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_swift () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sys_calls () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sysclean () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sysctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sysmerge () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_syspatch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sysrc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sysstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_systat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_system_profiler () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_sysupgrade () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tac () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tags () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tail () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tailspin () {
	# undefined
	builtin autoload -XUz /usr/local/share/zsh/site-functions
}
_tar () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tar_archive () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tardy () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tcpdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tcpsys () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tcptraceroute () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tee () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_telnet () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_terminals () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tex () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_texi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_texinfo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_the_silver_searcher () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_tidy () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tiff () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tilde () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tilde_files () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_time_zone () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_timeout () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tla () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tload () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tmux () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_todo.sh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_toilet () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_toolchain-source () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_top () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_topgit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_totd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_touch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tpb () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tput () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tracepath () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_transmission () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_trap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_trash () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tree () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_trip () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_truncate () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_truss () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_trust () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_tspin () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_tty () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ttyctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ttys () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_tune2fs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_twidge () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_twisted () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_typeset () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ulimit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_uml () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_umountable () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_unace () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_uname () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_unexpand () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_unhash () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_uniq () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_unison () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_units () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_unshare () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_update-alternatives () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_update-rc.d () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_uptime () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_urls () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_urpmi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_urxvt () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_usbconfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_uscan () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_user_admin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_user_at_host () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_user_expand () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_user_math_func () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_users () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_users_on () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_uv () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_uvx () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_valgrind () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_value () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_values () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vared () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vars () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vcs_info () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vcs_info_hooks () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vim () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vim-addons () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_visudo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vmctl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vmstat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vnc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_volume_groups () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vorbis () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vpnc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_vserver () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_w () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_w3m () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wait () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wajig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wakeup_capable_devices () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wanna-build () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wanted () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_watch () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_watch-snoop () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_webbrowser () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wget () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_whereis () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_which () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_who () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_whois () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_widgets () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wiggle () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wipefs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_wpa_cli () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_borderwidth () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_color () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_colormapid () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_cursor () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_display () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_extension () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_font () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_geometry () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_keysym () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_locale () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_modifier () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_name () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_resource () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_selection_timeout () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_title () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_utils () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_visual () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_x_window () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xargs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xauth () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xautolock () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xclip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xcode-select () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xdvi () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xfig () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xft_fonts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xinput () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xloadimage () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xmlsoft () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xmlstarlet () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xmms2 () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xmodmap () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xournal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xpdf () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xrandr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xscreensaver () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xset () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xt_arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xt_session_id () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xterm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xwit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xxd () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_xz () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_yafc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_yast () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_yodl () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_yp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_yt-dlp () {
	# undefined
	builtin autoload -XUz /opt/homebrew/share/zsh/site-functions
}
_yum () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zargs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zattr () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zcalc () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zcalc_line () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zcat () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zcompile () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zeal () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zed () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zfs () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zfs_dataset () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zfs_pool () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zftp () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zinit () {
	# undefined
	builtin autoload -XUz /Users/yangeok/.local/share/zinit/completions
}
_zip () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zle () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zlogin () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zmodload () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zmv () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zoneadm () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zones () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zparseopts () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zpty () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zsh () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zsh-mime-handler () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zsh_autosuggest_accept () {
	local -i retval max_cursor_pos=$#BUFFER 
	if [[ "$KEYMAP" = "vicmd" ]]
	then
		max_cursor_pos=$((max_cursor_pos - 1)) 
	fi
	if (( $CURSOR != $max_cursor_pos || !$#POSTDISPLAY ))
	then
		_zsh_autosuggest_invoke_original_widget $@
		return
	fi
	BUFFER="$BUFFER$POSTDISPLAY" 
	unset POSTDISPLAY
	_zsh_autosuggest_invoke_original_widget $@
	retval=$? 
	if [[ "$KEYMAP" = "vicmd" ]]
	then
		CURSOR=$(($#BUFFER - 1)) 
	else
		CURSOR=$#BUFFER 
	fi
	return $retval
}
_zsh_autosuggest_async_request () {
	zmodload zsh/system 2> /dev/null
	typeset -g _ZSH_AUTOSUGGEST_ASYNC_FD _ZSH_AUTOSUGGEST_CHILD_PID
	if [[ -n "$_ZSH_AUTOSUGGEST_ASYNC_FD" ]] && {
			true <&$_ZSH_AUTOSUGGEST_ASYNC_FD
		} 2> /dev/null
	then
		exec {_ZSH_AUTOSUGGEST_ASYNC_FD}<&-
		zle -F $_ZSH_AUTOSUGGEST_ASYNC_FD
		if [[ -n "$_ZSH_AUTOSUGGEST_CHILD_PID" ]]
		then
			if [[ -o MONITOR ]]
			then
				kill -TERM -$_ZSH_AUTOSUGGEST_CHILD_PID 2> /dev/null
			else
				kill -TERM $_ZSH_AUTOSUGGEST_CHILD_PID 2> /dev/null
			fi
		fi
	fi
	exec {_ZSH_AUTOSUGGEST_ASYNC_FD}< <(
		# Tell parent process our pid
		echo $sysparams[pid]

		# Fetch and print the suggestion
		local suggestion
		_zsh_autosuggest_fetch_suggestion "$1"
		echo -nE "$suggestion"
	)
	command true
	read _ZSH_AUTOSUGGEST_CHILD_PID <&$_ZSH_AUTOSUGGEST_ASYNC_FD
	zle -F "$_ZSH_AUTOSUGGEST_ASYNC_FD" _zsh_autosuggest_async_response
}
_zsh_autosuggest_async_response () {
	emulate -L zsh
	local suggestion
	if [[ -z "$2" || "$2" == "hup" ]]
	then
		IFS='' read -rd '' -u $1 suggestion
		zle autosuggest-suggest -- "$suggestion"
		exec {1}<&-
	fi
	zle -F "$1"
}
_zsh_autosuggest_bind_widget () {
	typeset -gA _ZSH_AUTOSUGGEST_BIND_COUNTS
	local widget=$1 
	local autosuggest_action=$2 
	local prefix=$ZSH_AUTOSUGGEST_ORIGINAL_WIDGET_PREFIX 
	local -i bind_count
	case $widgets[$widget] in
		(user:_zsh_autosuggest_(bound|orig)_*) bind_count=$((_ZSH_AUTOSUGGEST_BIND_COUNTS[$widget]))  ;;
		(user:*) _zsh_autosuggest_incr_bind_count $widget
			zle -N $prefix$bind_count-$widget ${widgets[$widget]#*:} ;;
		(builtin) _zsh_autosuggest_incr_bind_count $widget
			eval "_zsh_autosuggest_orig_${(q)widget}() { zle .${(q)widget} }"
			zle -N $prefix$bind_count-$widget _zsh_autosuggest_orig_$widget ;;
		(completion:*) _zsh_autosuggest_incr_bind_count $widget
			eval "zle -C $prefix$bind_count-${(q)widget} ${${(s.:.)widgets[$widget]}[2,3]}" ;;
	esac
	eval "_zsh_autosuggest_bound_${bind_count}_${(q)widget}() {
		_zsh_autosuggest_widget_$autosuggest_action $prefix$bind_count-${(q)widget} \$@
	}"
	zle -N -- $widget _zsh_autosuggest_bound_${bind_count}_$widget
}
_zsh_autosuggest_bind_widgets () {
	emulate -L zsh
	local widget
	local ignore_widgets
	ignore_widgets=(.\* _\* autosuggest-\* $ZSH_AUTOSUGGEST_ORIGINAL_WIDGET_PREFIX\* $ZSH_AUTOSUGGEST_IGNORE_WIDGETS) 
	for widget in ${${(f)"$(builtin zle -la)"}:#${(j:|:)~ignore_widgets}}
	do
		if [[ -n ${ZSH_AUTOSUGGEST_CLEAR_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget clear
		elif [[ -n ${ZSH_AUTOSUGGEST_ACCEPT_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget accept
		elif [[ -n ${ZSH_AUTOSUGGEST_EXECUTE_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget execute
		elif [[ -n ${ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS[(r)$widget]} ]]
		then
			_zsh_autosuggest_bind_widget $widget partial_accept
		else
			_zsh_autosuggest_bind_widget $widget modify
		fi
	done
}
_zsh_autosuggest_capture_completion_async () {
	_zsh_autosuggest_capture_setup
	zmodload zsh/parameter 2> /dev/null || return
	autoload +X _complete
	functions[_original_complete]=$functions[_complete] 
	_complete () {
		unset 'compstate[vared]'
		_original_complete "$@"
	}
	vared 1
}
_zsh_autosuggest_capture_completion_sync () {
	_zsh_autosuggest_capture_setup
	zle autosuggest-capture-completion
}
_zsh_autosuggest_capture_completion_widget () {
	local -a +h comppostfuncs
	comppostfuncs=(_zsh_autosuggest_capture_postcompletion) 
	CURSOR=$#BUFFER 
	zle -- ${(k)widgets[(r)completion:.complete-word:_main_complete]}
	if is-at-least 5.0.3
	then
		stty -onlcr -ocrnl -F /dev/tty
	fi
	echo -nE - $'\0'$BUFFER$'\0'
}
_zsh_autosuggest_capture_postcompletion () {
	compstate[insert]=1 
	unset 'compstate[list]'
}
_zsh_autosuggest_capture_setup () {
	autoload -Uz is-at-least
	if ! is-at-least 5.4
	then
		zshexit () {
			kill -KILL $$ 2>&- || command kill -KILL $$
			sleep 1
		}
	fi
	zstyle ':completion:*' matcher-list ''
	zstyle ':completion:*' path-completion false
	zstyle ':completion:*' max-errors 0 not-numeric
	bindkey '^I' autosuggest-capture-completion
}
_zsh_autosuggest_clear () {
	unset POSTDISPLAY
	_zsh_autosuggest_invoke_original_widget $@
}
_zsh_autosuggest_disable () {
	typeset -g _ZSH_AUTOSUGGEST_DISABLED
	_zsh_autosuggest_clear
}
_zsh_autosuggest_enable () {
	unset _ZSH_AUTOSUGGEST_DISABLED
	if (( $#BUFFER ))
	then
		_zsh_autosuggest_fetch
	fi
}
_zsh_autosuggest_escape_command () {
	setopt localoptions EXTENDED_GLOB
	echo -E "${1//(#m)[\"\'\\()\[\]|*?~]/\\$MATCH}"
}
_zsh_autosuggest_execute () {
	BUFFER="$BUFFER$POSTDISPLAY" 
	unset POSTDISPLAY
	_zsh_autosuggest_invoke_original_widget "accept-line"
}
_zsh_autosuggest_fetch () {
	if (( ${+ZSH_AUTOSUGGEST_USE_ASYNC} ))
	then
		_zsh_autosuggest_async_request "$BUFFER"
	else
		local suggestion
		_zsh_autosuggest_fetch_suggestion "$BUFFER"
		_zsh_autosuggest_suggest "$suggestion"
	fi
}
_zsh_autosuggest_fetch_suggestion () {
	typeset -g suggestion
	local -a strategies
	local strategy
	strategies=(${=ZSH_AUTOSUGGEST_STRATEGY}) 
	for strategy in $strategies
	do
		_zsh_autosuggest_strategy_$strategy "$1"
		[[ "$suggestion" != "$1"* ]] && unset suggestion
		[[ -n "$suggestion" ]] && break
	done
}
_zsh_autosuggest_highlight_apply () {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	if (( $#POSTDISPLAY ))
	then
		typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT="$#BUFFER $(($#BUFFER + $#POSTDISPLAY)) $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE" 
		region_highlight+=("$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT") 
	else
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}
_zsh_autosuggest_highlight_reset () {
	typeset -g _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	if [[ -n "$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT" ]]
	then
		region_highlight=("${(@)region_highlight:#$_ZSH_AUTOSUGGEST_LAST_HIGHLIGHT}") 
		unset _ZSH_AUTOSUGGEST_LAST_HIGHLIGHT
	fi
}
_zsh_autosuggest_incr_bind_count () {
	typeset -gi bind_count=$((_ZSH_AUTOSUGGEST_BIND_COUNTS[$1]+1)) 
	_ZSH_AUTOSUGGEST_BIND_COUNTS[$1]=$bind_count 
}
_zsh_autosuggest_invoke_original_widget () {
	(( $# )) || return 0
	local original_widget_name="$1" 
	shift
	if (( ${+widgets[$original_widget_name]} ))
	then
		zle $original_widget_name -- $@
	fi
}
_zsh_autosuggest_modify () {
	local -i retval
	local -i KEYS_QUEUED_COUNT
	local orig_buffer="$BUFFER" 
	local orig_postdisplay="$POSTDISPLAY" 
	unset POSTDISPLAY
	_zsh_autosuggest_invoke_original_widget $@
	retval=$? 
	emulate -L zsh
	if (( $PENDING > 0 || $KEYS_QUEUED_COUNT > 0 ))
	then
		POSTDISPLAY="$orig_postdisplay" 
		return $retval
	fi
	if (( $#BUFFER > $#orig_buffer ))
	then
		local added=${BUFFER#$orig_buffer} 
		if [[ "$added" = "${orig_postdisplay:0:$#added}" ]]
		then
			POSTDISPLAY="${orig_postdisplay:$#added}" 
			return $retval
		fi
	fi
	if [[ "$BUFFER" = "$orig_buffer" ]]
	then
		POSTDISPLAY="$orig_postdisplay" 
		return $retval
	fi
	if [[ -n "${_ZSH_AUTOSUGGEST_DISABLED+x}" ]]
	then
		return $?
	fi
	if (( $#BUFFER > 0 ))
	then
		if [[ -z "$ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE" ]] || (( $#BUFFER <= $ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE ))
		then
			_zsh_autosuggest_fetch
		fi
	fi
	return $retval
}
_zsh_autosuggest_partial_accept () {
	local -i retval cursor_loc
	local original_buffer="$BUFFER" 
	BUFFER="$BUFFER$POSTDISPLAY" 
	_zsh_autosuggest_invoke_original_widget $@
	retval=$? 
	cursor_loc=$CURSOR 
	if [[ "$KEYMAP" = "vicmd" ]]
	then
		cursor_loc=$((cursor_loc + 1)) 
	fi
	if (( $cursor_loc > $#original_buffer ))
	then
		POSTDISPLAY="${BUFFER[$(($cursor_loc + 1)),$#BUFFER]}" 
		BUFFER="${BUFFER[1,$cursor_loc]}" 
	else
		BUFFER="$original_buffer" 
	fi
	return $retval
}
_zsh_autosuggest_start () {
	if (( ${+ZSH_AUTOSUGGEST_MANUAL_REBIND} ))
	then
		add-zsh-hook -d precmd _zsh_autosuggest_start
	fi
	_zsh_autosuggest_bind_widgets
}
_zsh_autosuggest_strategy_completion () {
	emulate -L zsh
	setopt EXTENDED_GLOB
	typeset -g suggestion
	local line REPLY
	whence compdef > /dev/null || return
	zmodload zsh/zpty 2> /dev/null || return
	[[ -n "$ZSH_AUTOSUGGEST_COMPLETION_IGNORE" ]] && [[ "$1" == $~ZSH_AUTOSUGGEST_COMPLETION_IGNORE ]] && return
	if zle
	then
		zpty $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME _zsh_autosuggest_capture_completion_sync
	else
		zpty $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME _zsh_autosuggest_capture_completion_async "\$1"
		zpty -w $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME $'\t'
	fi
	{
		zpty -r $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME line '*'$'\0''*'$'\0'
		suggestion="${${(@0)line}[2]}" 
	} always {
		zpty -d $ZSH_AUTOSUGGEST_COMPLETIONS_PTY_NAME
	}
}
_zsh_autosuggest_strategy_history () {
	emulate -L zsh
	setopt EXTENDED_GLOB
	local prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}" 
	local pattern="$prefix*" 
	if [[ -n $ZSH_AUTOSUGGEST_HISTORY_IGNORE ]]
	then
		pattern="($pattern)~($ZSH_AUTOSUGGEST_HISTORY_IGNORE)" 
	fi
	typeset -g suggestion="${history[(r)$pattern]}" 
}
_zsh_autosuggest_strategy_match_prev_cmd () {
	emulate -L zsh
	setopt EXTENDED_GLOB
	local prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}" 
	local pattern="$prefix*" 
	if [[ -n $ZSH_AUTOSUGGEST_HISTORY_IGNORE ]]
	then
		pattern="($pattern)~($ZSH_AUTOSUGGEST_HISTORY_IGNORE)" 
	fi
	local history_match_keys
	history_match_keys=(${(k)history[(R)$~pattern]}) 
	local histkey="${history_match_keys[1]}" 
	local prev_cmd="$(_zsh_autosuggest_escape_command "${history[$((HISTCMD-1))]}")" 
	for key in "${(@)history_match_keys[1,200]}"
	do
		[[ $key -gt 1 ]] || break
		if [[ "${history[$((key - 1))]}" == "$prev_cmd" ]]
		then
			histkey="$key" 
			break
		fi
	done
	typeset -g suggestion="$history[$histkey]" 
}
_zsh_autosuggest_suggest () {
	emulate -L zsh
	local suggestion="$1" 
	if [[ -n "$suggestion" ]] && (( $#BUFFER ))
	then
		POSTDISPLAY="${suggestion#$BUFFER}" 
	else
		unset POSTDISPLAY
	fi
}
_zsh_autosuggest_toggle () {
	if [[ -n "${_ZSH_AUTOSUGGEST_DISABLED+x}" ]]
	then
		_zsh_autosuggest_enable
	else
		_zsh_autosuggest_disable
	fi
}
_zsh_autosuggest_widget_accept () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_accept $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_clear () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_clear $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_disable () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_disable $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_enable () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_enable $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_execute () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_execute $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_fetch () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_fetch $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_modify () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_modify $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_partial_accept () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_partial_accept $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_suggest () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_suggest $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_autosuggest_widget_toggle () {
	local -i retval
	_zsh_autosuggest_highlight_reset
	_zsh_autosuggest_toggle $@
	retval=$? 
	_zsh_autosuggest_highlight_apply
	zle -R
	return $retval
}
_zsh_highlight () {
	local ret=$? 
	typeset -r ret
	(( ${+region_highlight} )) || {
		echo 'zsh-syntax-highlighting: error: $region_highlight is not defined' >&2
		echo 'zsh-syntax-highlighting: (Check whether zsh-syntax-highlighting was installed according to the instructions.)' >&2
		return $ret
	}
	(( ${+zsh_highlight__memo_feature} )) || {
		region_highlight+=(" 0 0 fg=red, memo=zsh-syntax-highlighting") 
		case ${region_highlight[-1]} in
			("0 0 fg=red") integer -gr zsh_highlight__memo_feature=0  ;;
			("0 0 fg=red memo=zsh-syntax-highlighting") integer -gr zsh_highlight__memo_feature=1  ;;
			(" 0 0 fg=red, memo=zsh-syntax-highlighting")  ;&
			(*) if is-at-least 5.8.0.3 $ZSH_VERSION.0.0
				then
					integer -gr zsh_highlight__memo_feature=1 
				else
					integer -gr zsh_highlight__memo_feature=0 
				fi ;;
		esac
		region_highlight[-1]=() 
	}
	if (( zsh_highlight__memo_feature ))
	then
		region_highlight=("${(@)region_highlight:#*memo=zsh-syntax-highlighting*}") 
	else
		region_highlight=() 
	fi
	if [[ $WIDGET == zle-isearch-update ]] && {
			$zsh_highlight__pat_static_bug || ! (( $+ISEARCHMATCH_ACTIVE ))
		}
	then
		return $ret
	fi
	local -A zsyh_user_options
	if zmodload -e zsh/parameter
	then
		zsyh_user_options=("${(kv)options[@]}") 
	else
		local canonical_options onoff option raw_options
		raw_options=(${(f)"$(emulate -R zsh; set -o)"}) 
		canonical_options=(${${${(M)raw_options:#*off}%% *}#no} ${${(M)raw_options:#*on}%% *}) 
		for option in "${canonical_options[@]}"
		do
			[[ -o $option ]]
			case $? in
				(0) zsyh_user_options+=($option on)  ;;
				(1) zsyh_user_options+=($option off)  ;;
				(*) echo "zsh-syntax-highlighting: warning: '[[ -o $option ]]' returned $?" ;;
			esac
		done
	fi
	typeset -r zsyh_user_options
	emulate -L zsh
	setopt localoptions warncreateglobal nobashrematch
	local REPLY
	[[ -n ${ZSH_HIGHLIGHT_MAXLENGTH:-} ]] && [[ $#BUFFER -gt $ZSH_HIGHLIGHT_MAXLENGTH ]] && return $ret
	[[ $PENDING -gt 0 ]] && return $ret
	{
		local cache_place
		local -a region_highlight_copy
		local highlighter
		for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS
		do
			cache_place="_zsh_highlight__highlighter_${highlighter}_cache" 
			typeset -ga ${cache_place}
			if ! type "_zsh_highlight_highlighter_${highlighter}_predicate" >&/dev/null
			then
				echo "zsh-syntax-highlighting: warning: disabling the ${(qq)highlighter} highlighter as it has not been loaded" >&2
				ZSH_HIGHLIGHT_HIGHLIGHTERS=(${ZSH_HIGHLIGHT_HIGHLIGHTERS:#${highlighter}}) 
			elif "_zsh_highlight_highlighter_${highlighter}_predicate"
			then
				region_highlight_copy=("${region_highlight[@]}") 
				region_highlight=() 
				{
					"_zsh_highlight_highlighter_${highlighter}_paint"
				} always {
					: ${(AP)cache_place::="${region_highlight[@]}"}
				}
				region_highlight=("${region_highlight_copy[@]}") 
			fi
			region_highlight+=("${(@P)cache_place}") 
		done
		() {
			(( REGION_ACTIVE )) || return
			integer min max
			if (( MARK > CURSOR ))
			then
				min=$CURSOR max=$MARK 
			else
				min=$MARK max=$CURSOR 
			fi
			if (( REGION_ACTIVE == 1 ))
			then
				[[ $KEYMAP = vicmd ]] && (( max++ ))
			elif (( REGION_ACTIVE == 2 ))
			then
				local needle=$'\n' 
				(( min = ${BUFFER[(Ib:min:)$needle]} ))
				(( max = ${BUFFER[(ib:max:)$needle]} - 1 ))
			fi
			_zsh_highlight_apply_zle_highlight region standout "$min" "$max"
		}
		(( $+YANK_ACTIVE )) && (( YANK_ACTIVE )) && _zsh_highlight_apply_zle_highlight paste standout "$YANK_START" "$YANK_END"
		(( $+ISEARCHMATCH_ACTIVE )) && (( ISEARCHMATCH_ACTIVE )) && _zsh_highlight_apply_zle_highlight isearch underline "$ISEARCHMATCH_START" "$ISEARCHMATCH_END"
		(( $+SUFFIX_ACTIVE )) && (( SUFFIX_ACTIVE )) && _zsh_highlight_apply_zle_highlight suffix bold "$SUFFIX_START" "$SUFFIX_END"
		return $ret
	} always {
		typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER="$BUFFER" 
		typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR=$CURSOR 
	}
}
_zsh_highlight__function_callable_p () {
	if _zsh_highlight__is_function_p "$1" && ! _zsh_highlight__function_is_autoload_stub_p "$1"
	then
		return 0
	else
		(
			autoload -U +X -- "$1" 2> /dev/null
		)
		return $?
	fi
}
_zsh_highlight__function_is_autoload_stub_p () {
	if zmodload -e zsh/parameter
	then
		[[ "$functions[$1]" == *"builtin autoload -X"* ]]
	else
		[[ "${${(@f)"$(which -- "$1")"}[2]}" == $'\t'$histchars[3]' undefined' ]]
	fi
}
_zsh_highlight__is_function_p () {
	if zmodload -e zsh/parameter
	then
		(( ${+functions[$1]} ))
	else
		[[ $(type -wa -- "$1") == *'function'* ]]
	fi
}
_zsh_highlight__zle-line-finish () {
	() {
		local -h -r WIDGET=zle-line-finish 
		_zsh_highlight
	}
}
_zsh_highlight__zle-line-pre-redraw () {
	true && _zsh_highlight "$@"
}
_zsh_highlight_add_highlight () {
	local -i start end
	local highlight
	start=$1 
	end=$2 
	shift 2
	for highlight
	do
		if (( $+ZSH_HIGHLIGHT_STYLES[$highlight] ))
		then
			region_highlight+=("$start $end $ZSH_HIGHLIGHT_STYLES[$highlight], memo=zsh-syntax-highlighting") 
			break
		fi
	done
}
_zsh_highlight_apply_zle_highlight () {
	local entry="$1" default="$2" 
	integer first="$3" second="$4" 
	local region="${zle_highlight[(r)${entry}:*]-}" 
	if [[ -z "$region" ]]
	then
		region=$default 
	else
		region="${region#${entry}:}" 
		if [[ -z "$region" ]] || [[ "$region" == none ]]
		then
			return
		fi
	fi
	integer start end
	if (( first < second ))
	then
		start=$first end=$second 
	else
		start=$second end=$first 
	fi
	region_highlight+=("$start $end $region, memo=zsh-syntax-highlighting") 
}
_zsh_highlight_bind_widgets () {
	
}
_zsh_highlight_brackets_match () {
	case $BUFFER[$1] in
		(\() [[ $BUFFER[$2] == \) ]] ;;
		(\[) [[ $BUFFER[$2] == \] ]] ;;
		(\{) [[ $BUFFER[$2] == \} ]] ;;
		(*) false ;;
	esac
}
_zsh_highlight_buffer_modified () {
	[[ "${_ZSH_HIGHLIGHT_PRIOR_BUFFER:-}" != "$BUFFER" ]]
}
_zsh_highlight_call_widget () {
	builtin zle "$@" && _zsh_highlight
}
_zsh_highlight_cursor_moved () {
	[[ -n $CURSOR ]] && [[ -n ${_ZSH_HIGHLIGHT_PRIOR_CURSOR-} ]] && (($_ZSH_HIGHLIGHT_PRIOR_CURSOR != $CURSOR))
}
_zsh_highlight_highlighter_brackets_paint () {
	local char style
	local -i bracket_color_size=${#ZSH_HIGHLIGHT_STYLES[(I)bracket-level-*]} buflen=${#BUFFER} level=0 matchingpos pos 
	local -A levelpos lastoflevel matching
	pos=0 
	for char in ${(s..)BUFFER}
	do
		(( ++pos ))
		case $char in
			(["([{"]) levelpos[$pos]=$((++level)) 
				lastoflevel[$level]=$pos  ;;
			([")]}"]) if (( level > 0 ))
				then
					matchingpos=$lastoflevel[$level] 
					levelpos[$pos]=$((level--)) 
					if _zsh_highlight_brackets_match $matchingpos $pos
					then
						matching[$matchingpos]=$pos 
						matching[$pos]=$matchingpos 
					fi
				else
					levelpos[$pos]=-1 
				fi ;;
		esac
	done
	for pos in ${(k)levelpos}
	do
		if (( $+matching[$pos] ))
		then
			if (( bracket_color_size ))
			then
				_zsh_highlight_add_highlight $((pos - 1)) $pos bracket-level-$(( (levelpos[$pos] - 1) % bracket_color_size + 1 ))
			fi
		else
			_zsh_highlight_add_highlight $((pos - 1)) $pos bracket-error
		fi
	done
	if [[ $WIDGET != zle-line-finish ]]
	then
		pos=$((CURSOR + 1)) 
		if (( $+levelpos[$pos] )) && (( $+matching[$pos] ))
		then
			local -i otherpos=$matching[$pos] 
			_zsh_highlight_add_highlight $((otherpos - 1)) $otherpos cursor-matchingbracket
		fi
	fi
}
_zsh_highlight_highlighter_brackets_predicate () {
	[[ $WIDGET == zle-line-finish ]] || _zsh_highlight_cursor_moved || _zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_cursor_paint () {
	[[ $WIDGET == zle-line-finish ]] && return
	_zsh_highlight_add_highlight $CURSOR $(( $CURSOR + 1 )) cursor
}
_zsh_highlight_highlighter_cursor_predicate () {
	[[ $WIDGET == zle-line-finish ]] || _zsh_highlight_cursor_moved
}
_zsh_highlight_highlighter_line_paint () {
	_zsh_highlight_add_highlight 0 $#BUFFER line
}
_zsh_highlight_highlighter_line_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_main_paint () {
	setopt localoptions extendedglob
	if [[ $CONTEXT == (select|vared) ]]
	then
		return
	fi
	typeset -a ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR
	typeset -a ZSH_HIGHLIGHT_TOKENS_CONTROL_FLOW
	local -a options_to_set reply
	local REPLY
	local flags_with_argument
	local flags_sans_argument
	local flags_solo
	local -A precommand_options
	precommand_options=('-' '' 'builtin' '' 'command' :pvV 'exec' a:cl 'noglob' '' 'doas' aCu:Lns 'nice' n: 'pkexec' '' 'sudo' Cgprtu:AEHPSbilns:eKkVv 'stdbuf' ioe: 'eatmydata' '' 'catchsegv' '' 'nohup' '' 'setsid' :wc 'env' u:i 'ionice' cn:t:pPu 'strace' IbeaosXPpEuOS:ACdfhikqrtTvVxyDc 'ssh-agent' aEPt:csDd:k 'tabbed' gnprtTuU:cdfhs 'chronic' :ev 'ifne' :n) 
	if [[ $zsyh_user_options[ignorebraces] == on || ${zsyh_user_options[ignoreclosebraces]:-off} == on ]]
	then
		local right_brace_is_recognised_everywhere=false 
	else
		local right_brace_is_recognised_everywhere=true 
	fi
	if [[ $zsyh_user_options[pathdirs] == on ]]
	then
		options_to_set+=(PATH_DIRS) 
	fi
	ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR=('|' '||' ';' '&' '&&' $'\n' '|&' '&!' '&|') 
	ZSH_HIGHLIGHT_TOKENS_CONTROL_FLOW=($'\x7b' $'\x28' '()' 'while' 'until' 'if' 'then' 'elif' 'else' 'do' 'time' 'coproc' '!') 
	if (( $+X_ZSH_HIGHLIGHT_DIRS_BLACKLIST ))
	then
		print 'zsh-syntax-highlighting: X_ZSH_HIGHLIGHT_DIRS_BLACKLIST is deprecated. Please use ZSH_HIGHLIGHT_DIRS_BLACKLIST.' >&2
		ZSH_HIGHLIGHT_DIRS_BLACKLIST=($X_ZSH_HIGHLIGHT_DIRS_BLACKLIST) 
		unset X_ZSH_HIGHLIGHT_DIRS_BLACKLIST
	fi
	_zsh_highlight_main_highlighter_highlight_list -$#PREBUFFER '' 1 "$PREBUFFER$BUFFER"
	local start end_ style
	for start end_ style in $reply
	do
		(( start >= end_ )) && {
			print -r -- "zsh-syntax-highlighting: BUG: _zsh_highlight_highlighter_main_paint: start($start) >= end($end_)" >&2
			return
		}
		(( end_ <= 0 )) && continue
		(( start < 0 )) && start=0 
		_zsh_highlight_main_calculate_fallback $style
		_zsh_highlight_add_highlight $start $end_ $reply
	done
}
_zsh_highlight_highlighter_main_predicate () {
	[[ $WIDGET == zle-line-finish ]] || _zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_pattern_paint () {
	setopt localoptions extendedglob
	local pattern
	for pattern in ${(k)ZSH_HIGHLIGHT_PATTERNS}
	do
		_zsh_highlight_pattern_highlighter_loop "$BUFFER" "$pattern"
	done
}
_zsh_highlight_highlighter_pattern_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_regexp_paint () {
	setopt localoptions extendedglob
	local pattern
	for pattern in ${(k)ZSH_HIGHLIGHT_REGEXP}
	do
		_zsh_highlight_regexp_highlighter_loop "$BUFFER" "$pattern"
	done
}
_zsh_highlight_highlighter_regexp_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_highlighter_root_paint () {
	if (( EUID == 0 ))
	then
		_zsh_highlight_add_highlight 0 $#BUFFER root
	fi
}
_zsh_highlight_highlighter_root_predicate () {
	_zsh_highlight_buffer_modified
}
_zsh_highlight_load_highlighters () {
	setopt localoptions noksharrays bareglobqual
	[[ -d "$1" ]] || {
		print -r -- "zsh-syntax-highlighting: highlighters directory ${(qq)1} not found." >&2
		return 1
	}
	local highlighter highlighter_dir
	for highlighter_dir in $1/*/(/)
	do
		highlighter="${highlighter_dir:t}" 
		[[ -f "$highlighter_dir${highlighter}-highlighter.zsh" ]] && . "$highlighter_dir${highlighter}-highlighter.zsh"
		if type "_zsh_highlight_highlighter_${highlighter}_paint" &> /dev/null && type "_zsh_highlight_highlighter_${highlighter}_predicate" &> /dev/null
		then
			
		elif type "_zsh_highlight_${highlighter}_highlighter" &> /dev/null && type "_zsh_highlight_${highlighter}_highlighter_predicate" &> /dev/null
		then
			if false
			then
				print -r -- "zsh-syntax-highlighting: warning: ${(qq)highlighter} highlighter uses deprecated entry point names; please ask its maintainer to update it: https://github.com/zsh-users/zsh-syntax-highlighting/issues/329" >&2
			fi
			eval "_zsh_highlight_highlighter_${(q)highlighter}_paint() { _zsh_highlight_${(q)highlighter}_highlighter \"\$@\" }"
			eval "_zsh_highlight_highlighter_${(q)highlighter}_predicate() { _zsh_highlight_${(q)highlighter}_highlighter_predicate \"\$@\" }"
		else
			print -r -- "zsh-syntax-highlighting: ${(qq)highlighter} highlighter should define both required functions '_zsh_highlight_highlighter_${highlighter}_paint' and '_zsh_highlight_highlighter_${highlighter}_predicate' in ${(qq):-"$highlighter_dir${highlighter}-highlighter.zsh"}." >&2
		fi
	done
}
_zsh_highlight_main__is_global_alias () {
	if zmodload -e zsh/parameter
	then
		(( ${+galiases[$arg]} ))
	elif [[ $arg == '='* ]]
	then
		return 1
	else
		alias -L -g -- "$1" > /dev/null
	fi
}
_zsh_highlight_main__is_redirection () {
	[[ $1 == (<0-9>|)(\<|\>)* ]] && [[ $1 != (\<|\>)$'\x28'* ]] && [[ $1 != *'<'*'-'*'>'* ]]
}
_zsh_highlight_main__is_runnable () {
	if _zsh_highlight_main__type "$1"
	then
		[[ $REPLY != none ]]
	else
		return 2
	fi
}
_zsh_highlight_main__precmd_hook () {
	setopt localoptions
	if eval '[[ -o warnnestedvar ]]' 2> /dev/null
	then
		unsetopt warnnestedvar
	fi
	_zsh_highlight_main__command_type_cache=() 
}
_zsh_highlight_main__resolve_alias () {
	if zmodload -e zsh/parameter
	then
		REPLY=${aliases[$arg]} 
	else
		REPLY="${"$(alias -- $arg)"#*=}" 
	fi
}
_zsh_highlight_main__stack_pop () {
	if [[ $braces_stack[1] == $1 ]]
	then
		braces_stack=${braces_stack:1} 
		if (( $+2 ))
		then
			style=$2 
		fi
		return 0
	else
		style=unknown-token 
		return 1
	fi
}
_zsh_highlight_main__type () {
	integer -r aliases_allowed=${2-1} 
	integer may_cache=1 
	if (( $+_zsh_highlight_main__command_type_cache ))
	then
		REPLY=$_zsh_highlight_main__command_type_cache[(e)$1] 
		if [[ -n "$REPLY" ]]
		then
			return
		fi
	fi
	if (( $#options_to_set ))
	then
		setopt localoptions $options_to_set
	fi
	unset REPLY
	if zmodload -e zsh/parameter
	then
		if (( $+aliases[(e)$1] ))
		then
			may_cache=0 
		fi
		if (( ${+galiases[(e)$1]} )) && (( aliases_allowed ))
		then
			REPLY='global alias' 
		elif (( $+aliases[(e)$1] )) && (( aliases_allowed ))
		then
			REPLY=alias 
		elif [[ $1 == *.* && -n ${1%.*} ]] && (( $+saliases[(e)${1##*.}] ))
		then
			REPLY='suffix alias' 
		elif (( $reswords[(Ie)$1] ))
		then
			REPLY=reserved 
		elif (( $+functions[(e)$1] ))
		then
			REPLY=function 
		elif (( $+builtins[(e)$1] ))
		then
			REPLY=builtin 
		elif (( $+commands[(e)$1] ))
		then
			REPLY=command 
		elif {
				[[ $1 != */* ]] || is-at-least 5.3
			} && ! (
				builtin type -w -- "$1"
			) > /dev/null 2>&1
		then
			REPLY=none 
		fi
	fi
	if ! (( $+REPLY ))
	then
		REPLY="${$(:; (( aliases_allowed )) || unalias -- "$1" 2>/dev/null; LC_ALL=C builtin type -w -- "$1" 2>/dev/null)##*: }" 
		if [[ $REPLY == 'alias' ]]
		then
			may_cache=0 
		fi
	fi
	if (( may_cache )) && (( $+_zsh_highlight_main__command_type_cache ))
	then
		_zsh_highlight_main__command_type_cache[(e)$1]=$REPLY 
	fi
	[[ -n $REPLY ]]
	return $?
}
_zsh_highlight_main_add_many_region_highlights () {
	for 1 2 3
	do
		_zsh_highlight_main_add_region_highlight $1 $2 $3
	done
}
_zsh_highlight_main_add_region_highlight () {
	integer start=$1 end=$2 
	shift 2
	if (( in_alias ))
	then
		[[ $1 == unknown-token ]] && alias_style=unknown-token 
		return
	fi
	if (( in_param ))
	then
		if [[ $1 == unknown-token ]]
		then
			param_style=unknown-token 
		fi
		if [[ -n $param_style ]]
		then
			return
		fi
		param_style=$1 
		return
	fi
	(( start += buf_offset ))
	(( end += buf_offset ))
	list_highlights+=($start $end $1) 
}
_zsh_highlight_main_calculate_fallback () {
	local -A fallback_of
	fallback_of=(alias arg0 suffix-alias arg0 global-alias dollar-double-quoted-argument builtin arg0 function arg0 command arg0 precommand arg0 hashed-command arg0 autodirectory arg0 arg0_\* arg0 path_prefix path path_pathseparator path path_prefix_pathseparator path_prefix single-quoted-argument{-unclosed,} double-quoted-argument{-unclosed,} dollar-quoted-argument{-unclosed,} back-quoted-argument{-unclosed,} command-substitution{-quoted,,-unquoted,} command-substitution-delimiter{-quoted,,-unquoted,} command-substitution{-delimiter,} process-substitution{-delimiter,} back-quoted-argument{-delimiter,}) 
	local needle=$1 value 
	reply=($1) 
	while [[ -n ${value::=$fallback_of[(k)$needle]} ]]
	do
		unset "fallback_of[$needle]"
		reply+=($value) 
		needle=$value 
	done
}
_zsh_highlight_main_highlighter__try_expand_parameter () {
	local arg="$1" 
	unset reply
	{
		{
			local -a match mbegin mend
			local MATCH
			integer MBEGIN MEND
			local parameter_name
			local -a words
			if [[ $arg[1] != '$' ]]
			then
				return 1
			fi
			if [[ ${arg[2]} == '{' ]] && [[ ${arg[-1]} == '}' ]]
			then
				parameter_name=${${arg:2}%?} 
			else
				parameter_name=${arg:1} 
			fi
			if [[ $res == none ]] && [[ ${parameter_name} =~ ^${~parameter_name_pattern}$ ]] && [[ ${(tP)MATCH} != *special* ]]
			then
				case ${(tP)MATCH} in
					(*array*|*assoc*) words=(${(P)MATCH})  ;;
					("") words=()  ;;
					(*) words=(${(P)MATCH})  ;;
				esac
				reply=("${words[@]}") 
			else
				return 1
			fi
		}
	}
}
_zsh_highlight_main_highlighter_check_assign () {
	setopt localoptions extended_glob
	[[ $arg == [[:alpha:]_][[:alnum:]_]#(|\[*\])(|[+])=* ]] || [[ $arg == [0-9]##(|[+])=* ]]
}
_zsh_highlight_main_highlighter_check_path () {
	_zsh_highlight_main_highlighter_expand_path "$1"
	local expanded_path="$REPLY" tmp_path 
	integer in_command_position=$2 
	if [[ $zsyh_user_options[autocd] == on ]]
	then
		integer autocd=1 
	else
		integer autocd=0 
	fi
	if (( in_command_position ))
	then
		REPLY=arg0 
	else
		REPLY=path 
	fi
	if [[ ${1[1]} == '=' && $1 == ??* && ${1[2]} != $'\x28' && $zsyh_user_options[equals] == 'on' && $expanded_path[1] != '/' ]]
	then
		REPLY=unknown-token 
		return 0
	fi
	[[ -z $expanded_path ]] && return 1
	if [[ $expanded_path[1] == / ]]
	then
		tmp_path=$expanded_path 
	else
		tmp_path=$PWD/$expanded_path 
	fi
	tmp_path=$tmp_path:a 
	while [[ $tmp_path != / ]]
	do
		[[ -n ${(M)ZSH_HIGHLIGHT_DIRS_BLACKLIST:#$tmp_path} ]] && return 1
		tmp_path=$tmp_path:h 
	done
	if (( in_command_position ))
	then
		if [[ -x $expanded_path ]]
		then
			if (( autocd ))
			then
				if [[ -d $expanded_path ]]
				then
					REPLY=autodirectory 
				fi
				return 0
			elif [[ ! -d $expanded_path ]]
			then
				return 0
			fi
		fi
	else
		if [[ -L $expanded_path || -e $expanded_path ]]
		then
			return 0
		fi
	fi
	if [[ $expanded_path != /* ]] && (( autocd || ! in_command_position ))
	then
		local cdpath_dir
		for cdpath_dir in $cdpath
		do
			if [[ -d "$cdpath_dir/$expanded_path" && -x "$cdpath_dir/$expanded_path" ]]
			then
				if (( in_command_position && autocd ))
				then
					REPLY=autodirectory 
				fi
				return 0
			fi
		done
	fi
	[[ ! -d ${expanded_path:h} ]] && return 1
	if (( has_end && (len == end_pos) )) && (( ! in_alias )) && [[ $WIDGET != zle-line-finish ]]
	then
		local -a tmp
		if (( in_command_position ))
		then
			tmp=(${expanded_path}*(N-*,N-/)) 
		else
			tmp=(${expanded_path}*(N)) 
		fi
		(( ${+tmp[1]} )) && REPLY=path_prefix  && return 0
	fi
	return 1
}
_zsh_highlight_main_highlighter_expand_path () {
	(( $# == 1 )) || print -r -- "zsh-syntax-highlighting: BUG: _zsh_highlight_main_highlighter_expand_path: called without argument" >&2
	setopt localoptions nonomatch
	unset REPLY
	: ${REPLY:=${(Q)${~1}}}
}
_zsh_highlight_main_highlighter_highlight_argument () {
	local base_style=default i=$1 option_eligible=${2:-1} path_eligible=1 ret start style 
	local -a highlights
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	case "$arg[i]" in
		('%') if [[ $arg[i+1] == '?' ]]
			then
				(( i += 2 ))
			fi ;;
		('-') if (( option_eligible ))
			then
				if [[ $arg[i+1] == - ]]
				then
					base_style=double-hyphen-option 
				else
					base_style=single-hyphen-option 
				fi
				path_eligible=0 
			fi ;;
		('=') if [[ $arg[i+1] == $'\x28' ]]
			then
				(( i += 2 ))
				_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
				ret=$? 
				(( i += REPLY ))
				highlights+=($(( start_pos + $1 - 1 )) $(( start_pos + i )) process-substitution $(( start_pos + $1 - 1 )) $(( start_pos + $1 + 1 )) process-substitution-delimiter $reply) 
				if (( ret == 0 ))
				then
					highlights+=($(( start_pos + i - 1 )) $(( start_pos + i )) process-substitution-delimiter) 
				fi
			fi ;;
	esac
	(( --i ))
	while (( ++i <= $#arg ))
	do
		i=${arg[(ib.i.)[\\\'\"\`\$\<\>\*\?]]} 
		case "$arg[$i]" in
			("") break ;;
			("\\") (( i += 1 ))
				continue ;;
			("'") _zsh_highlight_main_highlighter_highlight_single_quote $i
				(( i = REPLY ))
				highlights+=($reply)  ;;
			('"') _zsh_highlight_main_highlighter_highlight_double_quote $i
				(( i = REPLY ))
				highlights+=($reply)  ;;
			('`') _zsh_highlight_main_highlighter_highlight_backtick $i
				(( i = REPLY ))
				highlights+=($reply)  ;;
			('$') if [[ $arg[i+1] != "'" ]]
				then
					path_eligible=0 
				fi
				if [[ $arg[i+1] == "'" ]]
				then
					_zsh_highlight_main_highlighter_highlight_dollar_quote $i
					(( i = REPLY ))
					highlights+=($reply) 
					continue
				elif [[ $arg[i+1] == $'\x28' ]]
				then
					if [[ $arg[i+2] == $'\x28' ]] && _zsh_highlight_main_highlighter_highlight_arithmetic $i
					then
						(( i = REPLY ))
						highlights+=($reply) 
						continue
					fi
					start=$i 
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
					ret=$? 
					(( i += REPLY ))
					highlights+=($(( start_pos + start - 1)) $(( start_pos + i )) command-substitution-unquoted $(( start_pos + start - 1)) $(( start_pos + start + 1)) command-substitution-delimiter-unquoted $reply) 
					if (( ret == 0 ))
					then
						highlights+=($(( start_pos + i - 1)) $(( start_pos + i )) command-substitution-delimiter-unquoted) 
					fi
					continue
				fi
				while [[ $arg[i+1] == [=~#+'^'] ]]
				do
					(( i += 1 ))
				done
				if [[ $arg[i+1] == [*@#?$!-] ]]
				then
					(( i += 1 ))
				fi ;;
			([\<\>]) if [[ $arg[i+1] == $'\x28' ]]
				then
					start=$i 
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
					ret=$? 
					(( i += REPLY ))
					highlights+=($(( start_pos + start - 1)) $(( start_pos + i )) process-substitution $(( start_pos + start - 1)) $(( start_pos + start + 1 )) process-substitution-delimiter $reply) 
					if (( ret == 0 ))
					then
						highlights+=($(( start_pos + i - 1)) $(( start_pos + i )) process-substitution-delimiter) 
					fi
					continue
				fi ;|
			(*) if $highlight_glob && [[ $zsyh_user_options[multios] == on || $in_redirection -eq 0 ]] && [[ ${arg[$i]} =~ ^[*?] || ${arg:$i-1} =~ ^\<[0-9]*-[0-9]*\> ]]
				then
					highlights+=($(( start_pos + i - 1 )) $(( start_pos + i + $#MATCH - 1)) globbing) 
					(( i += $#MATCH - 1 ))
					path_eligible=0 
				else
					continue
				fi ;;
		esac
	done
	if (( path_eligible ))
	then
		if (( in_redirection )) && [[ $last_arg == *['<>']['&'] && $arg[$1,-1] == (<0->|p|-) ]]
		then
			if [[ $arg[$1,-1] == (p|-) ]]
			then
				base_style=redirection 
			else
				base_style=numeric-fd 
			fi
		elif _zsh_highlight_main_highlighter_check_path $arg[$1,-1] 0
		then
			base_style=$REPLY 
			_zsh_highlight_main_highlighter_highlight_path_separators $base_style
			highlights+=($reply) 
		fi
	fi
	highlights=($(( start_pos + $1 - 1 )) $end_pos $base_style $highlights) 
	_zsh_highlight_main_add_many_region_highlights $highlights
}
_zsh_highlight_main_highlighter_highlight_arithmetic () {
	local -a saved_reply
	local style
	integer i j k paren_depth ret
	reply=() 
	for ((i = $1 + 3 ; i <= end_pos - start_pos ; i += 1 )) do
		(( j = i + start_pos - 1 ))
		(( k = j + 1 ))
		case "$arg[$i]" in
			([\'\"\\@{}]) style=unknown-token  ;;
			('(') (( paren_depth++ ))
				continue ;;
			(')') if (( paren_depth ))
				then
					(( paren_depth-- ))
					continue
				fi
				[[ $arg[i+1] == ')' ]] && {
					(( i++ ))
					break
				}
				(( has_end && (len == k) )) && break
				return 1 ;;
			('`') saved_reply=($reply) 
				_zsh_highlight_main_highlighter_highlight_backtick $i
				(( i = REPLY ))
				reply=($saved_reply $reply) 
				continue ;;
			('$') if [[ $arg[i+1] == $'\x28' ]]
				then
					saved_reply=($reply) 
					if [[ $arg[i+2] == $'\x28' ]] && _zsh_highlight_main_highlighter_highlight_arithmetic $i
					then
						(( i = REPLY ))
						reply=($saved_reply $reply) 
						continue
					fi
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,end_pos]
					ret=$? 
					(( i += REPLY ))
					reply=($saved_reply $j $(( start_pos + i )) command-substitution-quoted $j $(( j + 2 )) command-substitution-delimiter-quoted $reply) 
					if (( ret == 0 ))
					then
						reply+=($(( start_pos + i - 1 )) $(( start_pos + i )) command-substitution-delimiter) 
					fi
					continue
				else
					continue
				fi ;;
			($histchars[1]) if [[ $arg[i+1] != ('='|$'\x28'|$'\x7b'|[[:blank:]]) ]]
				then
					style=history-expansion 
				else
					continue
				fi ;;
			(*) continue ;;
		esac
		reply+=($j $k $style) 
	done
	if [[ $arg[i] != ')' ]]
	then
		(( i-- ))
	fi
	style=arithmetic-expansion 
	reply=($(( start_pos + $1 - 1)) $(( start_pos + i )) arithmetic-expansion $reply) 
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_backtick () {
	local buf highlight style=back-quoted-argument-unclosed style_end 
	local -i arg1=$1 end_ i=$1 last offset=0 start subshell_has_end=0 
	local -a highlight_zone highlights offsets
	reply=() 
	last=$(( arg1 + 1 )) 
	while i=$arg[(ib:i+1:)[\\\\\`]] 
	do
		if (( i > $#arg ))
		then
			buf=$buf$arg[last,i] 
			offsets[i-arg1-offset]='' 
			(( i-- ))
			subshell_has_end=$(( has_end && (start_pos + i == len) )) 
			break
		fi
		if [[ $arg[i] == '\' ]]
		then
			(( i++ ))
			if [[ $arg[i] == ('$'|'`'|'\') ]]
			then
				buf=$buf$arg[last,i-2] 
				(( offset++ ))
				offsets[i-arg1-offset]=$offset 
			else
				buf=$buf$arg[last,i-1] 
			fi
		else
			style=back-quoted-argument 
			style_end=back-quoted-argument-delimiter 
			buf=$buf$arg[last,i-1] 
			offsets[i-arg1-offset]='' 
			break
		fi
		last=$i 
	done
	_zsh_highlight_main_highlighter_highlight_list 0 '' $subshell_has_end $buf
	for start end_ highlight in $reply
	do
		start=$(( start_pos + arg1 + start + offsets[(Rb:start:)?*] )) 
		end_=$(( start_pos + arg1 + end_ + offsets[(Rb:end_:)?*] )) 
		highlights+=($start $end_ $highlight) 
		if [[ $highlight == back-quoted-argument-unclosed && $style == back-quoted-argument ]]
		then
			style_end=unknown-token 
		fi
	done
	reply=($(( start_pos + arg1 - 1 )) $(( start_pos + i )) $style $(( start_pos + arg1 - 1 )) $(( start_pos + arg1 )) back-quoted-argument-delimiter $highlights) 
	if (( $#style_end ))
	then
		reply+=($(( start_pos + i - 1)) $(( start_pos + i )) $style_end) 
	fi
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_dollar_quote () {
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	local i j k style
	local AA
	integer c
	reply=() 
	for ((i = $1 + 2 ; i <= $#arg ; i += 1 )) do
		(( j = i + start_pos - 1 ))
		(( k = j + 1 ))
		case "$arg[$i]" in
			("'") break ;;
			("\\") style=back-dollar-quoted-argument 
				for ((c = i + 1 ; c <= $#arg ; c += 1 )) do
					[[ "$arg[$c]" != ([0-9xXuUa-fA-F]) ]] && break
				done
				AA=$arg[$i+1,$c-1] 
				if [[ "$AA" =~ "^(x|X)[0-9a-fA-F]{1,2}" || "$AA" =~ "^[0-7]{1,3}" || "$AA" =~ "^u[0-9a-fA-F]{1,4}" || "$AA" =~ "^U[0-9a-fA-F]{1,8}" ]]
				then
					(( k += $#MATCH ))
					(( i += $#MATCH ))
				else
					if (( $#arg > $i+1 )) && [[ $arg[$i+1] == [xXuU] ]]
					then
						style=unknown-token 
					fi
					(( k += 1 ))
					(( i += 1 ))
				fi ;;
			(*) continue ;;
		esac
		reply+=($j $k $style) 
	done
	if [[ $arg[i] == "'" ]]
	then
		style=dollar-quoted-argument 
	else
		(( i-- ))
		style=dollar-quoted-argument-unclosed 
	fi
	reply=($(( start_pos + $1 - 1 )) $(( start_pos + i )) $style $reply) 
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_double_quote () {
	local -a breaks match mbegin mend saved_reply
	local MATCH
	integer last_break=$(( start_pos + $1 - 1 )) MBEGIN MEND 
	local i j k ret style
	reply=() 
	for ((i = $1 + 1 ; i <= $#arg ; i += 1 )) do
		(( j = i + start_pos - 1 ))
		(( k = j + 1 ))
		case "$arg[$i]" in
			('"') break ;;
			('`') saved_reply=($reply) 
				_zsh_highlight_main_highlighter_highlight_backtick $i
				(( i = REPLY ))
				reply=($saved_reply $reply) 
				continue ;;
			('$') style=dollar-double-quoted-argument 
				if [[ ${arg:$i} =~ ^([A-Za-z_][A-Za-z0-9_]*|[0-9]+) ]]
				then
					(( k += $#MATCH ))
					(( i += $#MATCH ))
				elif [[ ${arg:$i} =~ ^[{]([A-Za-z_][A-Za-z0-9_]*|[0-9]+)[}] ]]
				then
					(( k += $#MATCH ))
					(( i += $#MATCH ))
				elif [[ $arg[i+1] == '$' ]]
				then
					(( k += 1 ))
					(( i += 1 ))
				elif [[ $arg[i+1] == [-#*@?] ]]
				then
					(( k += 1 ))
					(( i += 1 ))
				elif [[ $arg[i+1] == $'\x28' ]]
				then
					saved_reply=($reply) 
					if [[ $arg[i+2] == $'\x28' ]] && _zsh_highlight_main_highlighter_highlight_arithmetic $i
					then
						(( i = REPLY ))
						reply=($saved_reply $reply) 
						continue
					fi
					breaks+=($last_break $(( start_pos + i - 1 ))) 
					(( i += 2 ))
					_zsh_highlight_main_highlighter_highlight_list $(( start_pos + i - 1 )) S $has_end $arg[i,-1]
					ret=$? 
					(( i += REPLY ))
					last_break=$(( start_pos + i )) 
					reply=($saved_reply $j $(( start_pos + i )) command-substitution-quoted $j $(( j + 2 )) command-substitution-delimiter-quoted $reply) 
					if (( ret == 0 ))
					then
						reply+=($(( start_pos + i - 1 )) $(( start_pos + i )) command-substitution-delimiter-quoted) 
					fi
					continue
				else
					continue
				fi ;;
			("\\") style=back-double-quoted-argument 
				if [[ \\\`\"\$${histchars[1]} == *$arg[$i+1]* ]]
				then
					(( k += 1 ))
					(( i += 1 ))
				else
					continue
				fi ;;
			($histchars[1]) if [[ $arg[i+1] != ('='|$'\x28'|$'\x7b'|[[:blank:]]) ]]
				then
					style=history-expansion 
				else
					continue
				fi ;;
			(*) continue ;;
		esac
		reply+=($j $k $style) 
	done
	if [[ $arg[i] == '"' ]]
	then
		style=double-quoted-argument 
	else
		(( i-- ))
		style=double-quoted-argument-unclosed 
	fi
	(( last_break != start_pos + i )) && breaks+=($last_break $(( start_pos + i ))) 
	saved_reply=($reply) 
	reply=() 
	for 1 2 in $breaks
	do
		(( $1 != $2 )) && reply+=($1 $2 $style) 
	done
	reply+=($saved_reply) 
	REPLY=$i 
}
_zsh_highlight_main_highlighter_highlight_list () {
	integer start_pos end_pos=0 buf_offset=$1 has_end=$3 
	local alias_style param_style last_arg arg buf=$4 highlight_glob=true saw_assignment=false style 
	local in_array_assignment=false 
	integer in_alias=0 in_param=0 len=$#buf 
	local -a match mbegin mend list_highlights
	local -A seen_alias
	readonly parameter_name_pattern='([A-Za-z_][A-Za-z0-9_]*|[0-9]+)' 
	list_highlights=() 
	local braces_stack=$2 
	local this_word next_word=':start::start_of_pipeline:' 
	integer in_redirection
	local proc_buf="$buf" 
	local -a args
	if [[ $zsyh_user_options[interactivecomments] == on ]]
	then
		args=(${(zZ+c+)buf}) 
	else
		args=(${(z)buf}) 
	fi
	if [[ $braces_stack == 'S' ]] && (( $+args[3] && ! $+args[4] )) && [[ $args[3] == $'\x29' ]] && [[ $args[1] == *'<'* ]] && _zsh_highlight_main__is_redirection $args[1]
	then
		highlight_glob=false 
	fi
	while (( $#args ))
	do
		last_arg=$arg 
		arg=$args[1] 
		shift args
		if (( in_alias ))
		then
			(( in_alias-- ))
			if (( in_alias == 0 ))
			then
				seen_alias=() 
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos $alias_style
			fi
		fi
		if (( in_param ))
		then
			(( in_param-- ))
			if (( in_param == 0 ))
			then
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos $param_style
				param_style="" 
			fi
		fi
		if (( in_redirection == 0 ))
		then
			this_word=$next_word 
			next_word=':regular:' 
		elif (( !in_param ))
		then
			(( --in_redirection ))
		fi
		style=unknown-token 
		if [[ $this_word == *':start:'* ]]
		then
			in_array_assignment=false 
			if [[ $arg == 'noglob' ]]
			then
				highlight_glob=false 
			fi
		fi
		if (( in_alias == 0 && in_param == 0 ))
		then
			[[ "$proc_buf" = (#b)(#s)(([ $'\t']|[\\]$'\n')#)(?|)* ]]
			integer offset="${#match[1]}" 
			(( start_pos = end_pos + offset ))
			(( end_pos = start_pos + $#arg ))
			[[ $arg == ';' && ${match[3]} == $'\n' ]] && arg=$'\n' 
			proc_buf="${proc_buf[offset + $#arg + 1,len]}" 
		fi
		if [[ $zsyh_user_options[interactivecomments] == on && $arg[1] == $histchars[3] ]]
		then
			if [[ $this_word == *(':regular:'|':start:')* ]]
			then
				style=comment 
			else
				style=unknown-token 
			fi
			_zsh_highlight_main_add_region_highlight $start_pos $end_pos $style
			in_redirection=1 
			continue
		fi
		if [[ $this_word == *':start:'* ]] && ! (( in_redirection ))
		then
			_zsh_highlight_main__type "$arg" "$(( ! ${+seen_alias[$arg]} ))"
			local res="$REPLY" 
			if [[ $res == "alias" ]]
			then
				if [[ $arg == ?*=* ]]
				then
					(( in_alias == 0 )) && in_alias=1 
					_zsh_highlight_main_add_region_highlight $start_pos $end_pos unknown-token
					continue
				fi
				seen_alias[$arg]=1 
				_zsh_highlight_main__resolve_alias $arg
				local -a alias_args
				if [[ $zsyh_user_options[interactivecomments] == on ]]
				then
					alias_args=(${(zZ+c+)REPLY}) 
				else
					alias_args=(${(z)REPLY}) 
				fi
				args=($alias_args $args) 
				if (( in_alias == 0 ))
				then
					alias_style=alias 
					(( in_alias += $#alias_args + 1 ))
				else
					(( in_alias += $#alias_args ))
				fi
				(( in_redirection++ ))
				continue
			else
				_zsh_highlight_main_highlighter_expand_path $arg
				_zsh_highlight_main__type "$REPLY" 0
				res="$REPLY" 
			fi
		fi
		if _zsh_highlight_main__is_redirection $arg
		then
			if (( in_redirection == 1 ))
			then
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos unknown-token
			else
				in_redirection=2 
				_zsh_highlight_main_add_region_highlight $start_pos $end_pos redirection
			fi
			continue
		elif [[ $arg == '{'${~parameter_name_pattern}'}' ]] && _zsh_highlight_main__is_redirection $args[1]
		then
			in_redirection=3 
			_zsh_highlight_main_add_region_highlight $start_pos $end_pos named-fd
			continue
		fi
		if (( ! in_param )) && _zsh_highlight_main_highlighter__try_expand_parameter "$arg"
		then
			() {
				local -a words
				words=("${reply[@]}") 
				if (( $#words == 0 )) && (( ! in_redirection ))
				then
					(( ++in_redirection ))
					_zsh_highlight_main_add_region_highlight $start_pos $end_pos comment
					continue
				else
					(( in_param = 1 + $#words ))
					args=($words $args) 
					arg=$args[1] 
					_zsh_highlight_main__type "$arg" 0
					res=$REPLY 
				fi
			}
		fi
		if (( ! in_redirection ))
		then
			if [[ $this_word == *':sudo_opt:'* ]]
			then
				if [[ -n $flags_with_argument ]] && {
						if [[ -n $flags_sans_argument ]]
						then
							[[ $arg == '-'[$flags_sans_argument]#[$flags_with_argument] ]]
						else
							[[ $arg == '-'[$flags_with_argument] ]]
						fi
					}
				then
					this_word=${this_word//:start:/} 
					next_word=':sudo_arg:' 
				elif [[ -n $flags_with_argument ]] && {
						if [[ -n $flags_sans_argument ]]
						then
							[[ $arg == '-'[$flags_sans_argument]#[$flags_with_argument]* ]]
						else
							[[ $arg == '-'[$flags_with_argument]* ]]
						fi
					}
				then
					this_word=${this_word//:start:/} 
					next_word+=':start:' 
					next_word+=':sudo_opt:' 
				elif [[ -n $flags_sans_argument ]] && [[ $arg == '-'[$flags_sans_argument]# ]]
				then
					this_word=':sudo_opt:' 
					next_word+=':start:' 
					next_word+=':sudo_opt:' 
				elif [[ -n $flags_solo ]] && {
						if [[ -n $flags_sans_argument ]]
						then
							[[ $arg == '-'[$flags_sans_argument]#[$flags_solo]* ]]
						else
							[[ $arg == '-'[$flags_solo]* ]]
						fi
					}
				then
					this_word=':sudo_opt:' 
					next_word=':regular:' 
				elif [[ $arg == '-'* ]]
				then
					this_word=':sudo_opt:' 
					next_word+=':start:' 
					next_word+=':sudo_opt:' 
				else
					this_word=${this_word//:sudo_opt:/} 
				fi
			elif [[ $this_word == *':sudo_arg:'* ]]
			then
				next_word+=':sudo_opt:' 
				next_word+=':start:' 
			fi
		fi
		if [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR:#"$arg"} ]] && [[ $braces_stack != *T* || $arg != ('||'|'&&') ]]
		then
			if _zsh_highlight_main__stack_pop T || _zsh_highlight_main__stack_pop Q
			then
				style=unknown-token 
			elif $in_array_assignment
			then
				case $arg in
					($'\n') style=commandseparator  ;;
					(';') style=unknown-token  ;;
					(*) style=unknown-token  ;;
				esac
			elif [[ $this_word == *':regular:'* ]]
			then
				style=commandseparator 
			elif [[ $this_word == *':start:'* ]] && [[ $arg == $'\n' ]]
			then
				style=commandseparator 
			elif [[ $this_word == *':start:'* ]] && [[ $arg == ';' ]] && (( in_alias ))
			then
				style=commandseparator 
			else
				style=unknown-token 
			fi
			if [[ $arg == $'\n' ]] && $in_array_assignment
			then
				next_word=':regular:' 
			elif [[ $arg == ';' ]] && $in_array_assignment
			then
				next_word=':regular:' 
			else
				next_word=':start:' 
				highlight_glob=true 
				saw_assignment=false 
				if [[ $arg != '|' && $arg != '|&' ]]
				then
					next_word+=':start_of_pipeline:' 
				fi
			fi
		elif ! (( in_redirection)) && [[ $this_word == *':always:'* && $arg == 'always' ]]
		then
			style=reserved-word 
			highlight_glob=true 
			saw_assignment=false 
			next_word=':start::start_of_pipeline:' 
		elif ! (( in_redirection)) && [[ $this_word == *':start:'* ]]
		then
			if (( ${+precommand_options[$arg]} )) && _zsh_highlight_main__is_runnable $arg
			then
				style=precommand 
				() {
					set -- "${(@s.:.)precommand_options[$arg]}"
					flags_with_argument=$1 
					flags_sans_argument=$2 
					flags_solo=$3 
				}
				next_word=${next_word//:regular:/} 
				next_word+=':sudo_opt:' 
				next_word+=':start:' 
				if [[ $arg == 'exec' ]]
				then
					next_word+=':regular:' 
				fi
			else
				case $res in
					(reserved) style=reserved-word 
						case $arg in
							(time|nocorrect) next_word=${next_word//:regular:/} 
								next_word+=':start:'  ;;
							($'\x7b') braces_stack='Y'"$braces_stack"  ;;
							($'\x7d') _zsh_highlight_main__stack_pop 'Y' reserved-word
								if [[ $style == reserved-word ]]
								then
									next_word+=':always:' 
								fi ;;
							($'\x5b\x5b') braces_stack='T'"$braces_stack"  ;;
							('do') braces_stack='D'"$braces_stack"  ;;
							('done') _zsh_highlight_main__stack_pop 'D' reserved-word ;;
							('if') braces_stack=':?'"$braces_stack"  ;;
							('then') _zsh_highlight_main__stack_pop ':' reserved-word ;;
							('elif') if [[ ${braces_stack[1]} == '?' ]]
								then
									braces_stack=':'"$braces_stack" 
								else
									style=unknown-token 
								fi ;;
							('else') if [[ ${braces_stack[1]} == '?' ]]
								then
									:
								else
									style=unknown-token 
								fi ;;
							('fi') _zsh_highlight_main__stack_pop '?' ;;
							('foreach') braces_stack='$'"$braces_stack"  ;;
							('end') _zsh_highlight_main__stack_pop '$' reserved-word ;;
							('repeat') in_redirection=2 
								this_word=':start::regular:'  ;;
							('!') if [[ $this_word != *':start_of_pipeline:'* ]]
								then
									style=unknown-token 
								else
									
								fi ;;
						esac
						if $saw_assignment && [[ $style != unknown-token ]]
						then
							style=unknown-token 
						fi ;;
					('suffix alias') style=suffix-alias  ;;
					('global alias') style=global-alias  ;;
					(alias) : ;;
					(builtin) style=builtin 
						[[ $arg == $'\x5b' ]] && braces_stack='Q'"$braces_stack"  ;;
					(function) style=function  ;;
					(command) style=command  ;;
					(hashed) style=hashed-command  ;;
					(none) if (( ! in_param )) && _zsh_highlight_main_highlighter_check_assign
						then
							_zsh_highlight_main_add_region_highlight $start_pos $end_pos assign
							local i=$(( arg[(i)=] + 1 )) 
							saw_assignment=true 
							if [[ $arg[i] == '(' ]]
							then
								in_array_assignment=true 
								_zsh_highlight_main_add_region_highlight start_pos+i-1 start_pos+i reserved-word
							else
								next_word+=':start:' 
								if (( i <= $#arg ))
								then
									() {
										local highlight_glob=false 
										[[ $zsyh_user_options[globassign] == on ]] && highlight_glob=true 
										_zsh_highlight_main_highlighter_highlight_argument $i
									}
								fi
							fi
							continue
						elif (( ! in_param )) && [[ $arg[0,1] = $histchars[0,1] ]] && (( $#arg[0,2] == 2 ))
						then
							style=history-expansion 
						elif (( ! in_param )) && [[ $arg[0,1] == $histchars[2,2] ]]
						then
							style=history-expansion 
						elif (( ! in_param )) && ! $saw_assignment && [[ $arg[1,2] == '((' ]]
						then
							_zsh_highlight_main_add_region_highlight $start_pos $((start_pos + 2)) reserved-word
							if [[ $arg[-2,-1] == '))' ]]
							then
								_zsh_highlight_main_add_region_highlight $((end_pos - 2)) $end_pos reserved-word
							fi
							continue
						elif (( ! in_param )) && [[ $arg == '()' ]]
						then
							style=reserved-word 
						elif (( ! in_param )) && ! $saw_assignment && [[ $arg == $'\x28' ]]
						then
							style=reserved-word 
							braces_stack='R'"$braces_stack" 
						elif (( ! in_param )) && [[ $arg == $'\x29' ]]
						then
							if _zsh_highlight_main__stack_pop 'S'
							then
								REPLY=$start_pos 
								reply=($list_highlights) 
								return 0
							fi
							_zsh_highlight_main__stack_pop 'R' reserved-word
						else
							if _zsh_highlight_main_highlighter_check_path $arg 1
							then
								style=$REPLY 
							else
								style=unknown-token 
							fi
						fi ;;
					(*) _zsh_highlight_main_add_region_highlight $start_pos $end_pos arg0_$res
						continue ;;
				esac
			fi
			if [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_CONTROL_FLOW:#"$arg"} ]]
			then
				next_word=':start::start_of_pipeline:' 
			fi
		elif _zsh_highlight_main__is_global_alias "$arg"
		then
			style=global-alias 
		else
			case $arg in
				($'\x29') if $in_array_assignment
					then
						_zsh_highlight_main_add_region_highlight $start_pos $end_pos assign
						_zsh_highlight_main_add_region_highlight $start_pos $end_pos reserved-word
						in_array_assignment=false 
						next_word+=':start:' 
						continue
					elif (( in_redirection ))
					then
						style=unknown-token 
					else
						if _zsh_highlight_main__stack_pop 'S'
						then
							REPLY=$start_pos 
							reply=($list_highlights) 
							return 0
						fi
						_zsh_highlight_main__stack_pop 'R' reserved-word
					fi ;;
				($'\x28\x29') if (( in_redirection )) || $in_array_assignment
					then
						style=unknown-token 
					else
						if [[ $zsyh_user_options[multifuncdef] == on ]] || false
						then
							next_word+=':start::start_of_pipeline:' 
						fi
						style=reserved-word 
					fi ;;
				(*) if false
					then
						
					elif [[ $arg = $'\x7d' ]] && $right_brace_is_recognised_everywhere
					then
						if (( in_redirection )) || $in_array_assignment
						then
							style=unknown-token 
						else
							_zsh_highlight_main__stack_pop 'Y' reserved-word
							if [[ $style == reserved-word ]]
							then
								next_word+=':always:' 
							fi
						fi
					elif [[ $arg[0,1] = $histchars[0,1] ]] && (( $#arg[0,2] == 2 ))
					then
						style=history-expansion 
					elif [[ $arg == $'\x5d\x5d' ]] && _zsh_highlight_main__stack_pop 'T' reserved-word
					then
						:
					elif [[ $arg == $'\x5d' ]] && _zsh_highlight_main__stack_pop 'Q' builtin
					then
						:
					else
						_zsh_highlight_main_highlighter_highlight_argument 1 $(( 1 != in_redirection ))
						continue
					fi ;;
			esac
		fi
		_zsh_highlight_main_add_region_highlight $start_pos $end_pos $style
	done
	(( in_alias == 1 )) && in_alias=0 _zsh_highlight_main_add_region_highlight $start_pos $end_pos $alias_style
	(( in_param == 1 )) && in_param=0 _zsh_highlight_main_add_region_highlight $start_pos $end_pos $param_style
	[[ "$proc_buf" = (#b)(#s)(([[:space:]]|\\$'\n')#) ]]
	REPLY=$(( end_pos + ${#match[1]} - 1 )) 
	reply=($list_highlights) 
	return $(( $#braces_stack > 0 ))
}
_zsh_highlight_main_highlighter_highlight_path_separators () {
	local pos style_pathsep
	style_pathsep=$1_pathseparator 
	reply=() 
	[[ -z "$ZSH_HIGHLIGHT_STYLES[$style_pathsep]" || "$ZSH_HIGHLIGHT_STYLES[$1]" == "$ZSH_HIGHLIGHT_STYLES[$style_pathsep]" ]] && return 0
	for ((pos = start_pos; $pos <= end_pos; pos++ )) do
		if [[ $BUFFER[pos] == / ]]
		then
			reply+=($((pos - 1)) $pos $style_pathsep) 
		fi
	done
}
_zsh_highlight_main_highlighter_highlight_single_quote () {
	local arg1=$1 i q=\' style 
	i=$arg[(ib:arg1+1:)$q] 
	reply=() 
	if [[ $zsyh_user_options[rcquotes] == on ]]
	then
		while [[ $arg[i+1] == "'" ]]
		do
			reply+=($(( start_pos + i - 1 )) $(( start_pos + i + 1 )) rc-quote) 
			(( i++ ))
			i=$arg[(ib:i+1:)$q] 
		done
	fi
	if [[ $arg[i] == "'" ]]
	then
		style=single-quoted-argument 
	else
		(( i-- ))
		style=single-quoted-argument-unclosed 
	fi
	reply=($(( start_pos + arg1 - 1 )) $(( start_pos + i )) $style $reply) 
	REPLY=$i 
}
_zsh_highlight_pattern_highlighter_loop () {
	local buf="$1" pat="$2" 
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	if [[ "$buf" == (#b)(*)(${~pat})* ]]
	then
		region_highlight+=("$((mbegin[2] - 1)) $mend[2] $ZSH_HIGHLIGHT_PATTERNS[$pat], memo=zsh-syntax-highlighting") 
		"$0" "$match[1]" "$pat"
		return $?
	fi
}
_zsh_highlight_preexec_hook () {
	typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER= 
	typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR= 
}
_zsh_highlight_regexp_highlighter_loop () {
	local buf="$1" pat="$2" 
	integer OFFSET=0 
	local MATCH
	integer MBEGIN MEND
	local -a match mbegin mend
	while true
	do
		[[ "$buf" =~ "$pat" ]] || return
		region_highlight+=("$((MBEGIN - 1 + OFFSET)) $((MEND + OFFSET)) $ZSH_HIGHLIGHT_REGEXP[$pat], memo=zsh-syntax-highlighting") 
		buf="$buf[$(($MEND+1)),-1]" 
		OFFSET=$((MEND+OFFSET)) 
	done
}
_zsocket () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zstyle () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_ztodo () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
_zypper () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
add-zle-hook-widget () {
	# undefined
	builtin autoload -XU
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
alias_value () {
	(( $+aliases[$1] )) && echo $aliases[$1]
}
autojump_chpwd () {
	if [[ -f "${AUTOJUMP_ERROR_PATH}" ]]
	then
		autojump --add "$(pwd)" > /dev/null 2>> ${AUTOJUMP_ERROR_PATH} &|
	else
		autojump --add "$(pwd)" > /dev/null &|
	fi
}
b () {
	bookmarks_path=~/Library/Application\ Support/Google/Chrome/Default/Bookmarks 
	jq_script='
        def ancestors: while(. | length >= 2; del(.[-1,-2]));
        . as $in | paths(.url?) as $key | $in | getpath($key) | {name,url, path: [$key[0:-2] | ancestors as $a | $in | getpath($a) | .name?] | reverse | join("/") } | .path + "/" + .name + "\t" + .url' 
	jq -r "$jq_script" < "$bookmarks_path" | sed -E $'s/(.*)\t(.*)/\\1\t\x1b[36m\\2\x1b[m/g' | fzf --ansi | cut -d$'\t' -f2 | xargs open
}
bashcompinit () {
	# undefined
	builtin autoload -XUz
}
bcp () {
	local uninst=$(brew leaves | fzf -m) 
	if [[ -n $uninst ]]
	then
		for prog in $(echo $uninst)
		do
			brew uninstall $prog
		done
	fi
}
bracketed-paste-magic () {
	# undefined
	builtin autoload -XUz
}
btrestart () {
	sudo kextunload -b com.apple.iokit.BroadcomBluetoothHostControllerUSBTransport
	sudo kextload -b com.apple.iokit.BroadcomBluetoothHostControllerUSBTransport
}
build_prompt () {
	RETVAL=$? 
	prompt_status
	prompt_virtualenv
	prompt_aws
	prompt_context
	prompt_dir
	prompt_git
	prompt_bzr
	prompt_hg
	prompt_end
}
bup () {
	local upd=$(brew leaves | fzf -m) 
	if [[ -n $upd ]]
	then
		for prog in $(echo $upd)
		do
			brew upgrade $prog
		done
	fi
}
bzr_prompt_info () {
	BZR_CB=`bzr nick 2> /dev/null | grep -v "ERROR" | cut -d ":" -f2 | awk -F / '{print "bzr::"$1}'` 
	if [ -n "$BZR_CB" ]
	then
		BZR_DIRTY="" 
		[[ -n `bzr status` ]] && BZR_DIRTY=" %{$fg[red]%} * %{$fg[green]%}" 
		echo "$ZSH_THEME_SCM_PROMPT_PREFIX$BZR_CB$BZR_DIRTY$ZSH_THEME_GIT_PROMPT_SUFFIX"
	fi
}
c () {
	local cols sep google_history open
	cols=$(( COLUMNS / 3 )) 
	sep='{::}' 
	if [ "$(uname)" = "Darwin" ]
	then
		google_history="$HOME/Library/Application Support/Google/Chrome/Default/History" 
		open=open 
	else
		google_history="$HOME/.config/google-chrome/Default/History" 
		open=xdg-open 
	fi
	cp -f "$google_history" /tmp/h
	sqlite3 -separator $sep /tmp/h "select substr(title, 1, $cols), url
     from urls order by last_visit_time desc" | awk -F $sep '{printf "%-'$cols's  \x1b[36m%s\x1b[m\n", $1, $2}' | fzf --ansi --multi | sed 's#.*\(https*://\)#\1#' | xargs $open > /dev/null 2> /dev/null
}
cd () {
	if [[ "$#" != 0 ]]
	then
		builtin cd "$@"
		return
	fi
	while true
	do
		local lsd=$(echo ".." && ls -p | grep '/$' | sed 's;/$;;') 
		local dir="$(printf '%s\n' "${lsd[@]}" |
            fzf --reverse --preview '
                __cd_nxt="$(echo {})";
                __cd_path="$(echo $(pwd)/${__cd_nxt} | sed "s;//;/;")";
                echo $__cd_path;
                echo;
                ls -p --color=always "${__cd_path}";
        ')" 
		[[ ${#dir} != 0 ]] || return 0
		builtin cd "$dir" &> /dev/null
	done
}
cdf () {
	cd "$(pfd)"
}
cdx () {
	cd "$(pxd)"
}
chruby_prompt_info () {
	return 1
}
clipcopy () {
	pbcopy < "${1:-/dev/stdin}"
}
clippaste () {
	pbpaste
}
colors () {
	emulate -L zsh
	typeset -Ag color colour
	color=(00 none 01 bold 02 faint 22 normal 03 italic 23 no-italic 04 underline 24 no-underline 05 blink 25 no-blink 07 reverse 27 no-reverse 08 conceal 28 no-conceal 30 black 40 bg-black 31 red 41 bg-red 32 green 42 bg-green 33 yellow 43 bg-yellow 34 blue 44 bg-blue 35 magenta 45 bg-magenta 36 cyan 46 bg-cyan 37 white 47 bg-white 39 default 49 bg-default) 
	local k
	for k in ${(k)color}
	do
		color[${color[$k]}]=$k 
	done
	for k in ${color[(I)3?]}
	do
		color[fg-${color[$k]}]=$k 
	done
	for k in grey gray
	do
		color[$k]=${color[black]} 
		color[fg-$k]=${color[$k]} 
		color[bg-$k]=${color[bg-black]} 
	done
	colour=(${(kv)color}) 
	local lc=$'\e[' rc=m 
	typeset -Hg reset_color bold_color
	reset_color="$lc${color[none]}$rc" 
	bold_color="$lc${color[bold]}$rc" 
	typeset -AHg fg fg_bold fg_no_bold
	for k in ${(k)color[(I)fg-*]}
	do
		fg[${k#fg-}]="$lc${color[$k]}$rc" 
		fg_bold[${k#fg-}]="$lc${color[bold]};${color[$k]}$rc" 
		fg_no_bold[${k#fg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
	typeset -AHg bg bg_bold bg_no_bold
	for k in ${(k)color[(I)bg-*]}
	do
		bg[${k#bg-}]="$lc${color[$k]}$rc" 
		bg_bold[${k#bg-}]="$lc${color[bold]};${color[$k]}$rc" 
		bg_no_bold[${k#bg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
}
compaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz
}
compgen () {
	local opts prefix suffix job OPTARG OPTIND ret=1 
	local -a name res results jids
	local -A shortopts
	emulate -L sh
	setopt kshglob noshglob braceexpand nokshautoload
	shortopts=(a alias b builtin c command d directory e export f file g group j job k keyword u user v variable) 
	while getopts "o:A:G:C:F:P:S:W:X:abcdefgjkuv" name
	do
		case $name in
			([abcdefgjkuv]) OPTARG="${shortopts[$name]}"  ;&
			(A) case $OPTARG in
					(alias) results+=("${(k)aliases[@]}")  ;;
					(arrayvar) results+=("${(k@)parameters[(R)array*]}")  ;;
					(binding) results+=("${(k)widgets[@]}")  ;;
					(builtin) results+=("${(k)builtins[@]}" "${(k)dis_builtins[@]}")  ;;
					(command) results+=("${(k)commands[@]}" "${(k)aliases[@]}" "${(k)builtins[@]}" "${(k)functions[@]}" "${(k)reswords[@]}")  ;;
					(directory) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N-/)) 
						setopt nobareglobqual ;;
					(disabled) results+=("${(k)dis_builtins[@]}")  ;;
					(enabled) results+=("${(k)builtins[@]}")  ;;
					(export) results+=("${(k)parameters[(R)*export*]}")  ;;
					(file) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N)) 
						setopt nobareglobqual ;;
					(function) results+=("${(k)functions[@]}")  ;;
					(group) emulate zsh
						_groups -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(hostname) emulate zsh
						_hosts -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(job) results+=("${savejobtexts[@]%% *}")  ;;
					(keyword) results+=("${(k)reswords[@]}")  ;;
					(running) jids=("${(@k)savejobstates[(R)running*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(stopped) jids=("${(@k)savejobstates[(R)suspended*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(setopt | shopt) results+=("${(k)options[@]}")  ;;
					(signal) results+=("SIG${^signals[@]}")  ;;
					(user) results+=("${(k)userdirs[@]}")  ;;
					(variable) results+=("${(k)parameters[@]}")  ;;
					(helptopic)  ;;
				esac ;;
			(F) COMPREPLY=() 
				local -a args
				args=("${words[0]}" "${@[-1]}" "${words[CURRENT-2]}") 
				() {
					typeset -h words
					$OPTARG "${args[@]}"
				}
				results+=("${COMPREPLY[@]}")  ;;
			(G) setopt nullglob
				results+=(${~OPTARG}) 
				unsetopt nullglob ;;
			(W) results+=(${(Q)~=OPTARG})  ;;
			(C) results+=($(eval $OPTARG))  ;;
			(P) prefix="$OPTARG"  ;;
			(S) suffix="$OPTARG"  ;;
			(X) if [[ ${OPTARG[0]} = '!' ]]
				then
					results=("${(M)results[@]:#${OPTARG#?}}") 
				else
					results=("${results[@]:#$OPTARG}") 
				fi ;;
		esac
	done
	print -l -r -- "$prefix${^results[@]}$suffix"
}
compinit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
complete () {
	emulate -L zsh
	local args void cmd print remove
	args=("$@") 
	zparseopts -D -a void o: A: G: W: C: F: P: S: X: a b c d e f g j k u v p=print r=remove
	if [[ -n $print ]]
	then
		printf 'complete %2$s %1$s\n' "${(@kv)_comps[(R)_bash*]#* }"
	elif [[ -n $remove ]]
	then
		for cmd
		do
			unset "_comps[$cmd]"
		done
	else
		compdef _bash_complete\ ${(j. .)${(q)args[1,-1-$#]}} "$@"
	fi
}
current_branch () {
	git_current_branch
}
d () {
	if [[ -n $1 ]]
	then
		dirs "$@"
	else
		dirs -v | head -n 10
	fi
}
default () {
	(( $+parameters[$1] )) && return 0
	typeset -g "$1"="$2" && return 3
}
detect-clipboard () {
	emulate -L zsh
	if [[ "${OSTYPE}" == darwin* ]] && (( ${+commands[pbcopy]} )) && (( ${+commands[pbpaste]} ))
	then
		clipcopy () {
			pbcopy < "${1:-/dev/stdin}"
		}
		clippaste () {
			pbpaste
		}
	elif [[ "${OSTYPE}" == (cygwin|msys)* ]]
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" > /dev/clipboard
		}
		clippaste () {
			cat /dev/clipboard
		}
	elif [ -n "${WAYLAND_DISPLAY:-}" ] && (( ${+commands[wl-copy]} )) && (( ${+commands[wl-paste]} ))
	then
		clipcopy () {
			wl-copy < "${1:-/dev/stdin}"
		}
		clippaste () {
			wl-paste
		}
	elif [ -n "${DISPLAY:-}" ] && (( ${+commands[xclip]} ))
	then
		clipcopy () {
			xclip -in -selection clipboard < "${1:-/dev/stdin}"
		}
		clippaste () {
			xclip -out -selection clipboard
		}
	elif [ -n "${DISPLAY:-}" ] && (( ${+commands[xsel]} ))
	then
		clipcopy () {
			xsel --clipboard --input < "${1:-/dev/stdin}"
		}
		clippaste () {
			xsel --clipboard --output
		}
	elif (( ${+commands[lemonade]} ))
	then
		clipcopy () {
			lemonade copy < "${1:-/dev/stdin}"
		}
		clippaste () {
			lemonade paste
		}
	elif (( ${+commands[doitclient]} ))
	then
		clipcopy () {
			doitclient wclip < "${1:-/dev/stdin}"
		}
		clippaste () {
			doitclient wclip -r
		}
	elif (( ${+commands[win32yank]} ))
	then
		clipcopy () {
			win32yank -i < "${1:-/dev/stdin}"
		}
		clippaste () {
			win32yank -o
		}
	elif [[ $OSTYPE == linux-android* ]] && (( $+commands[termux-clipboard-set] ))
	then
		clipcopy () {
			termux-clipboard-set < "${1:-/dev/stdin}"
		}
		clippaste () {
			termux-clipboard-get
		}
	elif [ -n "${TMUX:-}" ] && (( ${+commands[tmux]} ))
	then
		clipcopy () {
			tmux load-buffer "${1:--}"
		}
		clippaste () {
			tmux save-buffer -
		}
	elif [[ $(uname -r) = *icrosoft* ]]
	then
		clipcopy () {
			clip.exe < "${1:-/dev/stdin}"
		}
		clippaste () {
			powershell.exe -noprofile -command Get-Clipboard
		}
	else
		_retry_clipboard_detection_or_fail () {
			local clipcmd="${1}" 
			shift
			if detect-clipboard
			then
				"${clipcmd}" "$@"
			else
				print "${clipcmd}: Platform $OSTYPE not supported or xclip/xsel not installed" >&2
				return 1
			fi
		}
		clipcopy () {
			_retry_clipboard_detection_or_fail clipcopy "$@"
		}
		clippaste () {
			_retry_clipboard_detection_or_fail clippaste "$@"
		}
		return 1
	fi
}
down-line-or-beginning-search () {
	# undefined
	builtin autoload -XU
}
edit-command-line () {
	# undefined
	builtin autoload -XU
}
env_default () {
	[[ ${parameters[$1]} = *-export* ]] && return 0
	export "$1=$2" && return 3
}
fbr () {
	local branches branch
	branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)")  && branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m)  && git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}
fco () {
	local tags branches target
	branches=$(
    git --no-pager branch --all \
      --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" \
    | sed '/^$/d')  || return
	tags=$(
    git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}')  || return
	target=$(
    (echo "$branches"; echo "$tags") |
    fzf --no-hscroll --no-multi -n 2 \
        --ansi)  || return
	git checkout $(awk '{print $2}' <<<"$target" )
}
fco_preview () {
	local tags branches target
	branches=$(
    git --no-pager branch --all \
      --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" \
    | sed '/^$/d')  || return
	tags=$(
    git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}')  || return
	target=$(
    (echo "$branches"; echo "$tags") |
    fzf --no-hscroll --no-multi -n 2 \
        --ansi --preview="git --no-pager log -150 --pretty=format:%s '..{2}'")  || return
	git checkout $(awk '{print $2}' <<<"$target" )
}
freespace () {
	if [[ -z "$1" ]]
	then
		echo "Usage: $0 <disk>"
		echo "Example: $0 /dev/disk1s1"
		echo
		echo "Possible disks:"
		df -h | awk 'NR == 1 || /^\/dev\/disk/'
		return 1
	fi
	echo "Cleaning purgeable files from disk: $1 ...."
	diskutil secureErase freespace 0 $1
}
fshow () {
	git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" | fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
FZF-EOF"
}
fzfv () {
	fzf --preview '[[ $(file --mime {}) =~ binary ]] &&
                 echo {} is a binary file ||
                 (cat {}) 2> /dev/null | head -500'
}
gccd () {
	command git clone --recurse-submodules "$@"
	[[ -d "$_" ]] && cd "$_" || cd "${${_:t}%.git}"
}
gdnolock () {
	git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
}
gdv () {
	git diff -w "$@" | view -
}
gemini () {
	GOOGLE_CLOUD_PROJECT="yangeok" CLOUDSDK_CORE_PROJECT="yangeok" command gemini "$@"
}
getent () {
	if [[ $1 = hosts ]]
	then
		sed 's/#.*//' /etc/$1 | grep -w $2
	elif [[ $2 = <-> ]]
	then
		grep ":$2:[^:]*$" /etc/$1
	else
		grep "^$2:" /etc/$1
	fi
}
ggf () {
	[[ "$#" != 1 ]] && local b="$(git_current_branch)" 
	git push --force origin "${b:=$1}"
}
ggfl () {
	[[ "$#" != 1 ]] && local b="$(git_current_branch)" 
	git push --force-with-lease origin "${b:=$1}"
}
ggl () {
	if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]
	then
		git pull origin "${*}"
	else
		[[ "$#" == 0 ]] && local b="$(git_current_branch)" 
		git pull origin "${b:=$1}"
	fi
}
ggp () {
	if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]
	then
		git push origin "${*}"
	else
		[[ "$#" == 0 ]] && local b="$(git_current_branch)" 
		git push origin "${b:=$1}"
	fi
}
ggpnp () {
	if [[ "$#" == 0 ]]
	then
		ggl && ggp
	else
		ggl "${*}" && ggp "${*}"
	fi
}
ggu () {
	[[ "$#" != 1 ]] && local b="$(git_current_branch)" 
	git pull --rebase origin "${b:=$1}"
}
git_commits_ahead () {
	if __git_prompt_git rev-parse --git-dir &> /dev/null
	then
		local commits="$(__git_prompt_git rev-list --count @{upstream}..HEAD 2>/dev/null)" 
		if [[ -n "$commits" && "$commits" != 0 ]]
		then
			echo "$ZSH_THEME_GIT_COMMITS_AHEAD_PREFIX$commits$ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX"
		fi
	fi
}
git_commits_behind () {
	if __git_prompt_git rev-parse --git-dir &> /dev/null
	then
		local commits="$(__git_prompt_git rev-list --count HEAD..@{upstream} 2>/dev/null)" 
		if [[ -n "$commits" && "$commits" != 0 ]]
		then
			echo "$ZSH_THEME_GIT_COMMITS_BEHIND_PREFIX$commits$ZSH_THEME_GIT_COMMITS_BEHIND_SUFFIX"
		fi
	fi
}
git_current_branch () {
	local ref
	ref=$(__git_prompt_git symbolic-ref --quiet HEAD 2> /dev/null) 
	local ret=$? 
	if [[ $ret != 0 ]]
	then
		[[ $ret == 128 ]] && return
		ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  || return
	fi
	echo ${ref#refs/heads/}
}
git_current_user_email () {
	__git_prompt_git config user.email 2> /dev/null
}
git_current_user_name () {
	__git_prompt_git config user.name 2> /dev/null
}
git_develop_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local branch
	for branch in dev devel development
	do
		if command git show-ref -q --verify refs/heads/$branch
		then
			echo $branch
			return
		fi
	done
	echo develop
}
git_main_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local ref
	for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk}
	do
		if command git show-ref -q --verify $ref
		then
			echo ${ref:t}
			return
		fi
	done
	echo master
}
git_prompt_ahead () {
	if [[ -n "$(__git_prompt_git rev-list origin/$(git_current_branch)..HEAD 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_AHEAD"
	fi
}
git_prompt_behind () {
	if [[ -n "$(__git_prompt_git rev-list HEAD..origin/$(git_current_branch) 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_BEHIND"
	fi
}
git_prompt_info () {
	if ! __git_prompt_git rev-parse --git-dir &> /dev/null || [[ "$(__git_prompt_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]
	then
		return 0
	fi
	local ref
	ref=$(__git_prompt_git symbolic-ref --short HEAD 2> /dev/null)  || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  || return 0
	local upstream
	if (( ${+ZSH_THEME_GIT_SHOW_UPSTREAM} ))
	then
		upstream=$(__git_prompt_git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null)  && upstream=" -> ${upstream}" 
	fi
	echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref:gs/%/%%}${upstream:gs/%/%%}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}
git_prompt_long_sha () {
	local SHA
	SHA=$(__git_prompt_git rev-parse HEAD 2> /dev/null)  && echo "$ZSH_THEME_GIT_PROMPT_SHA_BEFORE$SHA$ZSH_THEME_GIT_PROMPT_SHA_AFTER"
}
git_prompt_remote () {
	if [[ -n "$(__git_prompt_git show-ref origin/$(git_current_branch) 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_REMOTE_EXISTS"
	else
		echo "$ZSH_THEME_GIT_PROMPT_REMOTE_MISSING"
	fi
}
git_prompt_short_sha () {
	local SHA
	SHA=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  && echo "$ZSH_THEME_GIT_PROMPT_SHA_BEFORE$SHA$ZSH_THEME_GIT_PROMPT_SHA_AFTER"
}
git_prompt_status () {
	[[ "$(__git_prompt_git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]] && return
	local -A prefix_constant_map
	prefix_constant_map=('\?\? ' 'UNTRACKED' 'A  ' 'ADDED' 'M  ' 'ADDED' 'MM ' 'MODIFIED' ' M ' 'MODIFIED' 'AM ' 'MODIFIED' ' T ' 'MODIFIED' 'R  ' 'RENAMED' ' D ' 'DELETED' 'D  ' 'DELETED' 'UU ' 'UNMERGED' 'ahead' 'AHEAD' 'behind' 'BEHIND' 'diverged' 'DIVERGED' 'stashed' 'STASHED') 
	local -A constant_prompt_map
	constant_prompt_map=('UNTRACKED' "$ZSH_THEME_GIT_PROMPT_UNTRACKED" 'ADDED' "$ZSH_THEME_GIT_PROMPT_ADDED" 'MODIFIED' "$ZSH_THEME_GIT_PROMPT_MODIFIED" 'RENAMED' "$ZSH_THEME_GIT_PROMPT_RENAMED" 'DELETED' "$ZSH_THEME_GIT_PROMPT_DELETED" 'UNMERGED' "$ZSH_THEME_GIT_PROMPT_UNMERGED" 'AHEAD' "$ZSH_THEME_GIT_PROMPT_AHEAD" 'BEHIND' "$ZSH_THEME_GIT_PROMPT_BEHIND" 'DIVERGED' "$ZSH_THEME_GIT_PROMPT_DIVERGED" 'STASHED' "$ZSH_THEME_GIT_PROMPT_STASHED") 
	local status_constants
	status_constants=(UNTRACKED ADDED MODIFIED RENAMED DELETED STASHED UNMERGED AHEAD BEHIND DIVERGED) 
	local status_text
	status_text="$(__git_prompt_git status --porcelain -b 2> /dev/null)" 
	if [[ $? -eq 128 ]]
	then
		return 1
	fi
	local -A statuses_seen
	if __git_prompt_git rev-parse --verify refs/stash &> /dev/null
	then
		statuses_seen[STASHED]=1 
	fi
	local status_lines
	status_lines=("${(@f)${status_text}}") 
	if [[ "$status_lines[1]" =~ "^## [^ ]+ \[(.*)\]" ]]
	then
		local branch_statuses
		branch_statuses=("${(@s/,/)match}") 
		for branch_status in $branch_statuses
		do
			if [[ ! $branch_status =~ "(behind|diverged|ahead) ([0-9]+)?" ]]
			then
				continue
			fi
			local last_parsed_status=$prefix_constant_map[$match[1]] 
			statuses_seen[$last_parsed_status]=$match[2] 
		done
	fi
	for status_prefix in ${(k)prefix_constant_map}
	do
		local status_constant="${prefix_constant_map[$status_prefix]}" 
		local status_regex=$'(^|\n)'"$status_prefix" 
		if [[ "$status_text" =~ $status_regex ]]
		then
			statuses_seen[$status_constant]=1 
		fi
	done
	local status_prompt
	for status_constant in $status_constants
	do
		if (( ${+statuses_seen[$status_constant]} ))
		then
			local next_display=$constant_prompt_map[$status_constant] 
			status_prompt="$next_display$status_prompt" 
		fi
	done
	echo $status_prompt
}
git_remote_status () {
	local remote ahead behind git_remote_status git_remote_status_detailed
	remote=${$(__git_prompt_git rev-parse --verify ${hook_com[branch]}@{upstream} --symbolic-full-name 2>/dev/null)/refs\/remotes\/} 
	if [[ -n ${remote} ]]
	then
		ahead=$(__git_prompt_git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l) 
		behind=$(__git_prompt_git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l) 
		if [[ $ahead -eq 0 ]] && [[ $behind -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE" 
		elif [[ $ahead -gt 0 ]] && [[ $behind -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE$((ahead))%{$reset_color%}" 
		elif [[ $behind -gt 0 ]] && [[ $ahead -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE$((behind))%{$reset_color%}" 
		elif [[ $ahead -gt 0 ]] && [[ $behind -gt 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_DIVERGED_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE$((ahead))%{$reset_color%}$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE$((behind))%{$reset_color%}" 
		fi
		if [[ -n $ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_DETAILED ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_PREFIX${remote:gs/%/%%}$git_remote_status_detailed$ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_SUFFIX" 
		fi
		echo $git_remote_status
	fi
}
git_repo_name () {
	local repo_path
	if repo_path="$(__git_prompt_git rev-parse --show-toplevel 2>/dev/null)"  && [[ -n "$repo_path" ]]
	then
		echo ${repo_path:t}
	fi
}
goenv () {
	local command
	command="$1" 
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	case "$command" in
		(rehash | shell) eval "$(goenv "sh-$command" "$@")" ;;
		(*) command goenv "$command" "$@" ;;
	esac
}
grename () {
	if [[ -z "$1" || -z "$2" ]]
	then
		echo "Usage: $0 old_branch new_branch"
		return 1
	fi
	git branch -m "$1" "$2"
	if git push origin :"$1"
	then
		git push --set-upstream origin "$2"
	fi
}
handle_completion_insecurities () {
	local -aU insecure_dirs
	insecure_dirs=(${(f@):-"$(compaudit 2>/dev/null)"}) 
	[[ -z "${insecure_dirs}" ]] && return
	print "[oh-my-zsh] Insecure completion-dependent directories detected:"
	ls -ld "${(@)insecure_dirs}"
	cat <<EOD

[oh-my-zsh] For safety, we will not load completions from these directories until
[oh-my-zsh] you fix their permissions and ownership and restart zsh.
[oh-my-zsh] See the above list for directories with group or other writability.

[oh-my-zsh] To fix your permissions you can do so by disabling
[oh-my-zsh] the write permission of "group" and "others" and making sure that the
[oh-my-zsh] owner of these directories is either root or your current user.
[oh-my-zsh] The following command may help:
[oh-my-zsh]     compaudit | xargs chmod g-w,o-w

[oh-my-zsh] If the above didn't help or you want to skip the verification of
[oh-my-zsh] insecure directories you can set the variable ZSH_DISABLE_COMPFIX to
[oh-my-zsh] "true" before oh-my-zsh is sourced in your zshrc file.

EOD
}
has_typed_input () {
	emulate -L zsh
	zmodload zsh/zselect
	local termios
	termios=$(stty --save 2>/dev/null)  || return 1
	{
		stty -icanon
		zselect -t 0 -r 0
		return $?
	} always {
		stty $termios
	}
}
hg_prompt_info () {
	return 1
}
install_hook () {
	emulate -LR zsh
	typeset -ag precmd_functions
	if [[ -z $precmd_functions[(r)_jenv_export_hook] ]]
	then
		precmd_functions+=_jenv_export_hook 
	fi
}
is-at-least () {
	emulate -L zsh
	local IFS=".-" min_cnt=0 ver_cnt=0 part min_ver version order 
	min_ver=(${=1}) 
	version=(${=2:-$ZSH_VERSION} 0) 
	while (( $min_cnt <= ${#min_ver} ))
	do
		while [[ "$part" != <-> ]]
		do
			(( ++ver_cnt > ${#version} )) && return 0
			if [[ ${version[ver_cnt]} = *[0-9][^0-9]* ]]
			then
				order=(${version[ver_cnt]} ${min_ver[ver_cnt]}) 
				if [[ ${version[ver_cnt]} = <->* ]]
				then
					[[ $order != ${${(On)order}} ]] && return 1
				else
					[[ $order != ${${(O)order}} ]] && return 1
				fi
				[[ $order[1] != $order[2] ]] && return 0
			fi
			part=${version[ver_cnt]##*[^0-9]} 
		done
		while true
		do
			(( ++min_cnt > ${#min_ver} )) && return 0
			[[ ${min_ver[min_cnt]} = <-> ]] && break
		done
		(( part > min_ver[min_cnt] )) && return 0
		(( part < min_ver[min_cnt] )) && return 1
		part='' 
	done
}
is_plugin () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/plugins/$name/$name.plugin.zsh || builtin test -f $base_dir/plugins/$name/_$name
}
is_theme () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/$name.zsh-theme
}
itunes () {
	local APP_NAME=Music sw_vers=$(sw_vers -productVersion 2>/dev/null) 
	autoload is-at-least
	if [[ -z "$sw_vers" ]] || is-at-least 10.15 $sw_vers
	then
		if [[ $0 = itunes ]]
		then
			echo The itunes function name is deprecated. Use \'music\' instead. >&2
			return 1
		fi
	else
		APP_NAME=iTunes 
	fi
	local opt=$1 playlist=$2 
	(( $# > 0 )) && shift
	case "$opt" in
		(launch | play | pause | stop | rewind | resume | quit)  ;;
		(mute) opt="set mute to true"  ;;
		(unmute) opt="set mute to false"  ;;
		(next | previous) opt="$opt track"  ;;
		(vol) local new_volume volume=$(osascript -e "tell application \"$APP_NAME\" to get sound volume") 
			if [[ $# -eq 0 ]]
			then
				echo "Current volume is ${volume}."
				return 0
			fi
			case $1 in
				(up) new_volume=$((volume + 10 < 100 ? volume + 10 : 100))  ;;
				(down) new_volume=$((volume - 10 > 0 ? volume - 10 : 0))  ;;
				(<0-100>) new_volume=$1  ;;
				(*) echo "'$1' is not valid. Expected <0-100>, up or down."
					return 1 ;;
			esac
			opt="set sound volume to ${new_volume}"  ;;
		(playlist) if [[ -n "$playlist" ]]
			then
				osascript 2> /dev/null <<EOF
          tell application "$APP_NAME"
            set new_playlist to "$playlist" as string
            play playlist new_playlist
          end tell
EOF
				if [[ $? -eq 0 ]]
				then
					opt="play" 
				else
					opt="stop" 
				fi
			else
				opt="set allPlaylists to (get name of every playlist)" 
			fi ;;
		(playing | status) local currenttrack currentartist state=$(osascript -e "tell application \"$APP_NAME\" to player state as string") 
			if [[ "$state" = "playing" ]]
			then
				currenttrack=$(osascript -e "tell application \"$APP_NAME\" to name of current track as string") 
				currentartist=$(osascript -e "tell application \"$APP_NAME\" to artist of current track as string") 
				echo -E "Listening to ${fg[yellow]}${currenttrack}${reset_color} by ${fg[yellow]}${currentartist}${reset_color}"
			else
				echo "$APP_NAME is $state"
			fi
			return 0 ;;
		(shuf | shuff | shuffle) local state=$1 
			if [[ -n "$state" && "$state" != (on|off|toggle) ]]
			then
				print "Usage: $0 shuffle [on|off|toggle]. Invalid option."
				return 1
			fi
			case "$state" in
				(on | off) osascript > /dev/null 2>&1 <<EOF
            tell application "System Events" to perform action "AXPress" of (menu item "${state}" of menu "Shuffle" of menu item "Shuffle" of menu "Controls" of menu bar item "Controls" of menu bar 1 of application process "iTunes" )
EOF
					return 0 ;;
				(toggle | *) osascript > /dev/null 2>&1 <<EOF
            tell application "System Events" to perform action "AXPress" of (button 2 of process "iTunes"'s window "iTunes"'s scroll area 1)
EOF
					return 0 ;;
			esac ;;
		("" | -h | --help) echo "Usage: $0 <option>"
			echo "option:"
			echo "\t-h|--help\tShow this message and exit"
			echo "\tlaunch|play|pause|stop|rewind|resume|quit"
			echo "\tmute|unmute\tMute or unmute $APP_NAME"
			echo "\tnext|previous\tPlay next or previous track"
			echo "\tshuf|shuffle [on|off|toggle]\tSet shuffled playback. Default: toggle. Note: toggle doesn't support the MiniPlayer."
			echo "\tvol [0-100|up|down]\tGet or set the volume. 0 to 100 sets the volume. 'up' / 'down' increases / decreases by 10 points. No argument displays current volume."
			echo "\tplaying|status\tShow what song is currently playing in Music."
			echo "\tplaylist [playlist name]\t Play specific playlist"
			return 0 ;;
		(*) print "Unknown option: $opt"
			return 1 ;;
	esac
	osascript -e "tell application \"$APP_NAME\" to $opt"
}
j () {
	if [[ "$#" -ne 0 ]]
	then
		cd $(autojump $@)
		return
	fi
	cd "$(autojump -s | sort -k1gr | awk '$1 ~ /[0-9]:/ && $2 ~ /^\// { for (i=2; i<=NF; i++) { print $(i) } }' |  fzf --height 40% --reverse --inline-info)"
}
jc () {
	if [[ ${1} == -* ]] && [[ ${1} != "--" ]]
	then
		autojump ${@}
		return
	else
		j $(pwd) ${@}
	fi
}
jco () {
	if [[ ${1} == -* ]] && [[ ${1} != "--" ]]
	then
		autojump ${@}
		return
	else
		jo $(pwd) ${@}
	fi
}
jenv () {
	type typeset &> /dev/null && typeset command
	command="$1" 
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	case "$command" in
		(enable-plugin | rehash | shell | shell-options) eval "`jenv \"sh-$command\" \"$@\"`" ;;
		(*) command jenv "$command" "$@" ;;
	esac
}
jenv_prompt_info () {
	return 1
}
jo () {
	if [[ ${1} == -* ]] && [[ ${1} != "--" ]]
	then
		autojump ${@}
		return
	fi
	setopt localoptions noautonamedirs
	local output="$(autojump ${@})" 
	if [[ -d "${output}" ]]
	then
		case ${OSTYPE} in
			(linux*) xdg-open "${output}" ;;
			(darwin*) open "${output}" ;;
			(cygwin) cygstart "" $(cygpath -w -a ${output}) ;;
			(*) echo "Unknown operating system: ${OSTYPE}" >&2 ;;
		esac
	else
		echo "autojump: directory '${@}' not found"
		echo "\n${output}\n"
		echo "Try \`autojump --help\` for more information."
		false
	fi
}
k () {
	setopt local_options null_glob typeset_silent no_auto_pushd nomarkdirs
	typeset -a o_all o_almost_all o_human o_si o_directory o_group_directories o_no_directory o_no_vcs o_sort o_sort_reverse o_help
	zparseopts -E -D a=o_all -all=o_all A=o_almost_all -almost-all=o_almost_all c=o_sort d=o_directory -directory=o_directory -group-directories-first=o_group_directories h=o_human -human=o_human -si=o_si n=o_no_directory -no-directory=o_no_directory -no-vcs=o_no_vcs r=o_sort_reverse -reverse=o_sort_reverse -sort:=o_sort S=o_sort t=o_sort u=o_sort U=o_sort -help=o_help
	if [[ $? != 0 || "$o_help" != "" ]]
	then
		print -u2 "Usage: k [options] DIR"
		print -u2 "Options:"
		print -u2 "\t-a      --all           list entries starting with ."
		print -u2 "\t-A      --almost-all    list all except . and .."
		print -u2 "\t-c                      sort by ctime (inode change time)"
		print -u2 "\t-d      --directory     list only directories"
		print -u2 "\t-n      --no-directory  do not list directories"
		print -u2 "\t-h      --human         show filesizes in human-readable format"
		print -u2 "\t        --si            with -h, use powers of 1000 not 1024"
		print -u2 "\t-r      --reverse       reverse sort order"
		print -u2 "\t-S                      sort by size"
		print -u2 "\t-t                      sort by time (modification time)"
		print -u2 "\t-u                      sort by atime (use or access time)"
		print -u2 "\t-U                      Unsorted"
		print -u2 "\t        --sort WORD     sort by WORD: none (U), size (S),"
		print -u2 "\t                        time (t), ctime or status (c),"
		print -u2 "\t       		 atime or access or use (u)"
		print -u2 "\t        --no-vcs        do not get VCS status (much faster)"
		print -u2 "\t        --help          show this help"
		return 1
	fi
	if [[ "$o_directory" != "" && "$o_no_directory" != "" ]]
	then
		print -u2 "$o_directory and $o_no_directory cannot be used together"
		return 1
	fi
	local S_ORD="o" R_ORD="O" SPEC="n" 
	case ${o_sort:#--sort} in
		(-U | none) SPEC="N"  ;;
		(-t | time) SPEC="m"  ;;
		(-c | ctime | status) SPEC="c"  ;;
		(-u | atime | access | use) SPEC="a"  ;;
		(-S | size) S_ORD="O" R_ORD="o" SPEC="L"  ;;
	esac
	if [[ "$o_sort_reverse" == "" ]]
	then
		typeset SORT_GLOB="${S_ORD}${SPEC}" 
	else
		typeset SORT_GLOB="${R_ORD}${SPEC}" 
	fi
	if [[ "$o_group_directories" != "" ]]
	then
		SORT_GLOB="oe:[[ -d \$REPLY ]];REPLY=\$?:$SORT_GLOB" 
	fi
	typeset -i numfmt_available=0 
	typeset -i gnumfmt_available=0 
	if [[ "$o_human" != "" ]]
	then
		if [[ $+commands[numfmt] == 1 ]]
		then
			numfmt_available=1 
		elif [[ $+commands[gnumfmt] == 1 ]]
		then
			gnumfmt_available=1 
		else
			print -u2 "'numfmt' or 'gnumfmt' command not found, human readable output will not work."
			print -u2 "\tFalling back to normal file size output"
			o_human="" 
		fi
	fi
	numfmt_local () {
		if [[ "$o_si" != "" ]]
		then
			if (( $numfmt_available ))
			then
				numfmt --to=si $1
			elif (( $gnumfmt_available ))
			then
				gnumfmt --to=si $1
			fi
		else
			if (( $numfmt_available ))
			then
				numfmt --to=iec $1
			elif (( $gnumfmt_available ))
			then
				gnumfmt --to=iec $1
			fi
		fi
	}
	typeset -i INSIDE_WORK_TREE=0 
	if [[ $(command git rev-parse --is-inside-work-tree 2>/dev/null) == true ]]
	then
		INSIDE_WORK_TREE=1 
	fi
	typeset -a base_dirs
	typeset base_dir
	if [[ "$@" == "" ]]
	then
		base_dirs=. 
	else
		base_dirs=($@) 
	fi
	K_COLOR_DI="0;34" 
	K_COLOR_LN="0;35" 
	K_COLOR_SO="0;32" 
	K_COLOR_PI="0;33" 
	K_COLOR_EX="0;31" 
	K_COLOR_BD="34;46" 
	K_COLOR_CD="34;43" 
	K_COLOR_SU="30;41" 
	K_COLOR_SG="30;46" 
	K_COLOR_TW="30;42" 
	K_COLOR_OW="30;43" 
	K_COLOR_BR="0;30" 
	if [[ $(uname) == 'Darwin' && -n $LSCOLORS ]]
	then
		K_COLOR_DI=$(_k_bsd_to_ansi $LSCOLORS[1]  $LSCOLORS[2]) 
		K_COLOR_LN=$(_k_bsd_to_ansi $LSCOLORS[3]  $LSCOLORS[4]) 
		K_COLOR_SO=$(_k_bsd_to_ansi $LSCOLORS[5]  $LSCOLORS[6]) 
		K_COLOR_PI=$(_k_bsd_to_ansi $LSCOLORS[7]  $LSCOLORS[8]) 
		K_COLOR_EX=$(_k_bsd_to_ansi $LSCOLORS[9]  $LSCOLORS[10]) 
		K_COLOR_BD=$(_k_bsd_to_ansi $LSCOLORS[11] $LSCOLORS[12]) 
		K_COLOR_CD=$(_k_bsd_to_ansi $LSCOLORS[13] $LSCOLORS[14]) 
		K_COLOR_SU=$(_k_bsd_to_ansi $LSCOLORS[15] $LSCOLORS[16]) 
		K_COLOR_SG=$(_k_bsd_to_ansi $LSCOLORS[17] $LSCOLORS[18]) 
		K_COLOR_TW=$(_k_bsd_to_ansi $LSCOLORS[19] $LSCOLORS[20]) 
		K_COLOR_OW=$(_k_bsd_to_ansi $LSCOLORS[21] $LSCOLORS[22]) 
	fi
	for base_dir in $base_dirs
	do
		if [[ "$#base_dirs" > 1 ]]
		then
			if [[ "$base_dir" != "${base_dirs[1]}" ]]
			then
				print
			fi
			print -r "${base_dir}:"
		fi
		typeset -a MAX_LEN A RESULTS STAT_RESULTS
		typeset TOTAL_BLOCKS
		typeset K_EPOCH="${EPOCHSECONDS:?}" 
		typeset -i TOTAL_BLOCKS=0 
		MAX_LEN=(0 0 0 0 0 0) 
		RESULTS=() 
		typeset -i IS_GIT_REPO=0 
		typeset GIT_TOPLEVEL
		typeset -i LARGE_FILE_COLOR=196 
		typeset -a SIZELIMITS_TO_COLOR
		SIZELIMITS_TO_COLOR=(1024 46 2048 82 3072 118 5120 154 10240 190 20480 226 40960 220 102400 214 262144 208 524288 202) 
		typeset -i ANCIENT_TIME_COLOR=236 
		typeset -a FILEAGES_TO_COLOR
		FILEAGES_TO_COLOR=(0 196 60 255 3600 252 86400 250 604800 244 2419200 244 15724800 242 31449600 240 62899200 238) 
		typeset -a show_list
		show_list=() 
		if [[ ! -e $base_dir ]]
		then
			print -u2 "k: cannot access $base_dir: No such file or directory"
		elif [[ -f $base_dir ]]
		then
			show_list=($base_dir) 
		else
			if [[ "$o_all" != "" && "$o_almost_all" == "" && "$o_no_directory" == "" ]]
			then
				show_list+=($base_dir/.) 
				show_list+=($base_dir/..) 
			fi
			if [[ "$o_all" != "" || "$o_almost_all" != "" ]]
			then
				if [[ "$o_directory" != "" ]]
				then
					show_list+=($base_dir/*(D/$SORT_GLOB)) 
				elif [[ "$o_no_directory" != "" ]]
				then
					show_list+=($base_dir/*(D^/$SORT_GLOB)) 
				else
					show_list+=($base_dir/*(D$SORT_GLOB)) 
				fi
			else
				if [[ "$o_directory" != "" ]]
				then
					show_list+=($base_dir/*(/$SORT_GLOB)) 
				elif [[ "$o_no_directory" != "" ]]
				then
					show_list+=($base_dir/*(^/$SORT_GLOB)) 
				else
					show_list+=($base_dir/*($SORT_GLOB)) 
				fi
			fi
		fi
		typeset -i i=1 j=1 k=1 
		typeset -a STATS_PARAMS_LIST
		typeset fn statvar h
		typeset -A sv
		STATS_PARAMS_LIST=() 
		for fn in $show_list
		do
			statvar="stats_$i" 
			typeset -A $statvar
			zstat -H $statvar -Lsn -F "%s^%d^%b^%H:%M^%Y" -- "$fn"
			STATS_PARAMS_LIST+=($statvar) 
			i+=1 
		done
		for statvar in "${STATS_PARAMS_LIST[@]}"
		do
			sv=("${(@Pkv)statvar}") 
			if [[ ${#sv[mode]} -gt $MAX_LEN[1] ]]
			then
				MAX_LEN[1]=${#sv[mode]} 
			fi
			if [[ ${#sv[nlink]} -gt $MAX_LEN[2] ]]
			then
				MAX_LEN[2]=${#sv[nlink]} 
			fi
			if [[ ${#sv[uid]} -gt $MAX_LEN[3] ]]
			then
				MAX_LEN[3]=${#sv[uid]} 
			fi
			if [[ ${#sv[gid]} -gt $MAX_LEN[4] ]]
			then
				MAX_LEN[4]=${#sv[gid]} 
			fi
			if [[ "$o_human" != "" ]]
			then
				h=$(numfmt_local ${sv[size]}) 
				if (( ${#h} > $MAX_LEN[5] ))
				then
					MAX_LEN[5]=${#h} 
				fi
			else
				if [[ ${#sv[size]} -gt $MAX_LEN[5] ]]
				then
					MAX_LEN[5]=${#sv[size]} 
				fi
			fi
			TOTAL_BLOCKS+=$sv[blocks] 
		done
		echo "total $TOTAL_BLOCKS"
		typeset REPOMARKER
		typeset REPOBRANCH
		typeset PERMISSIONS HARDLINKCOUNT OWNER GROUP FILESIZE FILESIZE_OUT DATE NAME SYMLINK_TARGET
		typeset FILETYPE PER1 PER2 PER3 PERMISSIONS_OUTPUT STATUS
		typeset TIME_DIFF TIME_COLOR DATE_OUTPUT
		typeset -i IS_DIRECTORY IS_SYMLINK IS_SOCKET IS_PIPE IS_EXECUTABLE IS_BLOCK_SPECIAL IS_CHARACTER_SPECIAL HAS_UID_BIT HAS_GID_BIT HAS_STICKY_BIT IS_WRITABLE_BY_OTHERS
		typeset -i COLOR
		k=1 
		for statvar in "${STATS_PARAMS_LIST[@]}"
		do
			sv=("${(@Pkv)statvar}") 
			REPOMARKER=" " 
			REPOBRANCH="" 
			IS_DIRECTORY=0 
			IS_SYMLINK=0 
			IS_SOCKET=0 
			IS_PIPE=0 
			IS_EXECUTABLE=0 
			IS_BLOCK_SPECIAL=0 
			IS_CHARACTER_SPECIAL=0 
			HAS_UID_BIT=0 
			HAS_GID_BIT=0 
			HAS_STICKY_BIT=0 
			IS_WRITABLE_BY_OTHERS=0 
			PERMISSIONS="${sv[mode]}" 
			HARDLINKCOUNT="${sv[nlink]}" 
			OWNER="${sv[uid]}" 
			GROUP="${sv[gid]}" 
			FILESIZE="${sv[size]}" 
			DATE=(${(s:^:)sv[mtime]}) 
			NAME="${sv[name]}" 
			SYMLINK_TARGET="${sv[link]}" 
			if [[ -d "$NAME" ]]
			then
				IS_DIRECTORY=1 
			fi
			if [[ -L "$NAME" ]]
			then
				IS_SYMLINK=1 
			fi
			if [[ -S "$NAME" ]]
			then
				IS_SOCKET=1 
			fi
			if [[ -p "$NAME" ]]
			then
				IS_PIPE=1 
			fi
			if [[ -x "$NAME" ]]
			then
				IS_EXECUTABLE=1 
			fi
			if [[ -b "$NAME" ]]
			then
				IS_BLOCK_SPECIAL=1 
			fi
			if [[ -c "$NAME" ]]
			then
				IS_CHARACTER_SPECIAL=1 
			fi
			if [[ -u "$NAME" ]]
			then
				HAS_UID_BIT=1 
			fi
			if [[ -g "$NAME" ]]
			then
				HAS_GID_BIT=1 
			fi
			if [[ -k "$NAME" ]]
			then
				HAS_STICKY_BIT=1 
			fi
			if [[ $PERMISSIONS[9] == 'w' ]]
			then
				IS_WRITABLE_BY_OTHERS=1 
			fi
			if [[ "$o_no_vcs" != "" ]]
			then
				IS_GIT_REPO=0 
				GIT_TOPLEVEL='' 
			else
				if (( IS_DIRECTORY ))
				then
					builtin cd -q $NAME 2> /dev/null || builtin cd -q - > /dev/null && IS_GIT_REPO=0 
				else
					builtin cd -q $NAME:a:h 2> /dev/null || builtin cd -q - > /dev/null && IS_GIT_REPO=0 
				fi
				if [[ $(command git rev-parse --is-inside-work-tree 2>/dev/null) == true ]]
				then
					IS_GIT_REPO=1 
					GIT_TOPLEVEL=$(command git rev-parse --show-toplevel) 
				else
					IS_GIT_REPO=0 
				fi
				builtin cd -q - > /dev/null
			fi
			if [[ "$o_human" != "" ]]
			then
				FILESIZE_OUT=$(numfmt_local $FILESIZE) 
			else
				FILESIZE_OUT=$FILESIZE 
			fi
			PERMISSIONS="${(r:MAX_LEN[1]:)PERMISSIONS}" 
			HARDLINKCOUNT="${(l:MAX_LEN[2]:)HARDLINKCOUNT}" 
			OWNER="${(l:MAX_LEN[3]:)OWNER}" 
			GROUP="${(l:MAX_LEN[4]:)GROUP}" 
			FILESIZE_OUT="${(l:MAX_LEN[5]:)FILESIZE_OUT}" 
			FILETYPE="${PERMISSIONS[1]}" 
			PER1="${PERMISSIONS[2,4]}" 
			PER2="${PERMISSIONS[5,7]}" 
			PER3="${PERMISSIONS[8,10]}" 
			PERMISSIONS_OUTPUT="$FILETYPE$PER1$PER2$PER3" 
			OWNER=$'\e[38;5;241m'"$OWNER"$'\e[0m' 
			GROUP=$'\e[38;5;241m'"$GROUP"$'\e[0m' 
			COLOR=LARGE_FILE_COLOR 
			for i j in ${SIZELIMITS_TO_COLOR[@]}
			do
				(( FILESIZE <= i )) || continue
				COLOR=$j 
				break
			done
			FILESIZE_OUT=$'\e[38;5;'"${COLOR}m$FILESIZE_OUT"$'\e[0m' 
			TIME_DIFF=$(( K_EPOCH - DATE[1] )) 
			TIME_COLOR=$ANCIENT_TIME_COLOR 
			for i j in ${FILEAGES_TO_COLOR[@]}
			do
				(( TIME_DIFF < i )) || continue
				TIME_COLOR=$j 
				break
			done
			if (( TIME_DIFF < 15724800 ))
			then
				DATE_OUTPUT="${DATE[2]} ${(r:5:: :)${DATE[3][0,5]}} ${DATE[4]}" 
			else
				DATE_OUTPUT="${DATE[2]} ${(r:6:: :)${DATE[3][0,5]}} ${DATE[5]}" 
			fi
			DATE_OUTPUT[1]="${DATE_OUTPUT[1]//0/ }" 
			DATE_OUTPUT=$'\e[38;5;'"${TIME_COLOR}m${DATE_OUTPUT}"$'\e[0m' 
			if [[ "$o_no_vcs" != "" ]]
			then
				REPOMARKER="" 
			elif (( IS_GIT_REPO != 0))
			then
				if (( INSIDE_WORK_TREE == 0 ))
				then
					REPOBRANCH=$(command git --git-dir="$GIT_TOPLEVEL/.git" --work-tree="${NAME}" rev-parse --abbrev-ref HEAD 2>/dev/null) 
					if (( IS_DIRECTORY ))
					then
						if command git --git-dir="$GIT_TOPLEVEL/.git" --work-tree="${NAME}" diff --stat --quiet --ignore-submodules HEAD &> /dev/null
						then
							REPOMARKER=$'\e[38;5;46m|\e[0m' 
						else
							REPOMARKER=$'\e[0;31m+\e[0m' 
						fi
					fi
				else
					if (( IS_DIRECTORY ))
					then
						if command git check-ignore --quiet ${NAME} 2> /dev/null
						then
							STATUS='!!' 
						elif command git diff --stat --quiet --ignore-submodules ${NAME} 2> /dev/null
						then
							STATUS='' 
						else
							STATUS=' M' 
						fi
					else
						STATUS=$(command git status --porcelain --ignored --untracked-files=normal $GIT_TOPLEVEL/${${${NAME:a}##$GIT_TOPLEVEL}#*/}) 
					fi
					STATUS=${STATUS[1,2]} 
					if [[ $STATUS == ' M' ]]
					then
						REPOMARKER=$'\e[0;31m+\e[0m' 
					elif [[ $STATUS == 'M ' ]]
					then
						REPOMARKER=$'\e[38;5;082m+\e[0m' 
					elif [[ $STATUS == '??' ]]
					then
						REPOMARKER=$'\e[38;5;214m+\e[0m' 
					elif [[ $STATUS == '!!' ]]
					then
						REPOMARKER=$'\e[38;5;238m|\e[0m' 
					elif [[ $STATUS == 'A ' ]]
					then
						REPOMARKER=$'\e[38;5;082m+\e[0m' 
					else
						REPOMARKER=$'\e[38;5;082m|\e[0m' 
					fi
				fi
			fi
			NAME="${${NAME##*/}//$'\e'/\\e}" 
			if [[ $IS_DIRECTORY == 1 ]]
			then
				if [[ $IS_WRITABLE_BY_OTHERS == 1 ]]
				then
					if [[ $HAS_STICKY_BIT == 1 ]]
					then
						NAME=$'\e['"$K_COLOR_TW"'m'"$NAME"$'\e[0m' 
					fi
					NAME=$'\e['"$K_COLOR_OW"'m'"$NAME"$'\e[0m' 
				fi
				NAME=$'\e['"$K_COLOR_DI"'m'"$NAME"$'\e[0m' 
			elif [[ $IS_SYMLINK == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_LN"'m'"$NAME"$'\e[0m' 
			elif [[ $IS_SOCKET == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_SO"'m'"$NAME"$'\e[0m' 
			elif [[ $IS_PIPE == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_PI"'m'"$NAME"$'\e[0m' 
			elif [[ $HAS_UID_BIT == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_SU"'m'"$NAME"$'\e[0m' 
			elif [[ $HAS_GID_BIT == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_SG"'m'"$NAME"$'\e[0m' 
			elif [[ $IS_EXECUTABLE == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_EX"'m'"$NAME"$'\e[0m' 
			elif [[ $IS_BLOCK_SPECIAL == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_BD"'m'"$NAME"$'\e[0m' 
			elif [[ $IS_CHARACTER_SPECIAL == 1 ]]
			then
				NAME=$'\e['"$K_COLOR_CD"'m'"$NAME"$'\e[0m' 
			fi
			REPOBRANCH=$'\e['"$K_COLOR_BR"'m'"$REPOBRANCH"$'\e[0m' 
			if [[ $SYMLINK_TARGET != "" ]]
			then
				SYMLINK_TARGET=" -> ${SYMLINK_TARGET//$'\e'/\\e}" 
			fi
			print -r -- "$PERMISSIONS_OUTPUT $HARDLINKCOUNT $OWNER $GROUP $FILESIZE_OUT $DATE_OUTPUT $REPOMARKER $NAME$SYMLINK_TARGET $REPOBRANCH"
			k=$((k+1)) 
		done
	done
}
man-preview () {
	man -w "$@" &> /dev/null && man -t "$@" | open -f -a Preview || man "$@"
}
mkcd () {
	mkdir -p $@ && cd ${@:$#}
}
music () {
	local APP_NAME=Music sw_vers=$(sw_vers -productVersion 2>/dev/null) 
	autoload is-at-least
	if [[ -z "$sw_vers" ]] || is-at-least 10.15 $sw_vers
	then
		if [[ $0 = itunes ]]
		then
			echo The itunes function name is deprecated. Use \'music\' instead. >&2
			return 1
		fi
	else
		APP_NAME=iTunes 
	fi
	local opt=$1 playlist=$2 
	(( $# > 0 )) && shift
	case "$opt" in
		(launch | play | pause | stop | rewind | resume | quit)  ;;
		(mute) opt="set mute to true"  ;;
		(unmute) opt="set mute to false"  ;;
		(next | previous) opt="$opt track"  ;;
		(vol) local new_volume volume=$(osascript -e "tell application \"$APP_NAME\" to get sound volume") 
			if [[ $# -eq 0 ]]
			then
				echo "Current volume is ${volume}."
				return 0
			fi
			case $1 in
				(up) new_volume=$((volume + 10 < 100 ? volume + 10 : 100))  ;;
				(down) new_volume=$((volume - 10 > 0 ? volume - 10 : 0))  ;;
				(<0-100>) new_volume=$1  ;;
				(*) echo "'$1' is not valid. Expected <0-100>, up or down."
					return 1 ;;
			esac
			opt="set sound volume to ${new_volume}"  ;;
		(playlist) if [[ -n "$playlist" ]]
			then
				osascript 2> /dev/null <<EOF
          tell application "$APP_NAME"
            set new_playlist to "$playlist" as string
            play playlist new_playlist
          end tell
EOF
				if [[ $? -eq 0 ]]
				then
					opt="play" 
				else
					opt="stop" 
				fi
			else
				opt="set allPlaylists to (get name of every playlist)" 
			fi ;;
		(playing | status) local currenttrack currentartist state=$(osascript -e "tell application \"$APP_NAME\" to player state as string") 
			if [[ "$state" = "playing" ]]
			then
				currenttrack=$(osascript -e "tell application \"$APP_NAME\" to name of current track as string") 
				currentartist=$(osascript -e "tell application \"$APP_NAME\" to artist of current track as string") 
				echo -E "Listening to ${fg[yellow]}${currenttrack}${reset_color} by ${fg[yellow]}${currentartist}${reset_color}"
			else
				echo "$APP_NAME is $state"
			fi
			return 0 ;;
		(shuf | shuff | shuffle) local state=$1 
			if [[ -n "$state" && "$state" != (on|off|toggle) ]]
			then
				print "Usage: $0 shuffle [on|off|toggle]. Invalid option."
				return 1
			fi
			case "$state" in
				(on | off) osascript > /dev/null 2>&1 <<EOF
            tell application "System Events" to perform action "AXPress" of (menu item "${state}" of menu "Shuffle" of menu item "Shuffle" of menu "Controls" of menu bar item "Controls" of menu bar 1 of application process "iTunes" )
EOF
					return 0 ;;
				(toggle | *) osascript > /dev/null 2>&1 <<EOF
            tell application "System Events" to perform action "AXPress" of (button 2 of process "iTunes"'s window "iTunes"'s scroll area 1)
EOF
					return 0 ;;
			esac ;;
		("" | -h | --help) echo "Usage: $0 <option>"
			echo "option:"
			echo "\t-h|--help\tShow this message and exit"
			echo "\tlaunch|play|pause|stop|rewind|resume|quit"
			echo "\tmute|unmute\tMute or unmute $APP_NAME"
			echo "\tnext|previous\tPlay next or previous track"
			echo "\tshuf|shuffle [on|off|toggle]\tSet shuffled playback. Default: toggle. Note: toggle doesn't support the MiniPlayer."
			echo "\tvol [0-100|up|down]\tGet or set the volume. 0 to 100 sets the volume. 'up' / 'down' increases / decreases by 10 points. No argument displays current volume."
			echo "\tplaying|status\tShow what song is currently playing in Music."
			echo "\tplaylist [playlist name]\t Play specific playlist"
			return 0 ;;
		(*) print "Unknown option: $opt"
			return 1 ;;
	esac
	osascript -e "tell application \"$APP_NAME\" to $opt"
}
nvm_prompt_info () {
	which nvm &> /dev/null || return
	local nvm_prompt=${$(nvm current)#v} 
	echo "${ZSH_THEME_NVM_PROMPT_PREFIX}${nvm_prompt:gs/%/%%}${ZSH_THEME_NVM_PROMPT_SUFFIX}"
}
omz () {
	[[ $# -gt 0 ]] || {
		_omz::help
		return 1
	}
	local command="$1" 
	shift
	(( $+functions[_omz::$command] )) || {
		_omz::help
		return 1
	}
	_omz::$command "$@"
}
omz_diagnostic_dump () {
	emulate -L zsh
	builtin echo "Generating diagnostic dump; please be patient..."
	local thisfcn=omz_diagnostic_dump 
	local -A opts
	local opt_verbose opt_noverbose opt_outfile
	local timestamp=$(date +%Y%m%d-%H%M%S) 
	local outfile=omz_diagdump_$timestamp.txt 
	builtin zparseopts -A opts -D -- "v+=opt_verbose" "V+=opt_noverbose"
	local verbose n_verbose=${#opt_verbose} n_noverbose=${#opt_noverbose} 
	(( verbose = 1 + n_verbose - n_noverbose ))
	if [[ ${#*} > 0 ]]
	then
		opt_outfile=$1 
	fi
	if [[ ${#*} > 1 ]]
	then
		builtin echo "$thisfcn: error: too many arguments" >&2
		return 1
	fi
	if [[ -n "$opt_outfile" ]]
	then
		outfile="$opt_outfile" 
	fi
	_omz_diag_dump_one_big_text &> "$outfile"
	if [[ $? != 0 ]]
	then
		builtin echo "$thisfcn: error while creating diagnostic dump; see $outfile for details"
	fi
	builtin echo
	builtin echo Diagnostic dump file created at: "$outfile"
	builtin echo
	builtin echo To share this with OMZ developers, post it as a gist on GitHub
	builtin echo at "https://gist.github.com" and share the link to the gist.
	builtin echo
	builtin echo "WARNING: This dump file contains all your zsh and omz configuration files,"
	builtin echo "so don't share it publicly if there's sensitive information in them."
	builtin echo
}
omz_history () {
	local clear list
	zparseopts -E c=clear l=list
	if [[ -n "$clear" ]]
	then
		echo -n >| "$HISTFILE"
		fc -p "$HISTFILE"
		echo History file deleted. >&2
	elif [[ -n "$list" ]]
	then
		builtin fc "$@"
	else
		[[ ${@[-1]-} = *[0-9]* ]] && builtin fc -l "$@" || builtin fc -l "$@" 1
	fi
}
omz_termsupport_precmd () {
	[[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return
	title "$ZSH_THEME_TERM_TAB_TITLE_IDLE" "$ZSH_THEME_TERM_TITLE_IDLE"
}
omz_termsupport_preexec () {
	[[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return
	emulate -L zsh
	setopt extended_glob
	local -a cmdargs
	cmdargs=("${(z)2}") 
	if [[ "${cmdargs[1]}" = fg ]]
	then
		local job_id jobspec="${cmdargs[2]#%}" 
		case "$jobspec" in
			(<->) job_id=${jobspec}  ;;
			("" | % | +) job_id=${(k)jobstates[(r)*:+:*]}  ;;
			(-) job_id=${(k)jobstates[(r)*:-:*]}  ;;
			([?]*) job_id=${(k)jobtexts[(r)*${(Q)jobspec}*]}  ;;
			(*) job_id=${(k)jobtexts[(r)${(Q)jobspec}*]}  ;;
		esac
		if [[ -n "${jobtexts[$job_id]}" ]]
		then
			1="${jobtexts[$job_id]}" 
			2="${jobtexts[$job_id]}" 
		fi
	fi
	local CMD="${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}" 
	local LINE="${2:gs/%/%%}" 
	title "$CMD" "%100>...>${LINE}%<<"
}
omz_urldecode () {
	emulate -L zsh
	local encoded_url=$1 
	local caller_encoding=$langinfo[CODESET] 
	local LC_ALL=C 
	export LC_ALL
	local tmp=${encoded_url:gs/+/ /} 
	tmp=${tmp:gs/\\/\\\\/} 
	tmp=${tmp:gs/%/\\x/} 
	local decoded="$(printf -- "$tmp")" 
	local -a safe_encodings
	safe_encodings=(UTF-8 utf8 US-ASCII) 
	if [[ -z ${safe_encodings[(r)$caller_encoding]} ]]
	then
		decoded=$(echo -E "$decoded" | iconv -f UTF-8 -t $caller_encoding) 
		if [[ $? != 0 ]]
		then
			echo "Error converting string from UTF-8 to $caller_encoding" >&2
			return 1
		fi
	fi
	echo -E "$decoded"
}
omz_urlencode () {
	emulate -L zsh
	local -a opts
	zparseopts -D -E -a opts r m P
	local in_str="$@" 
	local url_str="" 
	local spaces_as_plus
	if [[ -z $opts[(r)-P] ]]
	then
		spaces_as_plus=1 
	fi
	local str="$in_str" 
	local encoding=$langinfo[CODESET] 
	local safe_encodings
	safe_encodings=(UTF-8 utf8 US-ASCII) 
	if [[ -z ${safe_encodings[(r)$encoding]} ]]
	then
		str=$(echo -E "$str" | iconv -f $encoding -t UTF-8) 
		if [[ $? != 0 ]]
		then
			echo "Error converting string from $encoding to UTF-8" >&2
			return 1
		fi
	fi
	local i byte ord LC_ALL=C 
	export LC_ALL
	local reserved=';/?:@&=+$,' 
	local mark='_.!~*''()-' 
	local dont_escape="[A-Za-z0-9" 
	if [[ -z $opts[(r)-r] ]]
	then
		dont_escape+=$reserved 
	fi
	if [[ -z $opts[(r)-m] ]]
	then
		dont_escape+=$mark 
	fi
	dont_escape+="]" 
	local url_str="" 
	for ((i = 1; i <= ${#str}; ++i )) do
		byte="$str[i]" 
		if [[ "$byte" =~ "$dont_escape" ]]
		then
			url_str+="$byte" 
		else
			if [[ "$byte" == " " && -n $spaces_as_plus ]]
			then
				url_str+="+" 
			else
				ord=$(( [##16] #byte )) 
				url_str+="%$ord" 
			fi
		fi
	done
	echo -E "$url_str"
}
open_command () {
	local open_cmd
	case "$OSTYPE" in
		(darwin*) open_cmd='open'  ;;
		(cygwin*) open_cmd='cygstart'  ;;
		(linux*) [[ "$(uname -r)" != *icrosoft* ]] && open_cmd='nohup xdg-open'  || {
				open_cmd='cmd.exe /c start ""' 
				[[ -e "$1" ]] && {
					1="$(wslpath -w "${1:a}")"  || return 1
				}
			} ;;
		(msys*) open_cmd='start ""'  ;;
		(*) echo "Platform $OSTYPE not supported"
			return 1 ;;
	esac
	${=open_cmd} "$@" &> /dev/null
}
parse_git_dirty () {
	local STATUS
	local -a FLAGS
	FLAGS=('--porcelain') 
	if [[ "$(__git_prompt_git config --get oh-my-zsh.hide-dirty)" != "1" ]]
	then
		if [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == "true" ]]
		then
			FLAGS+='--untracked-files=no' 
		fi
		case "${GIT_STATUS_IGNORE_SUBMODULES:-}" in
			(git)  ;;
			(*) FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"  ;;
		esac
		STATUS=$(__git_prompt_git status ${FLAGS} 2> /dev/null | tail -n 1) 
	fi
	if [[ -n $STATUS ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
	else
		echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
	fi
}
pfd () {
	osascript 2> /dev/null <<EOF
    tell application "Finder"
      return POSIX path of (insertion location as alias)
    end tell
EOF
}
pfs () {
	osascript 2> /dev/null <<EOF
    set output to ""
    tell application "Finder" to set the_selection to selection
    set item_count to count the_selection
    repeat with item_index from 1 to count the_selection
      if item_index is less than item_count then set the_delimiter to "\n"
      if item_index is item_count then set the_delimiter to ""
      set output to output & ((item item_index of the_selection as alias)'s POSIX path) & the_delimiter
    end repeat
EOF
}
pmodload () {
	local -A ices
	(( ${+ICE} )) && ices=("${(kv)ICE[@]}" teleid '') 
	local -A ICE ZINIT_ICE
	ICE=("${(kv)ices[@]}") ZINIT_ICE=("${(kv)ices[@]}") 
	while (( $# ))
	do
		ICE[teleid]="PZT::modules/$1${ICE[svn]-/init.zsh}" 
		ZINIT_ICE[teleid]="PZT::modules/$1${ICE[svn]-/init.zsh}" 
		if zstyle -t ":prezto:module:$1" loaded 'yes' 'no'
		then
			shift
			continue
		else
			[[ -z ${ZINIT_SNIPPETS[PZT::modules/$1${ICE[svn]-/init.zsh}]} && -z ${ZINIT_SNIPPETS[https://github.com/sorin-ionescu/prezto/trunk/modules/$1${ICE[svn]-/init.zsh}]} ]] && .zinit-load-snippet PZT::modules/"$1${ICE[svn]-/init.zsh}"
			shift
		fi
	done
}
prompt_aws () {
	[[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
	case "$AWS_PROFILE" in
		(*-prod | *production*) prompt_segment red yellow "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
		(*) prompt_segment green black "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
	esac
}
prompt_bzr () {
	(( $+commands[bzr] )) || return
	local dir="$PWD" 
	while [[ ! -d "$dir/.bzr" ]]
	do
		[[ "$dir" = "/" ]] && return
		dir="${dir:h}" 
	done
	local bzr_status status_mod status_all revision
	if bzr_status=$(bzr status 2>&1) 
	then
		status_mod=$(echo -n "$bzr_status" | head -n1 | grep "modified" | wc -m) 
		status_all=$(echo -n "$bzr_status" | head -n1 | wc -m) 
		revision=${$(bzr log -r-1 --log-format line | cut -d: -f1):gs/%/%%} 
		if [[ $status_mod -gt 0 ]]
		then
			prompt_segment yellow black "bzr@$revision ✚"
		else
			if [[ $status_all -gt 0 ]]
			then
				prompt_segment yellow black "bzr@$revision"
			else
				prompt_segment green black "bzr@$revision"
			fi
		fi
	fi
}
prompt_context () {
	
}
prompt_dir () {
	prompt_segment blue $CURRENT_FG '%~'
}
prompt_end () {
	if [[ -n $CURRENT_BG ]]
	then
		echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
	else
		echo -n "%{%k%}"
	fi
	echo -n "%{%f%}"
	CURRENT_BG='' 
}
prompt_git () {
	(( $+commands[git] )) || return
	if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]
	then
		return
	fi
	local PL_BRANCH_CHAR
	() {
		local LC_ALL="" LC_CTYPE="en_US.UTF-8" 
		PL_BRANCH_CHAR=$'\ue0a0' 
	}
	local ref dirty mode repo_path
	if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]
	then
		repo_path=$(git rev-parse --git-dir 2>/dev/null) 
		dirty=$(parse_git_dirty) 
		ref=$(git symbolic-ref HEAD 2> /dev/null)  || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)" 
		if [[ -n $dirty ]]
		then
			prompt_segment yellow black
		else
			prompt_segment green $CURRENT_FG
		fi
		if [[ -e "${repo_path}/BISECT_LOG" ]]
		then
			mode=" <B>" 
		elif [[ -e "${repo_path}/MERGE_HEAD" ]]
		then
			mode=" >M<" 
		elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]
		then
			mode=" >R>" 
		fi
		setopt promptsubst
		autoload -Uz vcs_info
		zstyle ':vcs_info:*' enable git
		zstyle ':vcs_info:*' get-revision true
		zstyle ':vcs_info:*' check-for-changes true
		zstyle ':vcs_info:*' stagedstr '✚'
		zstyle ':vcs_info:*' unstagedstr '±'
		zstyle ':vcs_info:*' formats ' %u%c'
		zstyle ':vcs_info:*' actionformats ' %u%c'
		vcs_info
		echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
	fi
}
prompt_hg () {
	(( $+commands[hg] )) || return
	local rev st branch
	if $(hg id >/dev/null 2>&1)
	then
		if $(hg prompt >/dev/null 2>&1)
		then
			if [[ $(hg prompt "{status|unknown}") = "?" ]]
			then
				prompt_segment red white
				st='±' 
			elif [[ -n $(hg prompt "{status|modified}") ]]
			then
				prompt_segment yellow black
				st='±' 
			else
				prompt_segment green $CURRENT_FG
			fi
			echo -n ${$(hg prompt "☿ {rev}@{branch}"):gs/%/%%} $st
		else
			st="" 
			rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g') 
			branch=$(hg id -b 2>/dev/null) 
			if `hg st | grep -q "^\?"`
			then
				prompt_segment red black
				st='±' 
			elif `hg st | grep -q "^[MA]"`
			then
				prompt_segment yellow black
				st='±' 
			else
				prompt_segment green $CURRENT_FG
			fi
			echo -n "☿ ${rev:gs/%/%%}@${branch:gs/%/%%}" $st
		fi
	fi
}
prompt_segment () {
	local bg fg
	[[ -n $1 ]] && bg="%K{$1}"  || bg="%k" 
	[[ -n $2 ]] && fg="%F{$2}"  || fg="%f" 
	if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]
	then
		echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
	else
		echo -n "%{$bg%}%{$fg%} "
	fi
	CURRENT_BG=$1 
	[[ -n $3 ]] && echo -n $3
}
prompt_status () {
	local -a symbols
	[[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘" 
	[[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡" 
	[[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙" 
	[[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}
prompt_virtualenv () {
	if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]
	then
		prompt_segment blue black "(${VIRTUAL_ENV:t:gs/%/%%})"
	fi
}
pushdf () {
	pushd "$(pfd)"
}
pxd () {
	dirname $(osascript 2>/dev/null <<EOF
    if application "Xcode" is running then
      tell application "Xcode"
        return path of active workspace document
      end tell
    end if
EOF
)
}
pyenv_prompt_info () {
	return 1
}
quick-look () {
	(( $# > 0 )) && qlmanage -p $* &> /dev/null &
}
rbenv () {
	local command
	command="${1:-}" 
	if [ "$#" -gt 0 ]
	then
		shift
	fi
	case "$command" in
		(rehash | shell) eval "$(rbenv "sh-$command" "$@")" ;;
		(*) command rbenv "$command" "$@" ;;
	esac
}
rbenv_prompt_info () {
	return 1
}
regexp-replace () {
	argv=("$1" "$2" "$3") 
	4=0 
	[[ -o re_match_pcre ]] && 4=1 
	emulate -L zsh
	local MATCH MBEGIN MEND
	local -a match mbegin mend
	if (( $4 ))
	then
		zmodload zsh/pcre || return 2
		pcre_compile -- "$2" && pcre_study || return 2
		4=0 6= 
		local ZPCRE_OP
		while pcre_match -b -n $4 -- "${(P)1}"
		do
			5=${(e)3} 
			argv+=(${(s: :)ZPCRE_OP} "$5") 
			4=$((argv[-2] + (argv[-3] == argv[-2]))) 
		done
		(($# > 6)) || return
		set +o multibyte
		5= 6=1 
		for 2 3 4 in "$@[7,-1]"
		do
			5+=${(P)1[$6,$2]}$4 
			6=$(($3 + 1)) 
		done
		5+=${(P)1[$6,-1]} 
	else
		4=${(P)1} 
		while [[ -n $4 ]]
		do
			if [[ $4 =~ $2 ]]
			then
				5+=${4[1,MBEGIN-1]}${(e)3} 
				if ((MEND < MBEGIN))
				then
					((MEND++))
					5+=${4[1]} 
				fi
				4=${4[MEND+1,-1]} 
				6=1 
			else
				break
			fi
		done
		[[ -n $6 ]] || return
		5+=$4 
	fi
	eval $1=\$5
}
rmdsstore () {
	find "${@:-.}" -type f -name .DS_Store -delete
}
ruby_prompt_info () {
	echo $(rvm_prompt_info || rbenv_prompt_info || chruby_prompt_info)
}
rvm_prompt_info () {
	[ -f $HOME/.rvm/bin/rvm-prompt ] || return 1
	local rvm_prompt
	rvm_prompt=$($HOME/.rvm/bin/rvm-prompt ${=ZSH_THEME_RVM_PROMPT_OPTIONS} 2>/dev/null) 
	[[ -z "${rvm_prompt}" ]] && return 1
	echo "${ZSH_THEME_RUBY_PROMPT_PREFIX}${rvm_prompt:gs/%/%%}${ZSH_THEME_RUBY_PROMPT_SUFFIX}"
}
spectrum_bls () {
	setopt localoptions nopromptsubst
	local ZSH_SPECTRUM_TEXT=${ZSH_SPECTRUM_TEXT:-Arma virumque cano Troiae qui primus ab oris} 
	for code in {000..255}
	do
		print -P -- "$code: ${BG[$code]}${ZSH_SPECTRUM_TEXT}%{$reset_color%}"
	done
}
spectrum_ls () {
	setopt localoptions nopromptsubst
	local ZSH_SPECTRUM_TEXT=${ZSH_SPECTRUM_TEXT:-Arma virumque cano Troiae qui primus ab oris} 
	for code in {000..255}
	do
		print -P -- "$code: ${FG[$code]}${ZSH_SPECTRUM_TEXT}%{$reset_color%}"
	done
}
split_tab () {
	local command="cd \\\"$PWD\\\"; clear" 
	(( $# > 0 )) && command="${command}; $*" 
	local the_app=$(_omz_macos_get_frontmost_app) 
	if [[ "$the_app" == 'iTerm' ]]
	then
		osascript 2> /dev/null <<EOF
      tell application "iTerm" to activate

      tell application "System Events"
        tell process "iTerm"
          tell menu item "Split Horizontally With Current Profile" of menu "Shell" of menu bar item "Shell" of menu bar 1
            click
          end tell
        end tell
        keystroke "${command} \n"
      end tell
EOF
	elif [[ "$the_app" == 'iTerm2' ]]
	then
		osascript <<EOF
      tell application "iTerm2"
        tell current session of first window
          set newSession to (split horizontally with same profile)
          tell newSession
            write text "${command}"
            select
          end tell
        end tell
      end tell
EOF
	elif [[ "$the_app" == 'Hyper' ]]
	then
		osascript > /dev/null <<EOF
    tell application "System Events"
      tell process "Hyper"
        tell menu item "Split Horizontally" of menu "Shell" of menu bar 1
          click
        end tell
      end tell
      delay 1
      keystroke "${command} \n"
    end tell
EOF
	else
		echo "$0: unsupported terminal app: $the_app" >&2
		return 1
	fi
}
spotify () {
	USER_CONFIG_DEFAULTS="CLIENT_ID=\"\"\nCLIENT_SECRET=\"\"" 
	USER_CONFIG_FILE="${HOME}/.shpotify.cfg" 
	if ! [[ -f "${USER_CONFIG_FILE}" ]]
	then
		touch "${USER_CONFIG_FILE}"
		echo -e "${USER_CONFIG_DEFAULTS}" > "${USER_CONFIG_FILE}"
	fi
	source "${USER_CONFIG_FILE}"
	showAPIHelp () {
		echo
		echo "Connecting to Spotify's API:"
		echo
		echo "  This command line application needs to connect to Spotify's API in order to"
		echo "  find music by name. It is very likely you want this feature!"
		echo
		echo "  To get this to work, you need to sign up (or in) and create an 'Application' at:"
		echo "  https://developer.spotify.com/my-applications/#!/applications/create"
		echo
		echo "  Once you've created an application, find the 'Client ID' and 'Client Secret'"
		echo "  values, and enter them into your shpotify config file at '${USER_CONFIG_FILE}'"
		echo
		echo "  Be sure to quote your values and don't add any extra spaces!"
		echo "  When done, it should look like this (but with your own values):"
		echo '  CLIENT_ID="abc01de2fghijk345lmnop"'
		echo '  CLIENT_SECRET="qr6stu789vwxyz"'
	}
	showHelp () {
		echo "Usage:"
		echo
		echo "  `basename $0` <command>"
		echo
		echo "Commands:"
		echo
		echo "  play                         # Resumes playback where Spotify last left off."
		echo "  play <song name>             # Finds a song by name and plays it."
		echo "  play album <album name>      # Finds an album by name and plays it."
		echo "  play artist <artist name>    # Finds an artist by name and plays it."
		echo "  play list <playlist name>    # Finds a playlist by name and plays it."
		echo "  play uri <uri>               # Play songs from specific uri."
		echo
		echo "  next                         # Skips to the next song in a playlist."
		echo "  prev                         # Returns to the previous song in a playlist."
		echo "  replay                       # Replays the current track from the beginning."
		echo "  pos <time>                   # Jumps to a time (in secs) in the current song."
		echo "  pause                        # Pauses (or resumes) Spotify playback."
		echo "  stop                         # Stops playback."
		echo "  quit                         # Stops playback and quits Spotify."
		echo
		echo "  vol up                       # Increases the volume by 10%."
		echo "  vol down                     # Decreases the volume by 10%."
		echo "  vol <amount>                 # Sets the volume to an amount between 0 and 100."
		echo "  vol [show]                   # Shows the current Spotify volume."
		echo
		echo "  status                       # Shows the current player status."
		echo "  status artist                # Shows the currently playing artist."
		echo "  status album                 # Shows the currently playing album."
		echo "  status track                 # Shows the currently playing track."
		echo
		echo "  share                        # Displays the current song's Spotify URL and URI."
		echo "  share url                    # Displays the current song's Spotify URL and copies it to the clipboard."
		echo "  share uri                    # Displays the current song's Spotify URI and copies it to the clipboard."
		echo
		echo "  toggle shuffle               # Toggles shuffle playback mode."
		echo "  toggle repeat                # Toggles repeat playback mode."
		showAPIHelp
	}
	cecho () {
		bold=$(tput bold) 
		green=$(tput setaf 2) 
		reset=$(tput sgr0) 
		echo $bold$green"$1"$reset
	}
	showArtist () {
		echo `osascript -e 'tell application "Spotify" to artist of current track as string'`
	}
	showAlbum () {
		echo `osascript -e 'tell application "Spotify" to album of current track as string'`
	}
	showTrack () {
		echo `osascript -e 'tell application "Spotify" to name of current track as string'`
	}
	showStatus () {
		state=`osascript -e 'tell application "Spotify" to player state as string'` 
		cecho "Spotify is currently $state."
		duration=`osascript -e 'tell application "Spotify"
            set durSec to (duration of current track / 1000) as text
            set tM to (round (durSec / 60) rounding down) as text
            if length of ((durSec mod 60 div 1) as text) is greater than 1 then
                set tS to (durSec mod 60 div 1) as text
            else
                set tS to ("0" & (durSec mod 60 div 1)) as text
            end if
            set myTime to tM as text & ":" & tS as text
            end tell
            return myTime'` 
		position=`osascript -e 'tell application "Spotify"
            set pos to player position
            set nM to (round (pos / 60) rounding down) as text
            if length of ((round (pos mod 60) rounding down) as text) is greater than 1 then
                set nS to (round (pos mod 60) rounding down) as text
            else
                set nS to ("0" & (round (pos mod 60) rounding down)) as text
            end if
            set nowAt to nM as text & ":" & nS as text
            end tell
            return nowAt'` 
		echo -e $reset"Artist: $(showArtist)\nAlbum: $(showAlbum)\nTrack: $(showTrack) \nPosition: $position / $duration"
	}
	if [ $# = 0 ]
	then
		showHelp
	else
		if [ ! -d /Applications/Spotify.app ] && [ ! -d $HOME/Applications/Spotify.app ]
		then
			echo "The Spotify application must be installed."
			return 1
		fi
		if [ $(osascript -e 'application "Spotify" is running') = "false" ]
		then
			osascript -e 'tell application "Spotify" to activate' || return 1
			sleep 2
		fi
	fi
	while [ $# -gt 0 ]
	do
		arg=$1 
		case $arg in
			("play") if [ $# != 1 ]
				then
					array=($@) 
					len=${#array[@]} 
					SPOTIFY_SEARCH_API="https://api.spotify.com/v1/search" 
					SPOTIFY_TOKEN_URI="https://accounts.spotify.com/api/token" 
					if [ -z "${CLIENT_ID}" ]
					then
						cecho "Invalid Client ID, please update ${USER_CONFIG_FILE}"
						showAPIHelp
						return 1
					fi
					if [ -z "${CLIENT_SECRET}" ]
					then
						cecho "Invalid Client Secret, please update ${USER_CONFIG_FILE}"
						showAPIHelp
						return 1
					fi
					SHPOTIFY_CREDENTIALS=$(printf "${CLIENT_ID}:${CLIENT_SECRET}" | base64 | tr -d "\n"|tr -d '\r') 
					SPOTIFY_PLAY_URI="" 
					getAccessToken () {
						cecho "Connecting to Spotify's API"
						SPOTIFY_TOKEN_RESPONSE_DATA=$( \
                        curl "${SPOTIFY_TOKEN_URI}" \
                            --silent \
                            -X "POST" \
                            -H "Authorization: Basic ${SHPOTIFY_CREDENTIALS}" \
                            -d "grant_type=client_credentials" \
                    ) 
						if ! [[ "${SPOTIFY_TOKEN_RESPONSE_DATA}" =~ "access_token" ]]
						then
							cecho "Authorization failed, please check ${USER_CONFG_FILE}"
							cecho "${SPOTIFY_TOKEN_RESPONSE_DATA}"
							showAPIHelp
							return 1
						fi
						SPOTIFY_ACCESS_TOKEN=$( \
                        printf "${SPOTIFY_TOKEN_RESPONSE_DATA}" \
                        | grep -E -o '"access_token":".*",' \
                        | sed 's/"access_token"://g' \
                        | sed 's/"//g' \
                        | sed 's/,.*//g' \
                    ) 
					}
					searchAndPlay () {
						type="$1" 
						Q="$2" 
						getAccessToken
						cecho "Searching ${type}s for: $Q"
						SPOTIFY_PLAY_URI=$( \
                        curl -s -G $SPOTIFY_SEARCH_API \
                            -H "Authorization: Bearer ${SPOTIFY_ACCESS_TOKEN}" \
                            -H "Accept: application/json" \
                            --data-urlencode "q=$Q" \
                            -d "type=$type&limit=1&offset=0" \
                        | grep -E -o "spotify:$type:[a-zA-Z0-9]+" -m 1
                    ) 
						echo "play uri: ${SPOTIFY_PLAY_URI}"
					}
					case $2 in
						("list") _args=${array[@]:2:$len} 
							Q=$_args 
							getAccessToken
							cecho "Searching playlists for: $Q"
							results=$( \
                            curl -s -G $SPOTIFY_SEARCH_API --data-urlencode "q=$Q" -d "type=playlist&limit=10&offset=0" -H "Accept: application/json" -H "Authorization: Bearer ${SPOTIFY_ACCESS_TOKEN}" \
                            | grep -E -o "spotify:playlist:[a-zA-Z0-9]+" -m 10 \
                        ) 
							count=$( \
                            echo "$results" | grep -c "spotify:playlist" \
                        ) 
							if [ "$count" -gt 0 ]
							then
								random=$(( $RANDOM % $count)) 
								SPOTIFY_PLAY_URI=$( \
                                echo "$results" | awk -v random="$random" '/spotify:playlist:[a-zA-Z0-9]+/{i++}i==random{print; exit}' \
                            ) 
							fi ;;
						("album" | "artist" | "track") _args=${array[@]:2:$len} 
							searchAndPlay $2 "$_args" ;;
						("uri") SPOTIFY_PLAY_URI=${array[@]:2:$len}  ;;
						(*) _args=${array[@]:1:$len} 
							searchAndPlay track "$_args" ;;
					esac
					if [ "$SPOTIFY_PLAY_URI" != "" ]
					then
						if [ "$2" = "uri" ]
						then
							cecho "Playing Spotify URI: $SPOTIFY_PLAY_URI"
						else
							cecho "Playing ($Q Search) -> Spotify URI: $SPOTIFY_PLAY_URI"
						fi
						osascript -e "tell application \"Spotify\" to play track \"$SPOTIFY_PLAY_URI\""
					else
						cecho "No results when searching for $Q"
					fi
				else
					cecho "Playing Spotify."
					osascript -e 'tell application "Spotify" to play'
				fi
				break ;;
			("pause") state=`osascript -e 'tell application "Spotify" to player state as string'` 
				if [ $state = "playing" ]
				then
					cecho "Pausing Spotify."
				else
					cecho "Playing Spotify."
				fi
				osascript -e 'tell application "Spotify" to playpause'
				break ;;
			("stop") state=`osascript -e 'tell application "Spotify" to player state as string'` 
				if [ $state = "playing" ]
				then
					cecho "Pausing Spotify."
					osascript -e 'tell application "Spotify" to playpause'
				else
					cecho "Spotify is already stopped."
				fi
				break ;;
			("quit") cecho "Quitting Spotify."
				osascript -e 'tell application "Spotify" to quit'
				break ;;
			("next") cecho "Going to next track."
				osascript -e 'tell application "Spotify" to next track'
				showStatus
				break ;;
			("prev") cecho "Going to previous track."
				osascript -e '
            tell application "Spotify"
                set player position to 0
                previous track
            end tell'
				showStatus
				break ;;
			("replay") cecho "Replaying current track."
				osascript -e 'tell application "Spotify" to set player position to 0'
				break ;;
			("vol") vol=`osascript -e 'tell application "Spotify" to sound volume as integer'` 
				if [[ $2 = "" || $2 = "show" ]]
				then
					cecho "Current Spotify volume level is $vol."
					break
				elif [ "$2" = "up" ]
				then
					if [ $vol -le 90 ]
					then
						newvol=$(( vol+10 )) 
						cecho "Increasing Spotify volume to $newvol."
					else
						newvol=100 
						cecho "Spotify volume level is at max."
					fi
				elif [ "$2" = "down" ]
				then
					if [ $vol -ge 10 ]
					then
						newvol=$(( vol-10 )) 
						cecho "Reducing Spotify volume to $newvol."
					else
						newvol=0 
						cecho "Spotify volume level is at min."
					fi
				elif [[ $2 =~ ^[0-9]+$ ]] && [[ $2 -ge 0 && $2 -le 100 ]]
				then
					newvol=$2 
					cecho "Setting Spotify volume level to $newvol"
				else
					echo "Improper use of 'vol' command"
					echo "The 'vol' command should be used as follows:"
					echo "  vol up                       # Increases the volume by 10%."
					echo "  vol down                     # Decreases the volume by 10%."
					echo "  vol [amount]                 # Sets the volume to an amount between 0 and 100."
					echo "  vol                          # Shows the current Spotify volume."
					return 1
				fi
				osascript -e "tell application \"Spotify\" to set sound volume to $newvol"
				break ;;
			("toggle") if [ "$2" = "shuffle" ]
				then
					osascript -e 'tell application "Spotify" to set shuffling to not shuffling'
					curr=`osascript -e 'tell application "Spotify" to shuffling'` 
					cecho "Spotify shuffling set to $curr"
				elif [ "$2" = "repeat" ]
				then
					osascript -e 'tell application "Spotify" to set repeating to not repeating'
					curr=`osascript -e 'tell application "Spotify" to repeating'` 
					cecho "Spotify repeating set to $curr"
				fi
				break ;;
			("status") if [ $# != 1 ]
				then
					case $2 in
						("artist") showArtist
							break ;;
						("album") showAlbum
							break ;;
						("track") showTrack
							break ;;
					esac
				else
					showStatus
				fi
				break ;;
			("info") info=`osascript -e 'tell application "Spotify"
                set durSec to (duration of current track / 1000)
                set tM to (round (durSec / 60) rounding down) as text
                if length of ((durSec mod 60 div 1) as text) is greater than 1 then
                    set tS to (durSec mod 60 div 1) as text
                else
                    set tS to ("0" & (durSec mod 60 div 1)) as text
                end if
                set myTime to tM as text & "min " & tS as text & "s"
                set pos to player position
                set nM to (round (pos / 60) rounding down) as text
                if length of ((round (pos mod 60) rounding down) as text) is greater than 1 then
                    set nS to (round (pos mod 60) rounding down) as text
                else
                    set nS to ("0" & (round (pos mod 60) rounding down)) as text
                end if
                set nowAt to nM as text & "min " & nS as text & "s"
                set info to "" & "\nArtist:         " & artist of current track
                set info to info & "\nTrack:          " & name of current track
                set info to info & "\nAlbum Artist:   " & album artist of current track
                set info to info & "\nAlbum:          " & album of current track
                set info to info & "\nSeconds:        " & durSec
                set info to info & "\nSeconds played: " & pos
                set info to info & "\nDuration:       " & mytime
                set info to info & "\nNow at:         " & nowAt
                set info to info & "\nPlayed Count:   " & played count of current track
                set info to info & "\nTrack Number:   " & track number of current track
                set info to info & "\nPopularity:     " & popularity of current track
                set info to info & "\nId:             " & id of current track
                set info to info & "\nSpotify URL:    " & spotify url of current track
                set info to info & "\nArtwork:        " & artwork url of current track
                set info to info & "\nPlayer:         " & player state
                set info to info & "\nVolume:         " & sound volume
                set info to info & "\nShuffle:        " & shuffling
                set info to info & "\nRepeating:      " & repeating
            end tell
            return info'` 
				cecho "$info"
				break ;;
			("share") uri=`osascript -e 'tell application "Spotify" to spotify url of current track'` 
				remove='spotify:track:' 
				url=${uri#$remove} 
				url="https://open.spotify.com/track/$url" 
				if [ "$2" = "" ]
				then
					cecho "Spotify URL: $url"
					cecho "Spotify URI: $uri"
					echo "To copy the URL or URI to your clipboard, use:"
					echo "\`spotify share url\` or"
					echo "\`spotify share uri\` respectively."
				elif [ "$2" = "url" ]
				then
					cecho "Spotify URL: $url"
					echo -n $url | pbcopy
				elif [ "$2" = "uri" ]
				then
					cecho "Spotify URI: $uri"
					echo -n $uri | pbcopy
				fi
				break ;;
			("pos") cecho "Adjusting Spotify play position."
				osascript -e "tell application \"Spotify\" to set player position to $2"
				break ;;
			("help") showHelp
				break ;;
			(*) showHelp
				return 1 ;;
		esac
	done
}
svn_prompt_info () {
	return 1
}
tab () {
	local command="cd \\\"$PWD\\\"; clear" 
	(( $# > 0 )) && command="${command}; $*" 
	local the_app=$(_omz_macos_get_frontmost_app) 
	if [[ "$the_app" == 'Terminal' ]]
	then
		osascript > /dev/null <<EOF
      tell application "System Events"
        tell process "Terminal" to keystroke "t" using command down
      end tell
      tell application "Terminal" to do script "${command}" in front window
EOF
	elif [[ "$the_app" == 'iTerm' ]]
	then
		osascript <<EOF
      tell application "iTerm"
        set current_terminal to current terminal
        tell current_terminal
          launch session "Default Session"
          set current_session to current session
          tell current_session
            write text "${command}"
          end tell
        end tell
      end tell
EOF
	elif [[ "$the_app" == 'iTerm2' ]]
	then
		osascript <<EOF
      tell application "iTerm2"
        tell current window
          create tab with default profile
          tell current session to write text "${command}"
        end tell
      end tell
EOF
	elif [[ "$the_app" == 'Hyper' ]]
	then
		osascript > /dev/null <<EOF
      tell application "System Events"
        tell process "Hyper" to keystroke "t" using command down
      end tell
      delay 1
      tell application "System Events"
        keystroke "${command}"
        key code 36  #(presses enter)
      end tell
EOF
	else
		echo "$0: unsupported terminal app: $the_app" >&2
		return 1
	fi
}
take () {
	if [[ $1 =~ ^(https?|ftp).*\.tar\.(gz|bz2|xz)$ ]]
	then
		takeurl "$1"
	elif [[ $1 =~ ^([A-Za-z0-9]\+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]
	then
		takegit "$1"
	else
		takedir "$@"
	fi
}
takedir () {
	mkdir -p $@ && cd ${@:$#}
}
takegit () {
	git clone "$1"
	cd "$(basename ${1%%.git})"
}
takeurl () {
	local data thedir
	data="$(mktemp)" 
	curl -L "$1" > "$data"
	tar xf "$data"
	thedir="$(tar tf "$data" | head -n 1)" 
	rm "$data"
	cd "$thedir"
}
tf_prompt_info () {
	return 1
}
title () {
	setopt localoptions nopromptsubst
	[[ -n "${INSIDE_EMACS:-}" && "$INSIDE_EMACS" != vterm ]] && return
	: ${2=$1}
	case "$TERM" in
		(cygwin | xterm* | putty* | rxvt* | konsole* | ansi | mlterm* | alacritty | st* | foot) print -Pn "\e]2;${2:q}\a"
			print -Pn "\e]1;${1:q}\a" ;;
		(screen* | tmux*) print -Pn "\ek${1:q}\e\\" ;;
		(*) if [[ "$TERM_PROGRAM" == "iTerm.app" ]]
			then
				print -Pn "\e]2;${2:q}\a"
				print -Pn "\e]1;${1:q}\a"
			else
				if (( ${+terminfo[fsl]} && ${+terminfo[tsl]} ))
				then
					print -Pn "${terminfo[tsl]}$1${terminfo[fsl]}"
				fi
			fi ;;
	esac
}
try_alias_value () {
	alias_value "$1" || echo "$1"
}
uninstall_oh_my_zsh () {
	env ZSH="$ZSH" sh "$ZSH/tools/uninstall.sh"
}
up-line-or-beginning-search () {
	# undefined
	builtin autoload -XU
}
upgrade_oh_my_zsh () {
	echo "${fg[yellow]}Note: \`$0\` is deprecated. Use \`omz update\` instead.$reset_color" >&2
	omz update
}
url-quote-magic () {
	# undefined
	builtin autoload -XUz
}
vi_mode_prompt_info () {
	return 1
}
virtualenv_prompt_info () {
	return 1
}
vncviewer () {
	open vnc://$@
}
vsplit_tab () {
	local command="cd \\\"$PWD\\\"; clear" 
	(( $# > 0 )) && command="${command}; $*" 
	local the_app=$(_omz_macos_get_frontmost_app) 
	if [[ "$the_app" == 'iTerm' ]]
	then
		osascript <<EOF
      -- tell application "iTerm" to activate
      tell application "System Events"
        tell process "iTerm"
          tell menu item "Split Vertically With Current Profile" of menu "Shell" of menu bar item "Shell" of menu bar 1
            click
          end tell
        end tell
        keystroke "${command} \n"
      end tell
EOF
	elif [[ "$the_app" == 'iTerm2' ]]
	then
		osascript <<EOF
      tell application "iTerm2"
        tell current session of first window
          set newSession to (split vertically with same profile)
          tell newSession
            write text "${command}"
            select
          end tell
        end tell
      end tell
EOF
	elif [[ "$the_app" == 'Hyper' ]]
	then
		osascript > /dev/null <<EOF
    tell application "System Events"
      tell process "Hyper"
        tell menu item "Split Vertically" of menu "Shell" of menu bar 1
          click
        end tell
      end tell
      delay 1
      keystroke "${command} \n"
    end tell
EOF
	else
		echo "$0: unsupported terminal app: $the_app" >&2
		return 1
	fi
}
work_in_progress () {
	command git -c log.showSignature=false log -n 1 2> /dev/null | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -q -- "--wip--" && echo "WIP!!"
}
za-bgn-atclone-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-bgn-atdelete-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-bgn-atload-handler () {
	emulate -RL zsh
	setopt extendedglob warncreateglobal typesetsilent noshortloops
	if [[ "$1" = plugin ]]
	then
		local type="$1" user="$2" plugin="$3" id_as="$4" dir="${5#%}" hook="$6" 
	else
		local type="$1" url="$2" id_as="$3" dir="${4#%}" hook="$5" 
	fi
	local nl=$'\n' trim_whitespace='((#s)[[:space:]]##|[[:space:]]##(#e))' 
	if [[ -n "${ICE[gem]}" ]]
	then
		local -a gems srcdst tmpsdst
		gems=("${(s.;.)ICE[gem]}") 
		local gem
		integer add_fbin
		for gem in $gems
		do
			srcdst=(${(@s.->.)gem}) 
			tmpsdst=(${(@s.<-.)srcdst[1]}) 
			if (( ${#tmpsdst} > 1 ))
			then
				srcdst=("${tmpsdst[1]}" "${tmpsdst[2]}" "${srcdst[2]:-${tmpdist[2]#\!}}") 
			else
				srcdst=("${tmpsdst[1]#\!}" "${tmpsdst[1]}" "${srcdst[2]:-${srcdst[1]#\!}}") 
			fi
			srcdst=("${srcdst[@]//${~trim_whitespace}/}") 
			[[ ${srcdst[2]} = \!* ]] && add_fbin=1  || add_fbin=0 
			srcdst[2]=${srcdst[2]#\!} 
			@zinit-substitute 'srcdst[1]' 'srcdst[2]' 'srcdst[3]'
			if (( add_fbin ))
			then
				local target_binary="g:$dir/bin/${srcdst[1]}" 
				ICE[fbin]+="${ICE[fbin]:+;}$target_binary -> ${srcdst[3]}" 
			fi
		done
	fi
	if [[ -n "${ICE[node]}" ]]
	then
		local -a nodes srcdst tmpsdst
		nodes=("${(s.;.)ICE[node]}") 
		local node
		integer add_fbin
		for node in $nodes
		do
			srcdst=(${(@s.->.)node}) 
			tmpsdst=(${(@s.<-.)srcdst[1]}) 
			if (( ${#tmpsdst} > 1 ))
			then
				srcdst=("${tmpsdst[1]}" "${tmpsdst[2]}" "${srcdst[2]:-${tmpdist[2]#\!}}") 
			else
				srcdst=("${tmpsdst[1]#\!}" "${tmpsdst[1]}" "${srcdst[2]:-${srcdst[1]#\!}}") 
			fi
			srcdst=("${srcdst[@]//${~trim_whitespace}/}") 
			[[ ${srcdst[2]} = \!* ]] && add_fbin=1  || add_fbin=0 
			srcdst[2]=${srcdst[2]#\!} 
			@zinit-substitute 'srcdst[1]' 'srcdst[2]' 'srcdst[3]'
			if (( add_fbin ))
			then
				local target_binary="n:$dir/node_modules/.bin/${srcdst[1]}" 
				ICE[fbin]+="${ICE[fbin]:+;}$target_binary -> ${srcdst[3]}" 
			fi
		done
	fi
	if [[ -n "${ICE[pip]}" ]]
	then
		local -a pips srcdst tmpsdst
		pips=("${(s.;.)ICE[pip]}") 
		local pip
		integer add_fbin
		for pip in $pips
		do
			srcdst=(${(@s.->.)pip}) 
			tmpsdst=(${(@s.<-.)srcdst[1]}) 
			if (( ${#tmpsdst} > 1 ))
			then
				srcdst=("${tmpsdst[1]}" "${tmpsdst[2]}" "${srcdst[2]:-${tmpdist[2]#\!}}") 
			else
				srcdst=("${tmpsdst[1]#\!}" "${tmpsdst[1]}" "${srcdst[2]:-${srcdst[1]#\!}}") 
			fi
			srcdst=("${srcdst[@]//${~trim_whitespace}/}") 
			[[ ${srcdst[2]} = \!* ]] && add_fbin=1  || add_fbin=0 
			srcdst[2]=${srcdst[2]#\!} 
			@zinit-substitute 'srcdst[1]' 'srcdst[2]' 'srcdst[3]'
			if (( add_fbin ))
			then
				local target_binary="p:$dir/venv/bin/${srcdst[1]}" 
				ICE[fbin]+="${ICE[fbin]:+;}$target_binary -> ${srcdst[3]}" 
			fi
		done
	fi
	if (( ${+ICE[fbin]}${+ICE[fsrc]}${+ICE[ferc]} > 0 ))
	then
		local -a fbins fsrcs fercs srcdst
		fbins=(${(s.;.)ICE[fbin]}) 
		fsrcs=(${(s.;.)ICE[fsrc]}) 
		fercs=(${(s.;.)ICE[ferc]}) 
		local fbin
		integer run_type=0 
		for fbin in $fbins "" "<sep1>" $fsrcs "" "<sep2>" $fercs ""
		do
			integer set_gem_home=0 set_node_path=0 set_virtualenv=0 set_cwd=0 use_all_null=0 use_err_null=0 use_out_null=0 
			[[ "$fbin" = "<sep1>" ]] && {
				run_type=1 
				continue
			}
			[[ "$fbin" = "<sep2>" ]] && {
				run_type=2 
				continue
			}
			if [[ ( ${+ICE[fbin]} -eq 1 && run_type -eq 0 && -z $fbin && ${#fbins} -eq 0 ) || ( ${+ICE[fsrc]} -eq 1 && run_type -eq 1 && -z $fbin && ${#fsrcs} -eq 0 ) || ( ${+ICE[ferc]} -eq 1 && run_type -eq 2 && -z $fbin && ${#fercs} -eq 0 ) ]]
			then
				if [[ -f $dir/${id_as:t} ]]
				then
					fbin="$dir/${id_as:t}" 
				elif [[ -n $plugin && -f $dir/$plugin ]]
				then
					fbin="$dir/$plugin" 
				elif [[ -n $url && -f $dir/${url:t} ]]
				then
					fbin="$dir/${url:t}" 
				else
					local -a files
					files=($dir/*(*Non:t)) 
					if (( ${#files} ))
					then
						fbin="${files[1]}" 
					else
						print -P -- "%F{38}bin-gem-node annex: %F{160}The automatic-empty fbin ice didn't find any executable files for %F{219}$id_as%f"
						break
					fi
				fi
			elif [[ -z $fbin ]]
			then
				continue
			fi
			srcdst=(${(@s.->.)fbin}) 
			srcdst=("${srcdst[@]//${~trim_whitespace}/}") 
			[[ ${srcdst[1]} = [gnpcNEO]#g[gnpcNEO]#:* ]] && set_gem_home=1 
			[[ ${srcdst[1]} = [gnpcNEO]#n[gnpcNEO]#:* ]] && set_node_path=1 
			[[ ${srcdst[1]} = [gnpcNEO]#p[gnpcNEO]#:* ]] && set_virtualenv=1 
			[[ ${srcdst[1]} = [gnpcNEO]#c[gnpcNEO]#:* ]] && set_cwd=1 
			[[ ${srcdst[1]} = [gnpcNEO]#N[gnpcNEO]#:* ]] && use_all_null=1 
			[[ ${srcdst[1]} = [gnpcNEO]#E[gnpcNEO]#:* ]] && use_err_null=1 
			[[ ${srcdst[1]} = [gnpcNEO]#O[gnpcNEO]#:* ]] && use_out_null=1 
			srcdst[1]=${srcdst[1]#[a-zA-Z]#:} 
			@zinit-substitute 'srcdst[1]' 'srcdst[2]'
			local target_binary="${${(M)srcdst[1]:#/*}:-$dir/${srcdst[1]}}" 
			.za-bgn-bin-or-src-function-body "$run_type" "${srcdst[2]:-${srcdst[1]:t}}" "$target_binary" "$dir" "$set_gem_home" "$set_node_path" "$set_virtualenv" "$set_cwd" "$use_all_null" "$use_err_null" "$use_out_null"
			eval "$REPLY"
		done
	fi
	if [[ -n "${ICE[fmod]}" ]]
	then
		local -a fmods srcdst
		fmods=("${(s.;.)ICE[fmod]}") 
		local fmod
		for fmod in $fmods
		do
			integer set_gem_home=0 set_node_path=0 set_virtualenv=0 set_cwd=0 use_all_null=0 use_err_null=0 use_out_null=0 
			srcdst=(${(@s.->.)fmod}) 
			srcdst=("${srcdst[@]//${~trim_whitespace}/}") 
			[[ ${srcdst[1]} = [gnpcNEO]#g[gnpcNEO]#:* ]] && set_gem_home=1 
			[[ ${srcdst[1]} = [gnpcNEO]#n[gnpcNEO]#:* ]] && set_node_path=1 
			[[ ${srcdst[1]} = [gnpcNEO]#p[gnpcNEO]#:* ]] && set_virtualenv=1 
			[[ ${srcdst[1]} = [gnpcNEO]#c[gnpcNEO]#:* ]] && set_cwd=1 
			[[ ${srcdst[1]} = [gnpcNEO]#N[gnpcNEO]#:* ]] && use_all_null=1 
			[[ ${srcdst[1]} = [gnpcNEO]#E[gnpcNEO]#:* ]] && use_err_null=1 
			[[ ${srcdst[1]} = [gnpcNEO]#O[gnpcNEO]#:* ]] && use_out_null=1 
			srcdst[1]=${srcdst[1]#[a-zA-Z]#:} 
			@zinit-substitute 'srcdst[1]' 'srcdst[2]'
			local target_function="${srcdst[1]}" 
			.za-bgn-mod-function-body "${srcdst[2]:-${srcdst[1]}}" "$target_function" "$dir" "$set_gem_home" "$set_node_path" "$set_virtualenv" "$set_cwd" "$use_all_null" "$use_err_null" "$use_out_null"
			eval "$REPLY"
		done
	fi
}
za-bgn-atpull-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-bgn-help-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-bgn-null-handler () {
	:
}
za-bgn-shim-list () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-bin-gem-node" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-patch-dl-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-patch-dl" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X -U -z
}
za-patch-dl-help-null-handler () {
	:
}
za-readurl-preinit-handler () {
	builtin emulate -LR zsh
	builtin setopt extendedglob warncreateglobal typesetsilent noshortloops rcquotes
	if [[ $ICE[as] != (readurl*|*readurl) && $ICE[.readurl] != (readurl*|*readurl) ]]
	then
		return 0
	fi
	[[ $1 == plugin ]] && {
		+zinit-message "{pre}readurl annex: {error}ERROR: as'$ICE[as]'" "ice can be used only with snippets.{rst}"
		return 7
	}
	local __type=$1 __url=$2 __id_as=$3 __dir=$4 __hook=$5 __subtype=$6 
	ICE[.readurl]=${ICE[.readurl]:-$ICE[as]} 
	if [[ $ICE[as] = ((readurl\||)(command|program)|(command|program)(\|readurl|)) ]]
	then
		ICE[as]=command 
	elif [[ $ICE[as] = ((readurl\||)completion|completion(\|readurl|)) ]]
	then
		ICE[as]=completion 
	elif [[ $ICE[as] = ((readurl\||)null|null(\|readurl|)) ]]
	then
		ICE[as]=null 
		ICE[pick]=${ICE[pick]:-/dev/null} 
	else
		if [[ $ICE[as] != readurl ]]
		then
			+zinit-message "{pre}readurl annex: {msg2}" "Warning: Unrecognized as'readurl|{data2}...{msg2}' variant ({data2}$ICE[as]{msg2})." "Falling back to {meta}as{hi}'{data}readurl{hi}'{msg2}.{rst}"
		fi
		unset 'ICE[as]'
	fi
	if [[ -d $__dir && $__subtype != update(|:*) ]]
	then
		return 0
	fi
	local -a match mbegin mend
	local MATCH
	integer MBEGIN MEND
	(( ${+functions[.zinit-setup-plugin-dir]} != 1 )) || builtin source $ZINIT[BIN_DIR]/zinit-install.zsh
	match=() 
	local dlpage=${__url%(#b)([^+])++*} 
	dlpage=$dlpage$match[1] 
	if [[ $ICE[dl] == (*\;)(#c0,1)ink(0)(#c0,1)[=:](#c0,1)[-_/[:alnum:]]* ]]
	then
		ICE[dlink]=${(j.;.)${${(@M)${(@s.;.)ICE[dl]}:#ink([=:]|)*}##ink([=:]|)}} 
		ICE[dl]=${(j.;.)${(@s.;.)ICE[dl]}:#ink([=:]|)*} 
		[[ -z $ICE[dlink] ]] && unset 'ICE[dlink]'
		[[ -z $ICE[dl] ]] && unset 'ICE[dl]'
	fi
	if [[ -z $ICE[dlink] ]]
	then
		local plus=${(MS)__url%%[^+]++##} pattern_url=$dlpage 
		plus=${plus#?++} 
		while [[ -n $plus ]]
		do
			pattern_url=${pattern_url:h} 
			plus=${plus%+} 
		done
		local pattern_url=${pattern_url}/${__url##*++} 
	else
		local -a urls sorts filters
		urls=(${(s.;.)ICE[dlink]}) 
		if ((${#urls} == 2))
		then
			local pattern_url=${urls[@]:#0*} pattern_url0=${${(M)urls[@]:#0*}##0(:|=)(#c0,1)} 
			if [[ $pattern_url == \!* ]]
			then
				sorts[2]=1 
				pattern_url=${pattern_url#\!} 
			fi
			if [[ $pattern_url == *[^\\]([\\][\\])#\~%[^%]##%* ]]
			then
				if [[ $pattern_url == (#b)(*)\~%([^%]##)%(*) ]]
				then
					pattern_url=$match[1]$match[3] 
					filters[2]=$match[2] 
				fi
			fi
			if [[ $pattern_url0 == \!* ]]
			then
				sorts[1]=1 
				pattern_url0=${pattern_url0#\!} 
			fi
			if [[ $pattern_url0 == *[^\\]([\\][\\])#\~%[^%]##%* ]]
			then
				if [[ $pattern_url0 == (#b)(*)\~%([^%]##)%(*) ]]
				then
					pattern_url0=$match[1]$match[3] 
					filters[1]=$match[2] 
				fi
			fi
		elif ((${#urls} == 1))
		then
			local pattern_url=${urls[@]:#0*} pattern_url0=${${(M)urls[@]:#0*}##0(:|=)(#c0,1)} 
			if [[ -n $pattern_url0 ]]
			then
				+zinit-message "{pre}readurl annex: {error}ERROR:{rst}" "The {meta}dlink0''{rst} ice cannot be used alone," "{meta}dlink''{rst} is always required."
				return 9
			fi
			if [[ $pattern_url == \!* ]]
			then
				sorts[1]=1 
				pattern_url=${pattern_url#\!} 
			fi
			if [[ $pattern_url == *[^\\]([\\][\\])#\~%[^%]##%* ]]
			then
				if [[ $pattern_url == (#b)(*)\~%([^%]##)%(*) ]]
				then
					pattern_url=$match[1]$match[3] 
					filters[1]=$match[2] 
				fi
			fi
		elif ((${#urls} > 2))
		then
			+zinit-message "{pre}readurl annex: {error}ERROR: {msg2}The ice {meta}dlink''{msg2}" "has been used too many times: {meta}#{obj}${#urls}{msg2}, while it can be used at most" "two times, as {meta2}dlink0''{msg2} and then {meta2}dlink''{msg2}, aborting.{rst}"
			return 9
		else
			local pattern_url=$ICE[dlink] 
		fi
	fi
	local -A map
	map=(".*" "*" ".+" "?##" "+" "##" "*" "#") 
	local -a filters
	filters=("${filters[@]//(#b)(${(~kj.|.)map})/$map[$match[1]]}") 
	local tmpfile="$(mktemp)" 
	pattern_url=${pattern_url//\%VERSION\%/[.,a-zA-Z0-9_-]+} 
	local pattern_url0=${pattern_url0//\%VERSION\%/[.,a-zA-Z0-9_-]+} 
	integer index
	local cur_paturl
	for cur_paturl in $pattern_url0 $pattern_url
	do
		index+=1 
		.zinit-download-file-stdout $dlpage >| $tmpfile || {
			.zinit-download-file-stdout $dlpage 1 >| $tmpfile || {
				+zinit-message "{pre}readurl annex: {error}ERROR: couldn't" "fetch the download page ({url}${dlpage//\%/%%}{error}){rst}"
				return 9
			}
		}
		local -a list
		list=(${(@f)"$(noglob command grep -E -io "href=.?$cur_paturl" $tmpfile)"}) 
		if ((sorts[index]))
		then
			list=(${list[@]:#[^[:digit:]]##}) 
			list=(${(On)list[@]}) 
		fi
		if [[ -n $filters[index] ]]
		then
			list=(${list[@]:#href=(?|)$~filters[index]}) 
		fi
		local selected=${list[1]#href=} 
		selected=${selected#[\"\']} 
		if [[ -z $selected ]]
		then
			+zinit-message "{pre}readurl annex: {error}ERROR:{rst}" "couldn't match the URL${${(M)cur_paturl:#$pattern_url0}:+-0} at the download page" "(which is {url}${dlpage//\%/%%}{rst}${${__id_as:#$__url}:+; the snippet is being identified as" "{meta}${__id_as}{rst}}; was matching {data2}${cur_paturl}{rst})."
			return 9
		fi
		if [[ $selected == /* ]]
		then
			local domain protocol
			if [[ $dlpage = (#b)(#i)((http(s|)|ftp(s|)|ssh|scp)://|)([^/]##)(*) ]]
			then
				protocol=$match[1] domain=$match[5] 
			fi
			if [[ -z $domain ]]
			then
				+zinit-message "{pre}readurl annex: {ehi}ERROR:{error} couldn't establish the domain name (unsupported" "protocol? supported are: {data}http(s){error},{data}ftp(s){error},{data}ssh{error},{data}scp{error}).{rst}"
				return 9
			fi
			local new_url=${protocol:-http://}$domain$selected 
		elif [[ $selected = (#i)(http(s|)|ftp(s|)|ssh|scp)://* ]]
		then
			local new_url=$selected 
		else
			local -a exts
			exts=(xhtml htmls html htm php php3 php4 phtml pl asp aspx ece js jsp jspx jhtml cfm py rb rhtml shtml cgi) 
			if [[ $dlpage = *.(${(~j:|:)exts}) ]]
			then
				local new_url=${dlpage:h}/$selected 
			else
				local new_url=$dlpage/$selected 
			fi
		fi
		dlpage=$new_url 
	done
	if [[ $__subtype == update(|:*) && -z $opts[(r)-f] ]]
	then
		{
			local old_url="$(< $__dir/._zinit/url_rsvd)" 
		} 2> /dev/null
		[[ $old_url == $new_url ]] && return 8
	fi
	url=$new_url 
	ICE[url_rsvd]=$new_url 
	ZINIT[annex-multi-flag:pull-active]=2 
	if [[ $__subtype == update(|:*) ]]
	then
		typeset -gA OPTS
		OPTS[opt_-q,--quiet]=0 
	fi
	+zinit-message "{pre}readurl annex: {msg}Matched the following URL: {url}${new_url}{rst}"
	return 0
}
za-rust-atclone-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-rust" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-rust-atdelete-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-rust" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-rust-atload-handler () {
	
}
za-rust-atpull-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-rust" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-rust-help-handler () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/plugins/zdharma-continuum---zinit-annex-rust" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X
}
za-rust-help-null-handler () {
	:
}
zi-browse-symbol () {
	local -a fpath
	fpath=("/Users/yangeok/.local/share/zinit/zinit.git" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/opt/homebrew/share/zsh/site-functions" "/Users/yangeok/.autojump/functions" "/Users/yangeok/.local/share/zinit/completions" "/Users/yangeok/.oh-my-zsh/plugins/macos" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-autosuggestions" "/Users/yangeok/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" "/Users/yangeok/.oh-my-zsh/plugins/k" "/Users/yangeok/.oh-my-zsh/plugins/git" "/Users/yangeok/.oh-my-zsh/plugins/fzf" "/Users/yangeok/.oh-my-zsh/functions" "/Users/yangeok/.oh-my-zsh/completions" "/Users/yangeok/.oh-my-zsh/cache/completions" "/opt/homebrew/share/zsh/site-functions" "/usr/local/share/zsh/site-functions" "/usr/share/zsh/site-functions" "/usr/share/zsh/5.9/functions" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh" "/Applications/OrbStack.app/Contents/MacOS/../Resources/completions/zsh") 
	builtin autoload -X -U -z
}
zicdclear () {
	.zinit-compdef-clear -q
}
zicdreplay () {
	.zinit-compdef-replay -q
}
zicompdef () {
	ZINIT_COMPDEF_REPLAY+=("${(j: :)${(q)@}}") 
}
zicompinit () {
	autoload -Uz compinit
	compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
}
zinit () {
	local -A ICE ZINIT_ICE
	ICE=("${(kv)ZINIT_ICES[@]}") 
	ZINIT_ICE=("${(kv)ICE[@]}") 
	ZINIT_ICES=() 
	integer ___retval ___retval2 ___correct
	local -a match mbegin mend
	local MATCH cmd ___q="\`" ___q2="'" IFS=$' \t\n\0' 
	integer MBEGIN MEND
	match=(${ZINIT_EXTS[(I)z-annex subcommand:$1]}) 
	if (( !${#match} ))
	then
		local -a reply
		local REPLY
	fi
	[[ -o ksharrays ]] && ___correct=1 
	local -A ___opt_map OPTS
	___opt_map=(-q opt_-q,--quiet:"update:[Turn off almost-all messages from the {cmd}update{rst} operation {b-lhi}FOR the objects{rst} which don't have any {b-lhi}new version{rst} available.] *:[Turn off any (or: almost-any) messages from the operation.]" --quiet opt_-q,--quiet -v opt_-v,--verbose:"Turn on more messages from the operation." --verbose opt_-v,--verbose -r opt_-r,--reset:"Reset the repository before updating (or remove the files for single-file snippets and gh-r plugins)." --reset opt_-r,--reset -a opt_-a,--all:"delete:[Delete {hi}all{rst} plugins and snippets.] update:[Update {b-lhi}all{rst} plugins and snippets.]" --all opt_-a,--all -c opt_-c,--clean:"Delete {b-lhi}only{rst} the {b-lhi}currently-not loaded{rst} plugins and snippets." --clean opt_-c,--clean -y opt_-y,--yes:"Automatically confirm any yes/no prompts." --yes opt_-y,--yes -f opt_-f,--force:"Force new download of the snippet file." --force opt_-f,--force -p opt_-p,--parallel:"Turn on concurrent, multi-thread update (of all objects)." --parallel opt_-p,--parallel -s opt_-s,--snippets:"snippets:[Update only snippets (i.e.: skip updating plugins).] times:[Show times in seconds instead of milliseconds.]" --snippets opt_-s,--snippets -L opt_-l,--plugins:"Update only plugins (i.e.: skip updating snippets)." --plugins opt_-l,--plugins -h opt_-h,--help:"Show this help message." --help opt_-h,--help -u opt_-u,--urge:"Cause all the hooks like{ehi}:{rst} {ice}atpull{apo}''{rst}, {ice}cp{apo}''{rst}, etc. to execute even when there aren't any new commits {b}/{rst} any new version of the {b}{meta}gh-r{rst} file {b}/{rst} etc.{…} available for download {ehi}{lr}{rst} simulate a non-empty update." --urge opt_-u,--urge -n opt_-n,--no-pager:"Disable the use of the pager." --no-pager opt_-n,--no-pager -m opt_-m,--moments:"Show the {apo}*{b-lhi}moments{apo}*{rst} of object (i.e.: a plugin or snippet) loading time." --moments opt_-m,--moments -b opt_-b,--bindkeys:"Load in light mode, however do still track {cmd}bindkey{rst} calls (to allow remapping the keys bound)." --bindkeys opt_-b,--bindkeys -x opt_-x,--command:"Load the snippet as a {cmd}command{rst}, i.e.: add it to {var}\$PATH{rst} and set {b-lhi}+x{rst} on it." --command opt_-x,--command cdclear "--help|--quiet|-h|-q" cdreplay "--help|--quiet|-h|-q" delete "--all|--clean|--help|--quiet|--yes|-a|-c|-h|-q|-y" env-whitelist "--help|--verbose|-h|-v" light "--help|-b|-h" snippet "--command|--force|--help|-f|-h|-x" times "--help|-h|-m|-s" unload "--help|--quiet|-h|-q" update "--all|--help|--no-pager|--parallel|--plugins|--quiet|--reset|--snippets|--urge|--verbose|-L|-a|-h|-n|-p|-q|-r|-s|-u|-v" version "") 
	cmd="$1" 
	if [[ $cmd == (times|unload|env-whitelist|update|snippet|load|light|cdreplay|cdclear) ]]
	then
		if (( $@[(I)-*] || OPTS[opt_-h,--help] ))
		then
			.zinit-parse-opts "$cmd" "$@"
			if (( OPTS[opt_-h,--help] ))
			then
				+zinit-prehelp-usage-message $cmd $___opt_map[$cmd] $@
				return 1
			fi
		fi
	fi
	reply=(${ZINIT_EXTS[(I)z-annex subcommand:*]}) 
	[[ ( -n $1 && $1 != (${~ZINIT[cmds]}|${(~j:|:)reply[@]#z-annex subcommand:}) ) || $1 = (load|light|snippet) ]] && {
		integer ___error
		if [[ $1 = (load|light|snippet) ]]
		then
			integer ___is_snippet
			() {
				builtin setopt localoptions extendedglob
				: ${@[@]//(#b)([ $'\t']##|(#s))(-b|--command|-f|--force)([ $'\t']##|(#e))/${OPTS[${match[2]}]::=1}}
			} "$@"
			builtin set -- "${@[@]:#(-b|--command|-f|--force)}"
			[[ $1 = light && -z ${OPTS[(I)-b]} ]] && ICE[light-mode]= 
			[[ $1 = snippet ]] && ICE[is-snippet]=  || ___is_snippet=-1 
			shift
			ZINIT_ICES=("${(kv)ICE[@]}") 
			ICE=() ZINIT_ICE=() 
			1="${1:+@}${1#@}${2:+/$2}" 
			(( $# > 1 )) && {
				shift -p $(( $# - 1 ))
			}
			[[ -z $1 ]] && {
				+zi-log "Argument needed, try: {cmd}help."
				return 1
			}
		else
			.zinit-ice "$@"
			___retval2=$? 
			local ___last_ice=${@[___retval2]} 
			shift ___retval2
			if [[ $# -gt 0 && $1 != for ]]
			then
				+zi-log -n "{b}{u-warn}ERROR{b-warn}:{rst} Unknown subcommand{ehi}:" "{apo}\`{cmd}$1{apo}\`{rst} "
				+zinit-prehelp-usage-message rst
				return 1
			elif (( $# == 0 ))
			then
				___error=1 
			else
				shift
			fi
		fi
		integer ___had_wait
		local ___id ___ehid ___etid ___key
		local -a ___arr
		ZINIT[annex-exposed-processed-IDs]= 
		if (( $# ))
		then
			local -a ___ices
			___ices=("${(kv)ZINIT_ICES[@]}") 
			ZINIT_ICES=() 
			while (( $# ))
			do
				.zinit-ice "$@"
				___retval2=$? 
				local ___last_ice=${@[___retval2]} 
				shift ___retval2
				if [[ -n $1 ]]
				then
					ICE=("${___ices[@]}" "${(kv)ZINIT_ICES[@]}") 
					ZINIT_ICE=("${(kv)ICE[@]}") ZINIT_ICES=() 
					integer ___msgs=${+ICE[debug]} 
					(( ___msgs )) && +zi-log "{pre}zinit-main:{faint} Processing {pname}$1{faint}{…}{rst}"
					ZINIT[annex-exposed-processed-IDs]+="${___id:+ $___id}" 
					___id="${${1#@}%%(///|//|/)}" 
					(( ___is_snippet == -1 )) && ___id="${___id#https://github.com/}" 
					___ehid="${ICE[id-as]:-$___id}" 
					___etid="${ICE[teleid]:-$___id}" 
					if (( ${+ICE[pack]} ))
					then
						___had_wait=${+ICE[wait]} 
						.zinit-load-ices "$___ehid"
						[[ $___had_wait -eq 0 ]] && unset 'ICE[wait]'
					fi
					[[ ${ICE[id-as]} = (auto|) && ${+ICE[id-as]} == 1 ]] && ICE[id-as]="${___etid:t}" 
					integer ___is_snippet=${${(M)___is_snippet:#-1}:-0} 
					() {
						builtin setopt localoptions extendedglob
						if [[ $___is_snippet -ge 0 && ( -n ${ICE[is-snippet]+1} || $___etid = ((#i)(http(s|)|ftp(s|)):/|(${(~kj.|.)ZINIT_1MAP}))* ) ]]
						then
							___is_snippet=1 
						fi
					} "$@"
					local ___type=${${${(M)___is_snippet:#1}:+snippet}:-plugin} 
					reply=(${(on)ZINIT_EXTS2[(I)zinit hook:before-load-pre <->]} ${(on)ZINIT_EXTS[(I)z-annex hook:before-load-<-> <->]} ${(on)ZINIT_EXTS2[(I)zinit hook:before-load-post <->]}) 
					for ___key in "${reply[@]}"
					do
						___arr=("${(Q)${(z@)ZINIT_EXTS[$___key]:-$ZINIT_EXTS2[$___key]}[@]}") 
						"${___arr[5]}" "$___type" "$___id" "${ICE[id_as]}" "${(j: :)${(q)@[2,-1]}}" "${(j: :)${(qkv)___ices[@]}}" "${${___key##(zinit|z-annex) hook:}%% <->}" load
						___retval2=$? 
						if (( ___retval2 ))
						then
							___retval+=$(( ___retval2 & 1 ? ___retval2 : 0 )) 
							(( ___retval2 & 1 && $# )) && shift
							if (( ___retval2 & 2 ))
							then
								local -a ___args
								___args=("${(@Q)${(@z)ZINIT[annex-before-load:new-@]}}") 
								builtin set -- "${___args[@]}"
							fi
							if (( ___retval2 & 4 ))
							then
								local -a ___new_ices
								___new_ices=("${(Q@)${(@z)ZINIT[annex-before-load:new-global-ices]}}") 
								(( 0 == ${#___new_ices} % 2 )) && ___ices=("${___new_ices[@]}")  || {
									[[ ${ZINIT[MUTE_WARNINGS]} != (1|true|on|yes) ]] && +zi-log "{u-warn}Warning{b-warn}:{msg} Bad new-ices returned" "from the annex{ehi}:{rst} {annex}${___arr[3]}{msg}," "please file an issue report at:{url}" "https://github.com/zdharma-continuum/${___arr[3]}/issues/new{msg}.{rst}"
									___ices=() ___retval+=7 
								}
							fi
							continue 2
						fi
					done
					integer ___action_load=0 ___turbo=0 
					if [[ -n ${(M)${+ICE[wait]}:#1}${ICE[load]}${ICE[unload]}${ICE[service]}${ICE[subscribe]} ]]
					then
						___turbo=1 
					fi
					if [[ -n ${ICE[trigger-load]} || ( ${+ICE[wait]} == 1 && ${ICE[wait]} = (\!|)(<->(a|b|c|)|) ) ]] && (( !ZINIT[OPTIMIZE_OUT_DISK_ACCESSES]
                    ))
					then
						if (( ___is_snippet > 0 ))
						then
							.zinit-get-object-path snippet $___ehid
						else
							.zinit-get-object-path plugin $___ehid
						fi
						(( $? )) && [[ ${zsh_eval_context[1]} = file ]] && {
							___action_load=1 
						}
						local ___object_path="$REPLY" 
					elif (( ! ___turbo ))
					then
						___action_load=1 
						reply=(1) 
					else
						reply=(1) 
					fi
					if [[ ${reply[-1]} -eq 1 && -n ${ICE[trigger-load]} ]]
					then
						() {
							builtin setopt localoptions extendedglob
							local ___mode
							(( ___is_snippet > 0 )) && ___mode=snippet  || ___mode="${${${ICE[light-mode]+light}}:-load}" 
							for MATCH in ${(s.;.)ICE[trigger-load]}
							do
								eval "${MATCH#!}() {
                                    ${${(M)MATCH#!}:+unset -f ${MATCH#!}}
                                    local a b; local -a ices
                                    # The wait'' ice is filtered-out.
                                    for a b ( ${(qqkv@)${(kv@)ICE[(I)^(trigger-load|wait|light-mode)]}} ) {
                                        ices+=( \"\$a\$b\" )
                                    }
                                    zinit ice \${ices[@]}; zinit $___mode ${(qqq)___id}
                                    ${${(M)MATCH#!}:+# Forward the call
                                    eval ${MATCH#!} \$@}
                                }"
							done
						} "$@"
						___retval+=$? 
						(( $# )) && shift
						continue
					fi
					if (( ${+ICE[if]} ))
					then
						eval "${ICE[if]}" || {
							(( $# )) && shift
							continue
						}
					fi
					for REPLY in ${(s.;.)ICE[has]}
					do
						(( ${+commands[$REPLY]} )) || {
							(( $# )) && shift
							continue 2
						}
					done
					integer ___had_cloneonly=0 
					ICE[wait]="${${(M)${+ICE[wait]}:#1}:+${(M)ICE[wait]#!}${${ICE[wait]#!}:-0}}" 
					if (( ___action_load || !ZINIT[HAVE_SCHEDULER] ))
					then
						if (( ___turbo && ZINIT[HAVE_SCHEDULER] ))
						then
							___had_cloneonly=${+ICE[cloneonly]} 
							ICE[cloneonly]="" 
						fi
						(( ___is_snippet )) && local ___opt="${(k)OPTS[*]}"  || local ___opt="${${ICE[light-mode]+light}:-${OPTS[(I)-b]:+light-b}}" 
						.zinit-load-object ${${${(M)___is_snippet:#1}:+snippet}:-plugin} $___id $___opt
						integer ___last_retval=$? 
						___retval+=___last_retval 
						if (( ___turbo && !___had_cloneonly && ZINIT[HAVE_SCHEDULER] ))
						then
							command rm -f $___object_path/._zinit/cloneonly
							unset 'ICE[cloneonly]'
						fi
					fi
					if (( ___turbo && ZINIT[HAVE_SCHEDULER] && 0 == ___last_retval ))
					then
						ICE[wait]="${ICE[wait]:-${ICE[service]:+0}}" 
						if (( ___is_snippet > 0 ))
						then
							ZINIT_SICE[$___ehid]= 
							.zinit-submit-turbo s${ICE[service]:+1} "" "$___id" "${(k)OPTS[*]}"
						else
							ZINIT_SICE[$___ehid]= 
							.zinit-submit-turbo p${ICE[service]:+1} "${${${ICE[light-mode]+light}}:-load}" "$___id" ""
						fi
						___retval+=$? 
					fi
				else
					___error=1 
				fi
				(( $# )) && shift
				___is_snippet=0 
			done
		else
			___error=1 
		fi
		if (( ___error ))
		then
			() {
				builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
				+zi-log -n "{u-warn}Error{b-warn}:{rst} No plugin or snippet ID given"
				if [[ -n $___last_ice ]]
				then
					+zi-log -n " (the last recognized ice was: {ice}""${___last_ice/(#m)(${~ZINIT[ice-list]})/"{data}$MATCH"}{apo}''{rst}).{error}
You can try to prepend {apo}${___q}{lhi}@{apo}'{error} to the ID if the last ice is in fact a plugin.{rst}
{note}Note:{rst} The {apo}\`{ice}ice{apo}\`{rst} subcommand is now again required if not using the for-syntax"
				fi
				+zi-log "."
			}
			return 2
		elif (( ! $# ))
		then
			return ___retval
		fi
	}
	case "$1" in
		(ice) shift
			.zinit-ice "$@" ;;
		(cdreplay) .zinit-compdef-replay "$2"
			___retval=$?  ;;
		(cdclear) .zinit-compdef-clear "$2" ;;
		((add-|)fpath) .zinit-add-fpath "${@[2-correct,-1]}" ;;
		(run) .zinit-run "${@[2-correct,-1]}" ;;
		(man) man "${ZINIT[BIN_DIR]}/doc/zinit.1" ;;
		(env-whitelist) shift
			.zinit-parse-opts env-whitelist "$@"
			builtin set -- "${reply[@]}"
			if (( $# == 0 ))
			then
				ZINIT[ENV-WHITELIST]= 
				(( OPTS[opt_-v,--verbose] )) && +zi-log "{msg2}Cleared the parameter whitelist.{rst}"
			else
				ZINIT[ENV-WHITELIST]+="${(j: :)${(q-kv)@}} " 
				local ___sep="$ZINIT[col-msg2], $ZINIT[col-data2]" 
				(( OPTS[opt_-v,--verbose] )) && +zi-log "{msg2}Extended the parameter whitelist with: {data2}${(pj:$___sep:)@}{msg2}.{rst}"
			fi ;;
		(*) reply=(${ZINIT_EXTS[z-annex subcommand:${(q)1}]}) 
			(( ${#reply} )) && {
				reply=("${(Q)${(z@)reply[1]}[@]}") 
				(( ${+functions[${reply[5]}]} )) && {
					"${reply[5]}" "$@"
					return $?
				} || {
					+zi-log "({error}Couldn't find the subcommand-handler \`{obj}${reply[5]}{error}' of the z-annex \`{file}${reply[3]}{error}')"
					return 1
				}
			}
			(( ${+functions[.zinit-confirm]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
			case "$1" in
				(zstatus) .zinit-show-zstatus ;;
				(delete) shift
					.zinit-delete "$@" ;;
				(times) .zinit-show-times "${@[2-correct,-1]}" ;;
				(self-update) .zinit-self-update ;;
				(unload) (( ${+functions[.zinit-unload]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
					if [[ -z $2 && -z $3 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						[[ $2 = -q ]] && {
							5=-q 
							shift
						}
						.zinit-unload "${2%%(///|//|/)}" "${${3:#-q}%%(///|//|/)}" "${${(M)4:#-q}:-${(M)3:#-q}}"
						___retval=$? 
					fi ;;
				(bindkeys) .zinit-list-bindkeys ;;
				(update) if (( ${+ICE[if]} ))
					then
						eval "${ICE[if]}" || return 1
					fi
					for REPLY in ${(s.;.)ICE[has]}
					do
						(( ${+commands[$REPLY]} )) || return 1
					done
					shift
					.zinit-parse-opts update "$@"
					builtin set -- "${reply[@]}"
					if [[ ${OPTS[opt_-a,--all]} -eq 1 || ${OPTS[opt_-p,--parallel]} -eq 1 || ${OPTS[opt_-s,--snippets]} -eq 1 || ${OPTS[opt_-l,--plugins]} -eq 1 || -z $1$2${ICE[teleid]}${ICE[id-as]} ]]
					then
						[[ -z $1$2 && $(( OPTS[opt_-a,--all] + OPTS[opt_-p,--parallel] + OPTS[opt_-s,--snippets] + OPTS[opt_-l,--plugins] )) -eq 0 ]] && {
							builtin print -r -- "Assuming --all is passed"
						}
						(( OPTS[opt_-p,--parallel] )) && OPTS[value]=${1:-15} 
						.zinit-update-or-status-all update
						___retval=$? 
					else
						local ___key ___id="${1%%(///|//|/)}${2:+/}${2%%(///|//|/)}" 
						[[ -z ${___id//[[:space:]]/} ]] && ___id="${ICE[id-as]:-$ICE[teleid]}" 
						.zinit-update-or-status update "$___id" ""
						___retval=$? 
					fi ;;
				(status) if [[ $2 = --all || ( -z $2 && -z $3 ) ]]
					then
						[[ -z $2 ]] && {
							builtin print -r -- "Assuming --all is passed"
						}
						.zinit-update-or-status-all status
						___retval=$? 
					else
						.zinit-update-or-status status "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
					fi ;;
				(report) if [[ $2 = --all || ( -z $2 && -z $3 ) ]]
					then
						[[ -z $2 ]] && {
							builtin print -r -- "Assuming --all is passed"
						}
						.zinit-show-all-reports
					else
						.zinit-show-report "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
					fi ;;
				(plugins) .zinit-list-plugins "$2" ;;
				(snippets) .zinit-list-snippets "$2" ;;
				(completions) .zinit-show-completions "$2" ;;
				(cclear) .zinit-clear-completions ;;
				(cdisable) if [[ -z $2 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						local ___f="_${2#_}" 
						if .zinit-cdisable "$___f"
						then
							(( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
							.zinit-forget-completion "$___f"
							+zi-log "Initializing completion system ({func}compinit{rst}){…}"
							builtin autoload -Uz compinit
							compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
						else
							___retval=1 
						fi
					fi ;;
				(cenable) if [[ -z $2 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						local ___f="_${2#_}" 
						if .zinit-cenable "$___f"
						then
							(( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
							.zinit-forget-completion "$___f"
							+zi-log "Initializing completion system ({func}compinit{rst}){…}"
							builtin autoload -Uz compinit
							compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
						else
							___retval=1 
						fi
					fi ;;
				(creinstall) (( ${+functions[.zinit-install-completions]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
					[[ $2 = -[qQ] ]] && {
						5=$2 
						shift
					}
					.zinit-install-completions "${2%%(///|//|/)}" "${3%%(///|//|/)}" 1 "${(M)4:#-[qQ]}"
					___retval=$? 
					[[ -z ${(M)4:#-[qQ]} ]] && +zi-log "Initializing completion ({func}compinit{rst}){…}"
					builtin autoload -Uz compinit
					compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}" ;;
				(cuninstall) if [[ -z $2 && -z $3 ]]
					then
						builtin print "Argument needed, try: help"
						___retval=1 
					else
						(( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
						.zinit-uninstall-completions "${2%%(///|//|/)}" "${3%%(///|//|/)}"
						___retval=$? 
						+zi-log "Initializing completion ({func}compinit{rst}){…}"
						builtin autoload -Uz compinit
						compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
					fi ;;
				(csearch) .zinit-search-completions ;;
				(compinit) (( ${+functions[.zinit-forget-completion]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-install.zsh" || return 1
					.zinit-compinit
					___retval=$?  ;;
				(compiled) .zinit-compiled ;;
				(compile|uncompile) (( ${+functions[.zinit-compile-plugin]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-autoload.zsh" || return 1
					local action="$1" all f help quiet 
					shift
					zparseopts -D -F -K -- {a,-all}=all {h,-help}=help {q,-quiet}=quiet || return
					if (( $#help ))
					then
						print "Usage:"
						print "  zinit ${0} <options> <plugin>"
						print " "
						print "Options:"
						print "  -a, --all       Checkout the specified branch"
						print "  -h, --help      Checkout the specified branch"
						print "  -q, --quiet     Checkout the specified tag or commit"
					fi
					if (( $#all ))
					then
						.zinit-compile-uncompile-all ${action}
						___retval="${?}" 
					else
						for f in ${(q+)^@}
						do
							.zinit-$action-plugin "${f}"
							(( ___retval += ${?} ))
						done
					fi ;;
				(debug) shift
					(( ${+functions[+zinit-debug]} )) || builtin source "${ZINIT[BIN_DIR]}/zinit-additional.zsh"
					+zinit-debug $@ ;;
				(cdlist) .zinit-list-compdef-replay ;;
				((c(hanges|d))|create|edit|glance|recall|stress) .zinit-"$1" "${@[2-correct,-1]%%(///|//|/)}"
					___retval=$?  ;;
				(recently) shift
					.zinit-recently "$@"
					___retval=$?  ;;
				(-h|--help|help) .zinit-help ;;
				(version) zi::version ;;
				(srv) () {
						setopt localoptions extendedglob warncreateglobal
						[[ ! -e ${ZINIT[SERVICES_DIR]}/"$2".fifo ]] && {
							builtin print "No such service: $2"
						} || {
							[[ $3 = (#i)(next|stop|quit|restart) ]] && {
								builtin print "${(U)3}" >>| ${ZINIT[SERVICES_DIR]}/"$2".fifo || builtin print "Service $2 inactive"
								___retval=1 
							} || {
								[[ $3 = (#i)start ]] && rm -f ${ZINIT[SERVICES_DIR]}/"$2".stop || {
									builtin print "Unknown service-command: $3"
									___retval=1 
								}
							}
						}
					} "$@" ;;
				(module) .zinit-module "${@[2-correct,-1]}"
					___retval=$?  ;;
				(*) if [[ -z $1 ]]
					then
						+zi-log -n "{b}{u-warn}ERROR{b-warn}:{rst} Missing a {cmd}subcommand "
						+zinit-prehelp-usage-message rst
					else
						+zi-log -n "{b}{u-warn}ERROR{b-warn}:{rst} Unknown subcommand{ehi}:{rst}" "{apo}\`{error}$1{apo}\`{rst} "
						+zinit-prehelp-usage-message rst
					fi
					___retval=1  ;;
			esac ;;
	esac
	return ___retval
}
zle-line-finish () {
	echoti rmkx
}
zle-line-init () {
	echoti smkx
}
zpcdclear () {
	.zinit-compdef-clear -q
}
zpcdreplay () {
	.zinit-compdef-replay -q
}
zpcompdef () {
	ZINIT_COMPDEF_REPLAY+=("${(j: :)${(q)@}}") 
}
zpcompinit () {
	autoload -Uz compinit
	compinit -d ${ZINIT[ZCOMPDUMP_PATH]:-${ZDOTDIR:-$HOME}/.zcompdump} "${(Q@)${(z@)ZINIT[COMPINIT_OPTS]}}"
}
zplugin () {
	zinit "$@"
}
zsh_stats () {
	fc -l 1 | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' | grep -v "./" | sort -nr | head -n 20 | column -c3 -s " " -t | nl
}

# setopts 18
setopt alwaystoend
setopt autocd
setopt autopushd
setopt completeinword
setopt extendedhistory
setopt noflowcontrol
setopt nohashdirs
setopt histexpiredupsfirst
setopt histignoredups
setopt histignorespace
setopt histverify
setopt interactivecomments
setopt login
setopt longlistjobs
setopt promptsubst
setopt pushdignoredups
setopt pushdminus
setopt sharehistory

# aliases 214
alias -- -='cd -'
alias -g ...=../..
alias -g ....=../../..
alias -g .....=../../../..
alias -g ......=../../../../..
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias _='sudo '
alias ac='~/airconnect/bin/aircast-macos-x86_64-static'
alias afind='ack -il'
alias artisan='php artisan'
alias bundletool='java -jar ~/bundletool-all-1.17.1.jar'
alias cvt-pdf='LANG=C LC_ALL=C sed -i '\'\'' s'\''|/Registry (Adobe) /Ordering (Korea1) /Supplement [0-9]|/Registry(Adobe) /Ordering(Identity) /Supplement 0|g'\'
alias diff='diff --color'
alias egrep='egrep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias fgrep='fgrep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias g=git
alias ga='git add'
alias gaa='git add --all'
alias gam='git am'
alias gama='git am --abort'
alias gamc='git am --continue'
alias gams='git am --skip'
alias gamscp='git am --show-current-patch'
alias gap='git apply'
alias gapa='git add --patch'
alias gapt='git apply --3way'
alias gau='git add --update'
alias gav='git add --verbose'
alias gb='git branch'
alias gbD='git branch -D'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbda='git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs git branch -d 2>/dev/null'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcam='git commit -a -m'
alias gcan!='git commit -v -a --no-edit --amend'
alias gcans!='git commit -v -a -s --no-edit --amend'
alias gcas='git commit -a -s'
alias gcasm='git commit -a -s -m'
alias gcb='git checkout -b'
alias gcd='git checkout $(git_develop_branch)'
alias gcf='git config --list'
alias gcl='git clone --recurse-submodules'
alias gclean='git clean -id'
alias gcm='git checkout $(git_main_branch)'
alias gcmsg='git commit -m'
alias gcn!='git commit -v --no-edit --amend'
alias gco='git checkout'
alias gcor='git checkout --recurse-submodules'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gcs='git commit -S'
alias gcsm='git commit -s -m'
alias gcss='git commit -S -s'
alias gcssm='git commit -S -s -m'
alias gd='git diff'
alias gdca='git diff --cached'
alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gdup='git diff @{upstream}'
alias gdw='git diff --word-diff'
alias gf='git fetch'
alias gfa='git fetch --all --prune --jobs=10'
alias gfg='git ls-files | grep'
alias gfo='git fetch origin'
alias gg='git gui citool'
alias gga='git gui citool --amend'
alias ggpull='git pull origin "$(git_current_branch)"'
alias ggpur=ggu
alias ggpush='git push origin "$(git_current_branch)"'
alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias ghh='git help'
alias gignore='git update-index --assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
alias gk='\gitk --all --branches &!'
alias gke='\gitk --all $(git log -g --pretty=%h) &!'
alias gl='git pull'
alias glg='git log --stat'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glgp='git log --stat -p'
alias glo='git log --oneline --decorate'
alias glod='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'
alias glods='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'' --date=short'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glol='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'\'
alias glola='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'\'' --all'
alias glols='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'\'' --stat'
alias glp=_git_log_prettily
alias glum='git pull upstream $(git_main_branch)'
alias gm='git merge'
alias gma='git merge --abort'
alias gmom='git merge origin/$(git_main_branch)'
alias gmtl='git mergetool --no-prompt'
alias gmtlvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/$(git_main_branch)'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease'
alias gpf!='git push --force'
alias gpoat='git push origin --all && git push origin --tags'
alias gpr='git pull --rebase'
alias gpristine='git reset --hard && git clean -dffx'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gpu='git push upstream'
alias gpv='git push -v'
alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbd='git rebase $(git_develop_branch)'
alias grbi='git rebase -i'
alias grbm='git rebase $(git_main_branch)'
alias grbo='git rebase --onto'
alias grbom='git rebase origin/$(git_main_branch)'
alias grbs='git rebase --skip'
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias grev='git revert'
alias grh='git reset'
alias grhh='git reset --hard'
alias grm='git rm'
alias grmc='git rm --cached'
alias grmv='git remote rename'
alias groh='git reset origin/$(git_current_branch) --hard'
alias grrm='git remote remove'
alias grs='git restore'
alias grset='git remote set-url'
alias grss='git restore --source'
alias grst='git restore --staged'
alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'
alias gru='git reset --'
alias grup='git remote update'
alias grv='git remote -v'
alias gsb='git status -sb'
alias gsd='git svn dcommit'
alias gsh='git show'
alias gsi='git submodule init'
alias gsps='git show --pretty=short --show-signature'
alias gsr='git svn rebase'
alias gss='git status -s'
alias gst='git status'
alias gsta='git stash push'
alias gstaa='git stash apply'
alias gstall='git stash --all'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gstu='gsta --include-untracked'
alias gsu='git submodule update'
alias gsw='git switch'
alias gswc='git switch -c'
alias gswd='git switch $(git_develop_branch)'
alias gswm='git switch $(git_main_branch)'
alias gtl='gtl(){ git tag --sort=-v:refname -n -l "${1}*" }; noglob gtl'
alias gts='git tag -s'
alias gtv='git tag | sort -V'
alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'
alias gup='git pull --rebase'
alias gupa='git pull --rebase --autostash'
alias gupav='git pull --rebase --autostash -v'
alias gupom='git pull --rebase origin $(git_main_branch)'
alias gupomi='git pull --rebase=interactive origin $(git_main_branch)'
alias gupv='git pull --rebase -v'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign -m "--wip-- [skip ci]"'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder'
alias history=omz_history
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias ls='ls -G'
alias lsa='ls -lah'
alias md='mkdir -p'
alias ofd='open_command $PWD'
alias rd=rmdir
alias run-help=man
alias showfiles='defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder'
alias tf=terraform
alias which-command=whence
alias yarns='yarn $(cat package.json | jq .scripts | jq -r "keys | .[]" | fzf)'
alias zi=zinit
alias zini=zinit
alias zpl=zinit
alias zplg=zinit

# exports 65
export ANDROID_HOME=/Users/Yangeok/Library/Android/sdk/
export AUTOJUMP_ERROR_PATH=/Users/yangeok/Library/autojump/errors.log
export AUTOJUMP_SOURCED=1
export BASH_MAX_OUTPUT_LENGTH=10000
export BUN_INSTALL=/Users/yangeok/.bun
export CLOUDSDK_PYTHON=/Users/yangeok/.pyenv/versions/3.11.9/bin/python
export CODEX_HOME=/Users/yangeok/Dev/Test/i-cherri/.codex
export COLORTERM=truecolor
export COMMAND_MODE=unix2003
export CONDA_CHANGEPS1=false
export CPPFLAGS=' -I/usr/local/opt/zlib/include -I/usr/local/opt/zlib/include'
export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
export GEMINI_API_KEY=AIzaSyA3geIdTO7-S6bQEL7yCJp1XOq5YSFPVyk
export GOENV_ROOT=/Users/yangeok/.goenv
export GOENV_SHELL=zsh
export GOOGLE_CLOUD_PROJECT=gen-lang-client-0696918616
export GOOGLE_CLOUD_SDK_PATH=/Users/yangeok/google-cloud-sdk
export GOROOT=/usr/local/go
export HOME=/Users/yangeok
export HOMEBREW_CELLAR=/opt/homebrew/Cellar
export HOMEBREW_PREFIX=/opt/homebrew
export HOMEBREW_REPOSITORY=/opt/homebrew
export INFOPATH=/opt/homebrew/share/info:/opt/homebrew/share/info:/opt/homebrew/share/info:
export JAVA_HOME=/Users/yangeok/.jenv/versions/21
export JDK_HOME=/Users/yangeok/.jenv/versions/21
export JENV_FORCEJAVAHOME=true
export JENV_FORCEJDKHOME=true
export JENV_LOADED=1
export JENV_SHELL=zsh
export LC_CTYPE=UTF-8
export LDFLAGS=' -L/usr/local/opt/zlib/lib -L/usr/local/opt/zlib/lib'
export LESS=-R
export LLVM_CONFIG=/opt/homebrew/opt/llvm/bin/llvm-config
export LOGNAME=yangeok
export LSCOLORS=Gxfxcxdxbxegedabagacad
export LaunchInstanceID=4BDA8E3A-8D58-47D2-92D8-5A6380D2C703
export MAX_MCP_OUTPUT_TOKENS=8000
export PAGER=less
export PKG_CONFIG_PATH=' /usr/local/opt/zlib/lib/pkgconfig /usr/local/opt/zlib/lib/pkgconfig'
export PMSPEC=0uUpiPsf
export PNPM_HOME=/Users/yangeok/Library/pnpm
export PYENV_ROOT=/Users/yangeok/.pyenv
export RBENV_SHELL=zsh
export REACT_EDITOR=cursor
export SECURITYSESSIONID=186b2
export SHELL=/bin/zsh
export SSH_AUTH_SOCK=/private/tmp/com.apple.launchd.6rNLqGFV3M/Listeners
export SSH_SOCKET_DIR='~/.ssh'
export TERM=xterm-256color
export TERM_PROGRAM=WarpTerminal
export TERM_PROGRAM_VERSION=v0.2026.05.13.09.15.stable_03
export TMPDIR=/var/folders/rd/3chs9m2n68q_4lnf9cmmrky00000gn/T/
export USER=yangeok
export WARP_CLIENT_VERSION=v0.2026.05.13.09.15.stable_03
export WARP_CLI_AGENT_PROTOCOL_VERSION=1
export WARP_HONOR_PS1=0
export WARP_IS_LOCAL_SHELL_SESSION=1
export WARP_USE_SSH_WRAPPER=1
export XPC_FLAGS=0x0
export XPC_SERVICE_NAME=0
export ZPFX=/Users/yangeok/.local/share/zinit/polaris
export ZSH=/Users/yangeok/.oh-my-zsh
export ZSH_CACHE_DIR=/Users/yangeok/.oh-my-zsh/cache
export __CFBundleIdentifier=dev.warp.Warp-Stable
export __CF_USER_TEXT_ENCODING=0x1F5:0x0:0x3
