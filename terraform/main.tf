module "kind_cluster" {
  source = "github.com/acvetochka/tf-modules//tf-kind-cluster?ref=cert_auth"
}

module "github_repository" {
  source                   = "github.com/den-vasyliev/tf-github-repository"
  github_owner             = var.GITHUB_OWNER
  github_token             = var.GITHUB_TOKEN
  repository_name          = var.FLUX_GITHUB_REPO
  public_key_openssh       = module.tls_private_key.public_key_openssh
  public_key_openssh_title = "flux"
}

module "tls_private_key" {
  source = "github.com/den-vasyliev/tf-hashicorp-tls-keys"
  algorithm = "RSA"
}

module "flux_bootstrap" {
  # source            = "./modules/flux-bootstrap"
  source            = "github.com/den-vasyliev/tf-fluxcd-flux-bootstrap?ref=kind_auth"
  # source            = "github.com/acvetochka/tf-modules//tf-fluxcd-flux-bootstrap?ref=kind_auth"
  github_repository = "${var.GITHUB_OWNER}/${var.FLUX_GITHUB_REPO}"
  private_key       = module.tls_private_key.private_key_pem
  config_host       = module.kind_cluster.endpoint
  config_client_key = module.kind_cluster.client_key
  config_ca         = module.kind_cluster.ca
  config_crt        = module.kind_cluster.crt
  github_token      = var.GITHUB_TOKEN
}

module "gke_cluster" {
  source         = "github.com/acvetochka/tf-google-gke-cluster"
  GOOGLE_REGION  = var.GOOGLE_REGION
  GOOGLE_PROJECT = var.GOOGLE_PROJECT
  GKE_NUM_NODES  = 2
}

module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_k8s_sa = true
  name                = "kustomize-controller"
  namespace           = "flux-system"
  project_id          = var.GOOGLE_PROJECT
  cluster_name        = "main"
  location            = var.GOOGLE_REGION
  annotate_k8s_sa     = true
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]
}

module "kms" {
  source             = "github.com/den-vasyliev/terraform-google-kms"
  project_id         = var.GOOGLE_PROJECT
  keyring            = "sops-flux"
  location           = "global"
  keys               = ["sops-key-flux"]
  prevent_destroy    = false
}

terraform {
  backend "gcs" {
    bucket = "tf-secret"
    prefix = "terraform/state"
  }
}