FROM quay.io/water-hole/ansible-operator
COPY k8s/ ${HOME}/k8s/
COPY roles/ ${HOME}/roles/
COPY playbook.yaml ${HOME}/playbook.yaml
COPY watches.yaml ${HOME}/watches.yaml
