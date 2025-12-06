output "file_path" {
    description = "Path to the file"
    value       = local_file.hello.filename
}

output "file_content" {
    description = "Content of the file"
    value       = local_file.hello.content
}