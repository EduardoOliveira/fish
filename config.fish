set PATH /usr/local/bin /usr/sbin $PATH

set -x GOPRIVATE "go.axofinance.io"
set -x DOCKER_HOST "unix://$HOME/.colima/default/docker.sock"

set --universal nvm_default_version lts

set PATH $PATH $HOME/go/bin

/opt/homebrew/bin/brew shellenv | source


if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Generated for envman. Do not edit.
test -s ~/.config/envman/load.fish; and source ~/.config/envman/load.fish
