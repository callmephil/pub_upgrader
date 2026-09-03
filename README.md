This package upgrades your `pubspec.yaml` dependencies versions.

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

The code will match the following patterns and will exclude anything else.

```yaml
package: ^..
package_with_underscore: ^..
```

## Demo

https://github.com/callmephil/pub_upgrader/assets/2213079/55b5aed1-d459-452a-b832-88c7075c582e
