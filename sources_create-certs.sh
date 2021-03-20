#!/usr/bin/env bash

function usage {

    echo -n "
NAME
    create-certs.sh - create CA, server and client certificates

SYNOPSIS
    create-certs.sh [OPTION]...

DESCRIPTION
    Script which helps you to create CA, server and client certificates.

    Available arguments.

    --mode
        'ca' to create CA, 'server' to create server cert, 'client' to create client cert

    --hostname
        FQDN server hostname

    --host-ip
        Host IP / Client (default: none)

    --password
        Password for CA Key generation

    --target-dir
        Target directory to store result files

    --expiration-days
        Certificate expiration in day - default: 3650 days

    --ca-subject
        Subject string for CA cert (default: /C=CZ/L=Prague/O=CompanyName/CN=docker1.aws.server.tld/emailAddress=ssl@domain.tld

    --quiet
        Disable printing output messages

AUTHOR
    Frantisek Preissler, pida42 <github@ntisek.cz>
"
    exit
}

QUIET=0

EXPIRATION_DAYS=3650
CA_SUBJECT_STR="/C=CZ/L=Prague/O=CompanyName/CN=docker1.aws.server.tld/emailAddress=ssl@domain.tld"

while [[ $# -gt 1 ]]; do

    _key="$1"

    case ${_key} in
        --mode)             MODE="$2"; shift                ;;
        --hostname)         NAME="$2"; shift                ;;
        --host-ip)          HOST_IP="$2"; shift             ;;
        --password)         PASSWORD="$2"; shift            ;;
        --target-dir)       TARGET_DIR="$2"; shift          ;;
        --expiration-days)  EXPIRATION_DAYS="$2"; shift     ;;
        --ca-subject)       CA_SUBJECT_STR="$2"; shift      ;;
        --quiet)            QUIET="1"; shift                ;;
        *)                  usage                           ;;
    esac

    shift

done

function _print() {
    if [[ "${quiet}" == "1" ]]; then return;
    else echo -e "[$(date "+%Y-%m-%d %H:%M:%S")] $(printf "[%5s]" "${1}") ${_message}"; fi
}
function die () { local _message="${1} Exiting ..."; echo "$(_print ERROR)"; exit 1; }
function error () { local _message="${1}"; echo "$(_print ERROR)"; }
function info () { local _message="${1}"; echo "$(_print INFO)"; }
function debug () { local _message="${1}"; echo "$(_print DEBUG)"; }

# Usage: if is_not_empty "${FOURTYTWO}"; then ...
function is_dir() { if [[ -d "$1" ]]; then return 0; fi; return 1; }
function is_file() { if [[ -f "$1" ]]; then return 0; fi; return 1; }
function is_empty() { if [[ -z "$1" ]]; then return 0; fi; return 1; }
function is_not_empty() { if [[ -n "$1" ]]; then return 0; fi; return 1; }

# ---

info "Running script: $0 $* ..."

debug "Mode              : ${MODE}"
debug "Host/Client name  : ${NAME}"
debug "Host IP           : ${HOST_IP}"
debug "Target directory  : ${TARGET_DIR}"
debug "Expiration        : ${EXPIRATION_DAYS}"

[[ "${MODE}" == "ca" ]] && debug "CA subject string : ${CA_SUBJECT_STR}"

if is_empty "${MODE}" || [[ "${MODE}" != "ca" ]] && is_empty "${NAME}" || is_empty "${PASSWORD}" || is_empty "${TARGET_DIR}"; then
    error "Bad usage!"
    usage
fi

function createCA {
    info "Start: CA certificates ..."

    openssl genrsa \
        -aes256 \
        -passout pass:${PASSWORD} \
        -out "${TARGET_DIR}/ca-key.pem" \
        4096 && \

    openssl req \
        -passin pass:${PASSWORD} \
        -new \
        -x509 \
        -days ${EXPIRATION_DAYS} \
        -key "${TARGET_DIR}/ca-key.pem" \
        -sha256 \
        -out "${TARGET_DIR}/ca.pem" \
        -subj "${CA_SUBJECT_STR}" || exit 1

    chmod 0400 "${TARGET_DIR}/ca-key.pem"
    chmod 0444 "${TARGET_DIR}/ca.pem"

    info "Hurray! Certificates successfuly created."

    info "Result files:\n"
    info "  ${TARGET_DIR}/ca-key.pem"
    info "  ${TARGET_DIR}/ca.pem"

    info "End: CA certificates"
}

