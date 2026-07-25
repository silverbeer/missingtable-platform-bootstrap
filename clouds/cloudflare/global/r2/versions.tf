terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # Cloudflare provider v5 is an auto-generated rewrite — resource names and
    # schemas differ from older v4 examples. Pin to v5 and verify against the
    # current provider docs. https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
