ShareDistributor 💰
===================

Automated Dividend Distribution for Tokenized Shares
----------------------------------------------------

This is a **Clarity smart contract** designed to manage tokenized shares and automate the proportional distribution of dividends to shareholders. It is built to be a robust, secure, and auditable system for managing equity and payouts on the Stacks blockchain. The contract supports multiple, distinct dividend rounds, employs a snapshot mechanism to ensure fair distribution, and prevents double-claiming of funds.

* * * * *

🚀 Features
-----------

-   **Tokenized Share Management:** Functions for issuing and transferring internal, non-fungible shares (represented by a simple balance map).

-   **Proportional Dividend Distribution:** Calculates dividends based on a shareholder's stake relative to the total shares at the time the dividend round was created.

-   **Dividend Round Snapshot:** When a new dividend round is initiated, the contract takes a **snapshot** of the total shares issued (`total-shares`) to serve as the denominator for distribution calculations. This ensures fairness, as share transfers *after* the round creation do not affect the total dividend pool calculation for that round.

-   **Claim Prevention:** Utilizes the `dividend-claims` map to prevent shareholders from claiming the dividend for a specific round more than once.

-   **Dual Distribution Methods:**

    -   **`claim-dividend` (Pull):** Shareholders can call this function themselves to claim their proportional amount.

    -   **`batch-distribute-dividends` (Push):** The contract owner can distribute dividends to a list of shareholders in a single transaction, useful for proactive distribution.

-   **Owner-Controlled Functions:** Key management functions like `issue-shares` and `create-dividend-round` are restricted to the contract owner (`tx-sender`).

-   **Secure Fund Management:** The `dividend-reserve` variable tracks the total outstanding dividend pool within the contract, ensuring all calculations are based on available funds.

* * * * *

⚙️ Contract Details
-------------------

### Data Structures

| **Data Structure** | **Type** | **Description** |
| --- | --- | --- |
| `share-balances` | `map<principal, uint>` | Tracks the current share balance for every address. |
| `total-shares` | `data-var<uint>` | Total number of shares ever issued. |
| `current-dividend-round` | `data-var<uint>` | The highest (latest) dividend round number created. |
| `dividend-pools` | `map<uint, uint>` | Stores the total dividend amount (e.g., in STX or other token unit) designated for a specific round number. |
| `dividend-claims` | `map<{shareholder: principal, round: uint}, bool>` | Tracks which shareholders have claimed their dividend for a given round. |
| `shares-snapshot` | `map<uint, uint>` | Stores the **total** shares issued at the moment a specific dividend round was created, ensuring the distribution base is fixed. |
| `round-active` | `map<uint, bool>` | Tracks whether a specific dividend round is open for claiming/distribution. |
| `dividend-reserve` | `data-var<uint>` | The total amount of dividends currently pooled within the contract awaiting distribution across all active rounds. |

* * * * *

🔒 Private (Internal) Functions
-------------------------------

These functions are not directly callable by external users; they implement the core business logic and security checks used by the public functions.

| **Function** | **Description** |
| --- | --- |
| `calculate-dividend` | Calculates a shareholder's proportional dividend amount using the formula: $\frac{\text{Shareholder Shares}}{\text{Total Shares Snapshot}} \times \text{Total Dividend Pool}$. It handles division by zero by returning `u0` if the snapshot is zero. |
| `has-minimum-shares` | A simple boolean check to ensure a given `shareholder` principal holds at least `u1` share. |
| `is-contract-owner` | Returns `true` if the `tx-sender` is the contract's deployer (`contract-owner`), used for access control on key management functions. |
| `update-balance` | Internal helper to safely update the `share-balances` map for a given address. |
| `process-shareholder-dividend` | A helper function used within the `batch-distribute-dividends` call. It checks if the shareholder has shares and hasn't claimed yet, and if so, sets their claim status to `true` for the current dividend round. **Note:** In a complete implementation, this would also include the logic for transferring the dividend amount. |

* * * * *

### Public Functions

| **Function** | **Access** | **Description** |
| --- | --- | --- |
| `issue-shares` | **Owner Only** | Mints a new number of shares to a recipient, increasing their balance and `total-shares`. |
| `transfer-shares` | Public | Allows a shareholder to transfer shares between addresses. |
| `create-dividend-round` | **Owner Only** | Initiates a new dividend round. Takes a snapshot of `total-shares` and sets the `dividend-amount` for the new round. Updates `dividend-reserve`. |
| `claim-dividend` | Public | Allows a shareholder to claim their proportional dividend for a specific, active round. Checks against the claim map and snapshot data. |
| `batch-distribute-dividends` | **Owner Only** | Owner can push dividends to a list of shareholders for a given round, marking their claims as processed. |

### Read-Only Functions

