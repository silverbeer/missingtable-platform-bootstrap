variable "project_id" {
  description = "GCP project that hosts Firebase (FCM) for Missing Table. No billing account linked (Spark)."
  type        = string
}

variable "region" {
  description = "Default GCP region (nothing regional is created here; required by the provider)."
  type        = string
  default     = "us-east1"
}

variable "billing_account" {
  description = "Billing account ID the project is linked to (XXXXXX-XXXXXX-XXXXXX). Not a secret."
  type        = string
}

variable "android_apps" {
  description = "Android applicationIds to register with Firebase, keyed by a short name. One per distinct applicationId in missing-table-android app/build.gradle.kts (prod flavor + local flavor's .local suffix)."
  type = map(object({
    package_name = string
    display_name = string
  }))
}

variable "budget_amount_usd" {
  description = "Monthly budget (USD) for alerting. FCM is no-cost, so any spend at all is unexpected."
  type        = number
  default     = 1
}

variable "budget_project_id" {
  description = "Billed GCP project the budget alert watches. The Firebase project itself has no billing account (Spark plan)."
  type        = string
  default     = "missing-table"
}
