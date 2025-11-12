#!/bin/bash
cd /Users/bhanna/Projects/Score/score/flutter_dashboard
export PATH="$PATH:/Users/bhanna/flutter/bin"
echo "Starting Flutter app from: $(pwd)"
echo "Flutter version: $(flutter --version | head -1)"
echo "Running flutter clean..."
flutter clean
echo "Getting dependencies..."
flutter pub get
echo "Starting app on web server port 3001..."
flutter run -d web-server --web-port=3001