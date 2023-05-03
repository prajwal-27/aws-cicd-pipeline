resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "pipeline-artifacts-prajwal"
  #acl    = "private"
    lifecycle {
    prevent_destroy = false
  }
} 

resource "aws_s3_bucket_acl" "s3_acl_codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.example]
}
# puting some ownership control to s3 bucket object default ["BucketOwnerPreferred", "ObjectWriter"]
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    object_ownership = "ObjectWriter"
  }
}
