resource "aws_s3_bucket" "assets" {
  bucket_prefix = "${local.name}-assets-"
  force_destroy = true
  tags = {
    "app.tier" = "storage"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_logging" "assets" {
  bucket        = aws_s3_bucket.assets.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/${aws_s3_bucket.assets.id}/"
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_bucket.json
}

data "aws_iam_policy_document" "assets_bucket" {
  statement {
    sid    = "ReadWrite"
    effect = "Allow"
    actions = [
      "s3:ListBucket*",
      "s3:Get*",
      "s3:PutObject*",
      "s3:DeleteObject*"
    ]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.bastion.arn,
        aws_iam_role.eks_node_group.arn
      ]
    }
    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*"
    ]
  }

  statement {
    sid    = "ReadOnly"
    effect = "Allow"
    actions = [
      "s3:ListBucket*",
      "s3:Get*"
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ecs_task.arn]
    }
    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*"
    ]
  }
}

resource "aws_s3_object" "images" {
  for_each     = fileset("files/img/", "*.png")
  bucket       = aws_s3_bucket.assets.id
  key          = "img/${each.value}"
  source       = "files/img/${each.value}"
  content_type = "image/png"
}

####################
## Logging Bucket ##

resource "aws_s3_bucket" "logs" {
  bucket_prefix = "${local.name}-logging-"
  force_destroy = true
  tags = {
    "app.tier" = "storage"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket.json
}

data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid     = "ELBLogs"
    effect  = "Allow"
    actions = ["s3:PutObject*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = ["${aws_s3_bucket.logs.arn}/*"]
  }

  statement {
    sid     = "S3Logs"
    effect  = "Allow"
    actions = ["s3:PutObject*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.logs.arn}/*"]
  }

  statement {
    sid    = "ReadOnly"
    effect = "Allow"
    actions = [
      "s3:ListBucket*",
      "s3:Get*"
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.bastion.arn]
    }
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
  }
}
