This package upgrades your `pubspec.yaml` dependencies versions.

## Installation

Add to your `pubspec.yaml` below `dev_dependencies`

```yaml
pub_upgrader: ^1.0.0
```

or run the command

```sh
flutter pub add pub_upgrader
```

## How It Works

The code will match the following patterns and will exclude anything else.

```yaml
package: ^..
package_with_underscore: ^..
```

## Known Issue

Currently only support dependencies & dev_dependencies.

## Demo

https://github.com/Flutter-Factories/pub_upgrader/assets/2213079/55b5aed1-d459-452a-b832-88c7075c582e

## Capabilities

- [x] upgrade dependencies.
- [ ] upgrade SDK/environment
- [ ] upgrade Android config
- [ ] upgrade Web config
- [ ] upgrade iOS config
- [ ] upgrade pods

<a href="https://www.buymeacoffee.com/pmakz" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
