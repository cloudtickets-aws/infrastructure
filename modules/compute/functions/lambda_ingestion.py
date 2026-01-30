import json
import os
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

# Inicializar clientes fuera del handler para reutilizar conexiones (Warm Start)
dynamodb = boto3.resource('dynamodb')
events = boto3.client('events')

INVENTORY_TABLE = os.environ['INVENTORY_TABLE']
EVENT_BUS_NAME = os.environ['EVENT_BUS_NAME']

def handler(event, context):
    try:
        # 1. Parseo de entrada
        body = json.loads(event.get('body', '{}'))
        seat_id = body.get('seat_id')
        event_id = body.get('event_id', 'AWS_CLOUD_TOUR')
        email = body.get('email')
        user_id = body.get('user_id', 'user_default')

        if not seat_id or not email:
            return response(400, {"error": "Asiento y email son requeridos"})

        table = dynamodb.Table(INVENTORY_TABLE)
        
        # Generamos el ID de reserva aquí para que esté disponible en todo el flujo
        reservation_id = f"res-{datetime.now().strftime('%m%d-%H%M%S')}"

        try:
            # --- 2. ATOMICIDAD ---
            # Intentamos la escritura condicional: solo si el status es 'AVAILABLE'
            table.update_item(
                Key={'EventID': event_id, 'SeatID': seat_id},
                UpdateExpression="SET #s = :res, #u = :user, #em = :email, #rid = :rid",
                ConditionExpression="#s = :avail",
                ExpressionAttributeNames={
                    '#s': 'status', 
                    '#u': 'userId', 
                    '#em': 'userEmail',
                    '#rid': 'reservationId'
                },
                ExpressionAttributeValues={
                    ':res': 'RESERVED',
                    ':avail': 'AVAILABLE',
                    ':user': user_id,
                    ':email': email,
                    ':rid': reservation_id
                }
            )
            
            # Si el update fue exitoso, notificamos a EventBridge (esto dispara el flujo)
            send_event(event_id, seat_id, email, user_id, reservation_id)
            
            # DEVOLVEMOS EL ID PARA QUE ARTILLERY LO CAPTURE
            return response(201, {
                "message": "Reserva creada con éxito",
                "reservationId": reservation_id,
                "status": "RESERVED"
            })

        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                
                # --- 3. IDEMPOTENCIA ---
                # Si falló, verificamos si es porque el MISMO usuario ya lo tiene
                actual_item = table.get_item(Key={'EventID': event_id, 'SeatID': seat_id}).get('Item', {})
                
                if actual_item.get('userId') == user_id:
                    # El usuario ya es dueño de la reserva. Devolvemos su ID previo.
                    return response(200, {
                        "message": "Reserva confirmada previamente",
                        "reservationId": actual_item.get('reservationId'),
                        "status": "RESERVED"
                    })
                else:
                    # El asiento es de otra persona
                    return response(409, {"error": "El asiento ya no está disponible"})
            raise e

    except Exception as e:
        print(f"ERROR: {str(e)}")
        return response(500, {"error": "Error interno del sistema"})

def send_event(event_id, seat_id, email, user_id, reservation_id):
    """Publica el evento en EventBridge para iniciar la orquestación"""
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
    """Estructura de respuesta para API Gateway"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }