output "arn_of_bucket" {
    description = "ARN of the bucket"
    value       = aws_s3_bucket.my_bucket.arn
}

output "region_of_bucket" {
    description = "Region of the bucket"
    value       = aws_s3_bucket.my_bucket.region
}