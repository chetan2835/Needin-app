#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Creating .env from Xcode Cloud environment variables..."

printf '%s\n' \
  "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" \
  "MSG91_WIDGET_ID=$MSG91_WIDGET_ID" \
  "MSG91_AUTH_TOKEN=$MSG91_AUTH_TOKEN" \
  "SUPABASE_URL=$SUPABASE_URL" \
  "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  > .env

echo ".env created successfully."

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"

export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios
flutter pub get

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

cd ios
pod install --repo-update
