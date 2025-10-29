variable "BASH_SOURCE" {
  type        = string
  description = "Path to the bash script source for stage-env user data."
  default     = "/etc/profile"
}

variable "color" {
  type        = string
  description = "Color code for output in stage-env user data script."
  default     = "\u001b[0;32m"
}

variable "message" {
  type        = string
  description = "Message to display in stage-env user data script."
  default     = "Staging environment setup in progress"
}

variable "NC" {
  type        = string
  description = "ANSI reset color code for stage-env user data script."
  default     = "\u001b[0m"
}

variable "BLUE" {
  type        = string
  description = "ANSI blue color code for stage-env user data script."
  default     = "\u001b[34m"
}

variable "GREEN" {
  type        = string
  description = "ANSI green color code for stage-env user data script."
  default     = "\u001b[32m"
}

variable "YELLOW" {
  type        = string
  description = "ANSI yellow color code for stage-env user data script."
  default     = "\u001b[33m"
}

variable "RED" {
  type        = string
  description = "ANSI red color code for stage-env user data script."
  default     = "\u001b[31m"
}