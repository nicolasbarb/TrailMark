fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios setup_match

```sh
[bundle exec] fastlane ios setup_match
```

Setup all certificates and profiles (development, adhoc, appstore)

### ios regenerate_certificates

```sh
[bundle exec] fastlane ios regenerate_certificates
```

Clean and regenerate all certificates and profiles

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Push a new build to TestFlight. Use bump:patch/minor/major to create a new App Store version.

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Push metadata (description, keywords, etc.) to App Store Connect. Use version:x.y.z to target a specific version.

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate app screenshots automatically

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
