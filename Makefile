help: ## Print documentation
	@{ grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST); echo -e '$(EXTRA_HELP)'; } | sed 's/^ //' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-33s\033[0m %s\n", $$1, $$2}'

include lib.mk
include nix.mk
include legacy.mk

PROJECT_NAME = cardano-node
NUM_PROC     = $(nproc --all)

## One of:  shey alra mary alzo
ERA     ?= alzo

PROFILE ?= default-${ERA}
REV     ?= master
ARGS    ?=
CMD     ?=

lint hlint:
	hlint .

stylish-haskell: ## Apply stylish-haskell on all *.hs files
	@find . -type f -name "*.hs" -not -path '.git' -print0 | xargs -0 stylish-haskell -i

cabal-hashes:
	nix run .#checkCabalProject

cli node:
	cabal --ghc-options="+RTS -qn8 -A32M -RTS" build cardano-$@

trace-documentation:
	cabal run -- exe:cardano-node trace-documentation --config 'configuration/cardano/mainnet-config-new-tracing.yaml' --output-file 'doc/new-tracing/tracers_doc_generated.md'

###
### Workbench
###
##
## Base targets:
##
shell:                                           ## Nix shell, CI mode (from Nix store), vars: PROFILE, CMD
	nix-shell --max-jobs 8 --cores 0 --show-trace --argstr profileName ${PROFILE} ${ARGS} ${if ${CMD},--run "${CMD}"}
shell-dev: shell
shell-dev: ARGS += --arg 'workbenchDevMode' true ## Nix shell, dev mode (from checkout), vars: PROFILE, CMD

list-profiles:                                   ## List workbench profiles
	nix build .#workbench.profile-names-json --json | jq '.[0].outputs.out' -r | xargs jq .
show-profile:                                    ## NAME=profile-name
	@test -n "${NAME}" || { echo 'HELP:  to specify profile to show, add NAME=profle-name' && exit 1; }
	nix build .#all-profiles-json --json --option substitute false | jq '.[0].outputs.out' -r | xargs jq ".\"${NAME}\" | if . == null then error(\"\n###\n### Error:  unknown profile: ${NAME}  Please consult:  make list-profiles\n###\") else . end"
ps:                                              ## Plain-text list of profiles
	@nix build .#workbench.profile-names-json --json | jq '.[0].outputs.out' -r | xargs jq '.[]' --raw-output

##
## Profile-based cluster shells (autogenerated targets)
##
SHELL_PROFILES += startstop startstop-oldtracing
SHELL_PROFILES += smoke 10 plutus

SHELL_PROFILES += forge-stress forge-stress-plutus forge-stress-oldtracing

SHELL_PROFILES += chainsync-early-byron  chainsync-early-byron-oldtracing
SHELL_PROFILES += chainsync-early-alonzo chainsync-early-alonzo-oldtracing

## Note:  to enable a shell for a profile, just add its name (one of names from 'make ps') to SHELL_PROFILES

$(eval $(call define_profile_targets,$(SHELL_PROFILES)))


###
### Misc
###
clean-profile proclean:
	rm -f *.html *.prof *.hp *.stats *.eventlog

clean: clean-profile
	rm -rf logs/ socket/ cluster.*

full-clean: clean
	rm -rf db dist-newstyle $(shell find . -name '*~' -or -name '*.swp')

cls:
	echo -en "\ec"

.PHONY: cabal-hashes clean cli cls cluster-profiles cluster-shell help node run-test shell shell-dev stylish-haskell
