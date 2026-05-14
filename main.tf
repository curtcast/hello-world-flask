terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Service Account for Cloud Run
resource "google_service_account" "flask_service_account" {
  account_id   = "flask-service-account"
  display_name = "Flask Service Account"
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "flask_repo" {
  location      = var.region
  repository_id = "flask-repo"
  description   = "Docker repository for Flask app"
  format        = "DOCKER"
}

# IAM: Allow Cloud Run service account to pull from Artifact Registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_reader" {
  repository = google_artifact_registry_repository.flask_repo.name
  location   = google_artifact_registry_repository.flask_repo.location
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.flask_service_account.email}"
}

# IAM: Allow service account to act as Cloud Run service agent
resource "google_project_iam_member" "cloud_run_service_agent" {
  project = var.project_id
  role    = "roles/run.serviceAgent"
  member  = "serviceAccount:${google_service_account.flask_service_account.email}"
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "flask_db" {
  name             = "flask-db-instance"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier      = "db-f1-micro"
    disk_size = 10

    ip_configuration {
      ipv4_enabled = true
    }
  }

  deletion_protection = false
}

# Cloud SQL Database
resource "google_sql_database" "flask_database" {
  name     = "flask_db"
  instance = google_sql_database_instance.flask_db.name
}

# Cloud SQL User
resource "google_sql_user" "flask_user" {
  name     = "flask_user"
  instance = google_sql_database_instance.flask_db.name
  password = random_password.db_password.result
}

# Random password for database user
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# IAM: Grant Cloud Run service account SQL client access
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.flask_service_account.email}"
}

# Cloud Run Service
resource "google_cloud_run_service" "flask_service" {
  name     = "flask-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.flask_service_account.email

      containers {
        image = var.image_url

        ports {
          container_port = 8080
        }

        env {
          name  = "DATABASE_URL"
          value = "postgresql://${google_sql_user.flask_user.name}:${random_password.db_password.result}@/${google_sql_database.flask_database.name}?host=/cloudsql/${google_sql_database_instance.flask_db.connection_name}"
        }

        env {
          name  = "INSTANCE_CONNECTION_NAME"
          value = google_sql_database_instance.flask_db.connection_name
        }

        env {
          name  = "PORT"
          value = "8080"
        }

        startup_probe {
          initial_delay_seconds = 30
          timeout_seconds       = 10
          period_seconds        = 10
          failure_threshold     = 3

          http_get {
            path = "/"
            port = 8080
          }
        }

        liveness_probe {
          initial_delay_seconds = 60
          period_seconds        = 10
          timeout_seconds       = 5
          failure_threshold     = 3

          http_get {
            path = "/"
            port = 8080
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_service_account.flask_service_account,
    google_artifact_registry_repository.flask_repo,
    google_sql_database.flask_database,
    google_sql_user.flask_user
  ]
}

# IAM: Allow public access to Cloud Run service
resource "google_cloud_run_service_iam_member" "all_users" {
  service  = google_cloud_run_service.flask_service.name
  location = google_cloud_run_service.flask_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Output the service URL
output "flask_service_url" {
  description = "The URL of the Flask Cloud Run service"
  value       = google_cloud_run_service.flask_service.status[0].url
}

# Output database connection info
output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.flask_db.connection_name
}

output "database_user" {
  description = "Database user"
  value       = google_sql_user.flask_user.name
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.flask_database.name
}
