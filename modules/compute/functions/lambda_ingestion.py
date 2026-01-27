import json
import os
import boto3
from datetime import datetime

# Inicializar los clientes de AWS fuera del handler para reutilizar conexiones
dynamodb = boto3.resource('dynamodb')
inventory_table = dynamodb.Table(os.environ['INVENTORY_TABLE'])
reservations_table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])

def handler(event, context):
    try:
        # 1. Parsear el cuerpo de la petición (desde React)
        body = json.loads(event.get('body', '{}'))
        email = body.get('email')
        seat_id = body.get('seat_id') # Ej: "A-1"
        event_id = body.get('event_id', 'CONCIERTO_2026') 

        # 2. Lógica simple: Intentar reservar en inventario
        # Aquí es donde en el futuro conectaremos la Step Function
        print(f"Recibida reserva para {email} en asiento {seat_id}")

        # 3. Respuesta exitosa
        return {
            "statusCode": 201,
            "headers": { "Content-Type": "application/json" },
            "body": json.dumps({
                "message": "Reserva recibida exitosamente",
                "seat": seat_id,
                "status": "PROCESSING"
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal Server Error"})
        }