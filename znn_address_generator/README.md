# znn_address_generator

Concurrently generate mnemonics and addresses, then save them to disk.

### Variables
```dart
int queueSize = 10; // number of threads
int jobs = 100;     // number of mnemonics to generate
int addressesPerMnemonic = 5;
```

### Setup
Update variables in main.dart
```dart
dart pub get
dart run main.dart
```