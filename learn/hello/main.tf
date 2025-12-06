# My first OpenTofu configuration
# This creates a local file - no cloud needed!

resource "local_file" "hello" {
  content  = "Hello, OpenTofu!"
  filename = "${path.module}/hello.txt"
}