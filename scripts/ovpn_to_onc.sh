#!/usr/bin/env bash
# This conversion logic is based on the [ChromeOS VPN ONC block](https://docs.google.com/document/d/18TU22gueH5OKYHZVJ5nXuqHnk2GN6nDvfu2Hbrb4YLE/pub#h.oimioyixntt3) from [OpenVPN Manual Setup](https://www.chromium.org/chromium-os/how-tos-and-troubleshooting/openvpn-manual-setup)

set -eu

if [ "$#" -lt 1 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  cat <<-ENDOFMESSAGE
Please specify the ovpn file you want to convert.
Usage: $0 <name>.ovpn

ENDOFMESSAGE
  exit 1
fi

ovpn_file=$(readlink -f "$1")
if [ ! -f "${ovpn_file}" ]; then
    printf "No such file: %s\\n\\n" "${ovpn_file}"
    exit 1
fi

# Remove the extension and the prefix
# See https://unix.stackexchange.com/a/137785
name_no_ext=${ovpn_file%.*}
USERNAME="${name_no_ext##*/}"

# Create output folder
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_dir="${script_dir}/output"
rm -rf "${output_dir}" && mkdir "${output_dir}"

# Generate .crt file
crt_file="${output_dir}"/"${USERNAME}".crt
awk '/<cert>/{flag=1;next}/<\/cert>/{flag=0}flag' "${ovpn_file}" > "${crt_file}"

# Generate .key file
key_file="${output_dir}"/"${USERNAME}".key
awk '/<key>/{flag=1;next}/<\/key>/{flag=0}flag' "${ovpn_file}" > "${key_file}"

# Generate ca.crt
ca_file="${output_dir}"/ca.crt
awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' "${ovpn_file}" > "${ca_file}"

# Generate .p12 file
p12_file="${output_dir}"/"${USERNAME}".p12
passwd=$(grep -oP 'CLIENT_PASS=\K.*$' "${script_dir}"/../setupVars.conf)
openssl pkcs12 -export \
    -inkey "${key_file}" \
    -in "${crt_file}" \
    -certfile "${ca_file}" \
    -out "${p12_file}" \
    -passin pass:"${passwd}" \
    -passout pass:"${passwd}"

chmod 0600 "${key_file}" "${p12_file}"


# Generate .onc file

GUID_1=$(cat /proc/sys/kernel/random/uuid)
GUID_2=$(cat /proc/sys/kernel/random/uuid)

host_port=$(grep -oP 'remote +\K[0-9\. ]+$' "$ovpn_file")
IFS=" " read -r -a host_port_arr <<< "${host_port}"

# Remove the trailing whitespace
# See https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
HOSTHAME="$(echo -e "${host_port_arr[0]}" | sed -e 's/[[:space:]]*$//')"
PORT="$(echo -e "${host_port_arr[1]}" | sed -e 's/[[:space:]]*$//')"

PROTO=$(grep -oP 'proto +\K[\w]+' "$ovpn_file")

# See awk usage: https://stackoverflow.com/a/17988834
CA_CERT=$(awk '/<ca>/{flag=1;next}/<\/ca>/{flag=0}flag' "${ovpn_file}")
CA_CERT=$(awk '/-+BEGIN CERTIFICATE-+/{flag=1;next}/-+END CERTIFICATE-+/{flag=0}flag' <<< "${CA_CERT}")
CA_CERT=$(tr -d '\r\n' <<< "${CA_CERT}")

TLS_AUTH_KEY=$(awk '/<tls-auth>/{flag=1;next}/<\/tls-auth>/{flag=0}flag' "${ovpn_file}")
# Remove the comment lines
TLS_AUTH_KEY=$(sed '/^#/ d' <<< "${TLS_AUTH_KEY}")
# Replace all the newlines with literal “\n” characters
TLS_AUTH_KEY=$(sed '{:q;N;s/\n/\\n/g;t q}' <<< "${TLS_AUTH_KEY}")

# Make a copy of the template before updating placeholders
onc_file="${output_dir}"/"${USERNAME}".onc
cp "${script_dir}/template.onc" "${onc_file}"

keys=(GUID_1 GUID_2 USERNAME HOSTHAME PORT PROTO CA_CERT TLS_AUTH_KEY)
for k in "${keys[@]}"; do
    printf -v encoded_val "%q" "${!k}"
    encoded_val=$(sed 's/\//\\\//g' <<< "${encoded_val}")
    sed -i "s/<${k}>/${encoded_val}/g" "${onc_file}"
done

printf "\\n#### Successfully Generated Files to %s ####\\n" "${output_dir}"
ls "${output_dir}" 
