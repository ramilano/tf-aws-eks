module "loki_chunks_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  
  count = var.features["monitoring"] == "true" ? 1 : 0

  bucket = "${local.name}-${var.region}-loki-chunks"
  acl    = "private"
  control_object_ownership = true
  object_ownership = "BucketOwnerPreferred"

  attach_deny_insecure_transport_policy = true
  attach_deny_incorrect_encryption_headers = true
  attach_deny_unencrypted_object_uploads = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

}

module "loki_ruler_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  
  count = var.features["monitoring"] == "true" ? 1 : 0

  bucket = "${local.name}-${var.region}-loki-ruler"
  acl    = "private"
  control_object_ownership = true
  object_ownership = "BucketOwnerPreferred"

  attach_deny_insecure_transport_policy = true
  attach_deny_incorrect_encryption_headers = true
  attach_deny_unencrypted_object_uploads = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

}



module "tempo_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  
  count = var.features["monitoring"] == "true" ? 1 : 0

  bucket = "${local.name}-${var.region}-tempo-data"
  acl    = "private"
  control_object_ownership = true
  object_ownership = "BucketOwnerPreferred"

  attach_deny_insecure_transport_policy = true
  attach_deny_incorrect_encryption_headers = false
  attach_deny_unencrypted_object_uploads = false

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
