import json
import os
import boto3
import time
from botocore.exceptions import ClientError

# Inicializar recursos
dynamodb = boto3.resource('dynamodb')
# Cliente para Step Functions
sfn_client = boto3.client('stepfunctions')

inventory_table = dynamodb.Table(os.environ['INVENTORY_TABLE'])
reservations_table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])
# ARN de la State Machine desde variables de entorno
STATE_MACHINE_ARN = os.environ['STATE_MACHINE_ARN']

def handler(event, context):
    for record in event['Records']:
        try:
            # 1. Parsear el mensaje
            message_body = json.loads(record['body'])
            detail = message_body['detail']
            
            event_id = detail['eventId']
            seat_id = detail['seatId']
            reservation_id = detail['reservationId']
            email = detail['userEmail']
            
            print(f"Procesando reserva {reservation_id} para el asiento {seat_id}")

            # 2. Transacción: Actualizar Inventario a RESERVED
            try:
                inventory_table.update_item(
                    Key={'EventID': event_id, 'SeatID': seat_id},
                    UpdateExpression="SET #s = :new_status",
                    ConditionExpression="#s = :expected_status",
                    ExpressionAttributeNames={'#s': 'status'},
                    ExpressionAttributeValues={
                        ':new_status': 'RESERVED',
                        ':expected_status': 'AVAILABLE'
                    }
                )
            except ClientError as e:
                if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    print(f"Error: El asiento {seat_id} ya fue tomado por otro proceso.")
                    continue
                raise e

            # 3. Crear el registro en la tabla de Reservas
            expires_at = int(time.time()) + 30 
            
            reservations_table.put_item(
                Item={
                    'ReservationID': reservation_id,
                    'EventID': event_id,
                    'SeatID': seat_id,
                    'UserEmail': email,
                    'status': 'PENDING',
                    'CreatedAt': int(time.time()),
                    'ExpiresAt': expires_at
                }
            )

            print(f"Reserva {reservation_id} creada exitosamente.")

            # 4. INICIAR STEP FUNCTIONS (El Orquestador)
            # Le pasamos el reservationId como entrada para que sepa qué vigilar
            sfn_client.start_execution(
                stateMachineArn=STATE_MACHINE_ARN,
                name=f"exec-{reservation_id}-{int(time.time())}", # Nombre único para la ejecución
                input=json.dumps({
                    "reservationId": reservation_id
                })
            )
            
            print(f"Step Function iniciada para la reserva {reservation_id}")

        except Exception as e:
            print(f"Error procesando registro SQS: {str(e)}")
            raise e

    return {"status": "SUCCESS"}