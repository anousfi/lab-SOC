variable "region" {
  description = "Nom de la région"
  type        = string
  default     = "eu-west-3"
}

variable "availability_zone" {
  description = "zone de disponibilité"
  type        = string
  default     = "eu-west-3a"
}

variable "ami" {
  description = "type d'instance AWS"
  type        = string
  default     = "ami-007dcf089b8078f1a"
}

variable "instance_type1" {
  description = "type d'instance EC2 pour admin tasks et kibana"
  type        = string
  default     = "t3.small"
}

variable "instance_type2" {
  description = "type d'instance EC2 pour ElasticSearch"
  type        = string
  default     = "c7i-flex.large"
}

variable "common_tags" {
  type = map(string)

  default = {
    Environment = "lab"
    Project     = "ansible-lab"
  }
}