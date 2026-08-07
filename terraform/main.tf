terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4"
    }
  }
}

provider "kind" {}

# This resource creates the kind cluster
resource "kind_cluster" "default" {
  name           = "observability-lab"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      
      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\""
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
    }
  }
}

# Create a namespace for all observability tools
resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = "observability"
  }
  depends_on = [kind_cluster.default]
}

# Create a namespace for the application
resource "kubernetes_namespace_v1" "apps" {
  metadata {
    name = "apps"
  }
  depends_on = [kind_cluster.default]
}
