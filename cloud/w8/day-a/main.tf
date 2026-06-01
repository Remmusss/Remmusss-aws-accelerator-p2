locals {
  summary_lines = concat(
    [
      "# Terraform Day A Summary",
      "",
      "- Project: ${var.project_name}",
      "- Owner: ${var.owner}",
      "- Environment: ${var.environment}",
      "- Generated label: ${random_pet.project_label.id}",
      "",
      "## Tags",
      "",
    ],
    [for key, value in var.tags : "- ${key}: ${value}"]
  )

  summary_content = "${join("\n", local.summary_lines)}\n"
}

resource "random_pet" "project_label" {
  prefix = var.environment
  length = 2
}

resource "local_file" "day_a_summary" {
  filename = "${path.module}/generated/day-a-summary.md"
  content  = local.summary_content
}
