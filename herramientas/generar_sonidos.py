# Genera los efectos de sonido del combate en sonidos/ (WAV mono 16 bits).
# Uso:  python herramientas/generar_sonidos.py
# Solo usa la librería estándar de Python. Cambia los números y vuelve a correrlo.
import math
import os
import random
import struct
import wave

SR = 22050
CARPETA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sonidos")
random.seed(33)


def guardar(nombre, muestras):
    pico = max(1e-9, max(abs(m) for m in muestras))
    datos = b"".join(struct.pack("<h", int(max(-1, min(1, m / pico * 0.9)) * 32767)) for m in muestras)
    with wave.open(os.path.join(CARPETA, nombre), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos)
    print("ok", nombre, round(len(muestras) / SR, 2), "s")


def ruido_filtrado(n, corte_ini, corte_fin=None):
    # ruido blanco por un filtro pasa-bajos de un polo que puede barrer
    corte_fin = corte_ini if corte_fin is None else corte_fin
    y, out = 0.0, []
    for i in range(n):
        f = corte_ini + (corte_fin - corte_ini) * i / n
        a = 1 - math.exp(-2 * math.pi * f / SR)
        y += a * (random.uniform(-1, 1) - y)
        out.append(y)
    return out


def parry():
    # choque metálico: parciales inarmónicos que decaen + chasquido inicial
    n = int(SR * 0.7)
    parciales = [(1180, 1.0, 7), (1873, 0.7, 9), (2650, 0.5, 11), (3910, 0.35, 14), (590, 0.4, 6)]
    s = []
    clic = ruido_filtrado(n, 6000)
    for i in range(n):
        t = i / SR
        v = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-d * t) for f, a, d in parciales)
        v += clic[i] * 2.5 * math.exp(-t * 60)
        s.append(v)
    return s


def aviso():
    # "sssh-ting": aire que sube + un brillo agudo; avisa que el golpe está por caer
    n = int(SR * 0.32)
    aire = ruido_filtrado(n, 500, 5000)
    s = []
    for i in range(n):
        t = i / SR
        env = math.sin(math.pi * min(1.0, t / 0.32)) ** 1.5
        v = aire[i] * env * 2.0
        if t > 0.18:
            v += 0.35 * math.sin(2 * math.pi * 2600 * t) * math.exp(-(t - 0.18) * 30)
        s.append(v)
    return s


def herida():
    # golpe sordo: tono grave que cae + ruido corto
    n = int(SR * 0.35)
    r = ruido_filtrado(n, 900)
    s = []
    fase = 0.0
    for i in range(n):
        t = i / SR
        fase += 2 * math.pi * (140 - 80 * t / 0.35) / SR
        s.append(math.sin(fase) * math.exp(-t * 9) + r[i] * 3.0 * math.exp(-t * 25))
    return s


def esquiva():
    n = int(SR * 0.3)
    r = ruido_filtrado(n, 3500, 700)
    return [r[i] * math.sin(math.pi * i / n) for i in range(n)]


def contra():
    # tajo pesado: barrido de aire + choque más grave
    n = int(SR * 0.6)
    aire = ruido_filtrado(n, 4000, 800)
    s = []
    for i in range(n):
        t = i / SR
        v = aire[i] * 1.5 * math.exp(-t * 6)
        v += sum(a * math.sin(2 * math.pi * f * t) * math.exp(-d * t) for f, a, d in [(420, 1, 6), (873, 0.6, 8), (1560, 0.4, 10)])
        s.append(v)
    return s


def descanso():
    # campanitas suaves (Do-Mi-Sol-Do)
    n = int(SR * 1.8)
    notas = [(523.25, 0.0), (659.25, 0.18), (783.99, 0.36), (1046.5, 0.54)]
    s = [0.0] * n
    for f, ini in notas:
        for i in range(int(ini * SR), n):
            t = i / SR - ini
            s[i] += (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2.01 * t)) * math.exp(-t * 2.5)
    return s


if __name__ == "__main__":
    guardar("parry.wav", parry())
    guardar("aviso_golpe.wav", aviso())
    guardar("herida.wav", herida())
    guardar("esquiva.wav", esquiva())
    guardar("contraataque.wav", contra())
    guardar("descanso.wav", descanso())
