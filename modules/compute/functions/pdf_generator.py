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

            # --- CONFIGURACIÓN INICIAL ---
            pdf = FPDF()
            pdf.add_page()
            
            # --- HEADER DARK (AWS THEME) ---
            pdf.set_fill_color(22, 27, 34) 
            pdf.rect(0, 0, 210, 55, 'F')
            
            pdf.set_text_color(255, 255, 255)
            pdf.set_font("Arial", 'B', 24)
            pdf.set_xy(0, 15)
            # Usamos encode('latin-1', 'replace').decode('latin-1') para asegurar compatibilidad
            pdf.cell(0, 10, "AWS CLOUD TOUR 2026".encode('latin-1', 'replace').decode('latin-1'), ln=True, align="C")
            
            pdf.set_font("Arial", '', 10)
            pdf.cell(0, 8, "EN VIVO | EVENTO EXCLUSIVO".encode('latin-1', 'replace').decode('latin-1'), ln=True, align="C")
            
            # --- UBICACIÓN DESTACADA ---
            pdf.set_font("Arial", 'B', 12)
            pdf.set_text_color(255, 153, 0) # Naranja AWS
            pdf.cell(0, 10, "LIBERTADORES STADIUM - BOGOTÁ".encode('latin-1', 'replace').decode('latin-1'), ln=True, align="C")

            # --- CÓDIGO DE BARRAS DINÁMICO ---
            pdf.set_fill_color(0, 0, 0)
            start_x = 75
            for i, char in enumerate(str(res_id)):
                width = 0.4 if ord(char) % 2 == 0 else 1.1
                pdf.rect(start_x + (i * 1.8), 60, width, 12, 'F')
            
            pdf.set_text_color(0, 0, 0)
            pdf.set_xy(0, 73)
            pdf.set_font("Courier", 'B', 9)
            pdf.cell(0, 5, f"{res_id}", ln=True, align="C")

            # --- SECCIÓN DE ASIENTOS ---
            pdf.ln(10)
            pdf.set_fill_color(240, 242, 245)
            pdf.rect(10, 85, 190, 25, 'F')
            
            pdf.set_xy(10, 88)
            pdf.set_font("Arial", 'B', 8)
            pdf.set_text_color(100, 100, 100)
            pdf.cell(63, 5, "PUERTA", align="C")
            pdf.cell(63, 5, "FILA", align="C")
            pdf.cell(63, 5, "ASIENTO", align="C", ln=True)
            
            pdf.set_font("Arial", 'B', 16)
            pdf.set_text_color(22, 27, 34)
            pdf.cell(63, 10, "NORTE 02", align="C")
            pdf.cell(63, 10, "F-12", align="C")
            pdf.cell(63, 10, "V-04", align="C", ln=True)

            # --- DETALLES GENERALES ---
            pdf.ln(10)
            pdf.set_draw_color(22, 27, 34)
            pdf.set_line_width(0.5)
            pdf.line(10, 120, 200, 120)
            
            # Lista con tildes
            details = [
                ("FECHA:", "SÁBADO, 29 DE FEBRERO 2026"),
                ("HORA:", "17:00 (APERTURA 15:30)"),
                ("ZONA:", "PLATEA VIP / ACCESO EXCLUSIVO"),
                ("ESTADO:", "RESERVA CONFIRMADA")
            ]
            
            pdf.set_xy(10, 125)
            for label, value in details:
                pdf.set_font("Arial", 'B', 10)
                pdf.cell(40, 8, label.encode('latin-1', 'replace').decode('latin-1'))
                pdf.set_font("Arial", '', 10)
                if "CONFIRMADA" in value:
                    pdf.set_text_color(39, 174, 96)
                pdf.cell(0, 8, value.encode('latin-1', 'replace').decode('latin-1'), ln=True)
                pdf.set_text_color(0, 0, 0)

            # --- FOOTER ---
            pdf.set_xy(10, 170)
            pdf.set_font("Arial", 'I', 8)
            pdf.set_text_color(150, 150, 150)
            footer_text = (
                "Escanea este código en los puntos de control del Estadio Libertadores.\n"
                "Este evento es propiedad de CloudTickets en colaboración con AWS.\n"
                "No se permite el ingreso de alimentos ni cámaras profesionales."
            )
            pdf.multi_cell(190, 4, footer_text.encode('latin-1', 'replace').decode('latin-1'), align="C")

            # --- SALIDA ---
            pdf.output(local_path)

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