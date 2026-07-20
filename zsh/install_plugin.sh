#!/bin/zsh

# Tips about text history
if [ ! -d fzf-tab ]; then
  git clone https://github.com/Aloxaf/fzf-tab ~/.zsh/fzf-tab
fi

# Syntax highlighting
if [ ! -d zsh-syntax-highlighting ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
fi

mv ~/.zshrc ~/.zshrc.bak 2>/dev/null

cp ./.zshrc.origin ~/.zshrc

if command -v starship &>/dev/null; then
  if ! grep -qF 'eval "$(starship init zsh)"' ~/.zshrc 2>/dev/null; then
    echo 'eval "$(starship init zsh)"' >> ~/.zshrc
  fi
else
  curl -sS https://starship.rs/install.sh | sh
fi

source ~/.zshrc
