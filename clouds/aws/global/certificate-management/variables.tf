variable "domain_name" {
  description = "The domain name to create a certificate for"
  type        = string
  default     = "missingtable.com"
}

variable "letsencrypt_email" {
  description = "The email address to use for Let's Encrypt"
  type        = string
}

variable "resend_dkim_value" {
  description = "DKIM TXT record value provided by Resend after domain verification (resend.com/domains)"
  type        = string
}
