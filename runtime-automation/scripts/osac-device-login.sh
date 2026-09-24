#!/bin/bash
# Automated osac device flow login.
# Starts osac login --flow device in background, completes the browser
# flow programmatically, and waits for the login to finish.
#
# Usage: osac-device-login.sh <keycloak_url> <api_url> <username> <password>
set -euo pipefail

KC_URL="${1:?Usage: $0 <keycloak_url> <api_url> <username> <password>}"
API_URL="${2:?}"
USERNAME="${3:?}"
PASSWORD="${4:?}"

LOGIN_LOG=$(mktemp)
COOKIE_JAR=$(mktemp)
RESP_FILE=$(mktemp)
HDR_FILE=$(mktemp)
trap "rm -f ${LOGIN_LOG} ${COOKIE_JAR} ${RESP_FILE} ${HDR_FILE}" EXIT

py_extract() {
  python3 -c "
import re, html, sys
content = sys.stdin.read()
m = re.search(sys.argv[1], content)
if m: print(html.unescape(m.group(1)))
" "$1"
}

get_redirect() {
  grep -i "^location:" "${HDR_FILE}" | tail -1 | tr -d '\r' | sed 's/^[Ll]ocation: //'
}

fixurl() {
  local url="$1"
  if [[ "${url}" == /* ]]; then echo "${KC_URL}${url}"; else echo "${url}"; fi
}

# Start osac login in background
osac logout 2>/dev/null || true
osac login --insecure --address "${API_URL}" --flow device > "${LOGIN_LOG}" 2>&1 &
OSAC_PID=$!

# Wait for user code to appear
for i in $(seq 1 30); do
  if grep -q "[A-Z]\{4\}-[A-Z]\{4\}" "${LOGIN_LOG}" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

USER_CODE=$(grep -oE '[A-Z]{4}-[A-Z]{4}' "${LOGIN_LOG}" | head -1)
if [ -z "${USER_CODE}" ]; then
  >&2 echo "ERROR: Failed to get user code from osac login"
  kill ${OSAC_PID} 2>/dev/null || true
  exit 1
fi
>&2 echo "User code: ${USER_CODE}"

# Navigate verification URL
curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" -L \
  "${KC_URL}/realms/osac/device?user_code=${USER_CODE}" -o "${RESP_FILE}"

LOGIN_ACTION=$(cat "${RESP_FILE}" | py_extract 'action="([^"]+)"')

# Submit username
curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" \
  -D "${HDR_FILE}" -o "${RESP_FILE}" \
  -X POST "${LOGIN_ACTION}" -d "username=${USERNAME}"

HTTP_CODE=$(grep "^HTTP" "${HDR_FILE}" | tail -1 | awk '{print $2}')

if [ "${HTTP_CODE}" = "303" ] || [ "${HTTP_CODE}" = "302" ]; then
  REDIRECT=$(fixurl "$(get_redirect)")
  >&2 echo "Auto-redirected to broker."
  curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" -D "${HDR_FILE}" -o /dev/null "${REDIRECT}"
  REDIRECT=$(fixurl "$(get_redirect)")
else
  BROKER_LINK=$(cat "${RESP_FILE}" | py_extract 'href="([^"]*broker/[^"]+/login[^"]*)"')
  REDIRECT=$(fixurl "${BROKER_LINK}")
  >&2 echo "Clicking IdP broker link."
fi

# Follow to IdP login form
curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" -L -o "${RESP_FILE}" "${REDIRECT}"
IDP_ACTION=$(cat "${RESP_FILE}" | py_extract 'action="([^"]+)"')
>&2 echo "IdP login form found."

# Submit credentials
curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" \
  -D "${HDR_FILE}" -o /dev/null \
  -X POST "${IDP_ACTION}" \
  -d "username=${USERNAME}&password=${PASSWORD}&credentialId="

# Follow broker callback → consent page
REDIRECT=$(fixurl "$(get_redirect)")
curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" -D "${HDR_FILE}" -o /dev/null "${REDIRECT}"
REDIRECT=$(fixurl "$(get_redirect)")
curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" -L -o "${RESP_FILE}" "${REDIRECT}"

# Approve consent
CONSENT_ACTION=$(cat "${RESP_FILE}" | py_extract 'action="([^"]*consent[^"]*)"')
HIDDEN_CODE=$(cat "${RESP_FILE}" | py_extract 'name="code"\s+value="([^"]+)"')
CONSENT_ACTION=$(fixurl "${CONSENT_ACTION}")

curl -sk -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" \
  -X POST "${CONSENT_ACTION}" -d "code=${HIDDEN_CODE}&accept=Yes" -o /dev/null
>&2 echo "Consent approved."

# Wait for osac login to finish
>&2 echo "Waiting for osac login to complete..."
if wait ${OSAC_PID}; then
  >&2 echo "SUCCESS: osac login completed for ${USERNAME}"
else
  >&2 echo "ERROR: osac login failed"
  cat "${LOGIN_LOG}" >&2
  exit 1
fi
