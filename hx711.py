# hx711.py
import RPi.GPIO as GPIO

class HX711:
    def __init__(self, dout, pd_sck):
        self.dout = dout
        self.pd_sck = pd_sck
        self.offset = 0
        self.reference_unit = 1
        GPIO.setup(self.pd_sck, GPIO.OUT)
        GPIO.setup(self.dout, GPIO.IN)

    def read(self):
        while GPIO.input(self.dout) == 1:
            pass
        count = 0
        for _ in range(24):
            GPIO.output(self.pd_sck, True)
            count = count << 1
            GPIO.output(self.pd_sck, False)
            if GPIO.input(self.dout):
                count += 1
        GPIO.output(self.pd_sck, True)
        GPIO.output(self.pd_sck, False)
        count ^= 0x800000
        return count

    def get_weight(self):
        raw = self.read()
        return (raw - self.offset) / self.reference_unit

    def tare(self):
        self.offset = self.read()

    def set_reference_unit(self, ref):
        self.reference_unit = ref
