# Devlog: RPG 3D Game

A Skyrim-inspired 3D RPG built in **Godot 4.3**, made to learn game architecture and game design from the ground up.

**Current goal: a vertical slice**: one small, complete slice of the game where every core system works end to end.

- [x] Player controller (first/third-person camera)
- [x] Interaction system
- [x] Items
- [x] Inventory (logic + UI, use, drop)
- [ ] Dialogue
- [ ] Quests
- [ ] Save / Load

---

## 0. Project setup

**Built:** Git repo with Git LFS for binary assets, `.gitignore` / `.gitattributes`, and a feature-based folder structure (`core`, `systems`, `actors`, `data`, `world`, `ui`, `assets`).

**Decisions:**
- **Feature-based folders** instead of type-based (`scripts/`, `scenes/`). Everything belonging to one system lives together, which scales better as the project grows.
- **Feature-branch workflow:** one branch per feature, merged into `main` only when it works. `main` always runs.

---

## 1. Player controller

**Built:** Player scene with movement and a switchable first/third-person camera (`CameraRig` → `SpringArm3D` → `Camera3D`), tested in a greybox level.

**Problems & fixes:**
- Camera clipped through walls in third person. Fixed using the `SpringArm3D`'s collision so the camera pulls in when blocked.

**Learned:** greyboxing (testing mechanics with simple shapes before any art) keeps the focus on how the game *feels*.

---

## 2. Interaction system

**Built:** a reusable `Interactable` component (`Area3D`) and an `InteractionRay` (`RayCast3D`) from the camera with a max reach measured from the player. Press **E** to interact.

**Decisions:**
- **Component, not inheritance:** any object becomes interactable by adding one child node.
- **Named physics layers** (`world`, `interactable`) so the ray only detects what it should.
- The `interacted` signal passes the **interactor**, so objects know *who* used them (player now, NPCs later).

---

## 3. HUD + EventBus

**Built:** an `EventBus` autoload (global signals) and a HUD showing a crosshair and an interaction prompt (`E  Pick up Iron Dagger`).

**Decision:** systems talk through the EventBus instead of referencing each other directly, so the HUD doesn't need to know the interaction system exists.

---

## 4. Items

**Built:** `ItemData` / `WeaponData` as custom **Resources**, item definitions stored as `.tres` data files, and a `Pickup` scene for items in the world.

**Decisions:**
- **Data-driven items:** a new item is a new data file, not new code.
- **Definition vs. instance:** the `.tres` is the item's definition. The inventory only references it, never copies it.

**Problems & fixes:**
- **Crash after picking up an item:** the ray still held a reference to the freed pickup. Fixed by listening to the target's `tree_exiting` signal and checking `is_instance_valid()` before interacting.
- **Double pickup:** one item could be picked up twice in the same frame. Fixed with a `_taken` guard flag.

---

## 5. Inventory (logic)

**Built:** an `Inventory` component with stacking (`max_stack`), Skyrim-style weight tracking, `add_item`, `remove_item`, `count_of`, `has_item`.

**Decisions:**
- **Weight-based limits** (like Skyrim) instead of a slot grid. Limits create meaningful choices about what to carry.
- **Compare items by `id`**, not by object reference, so it will keep working after save/load.
- **Direct calls for transactions, EventBus for announcements:** the pickup adds to a *specific* inventory directly, then announces "item picked up" globally.

**Problems & fixes:**
- **Atomic removal:** `remove_item` validates first and either removes everything or nothing, so no half-finished trades.
- **Removing while iterating:** the loop runs backwards so deleting empty stacks doesn't skip elements.

---

## 6. Inventory UI, using & dropping items

**Built:** an inventory screen (Tab / I) with an item list, details panel, category tabs, using items (double-click / Enter) and dropping items (R). Added a reusable `Health` component and `ConsumableData` (health potion).

**Decisions:**
- **Model–View separation:** the screen only displays the inventory and redraws on its `changed` signal. It never edits data directly. It asks the player, and the player decides.
- **Pause via Process Mode:** the world pauses, the menu runs with `Process Mode = Always`.
- **Data-driven tabs:** category tabs are generated from the `ItemData.Category` enum, so a new category automatically gets a tab.
- **Polymorphic item use:** each item type overrides `use()` (Open/Closed Principle). New item types need no changes to the player, inventory or UI.
- Potions are **not consumed at full health**: a small fairness choice.
- **Remove before spawn** when dropping, so a failed removal can never duplicate an item.

**Problems & fixes:**
- **Tab opened the menu but couldn't close it:** the focused `ItemList` consumed Tab for UI focus navigation before `_unhandled_input` ran. Fixed by handling the toggle in `_input`, which runs before the GUI.
- **Potion fields reset to defaults:** swapping a `.tres` file's script from `ItemData` to `ConsumableData` dropped its saved values. Re-entered them; new item types are now created with the right type from the start.

**Learned:** Godot's input pipeline: `_input` → GUI → `_shortcut_input` → `_unhandled_input`.

---

## Ideas for later
- Ask "how many?" when dropping a stack
- Make dropped items physics objects that fall
- Check for walls before spawning dropped items
- A shared **magic effects** system for potions, spells and enchantments (like Skyrim)
