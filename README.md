This package safely updates `pubspec.yaml` dependencies to compatible versions by taking advantage of `dart pub add`.

## Installation

Install it globally with Dart:

```sh
dart pub global activate pub_upgrader
```

Then run it from anywhere:

```sh
pub_upgrader
```

## How It Works

`pub_upgrader` updates dependencies while trying to keep your project in a compatible state.

It:

- uses `dart pub add` to resolve versions
- respects locked package versions
- avoids incompatible version combinations
- handles overridden dependencies

## Demo

https://github.com/callmephil/pub_upgrader/assets/2213079/55b5aed1-d459-452a-b832-88c7075c582e
