<h1 align="center">
  <br>
  Squash Operator
</h1>

### Overview

An Operator is a Kubernetes `controller` that deploys and manages application’s resources and services in Kubernetes. 

In Kubernetes each of your application’s resources can be defined by a **C**ustom **R**esource **D**efinition (**CRD**). **CRD**’s uniquely identifies your applications custom resources by its `Group`, `Version` and `Kind` in a Kubernetes cluster. Once the CRD’s have been created, you would then create an instance of the **C**ustom **R**esource, or **CR**, with a unique name.


<h1 align="center">
    <img src="images/application Resources.png">
</h1>


Based on the [User Guide][User Guide]  which walks through an example of building a simple memcached-operator powered by Ansible tools and librairies provided by the Operator SDK I decided to build my own ***Squash Ansible Operator***. 

I'm explaining here how to create an ansible Operator but if you want just to test the `Squash Operator` you can clone the project and go to the [Deploy the squash-operator](https://github.com/dwojciec/squash-operator#deploy-the-squash-operator) section


## Create a new operator
```
$GOPATH/bin/operator-sdk --version
operator-sdk version 0.0.6+git
$ mkdir -p -p $GOPATH/src/github.com/squash-operator/
$ cd $GOPATH/src/github.com/squash-operator/
```

The **[Operator SDK][operatorsdk]** provides an option to create an Ansible Operator. An Ansible Operator leverages the full power of Ansible and it does not require the knowledge or the experience of any other programming language like GO or java. You have just write some Ansible code and edit a few YAML file to get your Operator up and running.


```

$ $GOPATH/bin/operator-sdk new squash-operator --api-version=app.example.com/v1alpha1 --kind=Squash --type=ansible
Create squash-operator/tmp/init/galaxy-init.sh
Create squash-operator/tmp/build/Dockerfile
Create squash-operator/tmp/build/test-framework/Dockerfile
Create squash-operator/tmp/build/go-test.sh
Rendering Ansible Galaxy role [squash-operator/roles/Squash]...
Cleaning up squash-operator/tmp/init
Create squash-operator/watches.yaml
Create squash-operator/deploy/rbac.yaml
Create squash-operator/deploy/crd.yaml
Create squash-operator/deploy/cr.yaml
Create squash-operator/deploy/operator.yaml
Run git init ...
Initialized empty Git repository in /Users/dwojciec/go/src/github.com/squash-operator/squash-operator/.git/
Run git init done

$ cd squash-operator
$ tree
.
├── deploy
│   ├── cr.yaml
│   ├── crd.yaml
│   ├── operator.yaml
│   └── rbac.yaml
├── roles
│   └── Squash
│       ├── README.md
│       ├── defaults
│       │   └── main.yml
│       ├── files
│       ├── handlers
│       │   └── main.yml
│       ├── meta
│       │   └── main.yml
│       ├── tasks
│       │   └── main.yml
│       ├── templates
│       ├── tests
│       │   ├── inventory
│       │   └── test.yml
│       └── vars
│           └── main.yml
├── tmp
│   └── build
│       ├── Dockerfile
│       ├── go-test.sh
│       └── test-framework
│           └── Dockerfile
└── watches.yaml

14 directories, 16 files
```

<h1 align="center">
    <img src="images/ansible operator pttern.png">
</h1>
<h1 align="center">
    <img src="images/squash resource.png" >
</h1>

Once all the code generated by the Operator SDK. I have to go to the deploy directory to check the content of all files.

