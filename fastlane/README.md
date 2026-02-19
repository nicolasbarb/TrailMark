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

Push a new build to TestFlight

### ios beta_no_bump

```sh
[bundle exec] fastlane ios beta_no_bump
```

Push to TestFlight without version bump (rebuild)

### ios build

```sh
[bundle exec] fastlane ios build
```

Build app for release (without upload)

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
