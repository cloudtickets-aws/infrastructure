import json
import os
import boto3
import time
from botocore.exceptions import ClientError

# Inicializar recursos AWS
dynamodb = boto3.resource('dynamodb')
sfn_client = boto3.client('stepfunctions')

reservations_table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])
STATE_MACHINE_ARN = os.environ['STATE_MACHINE_ARN']

def handler(event, context):
    for record in event['Records']:
        try:
            # 1. Parsear mensaje (Viene de SQS <--- EventBridge)
            message_body = json.loads(record['body'])
            # IMPORTANTE: EventBridge mete el evento dentro de la llave 'detail'
            detail = message_body.get('detail', message_body)

            reservation_id = detail['reservationId']
            event_id = detail['eventId']
            seat_id = detail['seatId']
            email = detail['userEmail']

            print(f"[INFO] Procesando reserva {reservation_id}")

            now = int(time.time())
            expires_at = now + 600 # 10 minutos de gracia (ajustable)

            # ------------------------------------------------------------------
            # 2. CREAR REGISTRO DE RESERVA (Para trazabilidad del flujo)
            # ------------------------------------------------------------------
            try:
                reservations_table.put_item(
                    Item={
                        'ReservationID': reservation_id,
                        'EventID': event_id,
                        'SeatID': seat_id,
                        'UserEmail': email,
                        'status': 'PENDING',
                        'CreatedAt': now,
                        'ExpiresAt': expires_at
                    },
                    ConditionExpression="attribute_not_exists(ReservationID)"
                )
            except ClientError as e:
                if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    print(f"[WARN] Reserva {reservation_id} ya procesada. Saltando.")
                    continue
                raise

            # ------------------------------------------------------------------
            # 3. INICIAR STEP FUNCTION (EL MOTOR)
            # ------------------------------------------------------------------
            sfn_client.start_execution(
                stateMachineArn=STATE_MACHINE_ARN,
                name=f"exec-{reservation_id}", # Idempotencia: evita ejecuciones dobles
                input=json.dumps({
                    "reservationId": reservation_id
                })
            )
            print(f"[OK] Step Function iniciada para {reservation_id}")

        except Exception as e:
            print(f"[ERROR] Error crítico: {str(e)}")
            # No lanzamos raise aquí para que un mensaje malo no bloquee el lote entero, 
            # pero en producción se recomienda usar Dead Letter Queues (DLQ).

    return {"status": "SUCCESS"}