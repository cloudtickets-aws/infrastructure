import json
import os
import boto3
from datetime import datetime

# Inicializar clientes (se reutilizan entre invocaciones)
dynamodb = boto3.resource('dynamodb')
events = boto3.client('events')

# Variables de entorno inyectadas por Terraform
INVENTORY_TABLE = os.environ['INVENTORY_TABLE']
EVENT_BUS_NAME = os.environ['EVENT_BUS_NAME']

def handler(event, context):
    try:
        # 1. Parsear datos de entrada desde el cuerpo de la petición (API Gateway)
        body = json.loads(event.get('body', '{}'))
        seat_id = body.get('seat_id')
        event_id = body.get('event_id', 'AWS_CLOUD_TOUR') # Valor por defecto para pruebas
        email = body.get('email')
        user_id = body.get('user_id', 'user_default')

        if not seat_id or not email:
            return response(400, {"error": "Asiento y email son requeridos"})

        # 2. VALIDACIÓN: ¿Está el asiento disponible en DynamoDB?
        table = dynamodb.Table(INVENTORY_TABLE)
        
        # CORRECCIÓN: Usamos las llaves exactas de Terraform (Case Sensitive)
        item = table.get_item(Key={
            'EventID': event_id, 
            'SeatID': seat_id
        })
        
        # Validar si el ítem existe y si su estado es exactamente 'AVAILABLE'
        if 'Item' not in item or item['Item'].get('status') != 'AVAILABLE':
            return response(409, {"error": "El asiento no existe o ya no está disponible"})

        # 3. ÉXITO: Publicar evento al Bus de EventBridge
        # Generamos un ID de reserva temporal para seguimiento
        reservation_id = f"res-{datetime.now().strftime('%m%d-%H%M%S')}"
        
        event_payload = {
            "reservationId": reservation_id,
            "eventId": event_id,
            "seatId": seat_id,
            "userEmail": email,
            "userId": user_id,
            "status": "PENDING"
        }

        # Enviamos el sobre al (EventBridge)
        events.put_events(
            Entries=[{
                'Source': 'com.cloudtickets.ingestion',
                'DetailType': 'reservation.requested',
                'Detail': json.dumps(event_payload),
                'EventBusName': EVENT_BUS_NAME
            }]
        )

        return response(201, {
            "message": "Solicitud recibida. Procesando reserva...",
            "reservationId": reservation_id,
            "seat": seat_id,
            "status": "PENDING"
        })

    except Exception as e:
        print(f"ERROR: {str(e)}")
        return response(500, {"error": "Error interno del sistema de ingesta"})

def response(status_code, body):
    """Estructura de respuesta estandarizada para API Gateway"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*" # Habilita CORS para el Frontend
        },
        "body": json.dumps(body)
    }