import json
import os
import boto3
import time
from botocore.exceptions import ClientError

# Inicializar recursos AWS
dynamodb = boto3.resource('dynamodb')
sfn_client = boto3.client('stepfunctions')

# Tablas DynamoDB
inventory_table = dynamodb.Table(os.environ['INVENTORY_TABLE'])
reservations_table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])

# Step Functions
STATE_MACHINE_ARN = os.environ['STATE_MACHINE_ARN']


def handler(event, context):
    for record in event['Records']:
        try:
            # 1. Parsear mensaje desde SQS (viene de EventBridge)
            message_body = json.loads(record['body'])
            detail = message_body['detail']

            event_id = detail['eventId']
            seat_id = detail['seatId']
            reservation_id = detail['reservationId']
            email = detail['userEmail']

            print(f"[INFO] Procesando reserva {reservation_id} | Asiento {seat_id}")

            now = int(time.time())
            expires_at = now + 30  # TTL 30s

            # ------------------------------------------------------------------
            # 2. CREAR RESERVA (IDEMPOTENTE)
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
                print(f"[OK] Reserva {reservation_id} creada")

            except ClientError as e:
                if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    # Evento duplicado → comportamiento esperado
                    print(f"[WARN] Reserva {reservation_id} ya existe. Evento duplicado. Ignorando.")
                    continue
                raise

            # ------------------------------------------------------------------
            # 3. RESERVAR ASIENTO (TRANSACCIÓN CONDICIONAL)
            # ------------------------------------------------------------------
            try:
                inventory_table.update_item(
                    Key={
                        'EventID': event_id,
                        'SeatID': seat_id
                    },
                    UpdateExpression="SET #s = :new_status",
                    ConditionExpression="#s = :expected_status",
                    ExpressionAttributeNames={
                        '#s': 'status'
                    },
                    ExpressionAttributeValues={
                        ':new_status': 'RESERVED',
                        ':expected_status': 'AVAILABLE'
                    }
                )
                print(f"[OK] Asiento {seat_id} marcado como RESERVED")

            except ClientError as e:
                if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    print(f"[WARN] Asiento {seat_id} ya no disponible. Abortando flujo.")
                    continue
                raise

            # ------------------------------------------------------------------
            # 4. INICIAR STEP FUNCTION (UNA SOLA VEZ)
            # ------------------------------------------------------------------
            sfn_client.start_execution(
                stateMachineArn=STATE_MACHINE_ARN,
                name=f"exec-{reservation_id}",  # nombre único = idempotencia
                input=json.dumps({
                    "reservationId": reservation_id
                })
            )

            print(f"[OK] Step Function iniciada para {reservation_id}")

        except Exception as e:
            # Error real → SQS reintenta
            print(f"[ERROR] Fallo procesando mensaje SQS: {str(e)}")
            raise

    return {"status": "SUCCESS"}
