# auto_image_sequencer

Animate and control a sequence of images

## Features

Animates a sequence of images at a given speed, animation can be controlled;

## Instaling

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  auto_image_sequencer:
    git:
      url: https://github.com/yabzec/auto_image_sequencer.git
      ref: main
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
AutoImageSequencer(
    imageUrls: images.map((i) => i.url).toList(),
    onCreate: (AutoImageSequencerController c) {
        c.onImageChange = (int i, ui.Image image) {
          index = i;
          currentImage = image;
        };
        controller = c;
        controller.play();
        controller.pause();
        controller.toggle();
        controller.stop();
        controller.jumpTo(10);
    },
    speed = 200 //in milliseconds
)
```
