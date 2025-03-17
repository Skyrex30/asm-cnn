Handwritten Digit Recognition with CNN

This project implements a convolutional neural network (CNN) for recognizing handwritten digits. The application includes a graphical interface for drawing digits, which are then processed and classified using a neural network.
Features

    Graphical User Interface
        Draw a digit on a black canvas
        Buttons for clearing the canvas and running digit recognition
        Displays the detected digit in the console

    Neural Network Architecture
        Convolutional Layer (3x3 kernel, padding=1, stride=1)
        Max-Pooling Layer (2x2 kernel, stride=2)
        Fully Connected Layer optimized with vector operations
        Activation Functions: ReLU
        Output Layer: ArgMax for digit classification

    File-based Model Loading
        Loads neural network structure from a text file
        Loads weights and biases from a binary file

How It Works

    The drawn digit is resized to 28x28 pixels
    Pixel values are scaled to the [-1,1] range
    The CNN processes the image and predicts the digit

Requirements

    Assembly language (32-bit)
    Neural network structure and weights files (conv_model.txt, conv_model.bin)

Usage

    Run the program
    Draw a digit on the canvas
    Click the green button (detection) to classify the digit