| **Function** | **Description** |
| --- | --- |
| `get-share-balance` | Retrieves the current share balance for a given account. |
| `get-total-shares` | Retrieves the current total shares issued. |
| `has-claimed-dividend` | Checks if a shareholder has claimed their dividend for a specific round. |
| `get-current-round` | Retrieves the most recently created dividend round number. |
| `get-dividend-pool` | Retrieves the total dividend amount allocated for a specific round. |

* * * * *

🛠️ Usage Example (Conceptual)
------------------------------

### 1\. **Setup and Share Issue (Owner)**

The contract owner deploys the contract and issues the initial shares.

Code snippet

```
(issue-shares 'ST000000000000000000000000000000000000000000 'u1000) ;; Owner gets 1000 shares
(issue-shares 'ST1SJ3DVKQ8YTWJ8B6XJG4MTW1JJQJT0000000000000 'u500) ;; Shareholder A gets 500 shares
;; Total shares = 1500

```

### 2\. **Create Dividend Round (Owner)**

The owner creates the first round, funding it with 15,000 units.

Code snippet

```
(create-dividend-round u15000)
;; current-dividend-round is now u1.
;; shares-snapshot for round u1 is u1500.
;; dividend-pools for round u1 is u15000.
;; dividend-reserve is u15000.

```

### 3\. **Shareholder Claims (Shareholder A)**

Shareholder A claims their dividend:

-   Shareholder A shares: 500

-   Snapshot total shares: 1500

-   Total dividend pool: 15,000

-   Calculation (via `calculate-dividend`): $\frac{500}{1500} \times 15000 = 5000$

Code snippet

```
(claim-dividend u1)
;; Returns ok u5000.
;; dividend-reserve is now u10000.
;; dividend-claims for {shareholder: 'ST1..., round: u1} is true.

```

* * * * *

⚠️ Security and Completeness Note
---------------------------------

This contract provides the **logic** for proportional dividend calculation and claim management. However, in a complete dApp:

1.  **Token Transfer:** The `claim-dividend` function should include a **real fungible token transfer** (e.g., using `stx-transfer-from?` or a call to an external token contract's `ft-transfer?`) to send the calculated `dividend-amount` to the `tx-sender`. This requires the contract to hold the dividend tokens or to be approved to spend them.

2.  **Asset Handling:** An external function (not included) would be necessary for the owner to fund the contract's reserve with the actual tokens *before* calling `create-dividend-round`, or for `create-dividend-round` to handle the token deposit as part of the transaction.

3.  **Error Handling for Batch:** The current `batch-distribute-dividends` uses a private helper `process-shareholder-dividend` that only marks the claim as true but does not perform the token transfer. A robust implementation would need to handle failed token transfers gracefully within the batch, likely by using a safe fold/map function that accumulates successful transfers and ensures atomicity where possible, or logs failures.

* * * * *

📜 Error Codes
--------------

| **Code** | **Constant** | **Description** |
| --- | --- | --- |
| `u100` | `err-owner-only` | The transaction sender is not the contract owner. |
| `u101` | `err-insufficient-balance` | Sender's share balance is too low, or the contract's dividend reserve is insufficient. |
| `u102` | `err-invalid-amount` | The amount specified is zero or invalid (e.g., dividend calculation resulted in zero). |
| `u103` | `err-already-claimed` | Dividend for this round has already been claimed by the shareholder. |
| `u104` | `err-no-dividends` | The dividend pool for the specified round is zero. |
| `u105` | `err-not-shareholder` | The caller has zero shares. |
| `u106` | `err-transfer-failed` | (Reserved for potential external token transfer failures). |
| `u107` | `err-round-not-active` | The dividend round is not active (i.e., it has been closed). |
| `u108` | `err-invalid-shares` | Total shares is zero, preventing dividend calculation. |

* * * * *

🤝 Contribution
---------------

We welcome contributions to improve the security, efficiency, and functionality of this contract.

### How to Contribute

1.  **Fork** the repository.

2.  **Clone** your forked repository:

    Bash

    ```
    git clone https://github.com/your-username/ShareDistributor.git

    ```

3.  **Create a new branch** for your feature or fix:

    Bash

    ```
    git checkout -b feature/your-feature-name

    ```

4.  **Implement** your changes. Ensure your code adheres to Clarity's best practices.

5.  **Test** your changes thoroughly using Clarity tools (e.g., Clarinet).

6.  **Commit** your changes with a clear and descriptive commit message:

    Bash

    ```
    git commit -m "feat: Add logic for external token transfer in claim-dividend"

    ```

7.  **Push** your branch:

    Bash

    ```
    git push origin feature/your-feature-name

    ```

8.  **Open a Pull Request** to the main repository's `main` branch.

All contributions will be reviewed for security and adherence to the project's goals.

* * * * *

⚖️ License
----------

The `ShareDistributor` contract is released under the **MIT License**, which is one of the most permissive free software licenses.

* * * * *

> **MIT License**
>
> Copyright (c) 2025 ShareDistributor
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR OF IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

* * * * *
