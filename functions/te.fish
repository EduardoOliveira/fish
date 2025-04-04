function te
    tmux new-window -n "$argv" "/usr/bin/env fish -l -c \"$argv\""
end
