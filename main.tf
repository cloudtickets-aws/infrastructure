# Invocación del módulo de almacenamiento
module "storage" {
  source       = "./modules/storage"
  
  # Aquí pasamos los valores de la raíz al módulo
  project_name = var.project_name
  environment  = var.environment
}