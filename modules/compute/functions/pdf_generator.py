import json
import os
import boto3
from fpdf import FPDF

s3 = boto3.client('s3')

def handler(event, context):
    for record in event['Records']:
        try:
            body = json.loads(record['body'])
            detail = body.get('detail', {})
            res_id = detail.get('reservationId', 'N/A')
            
            file_name = f"ticket-{res_id}.pdf"
            local_path = f"/tmp/{file_name}"

            # --- DISEÑO ESTILO AWS CLOUD TOUR 2026 ---
            pdf = FPDF()
            pdf.add_page()
            
            # Fondo oscuro para el encabezado (Color del frontend)
            pdf.set_fill_color(22, 27, 34) 
            pdf.rect(0, 0, 210, 60, 'F')
            
            # Badge "EN VIVO • EVENTO EXCLUSIVO"
            pdf.set_fill_color(231, 76, 60) # Rojo del badge
            pdf.set_text_color(255, 255, 255)
            pdf.set_font("Arial", 'B', 8)
            pdf.cell(0, 10, "EN VIVO  EVENTO EXCLUSIVO", ln=True, align="C")
            
            # Título principal
            pdf.set_font("Arial", 'B', 26)
            pdf.cell(0, 20, "AWS Cloud Tour 2026", ln=True, align="C")
            
            pdf.ln(25) # Espacio después del encabezado
            
            # --- CUERPO DEL TICKET ---
            pdf.set_text_color(40, 40, 40)
            pdf.set_font("Arial", 'B', 14)
            pdf.cell(0, 10, "DETALLES DE TU RESERVA", ln=False)
            pdf.set_font("Arial", size=10)
            pdf.cell(0, 10, "29 Febrero 2026 - 17:00", ln=True, align="R")
            
            pdf.line(10, 72, 200, 72)
            pdf.ln(10)
            
            # Tabla de Información
            pdf.set_fill_color(245, 247, 250)
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(60, 12, "  ID de Reserva:", border="B", fill=True)
            pdf.set_font("Arial", size=11)
            pdf.cell(0, 12, f"  {res_id}", border="B", ln=True)
            
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(60, 12, "  Ubicación:", border="B", fill=True)
            pdf.set_font("Arial", size=11)
            pdf.cell(0, 12, "  Bogotá, Colombia", border="B", ln=True)
            
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(60, 12, "  Estado:", border="B", fill=True)
            pdf.set_text_color(39, 174, 96) # Verde éxito
            pdf.cell(0, 12, "  CONFIRMADO / PAID", border="B", ln=True)

            # Footer con estilo
            pdf.ln(30)
            pdf.set_fill_color(22, 27, 34)
            pdf.rect(10, 140, 190, 40, 'D') # Un recuadro elegante para el mensaje
            
            pdf.set_xy(10, 145)
            pdf.set_text_color(100, 100, 100)
            pdf.set_font("Arial", 'I', 10)
            pdf.multi_cell(190, 7, "Presenta este código en la entrada del evento.\nLa zona de Platea VIP y Tribuna General abren puertas desde las 15:30.", align="C")

            pdf.output(local_path)

            # --- SUBIR A S3 ---
            with open(local_path, "rb") as f:
                s3.put_object(
                    Bucket=os.environ['TICKETS_BUCKET'],
                    Key=file_name,
                    Body=f,
                    ContentType='application/pdf'
                )

        except Exception as e:
            print(f"Error: {str(e)}")
            raise e
            
    return {"status": "SUCCESS"}