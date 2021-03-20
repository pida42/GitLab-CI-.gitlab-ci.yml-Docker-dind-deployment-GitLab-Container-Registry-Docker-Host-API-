#!/usr/bin/env python

import requests

URL = 'https://docker1.aws.server.tld:2376/containers/json?all=1'

CA_CERT = '/home/marvin42/.docker/ca.pem'
CLIENT_CERT = '/home/marvin42/.docker/cert.pem'
CLIENT_KEY = '/home/marvin42/.docker/key.pem'


def get_container_list():
    r = requests.get(url=URL, cert=(CLIENT_CERT, CLIENT_KEY), verify=CA_CERT)
    return r.json()


def print_containers_data():
    for c in get_container_list():
        print('Container %s (%s, %s)]' % (c['Names'][0], c['Id'], c['Status']))


print_containers_data()
