#!/usr/bin/env bash
# =============================================================================
# Run ONCE on the macOS VM (ssh vm) to install everything needed for iOS builds.
# =============================================================================
set -euo pipefail

log() { echo "[$(date +%H:%M:%S)] $*"; }

# 1. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Tools
log "Installing tools..."
brew install --quiet rbenv ruby-build cocoapods git

# 3. Ruby 3.2 (for Fastlane)
if ! rbenv versions | grep -q 3.2; then
  rbenv install 3.2.4
fi
rbenv global 3.2.4
eval "$(rbenv init -)"

# 4. Bundler
gem install bundler --no-document

# 5. Flutter
if ! command -v flutter >/dev/null 2>&1; then
  log "Installing Flutter..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
  export PATH="$HOME/flutter/bin:$PATH"
fi
flutter --version
flutter doctor

# 6. Xcode CLI tools (Xcode must be installed manually from App Store first)
xcode-select --install 2>/dev/null || true
if ! [ -d "/Applications/Xcode.app" ]; then
  log "⚠ Install Xcode from App Store, then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  log "  and: sudo xcodebuild -license accept"
  exit 1
fi
sudo xcodebuild -license accept

# 7. Create CI workspace
mkdir -p ~/hnag-ci

# 8. App Store Connect API key — store in keychain via Fastlane
log "✅ VM setup done."
log ""
log "Next: configure GitHub Actions secrets:"
log "  - VM_SSH_KEY (private key for ndh0408 user)"
log "  - TS_OAUTH_CLIENT_ID + TS_OAUTH_SECRET (Tailscale OAuth for runner)"
log "  - ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_CONTENT (App Store Connect API)"
log "  - APPLE_ID, APPLE_TEAM_ID, APPLE_ITC_TEAM_ID, APPLE_APP_ID"
