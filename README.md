# Vectron AI

COMING SOON!

Teach machines like it's 1979!

Vectron AI interfaces with the [Vectron 64](https://github.com/nickbild/vectron_64) breadboard computer (6502 CPU @ 1MHz, 32KB RAM, 32KB ROM) to provide gesture detecting artificial intelligence.  The gesture detection is used to control an Atari 2600 emulator.

## How It Works

Images are captured, downscaled, and converted to an integer vector by a Raspberry Pi 3 B+.  The vector is then transferred, one byte at a time, to a shift register in Vectron AI.  After each byte is loaded, an interrupt is sent to the Vectron 64 computer.

The Vectron 64 retrieves each byte and stores it in RAM.  When a full image has been received, it runs a k-nearest neighbors algorithm to classify the current image against 50 known images that are stored in the ROM.  The class of the best match (minimum sum of all pixel distances) determines the predicted class of the current image.  The 6502 assembly can be found [here](https://github.com/nickbild/vectron_ai/blob/master/vectron64.asm).

The Vectron 64 then puts an address on the address bus that Vectron AI interprets and in turn sends a signal to a GPIO pin on another Raspberry Pi 3 B+.  This Raspberry Pi is running a [script](https://github.com/nickbild/vectron_ai/blob/master/play_atari.py) that converts the GPIO signal to a simulated keypress.  The simulated keypress controls a [Stella](https://stella-emu.github.io/) Atari 2600 emulator.

When this is all put together, you can place your hand in front of the camera with any of the known gestures, and the game will be controlled accordingly.

## Media

Some examples of downscaled images that the Vectron 64 processes.  They have a beautiful 8-bit appearance.  As someone with more experience working with higher resolution images on artificial neural networks, I was a bit shocked by how accurate a simple algorithm like k-nearest neighbors is for image classification, and with very low resolution inputs.

Hand gesturing "up":
![up](https://raw.githubusercontent.com/nickbild/vectron_ai/master/media/up_large.bmp)

Hand gesturing "right":
![left](https://raw.githubusercontent.com/nickbild/vectron_ai/master/media/left_large.bmp)

The full setup:

![full_setup](https://raw.githubusercontent.com/nickbild/vectron_ai/master/media/full_setup_sm.jpg)

Close-up of the AI module:

![ai_module](https://raw.githubusercontent.com/nickbild/vectron_ai/master/media/ai_module_sm.jpg)

The camera:

![camera](https://raw.githubusercontent.com/nickbild/vectron_ai/master/media/camera_sms.jpg)

## Bill of Materials

- 1 x [Vectron 64](https://github.com/nickbild/vectron_64)
- 2 x Raspberry Pi 3 Model B+
- 1 x Raspberry Pi Camera v2
- 1 x Logic Level Shifter (3.3V -> 5V)
- 1 x Logic Level Shifter (5V -> 3.3V)
- 2 x 74HC32 Quad OR Gate
- 1 x 74HC595 Shift Register
- 4 x 74HCT688E Logic Comparator
- 1 x Miscellaneous Wire

## About the Author

[Nick A. Bild, MS](https://nickbild79.firebaseapp.com/#!/)
