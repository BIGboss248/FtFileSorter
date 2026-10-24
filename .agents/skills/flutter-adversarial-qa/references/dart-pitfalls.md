# Common Dart & Flutter Pitfalls (`flutter-adversarial-qa`)

Auditors should inspect code for these common defects:

## 1. Unmounted Context After Async Gaps
```dart
// BAD
await service.fetchData();
Navigator.of(context).pop();

// GOOD
await service.fetchData();
if (!context.mounted) return;
Navigator.of(context).pop();
```

## 2. Unclosed Controllers & Subscriptions
Failing to call `.dispose()` on `TextEditingController`, `AnimationController`, `ScrollController`, or `StreamSubscription` leads to memory leaks and zombie rebuilds.

## 3. UI Thread Blocking
Executing long loops, large JSON decoding, or heavy file processing on the root isolate causes jank and dropped frames. Wrap CPU-bound work with `Isolate.run()`.
