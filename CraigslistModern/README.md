# 📁 CoriyonsList/ — Native iOS Marketplace Redesign – Coriyon’s Portfolio

A high-fidelity, native iOS reimagining of the local marketplace experience. Built entirely with SwiftUI and MapKit, this repository contains the source code for a design-focused prototype that explores "Browse-first" discovery, spatial navigation, and experimental UI patterns. 

---

## ✅ Who This Is For

* **Designers & Researchers:** To explore the UX patterns, including the Swipe Feed and icon-based category navigation.
* **Beta Testers & Reviewers:** To understand the functional proof-of-concept features before testing via TestFlight.
* **Developers:** To reference the SwiftUI view architecture, MapKit integration, and custom Clarity analytics implementation.

---

## 📁 Folder Structure or Common Files

| File / Folder                  | Purpose                                                                 |
| ------------------------------ | ----------------------------------------------------------------------- |
| `CraigslistModernApp.swift`    | App entry point, custom font registration, and Microsoft Clarity setup. |
| `ContentView.swift`            | Main TabView controller routing to Home, Search, and Favorites.         |
| `HomeFeedView.swift`           | Contains the primary listing grid and access to the experimental Swipe feed. |
| `MapFeedView.swift`            | Spatial discovery UI combining MapKit with a bottom sheet listing view. |
| `ListingModel.swift`           | Data structures and networking logic for fetching the mock Gist payload. |

---

## 🔁 Guidelines or Usage Notes

* **Data Context:** All listings are populated via a mock JSON Gist URL. No real-world transactions or messaging capabilities are active in this build.
* **Experimental Toggles:** The `AccountView` contains feature flags for toggling experimental discovery patterns (Swipe Feed, AskAI).
* **Placeholders:** The Chat, Post, and AskAI views are high-fidelity visual placeholders included strictly to demonstrate future product vision and navigation flow.
* **Analytics:** Microsoft Clarity is integrated to track scroll depth, tap interactions, and view-switching behaviors to validate UX hypotheses.

---

## ⚙️ How to Contribute or Extend

To run this project locally, ensure you are using Xcode 16+ and targeting iOS 18.5 or later.

```bash
# Clone the repository
git clone [https://github.com/coriyon/coriyons-list.git](https://github.com/coriyon/coriyons-list.git)

# Open the project in Xcode
open CraigslistModern.xcodeproj

Last updated: March 25, 2026