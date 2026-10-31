# Auth is gcloud ADC (`gcloud auth application-default login`). The Firebase
# Management and Billing Budgets APIs reject end-user ADC calls that have no
# quota project, so bill API quota to the project itself.
provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

# Budget lives on the billing account; bill its API quota to the billed project
# (billingbudgets is enabled there, not on the unbilled Firebase project).
provider "google" {
  alias                 = "budget"
  project               = var.budget_project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.budget_project_id
}
