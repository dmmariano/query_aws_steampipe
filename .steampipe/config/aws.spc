connection "aws_apppacienteprd" {
  plugin      = "aws"
  profile     = "787345280606_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_datalakeprd" {
  plugin      = "aws"
  profile     = "308676119841_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_cockpitprd" {
  plugin      = "aws"
  profile     = "978569075048_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_cscprd" {
  plugin      = "aws"
  profile     = "800735908691_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_backbonedigitalprd" {
  plugin      = "aws"
  profile     = "413850945308_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_commandcenterprd" {
  plugin      = "aws"
  profile     = "007597074154_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_autcentcirurgicoprd" {
  plugin      = "aws"
  profile     = "802274005479_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_carteirizacaospprd" {
  plugin      = "aws"
  profile     = "654074949840_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_all" {
  type        = "aggregator"
  plugin      = "aws"
  connections = ["aws_*"]
}
