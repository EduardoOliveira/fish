function _zn_inner
    cd $argv
    tmux rename-window "zn $(path basename (pwd))"
    nvim .
end
