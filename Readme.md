# DeaField

## Description
DeaField is a quirky iOS application born out of a burst of creativity and two days of intense coding fun during the iOS Foundation program.

The main idea was to let people with hearing disabilities 'feel' music again through vibration (sense of touch) and custom animation (sense of sight).

This app extends the voice memo recording functionality, allowing users to convert the sound of recordings using Fourier transformations into harmonics.

The distinctive feature of this app is the ability to generate customized vibration based on the audio recording, accompanied by a visual animation based on the detected Hz frequency.

In the repository, there's the keynote presentation of our project and the Swift project itself.

## Key Features
1. **Voice Recording:** The app allows users to record voice memos.

2. **Fourier Analysis:** It uses Fourier transformations to convert the sound wave of the recording into harmonics.

3. **Custom Vibration Generation:** Based on harmonic analysis, the app creates customized vibration that reflects the unique characteristics of the recording.

4. **Visual Animation:** Displays an animation based on the Hz frequency detected from the audio recording.

5. **Limited Duration:** The app currently records for only 1.30 minutes due to the limitation in dynamically allocating the array used to store the sound wave.

## Fundamental Flaw
The app has a fundamental flaw: the limited duration of recordings to 1.30 minutes due to the static allocation of the array to store the sound wave.

This is because of the nature of sound wave sampling that we used, which requires a preallocated array.


`let audioFrameCount = UInt32(audioFile.length)`


## Main grup
The project was a whirlwind of creativity and coding mischief (sorry for the spaghetti code!), brought to life in just two days as part of the iOS Foundation program. 

The main grup consist of 5 people (3 designers and 2 developers):

1. [Stefano Aldanese](https://github.com/StefanoAldanese) - Coder / Computer Science student.
2. [Davide Perrotta](https://github.com/Davide002001) - Coder / Computer Science student.
3. Riccardo Introno - UI/UX Designer / Computer Science student.
4. Giuseppina Marino - UI/UX Designer / Tourism Business management student.
5. Eliana Bruno - UI/UX Designer / Education Sciences.

## System Requirements
- iOS 17.0 or later
- Compatible iOS device
