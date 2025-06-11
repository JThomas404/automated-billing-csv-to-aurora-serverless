resource "random_id" "s3_bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "boto3_billing_processed" {
  bucket        = "${var.bucket_name_processed}-${random_id.s3_bucket_suffix.hex}"
  force_destroy = true

  tags = var.tags
}
