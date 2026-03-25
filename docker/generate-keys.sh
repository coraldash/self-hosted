#!/bin/bash

# Generate Supabase ANON_KEY and SERVICE_ROLE_KEY from JWT_SECRET
# Usage: ./generate-keys.sh <JWT_SECRET>

set -e

JWT_SECRET="${1:-}"

if [ -z "$JWT_SECRET" ]; then
  echo "Usage: ./generate-keys.sh <JWT_SECRET>"
  echo ""
  echo "Generate a JWT_SECRET first:"
  echo "  openssl rand -base64 32"
  exit 1
fi

# Check if node is available
if ! command -v node &> /dev/null; then
  echo "Error: Node.js is required but not installed"
  exit 1
fi

# Generate keys using Node.js crypto
node -e "
const crypto = require('crypto');

function generateJWT(payload, secret) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', secret).update(header + '.' + body).digest('base64url');
  return header + '.' + body + '.' + signature;
}

const secret = process.argv[1];

const anonPayload = {
  role: 'anon',
  iss: 'supabase',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (10 * 365 * 24 * 60 * 60) // 10 years
};

const servicePayload = {
  role: 'service_role',
  iss: 'supabase',
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + (10 * 365 * 24 * 60 * 60) // 10 years
};

const anonKey = generateJWT(anonPayload, secret);
const serviceKey = generateJWT(servicePayload, secret);

console.log('# Add these to your .env file:\n');
console.log('ANON_KEY=' + anonKey);
console.log('');
console.log('SERVICE_ROLE_KEY=' + serviceKey);
" "$JWT_SECRET"
