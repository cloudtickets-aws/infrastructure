import json
import os
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

# Inicializar clientes
dynamodb = boto3.resource('dynamodb')
events = boto3.client('events')

INVENTORY_TABLE = os.environ['INVENTORY_TABLE']
EVENT_BUS_NAME = os.environ['EVENT_BUS_NAME']

def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        seat_id = body.get('seat_id')
        event_id = body.get('event_id', 'AWS_CLOUD_TOUR')
        email = body.get('email')
        user_id = body.get('user_id', 'user_default')

        if not seat_id or not email:
            return response(400, {"error": "Asiento y email son requeridos"})

        table = dynamodb.Table(INVENTORY_TABLE)

        try:
            # --- 1. ATOMICIDAD ---
            # Intentamos marcar el asiento como ocupado solo si está AVAILABLE.
            # Esto evita que dos personas reserven el mismo asiento.
            table.update_item(
                Key={'EventID': event_id, 'SeatID': seat_id},
                UpdateExpression="SET #s = :res, #u = :user, #em = :email",
                ConditionExpression="#s = :avail",
                ExpressionAttributeNames={'#s': 'status', '#u': 'userId', '#em': 'userEmail'},
                ExpressionAttributeValues={
                    ':res': 'RESERVED',
                    ':avail': 'AVAILABLE',
                    ':user': user_id,
                    ':email': email
                }
            )
            
            # Si el update funciona, disparamos el evento
            send_event(event_id, seat_id, email, user_id)
            return response(201, {"message": "Reserva creada con éxito", "status": "RESERVED"})

        except ClientError as e:
            # Si la condición de "AVAILABLE" falla, revisamos por qué
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                
                # --- 2. IDEMPOTENCIA ---
                # Consultamos quién tiene la reserva actualmente
                actual_item = table.get_item(Key={'EventID': event_id, 'SeatID': seat_id}).get('Item', {})
                
                if actual_item.get('userId') == user_id:
                    # El usuario ya lo tenía reservado (es un reintento del mismo cliente)
                    return response(200, {"message": "Reserva confirmada previamente", "status": "RESERVED"})
                else:
                    # El asiento lo tiene alguien más
                    return response(409, {"error": "El asiento ya no está disponible"})
            raise e

    except Exception as e:
        print(f"ERROR: {str(e)}")
        return response(500, {"error": "Error interno del sistema"})

def send_event(event_id, seat_id, email, user_id):
    """Función auxiliar para limpiar el código principal"""
    reservation_id = f"res-{datetime.now().strftime('%m%d-%H%M%S')}"
    events.put_events(
        Entries=[{
            'Source': 'com.cloudtickets.ingestion',
            'DetailType': 'reservation.requested',
            'Detail': json.dumps({
                "reservationId": reservation_id,
                "eventId": event_id,
                "seatId": seat_id,
                "userEmail": email,
                "userId": user_id,
                "status": "RESERVED"
            }),
            'EventBusName': EVENT_BUS_NAME
        }]
    )

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(body)
    }