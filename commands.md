# Fastforge Distribution Commands

## Development Environment

# Run all dev environment builds

fastforge distribute --release=dev

# Run specific platform builds (dev)

fastforge distribute --release=dev --job=release-dev-android
fastforge distribute --release=dev --job=release-dev-ios
fastforge distribute --release=dev --job=release-dev-macos
fastforge distribute --release=dev --job=release-dev-linux
fastforge distribute --release=dev --job=release-dev-windows
fastforge distribute --release=dev --job=release-dev-web

## Production Environment

# Run all production environment builds

fastforge distribute --release=prod

# Run specific platform builds (prod)

fastforge distribute --release=prod --job=release-prod-android
fastforge distribute --release=prod --job=release-prod-ios
fastforge distribute --release=prod --job=release-prod-macos
fastforge distribute --release=prod --job=release-prod-linux
fastforge distribute --release=prod --job=release-prod-windows
fastforge distribute --release=prod --job=release-prod-web

## Additional Options

# To see all available options

fastforge help distribute
