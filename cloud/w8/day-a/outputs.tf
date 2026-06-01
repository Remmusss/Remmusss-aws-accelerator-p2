output "project_label" {
  description = "Generated label"
  value       = random_pet.project_label.id
}

output "summary_file_path" {
  description = "Path to the generated local summary file."
  value       = local_file.day_a_summary.filename
}

output "tags" {
  description = "Resolved tag map."
  value       = var.tags
}
