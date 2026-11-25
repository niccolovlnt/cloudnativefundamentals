#!/usr/bin/env bash
# Prepara l'ambiente per la lezione 2 (macOS e Linux): verifica Docker, scarica kind, kubectl e kubecolor
# in ~/Downloads/cnf-tools e li aggiunge al PATH, con alias kubectl=kubecolor e autocompletion. Uso: bash setup.sh
set -euo pipefail

# --- 1. Docker ---
command -v docker >/dev/null || { echo "Docker non trovato. Installalo: https://docs.docker.com/engine/install/ (Linux) o Docker Desktop (macOS)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker e' installato ma il motore non risponde. Avvialo e riesegui lo script." >&2; exit 1; }
echo "Docker OK: $(docker version --format '{{.Server.Version}}')"

# --- 2. Piattaforma e cartella di destinazione ---
os=$(uname -s | tr '[:upper:]' '[:lower:]')   # darwin | linux
case "$(uname -m)" in
  x86_64|amd64)  arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) echo "Architettura non supportata: $(uname -m)" >&2; exit 1 ;;
esac
dest="$HOME/Downloads/cnf-tools"
mkdir -p "$dest"

# --- 3. kubectl (con verifica sha256) ---
ver=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
echo "Scarico kubectl $ver..."
curl -fsSL "https://dl.k8s.io/release/$ver/bin/$os/$arch/kubectl" -o "$dest/kubectl"
expected=$(curl -fsSL "https://dl.k8s.io/release/$ver/bin/$os/$arch/kubectl.sha256")
actual=$( (sha256sum "$dest/kubectl" 2>/dev/null || shasum -a 256 "$dest/kubectl") | cut -d' ' -f1)
[ "$expected" = "$actual" ] || { rm -f "$dest/kubectl"; echo "Checksum di kubectl non valido, file eliminato." >&2; exit 1; }

# --- 4. kind ---
echo "Scarico kind..."
curl -fsSL "https://kind.sigs.k8s.io/dl/latest/kind-$os-$arch" -o "$dest/kind"

# --- 4b. kubecolor (kubectl con output colorato, con verifica sha256) ---
kcver=$(curl -fsSL https://api.github.com/repos/kubecolor/kubecolor/releases/latest | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p')
[ -n "$kcver" ] || { echo "Impossibile leggere l'ultima versione di kubecolor." >&2; exit 1; }
echo "Scarico kubecolor $kcver..."
kcfile="kubecolor_${kcver}_${os}_${arch}.tar.gz"
kcurl="https://github.com/kubecolor/kubecolor/releases/download/v$kcver"
tmp=$(mktemp -d)
curl -fsSL "$kcurl/$kcfile" -o "$tmp/$kcfile"
expected=$(curl -fsSL "$kcurl/checksums.txt" | awk -v f="$kcfile" '$2==f {print $1}')
actual=$( (sha256sum "$tmp/$kcfile" 2>/dev/null || shasum -a 256 "$tmp/$kcfile") | cut -d' ' -f1)
[ -n "$expected" ] && [ "$expected" = "$actual" ] || { rm -rf "$tmp"; echo "Checksum di kubecolor non valido." >&2; exit 1; }
tar -xzf "$tmp/$kcfile" -C "$dest" kubecolor
rm -rf "$tmp"

chmod +x "$dest/kind" "$dest/kubectl" "$dest/kubecolor"

# --- 5. PATH e alias kubectl=kubecolor (file rc della shell, una sola volta) ---
case "${SHELL:-}" in
  */zsh) rc="$HOME/.zshrc"; sh=zsh ;;
  *)     rc="$HOME/.bashrc"; sh=bash ;;
esac
line="export PATH=\"$dest:\$PATH\""
grep -qsF "$line" "$rc" || echo "$line" >> "$rc"
export PATH="$dest:$PATH"
alias_line="alias kubectl=kubecolor"   # kubectl con output colorato
grep -qsxF "$alias_line" "$rc" || echo "$alias_line" >> "$rc"
 
# --- 5b. Autocompletion di kubectl (anche per l'alias kubecolor), generata una volta e caricata dal file rc ---
comp="$dest/kubectl-completion.$sh"
"$dest/kubectl" completion "$sh" > "$comp"
if [ "$sh" = zsh ]; then
  echo "compdef _kubectl kubecolor" >> "$comp"
  src="(( \$+functions[compdef] )) || { autoload -Uz compinit && compinit; }; source \"$comp\""
else
  echo "complete -o default -F __start_kubectl kubecolor" >> "$comp"
  src="source \"$comp\""
fi
grep -qsxF "$src" "$rc" || echo "$src" >> "$rc"

# --- 6. Verifica ---
kind version
kubectl version --client
kubecolor --kubecolor-version
echo
echo "Fatto! Apri un nuovo terminale (o: source $rc), poi: kind create cluster --config lesson2/kind-config.yaml"
