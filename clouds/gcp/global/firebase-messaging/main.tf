# =============================================================================
# COMMON
# =============================================================================

data "google_project" "this" {
  project_id = var.project_id
}

# Billed project the budget watches. The Firebase project has no billing account
# (Spark plan), so it cannot incur charges at all.
data "google_project" "budget" {
  project_id = var.budget_project_id
}

# =============================================================================
# APIS - Firebase + FCM (all no-cost)
# =============================================================================

locals {
  services = toset([
    "firebase.googleapis.com",
    "fcm.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "iam.googleapis.com",
  ])
}

resource "google_project_service" "services" {
  for_each = local.services

  project = var.project_id
  service = each.value

  # Turning an API off on destroy can break things outside this stack.
  disable_on_destroy = false
}

# =============================================================================
# FIREBASE - project + Android apps
# =============================================================================

# Dedicated Firebase project with no billing account: Spark plan, so nothing in
# it can be charged. Created in the Firebase console and imported (projects.addFirebase
# returned a bare 403 for missing-table). See the import block below.
import {
  to = google_firebase_project.this
  id = "projects/${var.project_id}"
}

resource "google_firebase_project" "this" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.services]
}

# One app per distinct applicationId: FCM tokens are scoped to the package, so
# the local flavor (.local suffix) needs its own registration to receive pushes.
resource "google_firebase_android_app" "apps" {
  provider = google-beta
  for_each = var.android_apps

  project      = var.project_id
  package_name = each.value.package_name
  display_name = each.value.display_name

  depends_on = [google_firebase_project.this]
}

data "google_firebase_android_app_config" "apps" {
  provider = google-beta
  for_each = google_firebase_android_app.apps

  project = var.project_id
  app_id  = each.value.app_id
}

# =============================================================================
# FCM SENDER - service account the backend uses for FCM HTTP v1
# =============================================================================

resource "google_service_account" "fcm_sender" {
  project      = var.project_id
  account_id   = "fcm-sender"
  display_name = "FCM sender (missing-table backend)"
  description  = "Sends Android push via FCM HTTP v1 (SB-1463/SB-1465). Key is created out-of-band by scripts/set-fcm-aws-secret.sh, never in Terraform state."
}

# Least-privilege predefined role that grants cloudmessaging.messages.create.
# The only other one, roles/cloudmessaging.editor, carries the identical
# permission set; there is no narrower predefined "sender" role.
resource "google_project_iam_member" "fcm_sender" {
  project = var.project_id
  role    = "roles/firebasecloudmessaging.admin"
  member  = google_service_account.fcm_sender.member
}

# Deliberately NO google_service_account_key: its private key would sit in
# plaintext in the S3 state. See scripts/set-fcm-aws-secret.sh.

# =============================================================================
# BUDGET - alert on any spend (FCM should cost $0)
# =============================================================================

resource "google_project_service" "budgets" {
  project            = var.budget_project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

moved {
  from = google_project_service.services["billingbudgets.googleapis.com"]
  to   = google_project_service.budgets
}

resource "google_billing_budget" "this" {
  provider        = google.budget
  billing_account = var.billing_account
  display_name    = "${var.budget_project_id} - any spend"

  budget_filter {
    projects = ["projects/${data.google_project.budget.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  # No all_updates_rule: the provider (v8) requires a Pub/Sub topic or a
  # monitoring channel inside it, and omitting it keeps the API default -
  # threshold emails to the billing account's admins/users (default IAM
  # recipients), which is all we want.

  depends_on = [google_project_service.budgets]
}
