# Adversarial Checklist (`flutter-adversarial-qa`)

The auditor subagent must check the target widget against this checklist:

## 1. Overflow & Layout Stress
- Does the layout crash when the user scales system fonts to 2.0x?
- What happens when a string contains 250 characters without any spaces? Does it push action buttons off-screen?
- When the desktop window is shrunk to 300x300, does the view scroll smoothly or throw a `RenderFlex` overflow?

## 2. Timing, Async & Concurrency
- If a user rapidly taps a submission button 5 times in 200ms, does it trigger 5 network requests?
- If the widget unmounts while an async operation is awaiting response, is `context.mounted` checked before navigating or showing dialogs?

## 3. Data & State Boundaries
- Does the widget handle an empty list cleanly with an empty placeholder view?
- Does it crash if optional model properties return `null`?
- How does the widget behave when the network provider throws a timeout or socket exception?
