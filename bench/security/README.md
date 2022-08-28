# Security benchmarks

This folder contains a bunch of simplistic security-related tests
that can be used to validate some security properties.

Having failing tests doesn't mean that a specific allocator is insecure,
nor does having working one mean the opposite:

- Some allocators don't want to trash performances for minor security gains.
- Sometimes it's more efficient to make memory corruption harder or impossible
  to exploit than trying to detect them. For example, double-free detection
  isn't necessarily worth it when you have types isolation.
- Being able to detect a dumb use-after-free doesn't mean that it's not trivial
  for an attacker to bypass the detection in more complex cases.

In the words of the developer of a high-profile allocator:

> I am very opinionated on what a secure allocator is. And anything an attacker
can bypass is not worth implementing. Otherwise your allocator is slow and
people will just replace it with faster less secure allocators.

Testing for security properties is hard, so take those results with a grain of
salt, and do make sure you understand what is being tested.
