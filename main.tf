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
  reservation_queue_arn  = module.messaging.reservation_queue_arn
}

# 3. CAPA DE MENSAJERÍA (EVENTOS Y COLAS)
module "messaging" {
  source       = "./modules/messaging"
  project_name = var.project_name
  environment  = var.environment
}

# 4. CAPA DE LÓGICA DE NEGOCIO (API Y LAMBDA)
module "compute" {
  source       = "./modules/compute"
  project_name = var.project_name
  environment  = var.environment

  # Inyectamos el Rol de Security, Tablas de Storage y el Bus de Messaging
  lambda_ingestion_role_arn = module.security.lambda_ingestion_role_arn
  inventory_table_name      = module.storage.inventory_table_name
  reservations_table_name   = module.storage.reservations_table_name
  event_bus_name            = module.messaging.event_bus_name 
  reservation_queue_arn     = module.messaging.reservation_queue_arn # <-- Nueva conexión
}