resource "kubernetes_deployment" "web" {
  metadata {
    name = "web"
  }
  spec {
    replicas = "${var.web_replicas}"
    selector {
      match_labels {
        app = "web"
      }
    }
    template {
      metadata {
        labels {
          app = "web"
        }
      }
      spec {
        volume {
          name = "codecov-yml"
          secret {
            secret_name = "${kubernetes_secret.codecov-yml.metadata.0.name}"
          }
        }
        container {
          name  = "web"
          image = "codecov/enterprise:v4.4.4"
          args  = ["web"]
          port {
            container_port = 5000
          }
          env {
            name = "STATSD_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          env {
            name = "MINIO_PORT_9000_TCP_ADDR"
            value = "minio"
          }
          env {
            name = "MINIO_PORT_9000_TCP_PORT"
            value = "9000"
          }
          env {
            name = "SERVICES__DATABASE_URL"
            value = "postgres://${google_sql_user.codecov.name}:${google_sql_user.codecov.password}@127.0.0.1:5432/${google_sql_database.codecov.name}"
          }
          env {
            name = "SERVICES__REDIS_URL"
            value = "redis://${google_redis_instance.codecov.host}:${google_redis_instance.codecov.port}"
          }
          env {
            name = "SERVICES__MINIO__ACCESS_KEY_ID"
            value = "${var.minio_access_key}"
          }
          env {
            name = "SERVICES__MINIO__SECRET_ACCESS_KEY"
            value = "${var.minio_secret_key}"
          }
          env {
            name = "SERVICES__MINIO__BUCKET"
            value = "${google_storage_bucket.minio.name}"
          }
          resources {
            limits {
              cpu    = "256m"
              memory = "512M"
            }
            requests {
              cpu    = "32m"
              memory = "64M"
            }
          }
          readiness_probe {
            http_get {
              path = "/login"
              port = "5000"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
          image_pull_policy = "Always"
          volume_mount {
            name = "codecov-yml"
            read_only = "true"
            mount_path = "/config"
          }
        }
        volume {
          name = "postgres-service-account"
          secret {
            secret_name = "${kubernetes_secret.postgres-service-account.metadata.0.name}"
          }
        }
        container {
          name = "cloudsql-proxy"
          image = "gcr.io/cloudsql-docker/gce-proxy:1.11"
          command = [
            "/cloud_sql_proxy",
            "-instances=${var.gcloud_project}:${var.region}:${google_sql_database_instance.codecov.name}=tcp:5432",
            "-credential_file=/creds/postgres-credentials.json"
          ]
          security_context {
            run_as_user = "2"
            allow_privilege_escalation = "false"
          }
          volume_mount {
            name = "postgres-service-account"
            mount_path = "/creds"
            read_only = "true"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "web" {
  metadata {
    name = "web"
  }
  spec {
    port {
      protocol    = "TCP"
      port        = "5000"
      target_port = "5000"
    }
    selector {
      app = "web"
    }
  }
}