```
$ pwd
/Users/dwojciec/go/src/github.com/squash-operator/squash-operator/deploy
$ tree
.
├── cr.yaml
├── crd.yaml
├── operator.yaml
└── rbac.yaml

0 directories, 4 files
```
I updated **rbac.yaml** with the code [here](https://raw.githubusercontent.com/dwojciec/squash-operator/master/deploy/rbac.yaml). Check the content of the **rbac.yaml** file because by default the namespace used is the *default* one for ***ClusterRoleBinding*** and maybe you want to use a different project to deploy your application. In my case I will deploy my Operator in a project I will create named ***operator-squash*** . I added and created a sa.yaml file to define **ServiceAccount** for my application ***squash-operator***.

## Building the Squash Ansible Role

The first thing to do is to modify the generated Ansible role under `roles/Squash`. This Ansible Role controls the logic that is executed when a resource is modified.
I updated the empty file `roles/Squash/tasks/main.yaml` with :

```

---
# tasks file for squash-server
- name: start squash-server
 k8s:
   definition:
     kind: Deployment
     apiVersion: apps/v1
     metadata:
       name: squash-server
       namespace: '{{ meta.namespace }}'
     spec:
       selector:
         matchLabels:
           app: squash-server
       template:
         metadata:
           labels:
             app: squash-server
         spec:
           containers:
           - name: squash-server
             image: soloio/squash-server:v0.2.1

- name: start squash-client
 k8s:
   state: present
   definition: "{{ lookup('template', '/opt/ansible/k8s/squash-client.yml') | from_yaml  }}"

- name: create squash-server service
 k8s:
   state: present
   definition: "{{ lookup('template', '/opt/ansible/k8s/squash-server-svc.yml') | from_yaml  }}"

```

This Ansible task is creating a Kubernetes deplyment using [k8s][k8s] module. The [k8s][k8s] Ansible module allows you to easily interact with the kubernetes resources idempotently. 

### Update of the Dockerfile (tmp/build/Dockerfile)

Inside the `roles/Squash/tasks/main.yaml` file I’m using multiples external files (template), like '/opt/ansible/k8s/squash-server-svc.yml'  and to consume this files I updated the Dockerfile to add them.
From ...`squash-operator/tmp/build/Dockerfile`

```
FROM quay.io/water-hole/ansible-operator

COPY roles/ ${HOME}/roles/
COPY watches.yaml ${HOME}/watches.yaml
```
to

```

FROM quay.io/water-hole/ansible-operator
COPY k8s/ ${HOME}/k8s/
COPY roles/ ${HOME}/roles/
COPY playbook.yaml ${HOME}/playbook.yaml
COPY watches.yaml ${HOME}/watches.yaml
```

### Update of  the watches.yaml

By default the operator SDK generated `watches.yaml` file watches Squash resource events and executes Ansible Role Squash. 

```
$ cat watches.yaml
---
- version: v1alpha1
  group: app.example.com
  kind: Squash
  role: /opt/ansible/roles/Squash
```
I decided to use the **Playbook** option by specifying a `playbook.yaml` file inside `watch.yaml` which will configure the operator to use this specified path when launching ansible-runner with the Ansible Playbook.

```
---
- version: v1alpha1
  group: app.example.com
  kind: Squash
  playbook: /opt/ansible/playbook.yaml
  finalizer:
    name: finalizer.app.example.com
    vars:
      sentinel: finalizer_running
```

### Build and run the operator
Before running the squash operator, Kubernetes needs to know about the new CRD the operator will be watching.

### Deploy the Custom Ressource Definition:
```
$ oc new-project operator-squash
$ kubectl create -f deploy/crd.yaml
```

### Build the squash-operator image and push it to a registry:
```

$ $GOPATH/bin/operator-sdk build quay.io/dwojciec/squash-operator:v0.0.1
$ docker push quay.io/dwojciec/squash-operator:v0.0.1
```
Kubernetes deployment manifests are generated in `deploy/operator.yaml`. The deployment image in this file needs to be modified from the placeholder **REPLACE_IMAGE** to the previous built image. Edit `deploy/operator.yaml` file and change :

```

spec:
      containers:
        - name: squash-operator
          image: REPLACE_IMAGE
          ports:
By
spec:
      containers:
        - name: squash-operator
          image: quay.io/dwojciec/squash-operator:v0.0.1
          ports:
```

### Deploy the squash-operator:
```
$ kubectl create -f deploy/rbac.yaml
$ kubectl create -f deploy/operator.yaml
$ kubectl create -f deploy/sa.yaml

```
Before testing squash you have to run :
```
 oc adm policy add-scc-to-user privileged -z squash-client
 oc expose svc squash-server
```

## References to go further:
* [An introduction to Ansible Operators in Kubernetes](https://opensource.com/article/18/10/ansible-operators-kubernetes)
* [Memcached Ansible Operator Demo](https://opensource.com/article/18/10/ansible-operators-kubernetes)

## Squash tool
* [SQUASH - The debugger for microservices](https://github.com/solo-io/squash)

 [User Guide]:https://github.com/operator-framework/operator-sdk/blob/master/doc/ansible/user-guide.md
 [k8s]:https://docs.ansible.com/ansible/2.6/modules/k8s_module.html
 [operatorsdk]:https://github.com/operator-framework/operator-sdk
 
 
 Test sync github 1
 
