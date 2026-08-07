terraform {
  required_version = ">= 1.0"
}

provider "kubernetes" {
  config_path = kind_cluster.default.kubeconfig_path
}
