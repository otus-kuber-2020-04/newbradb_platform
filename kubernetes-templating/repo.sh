#!/bin/bash
helm repo add templating https://chartmuseum.35.204.4.205.nip.io/hartrepo/library
helm push --username admin --password Harbor12345  frontend/ templating
helm push --username admin --password Harbor12345  hipster-shop/ templating
