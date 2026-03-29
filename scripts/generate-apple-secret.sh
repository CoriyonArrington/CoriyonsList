#!/bin/bash
# This script generates the client secret JWT for Sign in with Apple.
# It requires a .env.local file in the root directory with your Apple credentials.

# FIX: Load environment variables from .env.local file if it exists
if [ -f .env.local ]; then
  export $(cat .env.local | sed 's/#.*//g' | xargs)
fi

echo "➡️  Generating Apple Client Secret..."

# Check that required environment variables are set
if [ -z "$APPLE_KEY_ID" ] || [ -z "$APPLE_TEAM_ID" ] || [ -z "$APPLE_CLIENT_ID" ] || [ -z "$APPLE_P8_FILE_PATH" ]; then
  # FIX: Updated error message to reference .env.local
  echo "❌ Error: Please set APPLE_KEY_ID, APPLE_TEAM_ID, APPLE_CLIENT_ID, and APPLE_P8_FILE_PATH in your .env.local file."
  exit 1
fi

# Use Node.js to generate the JWT from the environment variables
node -e "
  const jwt = require('jsonwebtoken');
  const fs = require('fs');

  const keyId = process.env.APPLE_KEY_ID;
  const teamId = process.env.APPLE_TEAM_ID;
  const clientId = process.env.APPLE_CLIENT_ID;
  const privateKeyPath = process.env.APPLE_P8_FILE_PATH;

  if (!fs.existsSync(privateKeyPath)) {
    console.error('❌ Error: Private key file not found at:', privateKeyPath);
    process.exit(1);
  }

  const privateKey = fs.readFileSync(privateKeyPath);
  const now = Math.floor(Date.now() / 1000);

  const token = jwt.sign(
    {
      iss: teamId,
      iat: now,
      exp: now + 86400 * 180, // Token is valid for 180 days
      aud: 'https://appleid.apple.com',
      sub: clientId,
    },
    privateKey,
    {
      algorithm: 'ES256',
      header: { alg: 'ES256', kid: keyId },
    }
  );

  console.log('\n✅ Apple Client Secret JWT Generated Successfully:\n');
  console.log(token);
"