function checkCAFilesExist {
        is_file "${TARGET_DIR}/ca.pem" && is_file "${TARGET_DIR}/ca-key.pem" && return
        die "Files ${TARGET_DIR}/ca.pem and ${TARGET_DIR}/ca-key.pem doesn't exist! You need to create CA certificates first by running script first with '--mode ca' option."
}

function createServerCert {
    info "Start: Server certificates ..."

    checkCAFilesExist

    if is_empty "${HOST_IP}"; then
        IP_STRING=""
    else
        IP_STRING=",IP:${HOST_IP}"
    fi

    openssl genrsa \
        -out "${TARGET_DIR}/server-key.pem" \
        4096 && \
        openssl req \
        -subj "/CN=${NAME}" \
        -new \
        -key "${TARGET_DIR}/server-key.pem" \
        -out "${TARGET_DIR}/server.csr" && \

    echo "subjectAltName = DNS:${NAME}$IP_STRING" > "${TARGET_DIR}/extfile.cnf" && \

    openssl x509 \
        -passin pass:${PASSWORD} \
        -req \
        -days ${EXPIRATION_DAYS} \
        -in "${TARGET_DIR}/server.csr" \
        -CA "${TARGET_DIR}/ca.pem" \
        -CAkey "${TARGET_DIR}/ca-key.pem" \
        -CAcreateserial \
        -out "${TARGET_DIR}/server-cert.pem" \
        -extfile "${TARGET_DIR}/extfile.cnf" || exit 1

    rm "${TARGET_DIR}/server.csr" "${TARGET_DIR}/extfile.cnf" "${TARGET_DIR}/ca.srl"

    chmod 0400 "${TARGET_DIR}/server-key.pem"
    chmod 0444 "${TARGET_DIR}/server-cert.pem"

    info "Hurray! Certificates successfuly created."

    info "Result files:\n"
    info "  ${TARGET_DIR}/server-key.pem"
    info "  ${TARGET_DIR}/server-cert.pem"

    info "End: Server certificates"
}

function createClientCert {

    info "Start: Client certificates ..."

    checkCAFilesExist

    openssl genrsa \
        -out "${TARGET_DIR}/client-key.pem" \
        4096 && \

    openssl req \
        -subj "/CN=${NAME}" \
        -new \
        -key "${TARGET_DIR}/client-key.pem" \
        -out "${TARGET_DIR}/client.csr" && \

    echo "extendedKeyUsage = clientAuth" > "${TARGET_DIR}/extfile.cnf" && \

    openssl x509 \
        -passin pass:${PASSWORD} \
        -req \
        -days ${EXPIRATION_DAYS} \
        -in "${TARGET_DIR}/client.csr" \
        -CA "${TARGET_DIR}/ca.pem" \
        -CAkey "${TARGET_DIR}/ca-key.pem" \
        -CAcreateserial \
        -out "${TARGET_DIR}/client-cert.pem" \
        -extfile "${TARGET_DIR}/extfile.cnf" || exit 1

    rm "${TARGET_DIR}/client.csr" "${TARGET_DIR}/extfile.cnf" "${TARGET_DIR}/ca.srl"

    chmod 0400 "${TARGET_DIR}/client-key.pem"
    chmod 0444 "${TARGET_DIR}/client-cert.pem"

    mv "${TARGET_DIR}/client-key.pem" "${TARGET_DIR}/client-${NAME}-key.pem"
    mv "${TARGET_DIR}/client-cert.pem" "${TARGET_DIR}/client-${NAME}-cert.pem"

    info "Hurray! Certificates successfuly created."

    info "Result files:\n"
    info "  ${TARGET_DIR}/client-${NAME}-key.pem"
    info "  ${TARGET_DIR}/client-${NAME}-cert.pem"

    info "End: Client certificates ..."
}

[[ ! -d "${TARGET_DIR}" ]] && mkdir -p "${TARGET_DIR}"

case ${MODE} in
    ca)     createCA            ;;
    server) createServerCert    ;;
    client) createClientCert    ;;
    *)      usage               ;;
esac