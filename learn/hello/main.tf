# My first OpenTofu configuration
# This creates a local file - no cloud needed!

resource "local_file" "hello" {
  content  = "Hello, ${var.greeting}!"
  filename = "${path.module}/${var.filename}"
}