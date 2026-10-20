if status is-interactive
    # Commands to run in interactive sessions can go here
end

# WSL 的 /mnt/c 目錄都是 777，預設 ow/tw 是藍字綠底看不清楚，改成跟一般目錄一樣
set -gx LS_COLORS "$LS_COLORS:ow=01;34:tw=01;34"

alias ls="eza --icons"
alias rm="trash"

starship init fish | source
