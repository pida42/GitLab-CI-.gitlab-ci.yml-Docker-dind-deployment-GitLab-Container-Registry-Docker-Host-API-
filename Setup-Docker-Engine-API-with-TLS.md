## Securing the API - TLS certificates

Download script `create-certs.sh` and make it executable:

```bash
curl <CREATE_CERTS_SCRIPT_URL> && chmod +x ./create-certs.sh
```

Create folder to store Docker certificates:

```bash
mkdir -p /etc/docker/ssl/certs
```

Set temporary variables:

```bash
export \
  CC_HOSTNAME=docker1.aws.server.tld \
  CC_HOST_IP=192.168.42.42 \
  CC_PASSWORD=1234 \
  CC_TARGET_DIR=/etc/docker/ssl/certs \
  CC_EXPIRATION_DAYS=3650 \
  CC_CA_SUBJECT_STR="/C=CZ/L=Prague/O=Company Name/CN=docker1.aws.server.tld/emailAddress=ssl@domain.tld"
```

### CA certificate

```bash
./create-certs.sh \
    --mode ca \
    --hostname ${CC_HOSTNAME} \
    --password ${CC_PASSWORD} \
    --target-dir ${CC_TARGET_DIR} \
    --expiration-days ${CC_EXPIRATION_DAYS} \
    --ca-subject "${CC_CA_SUBJECT_STR}"
```

### Server key

```bash
./create-certs.sh \
    --mode server \
    --hostname ${CC_HOSTNAME} \
    --host-ip ${CC_HOST_IP} \
    --password ${CC_PASSWORD} \
    --target-dir ${CC_TARGET_DIR} \
    --expiration-days ${CC_EXPIRATION_DAYS}
```

### Client key

```bash
./create-certs.sh \
    --mode client \
    --hostname ${CC_HOSTNAME} \
    --password ${CC_PASSWORD} \
    --target-dir ${CC_TARGET_DIR} \
    --expiration-days ${CC_EXPIRATION_DAYS}
```

## Enabling the API

Edit service `/etc/systemd/system/multi-user.target.wants/docker.service` file and add `-H tcp://0.0.0.0:2376` to `ExecStart` command:

```bash
# [...]
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock -H tcp://0.0.0.0:2376 --tlsverify --tlscacert=/etc/docker/ssl/certs/ca.pem --tlscert=/etc/docker/ssl/certs/server-cert.pem --tlskey=/etc/docker/ssl/certs/server-key.pem
# [...]
```

Reload daemon to load new configuration changes:

```bash
systemctl daemon-reload
```

Restart Docker service: 

```bash
systemctl restart docker.service
```

## Configuring the API client

Copy created client certificates to `~/.docker` directory (by default):

```bash
mkdir ~/.config
```

```bash
cp ${CC_TARGET_DIR}/client-${CC_HOSTNAME}-key.pem ~/.docker/key.pem
cp ${CC_TARGET_DIR}/client-${CC_HOSTNAME}-cert.pem ~/.docker/cert.pem
```

```bash
export DOCKER_HOST=${CC_HOSTIP}:2376
```

## Testing API

### CURL

```bash
curl -X GET http://localhost:2376/containers/json?all=1 | json_pp
```

### Python 

Example of Docker API client implementation in attached Python file `sources_docker-api-client-example.py`.
