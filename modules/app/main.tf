terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.27" }
  }
}

resource "kubernetes_namespace" "app" {
  metadata { name = "demo" }
}

resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = { app = "nginx" }
  }
  spec {
    replicas = 3
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"
          port { container_port = 80 }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  spec {
    selector = { app = "nginx" }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
