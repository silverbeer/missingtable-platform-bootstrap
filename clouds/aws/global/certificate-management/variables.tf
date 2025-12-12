variable "domain_name" {
  description = "The domain name to create a certificate for"
  type        = string
  default     = "missingtable.com"
}

variable "letsencrypt_email" {
  description = "The email address to use for Let's Encrypt"
  type        = string
}
