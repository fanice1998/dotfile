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

# Go environment
# ── Go environment ──────────────────────────────────────────────
if command -v go >/dev/null 2>&1; then
  if ! grep -qF 'GOROOT="$(go env GOROOT)"' ~/.zshrc 2>&1; then
    echo 'export GOROOT="$(go env GOROOT)"' >> ~/.zshrc
    echo 'export GOPATH="$(go env GOPATH)"' >> ~/.zshrc
    echo 'export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"' >> ~/.zshrc
  fi
fi

# starship install and setting zshrc
if command -v starship 2>&1; then
  if ! grep -qF 'eval "$(starship init zsh)"' ~/.zshrc 2>/dev/null; then
    echo 'eval "$(starship init zsh)"' >> ~/.zshrc
  fi
else
  curl -sS https://starship.rs/install.sh | sh
  echo 'eval "$(starship init zsh)"' >> ~/.zshrc
fi

# reload
source ~/.zshrc

