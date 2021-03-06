# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# {{$recipes := "../../templates/tfengine/recipes"}}

data = {
  parent_type     = "folder"
  parent_id       = "12345678"
  billing_account = "000-000-000"
  state_bucket    = "example-terraform-state"

  # Default locations for resources. Can be overridden in individual templates.
  bigquery_location = "us-east1"
  cloud_sql_region  = "us-central1"
  compute_region    = "us-central1"
  storage_location  = "us-central1"
}

template "devops" {
  recipe_path = "{{$recipes}}/devops.hcl"
  output_path = "./devops"
  data = {
    # TODO(user): Uncomment and re-run the engine after generated devops module has been deployed.
    # Run `terraform init` in the devops module to backup its state to GCS.
    # enable_gcs_backend = true

    admins_group = "example-folder-admins@example.com"

    project = {
      project_id = "example-devops"
      owners = [
        "group:example-devops-owners@example.com",
      ]
    }
  }
}

template "cicd" {
  recipe_path = "{{$recipes}}/cicd.hcl"
  output_path = "./cicd"
  data = {
    project_id = "example-devops"
    cloud_source_repository = {
      name    = "example"
      readers = [
        "group:readers@example.com"
      ]
      writers = [
        "user:foo@example.com"
      ]
    }

    # Required to create Cloud Scheduler jobs.
    scheduler_region = "us-east1"

    build_viewers = [
      "group:example-cicd-viewers@example.com",
    ]
    terraform_root = "terraform"
    envs = [
      {
        name        = "dev"
        branch_name = "dev"
        triggers = {
          validate = {}
          plan = {
            run_on_schedule = "0 12 * * *" # Run at 12 PM EST everyday
          }
          apply = {}
        }
        managed_dirs = [
          "devops", // NOTE: CICD service account can only update APIs on the devops project.
          "dev/data",
        ]
      },
      {
        name        = "prod"
        branch_name = "main"
        triggers = {
          validate = {}
          plan = {
            run_on_schedule = "0 12 * * *" # Run at 12 PM EST everyday
          }
          apply = {
            run_on_push = false # Do not auto run on push to branch
          }
        }
        managed_dirs = [
          "devops", // NOTE: CICD service account can only update APIs on the devops project.
          "audit",
          "prod/data",
        ]
      }
    ]
  }
}

template "audit" {
  recipe_path = "{{$recipes}}/audit.hcl"
  output_path = "./audit"
  data = {
    auditors_group = "example-auditors@example.com"
    project = {
      project_id = "example-audit"
    }
    logs_bigquery_dataset = {
      dataset_id = "1yr_folder_audit_logs"
    }
    logs_storage_bucket = {
      name = "7yr-folder-audit-logs"
    }
    additional_filters = [
      # Need to escape \ and " to preserve them in the final filter strings.
      "logName=\\\"logs/forseti\\\"",
      "logName=\\\"logs/application\\\"",
    ]
  }
}

# Dev data project for team 1.
template "project_data_dev" {
  recipe_path = "{{$recipes}}/project.hcl"
  output_path = "./dev/data"
  data = {
    project = {
      project_id = "example-data-dev"
      apis = [
        "compute.googleapis.com",
      ]
    }
    resources = {
      storage_buckets = [{
        name = "example-bucket-dev"
        labels = {
          env = "dev"
        }
      }]
    }
  }
}


# Prod data project for team 1.
template "project_data_prod" {
  recipe_path = "{{$recipes}}/project.hcl"
  output_path = "./prod/data"
  data = {
    project = {
      project_id         = "example-data-prod"
      is_shared_vpc_host = true
      apis = [
        "compute.googleapis.com",
      ]
    }
    resources = {
      storage_buckets = [{
        name = "example-bucket-prod"
        labels = {
          env = "prod"
        }
      }]
    }
  }
}
