# Third-Party Notices

This project bundles ("vendors") source code from third-party open-source libraries. Their licenses are reproduced or referenced below. Each vendored library remains under its original license — only the PWManager-specific code in this repository is covered by [`LICENSE`](LICENSE).

Before redistributing this repository, please verify each upstream license by visiting the linked source repositories and confirm that any license texts included here match the upstream version.

---

## phc-winner-argon2 — `Sources/CArgon2/`, `Sources/VendoredArgon2/`

- **Upstream:** https://github.com/P-H-C/phc-winner-argon2
- **License:** Dual-licensed under CC0 1.0 Universal **or** Apache License 2.0 (at the recipient's option)
- **Authors:** Daniel Dinu, Dmitry Khovratovich, Jean-Philippe Aumasson, Samuel Neves
- **Notice from upstream source header:**

> Argon2 reference source code package - reference C implementations
>
> Copyright 2015 Daniel Dinu, Dmitry Khovratovich, Jean-Philippe Aumasson, and Samuel Neves
>
> You may use this work under the terms of a Creative Commons CC0 1.0 License/Waiver or the Apache Public License 2.0, at your option. The terms of these licenses can be found at:
> - CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0
> - Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0

The CC0 dedication waives all copyright. The Apache 2.0 alternative is reproduced at the URL above.

---

## SwiftKyber — `Sources/VendoredKyber/`

- **Upstream:** https://github.com/leif-ibsen/SwiftKyber
- **Author:** Leif Ibsen
- **License:** Refer to the upstream `LICENSE` file at https://github.com/leif-ibsen/SwiftKyber

---

## Digest — `Sources/VendoredDigest/`

- **Upstream:** https://github.com/leif-ibsen/Digest
- **Author:** Leif Ibsen
- **License:** Refer to the upstream `LICENSE` file at https://github.com/leif-ibsen/Digest

---

## BigInt — `Sources/VendoredBigInt/`

- **Upstream:** https://github.com/leif-ibsen/BigInt
- **Author:** Leif Ibsen
- **License:** Refer to the upstream `LICENSE` file at https://github.com/leif-ibsen/BigInt

---

## ASN1 — `Sources/VendoredASN1/`

- **Upstream:** https://github.com/leif-ibsen/ASN1
- **Author:** Leif Ibsen
- **License:** Refer to the upstream `LICENSE` file at https://github.com/leif-ibsen/ASN1

---

## TODO before publishing

The Leif Ibsen packages (SwiftKyber, Digest, BigInt, ASN1) need their actual `LICENSE` files copied from the upstream repos and added under `Sources/<package>/LICENSE` (or the full text quoted in this file). MIT and similar licenses require the original notice to travel with the code. Visit each upstream repo, copy its `LICENSE` file verbatim into this repo, and update this notice to confirm the license name.

The CArgon2 reference implementation already carries its license declaration in the C source headers, satisfying the notice requirement of CC0 / Apache 2.0.
