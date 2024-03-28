resource "aws_s3_bucket" "assets" {
  bucket_prefix = "${local.name}-assets-"
  force_destroy = true
  tags = {
    "app.tier" = "storage"
    yor_trace  = "923aaa10-a45b-4d50-b644-b9a4ba663fe7"
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
