variable "project_name" {
  type        = string
  description = "Nombre del proyecto pasado desde la raíz"
}

variable "environment" {
  type        = string
  description = "Ambiente pasado desde la raíz"
}

variable "web_acl_id" {
  type    = string
  default = null
}