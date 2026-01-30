import json
import os
import boto3
import time
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
sfn = boto3.client('stepfunctions')

table = dynamodb.Table(os.environ['RESERVATIONS_TABLE'])


def handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        reservation_id = body.get('reservationId')

        if not reservation_id:
            return response(400, {"message": "Falta reservationId"})

        print(f"[INFO] Procesando pago para {reservation_id}")

        # --------------------------------------------------
        # 1. OBTENER RESERVA
        # --------------------------------------------------
        result = table.get_item(Key={'ReservationID': reservation_id})
        item = result.get('Item')

        if not item:
            return response(404, {"message": "Reserva no encontrada"})

        status = item.get('status')
        task_token = item.get('taskToken')
        expires_at = item.get('ExpiresAt', 0)

        # --------------------------------------------------
        # 2. VALIDACIONES DE NEGOCIO
        # --------------------------------------------------
        if int(time.time()) > expires_at:
            return response(410, {"message": "La reserva expiró"})

        # IDOTEMPOTENCIA: pago repetido
        if status == 'CONFIRMED':
            print("[INFO] Pago ya procesado previamente")
            return response(200, {
                "message": "Pago ya confirmado",
                "reservationId": reservation_id
            })

        # --------------------------------------------------
        # 3. ACTUALIZAR A CONFIRMED (CONDICIONAL)
        # --------------------------------------------------
        try:
            table.update_item(
                Key={'ReservationID': reservation_id},
                UpdateExpression="SET #s = :confirmed",
                ConditionExpression="#s = :pending",
                ExpressionAttributeNames={'#s': 'status'},
                ExpressionAttributeValues={
                    ':confirmed': 'CONFIRMED',
                    ':pending': 'PENDING'
                }
            )
            print("[OK] Reserva marcada como CONFIRMED")

        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                # Otro request ya la confirmó
                return response(200, {
                    "message": "Pago ya confirmado",
                    "reservationId": reservation_id
                })
            raise

        # --------------------------------------------------
        # 4. DESPERTAR STEP FUNCTION (UNA SOLA VEZ)
        # --------------------------------------------------
        if task_token:
            try:
                sfn.send_task_success(
                    taskToken=task_token,
                    output=json.dumps({
                        "status": "CONFIRMED",
                        "reservationId": reservation_id
                    })
                )
                print("[OK] Step Function liberada")

            except sfn.exceptions.TaskDoesNotExist:
                print("[WARN] Task token expirado (flujo ya cerró)")
        else:
            print("[WARN] taskToken no presente en la reserva")

        return response(200, {
            "message": "Pago procesado correctamente",
            "reservationId": reservation_id
        })

    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return response(500, {"error": "Error interno"})


def response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }
