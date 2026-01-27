# 1. CAPA DE DATOS Y ALMACENAMIENTO
module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  environment  = var.environment
}

# 2. CAPA DE SEGURIDAD (IAM Y POLÍTICAS)
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  environment  = var.environment

  # Inyectamos dependencias de Storage para crear los permisos
  frontend_bucket_id     = module.storage.frontend_bucket_id
  frontend_bucket_arn    = module.storage.frontend_bucket_arn
  tickets_bucket_arn     = module.storage.tickets_bucket_arn
  reservations_table_arn = module.storage.reservations_table_arn
  inventory_table_arn    = module.storage.inventory_table_arn
}

# 3. CAPA DE LÓGICA DE NEGOCIO (API Y LAMBDA)
module "compute" {
  source       = "./modules/compute"
  project_name = var.project_name
  environment  = var.environment

  # Inyectamos el Rol de Security y los Nombres de las tablas de Storage
  lambda_ingestion_role_arn = module.security.lambda_ingestion_role_arn
  inventory_table_name      = module.storage.inventory_table_name
  reservations_table_name   = module.storage.reservations_table_name
}