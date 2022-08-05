terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubectl = {
        source  = "gavinbunney/kubectl"
        version = ">= 1.7.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
  
}

resource "digitalocean_kubernetes_cluster" "k8s_iniciativa" {
  name   = var.k8s_name
  region = var.region
  version = "1.23.9-do.0"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    node_count = 2

  }
}

resource "digitalocean_kubernetes_node_pool" "node_premium" {
  cluster_id = digitalocean_kubernetes_cluster.k8s_iniciativa.id

  name       = "premium"
  size       = "s-4vcpu-8gb"
  node_count = 2

 }

variable "do_token" {}
variable "k8s_name" {}
variable "region" {}

output "kube_endpoint" {
  value = digitalocean_kubernetes_cluster.k8s_iniciativa.endpoint
}

resource "local_file" "kube_config" {
    content  = digitalocean_kubernetes_cluster.k8s_iniciativa.kube_config.0.raw_config
    filename = "kube_config.yaml"
}


resource "kubectl_manifest" "deployment" {
    yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgre
spec:
  selector:
    matchLabels:
      app: postgre
  template:
    metadata:
      labels:
        app: postgre
    spec:
      containers:
        - name: postgre
          image: postgres:14.3
          ports:
            - containerPort: 5432
          env:
          - name: POSTGRES_PASSWORD
            value: "Kube#123"
          - name: POSTGRES_USER
            value: "kubenews"
          - name: POSTGRES_DB
            value: "kubenews"
---
apiVersion: v1
kind: Service
metadata:
  name: postgre
spec:
  selector:
    app: postgre
  ports:
  - port: 5432 
    targetPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubenews
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kubenews
  template:
    metadata:
      labels:
        app: kubenews
    spec:
      containers:
      - name: kubenews
        image: aocs/kube-news:v1
        env:
        - name: DB_DATABASE
          value: "kubenews"
        - name: DB_USERNAME
          value: "kubenews"
        - name: DB_PASSWORD
          value: "Kube#123"
        - name: DB_HOST
          value: "postgre"      
---
apiVersion: v1
kind: Service
metadata:
  name: kube-news
spec:
  selector:
    app: kubenews
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30000
  type: LoadBalancer
YAML
}