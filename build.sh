#!/bin/bash
set -e

echo "Installing Flutter..."
# Clone the Flutter stable channel into the vercel environment's root directory
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Display Flutter doctor to verify installation
flutter doctor -v

echo "Building Flutter Web App..."
# Navigate to the actual Flutter project folder
cd agri_score

# Fetch dependencies and build the web app
flutter pub get
flutter build web --release

echo "Moving build output to Vercel public directory..."
cd ..
mkdir -p public
# Copy the built web files to the 'public' directory which Vercel will serve
cp -R agri_score/build/web/* public/

echo "Build complete."
