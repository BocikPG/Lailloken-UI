## About:
A light-weight AHK script with UI and QoL features for Path of Exile, emphasizing ease-of-use, minimalist design, low hotkey requirements, and seamless integration into the game-client. This project is **`not`** affiliated with or endorsed by Grinding Gear Games (GGG) in any way.  
<br>

## Download & Setup
[![img](https://github.com/Lailloken/Lailloken-UI/blob/beta/img/readme/autohotkey.png)](https://www.autohotkey.com/download/) [![img](https://github.com/Lailloken/Lailloken-UI/blob/beta/img/readme/guide.png)](https://github.com/Lailloken/Lailloken-UI/wiki) [![img](https://github.com/Lailloken/Lailloken-UI/blob/beta/img/readme/download.png)](https://github.com/Lailloken/Lailloken-UI/archive/refs/heads/beta.zip)  
[![img](https://github.com/Lailloken/Lailloken-UI/blob/beta/img/readme/help.png)](https://github.com/Lailloken/Lailloken-UI/wiki/Known-Issues-&-Limitations) [![img](https://github.com/Lailloken/Lailloken-UI/blob/beta/img/readme/releases.png)](https://github.com/Lailloken/Lailloken-UI/releases) [![img](https://github.com/Lailloken/Lailloken-UI/blob/beta/img/readme/changelog.png)](https://github.com/Lailloken/Lailloken-UI/blob/main/data/changelog.json)
<br>
<br>

## Ideas & Feedback
I am very open to suggestions and ideas from other players. So if you have ideas on how to improve PoE-gameplay or this script, post them in the [ideas & feedback section](https://github.com/Lailloken/Lailloken-UI/discussions/categories/ideas-feedback).
<br>
<br>

## Philosophy, Motivation, Contributions
This project is my personal collection of UI and QoL features to improve the PoE gameplay experience. I am a self-taught tinkerer, and this is simply a fun project and learning experience for me that I decided to share for feedback and new ideas. It doesn't have a clearly defined scope but instead contains all kinds of features (both conventional and experimental) that reflect how I approach certain problems that I or other players come across while playing PoE.

I will not be taking direct code input or optimizations from people because learning-by-doing and problem-solving is what makes this project fun for me. I appreciate the fact that my project motivates people to work on it as well, but having to go through, double-check, and test other people's code sounds like a chore to me.
<br>
<br>

## Transparency Notice / Things you should know
- I'm in no position to claim whether or not this tool will get you banned, GGG has the final say

- all I can say is that I strictly follow GGG's official third-party policy regarding executable apps: [developer docs](https://www.pathofexile.com/developer/docs/index#policy)
- creation and publication of apps that violate the guidelines is as punishable as their usage, so it's in my best interest to adhere to them
<br>

- this tool reads the game's client.txt log-file while you're playing to:
  - track your character's in-game location and level
 
  - track character-deaths and monster-kills (kills are tracked on-demand after prompting the user to activate a macro with the /kills command)
- it automates the following key-inputs `exclusively after being initiated manually by the user`:
  - `CTRL + ALT + C` to copy item information from the client
 
  - `CTRL + F`, `CTRL + V`, `Enter` to initiate in-game searches in interfaces that support it
  - `Enter`, `CTRL + A + V`, `Enter` to paste chat-commands built into the game
- it reads the screen exclusively for context-assessment
  - in the background: to check if **`something within the script itself`** needs to be toggled on/off, e.g. hiding an overlay that would otherwise block an in-game interface
 
  - after pressing the `omni-key`: to determine the context of why/when it was pressed, e.g. while interacting with certain NPCs, or looking at / interacting with a specific interface
  - I want to stress that it merely searches for open interfaces/windows/panels, it **`does not`** read values or bars off the screen
- however, this context-assessment is not used to cycle between actions that affect or influence the game in any way
<br>

## Main Features
\* = based on a user-request
### [Clone-frames](https://github.com/Lailloken/Lailloken-UI/wiki/Clone-frames): pseudo interface-customization, functionally similar to 'Weakauras'  
![image](https://user-images.githubusercontent.com/61888437/167854263-ce6c5da5-e5fa-4f4d-9ff9-f544859fa170.png)  
<br>

### [Item-info](https://github.com/Lailloken/Lailloken-UI/wiki/Item-info): compact & customizable tooltip to determine loot quality at a glance
| segments ||
|---|---|
| DPS info | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/a1ba26c1-caf3-454f-b0db-a6382fc6fa35) |
| item-base info (optional) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/64ee0282-1cbd-464f-94d9-9de8d79f1e66) |
|   | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/ce61b656-474e-4ce3-871c-0124377d64ce) |
| comparison with current gear (optional) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/03ae8243-bdac-4f06-be2f-f3ab43365380) |
| eldritch implicits, (un)desired highlighting | ![image](https://user-images.githubusercontent.com/61888437/224276010-99ce801f-e2d8-4c99-af37-026a1847abe2.png) |
| explicits, rolls, (un)desired highlighting | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/e449237e-62ef-4abb-951a-f1b1b3b8631d) |
<br>

### [Context-menu](https://github.com/Lailloken/Lailloken-UI/wiki/Minor-Features) for items: single-hotkey access to features and popular 3rd-party websites  
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/c778ea69-346e-47de-8f1b-ce5f69668557) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/8ed592d5-fe0e-4aeb-b511-cee4f610da3d) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/e12e66f6-ffad-4a79-b402-ac1844b5e385) |
|---|---|---|
<br>

### [Search-strings](https://github.com/Lailloken/Lailloken-UI/wiki/Search-strings): customizable, single-hotkey menu for every individual in-game search  
| regular stash | vendor | Gwennen | beast-crafting |
|---|---|---|---|
| ![image](https://user-images.githubusercontent.com/61888437/214894515-609be1ef-1b7a-40d2-afe4-8fa6374d5442.png) | ![image](https://user-images.githubusercontent.com/61888437/214895726-1a1c93d9-7183-40ca-bd6d-2da446169286.png) | ![image](https://user-images.githubusercontent.com/61888437/214895979-0df171e8-b7f3-4f8a-873b-14ade78306b3.png) | ![image](https://user-images.githubusercontent.com/61888437/170810022-cda485de-8be9-4b78-b98e-b2481a809475.png) |
<br>

### [Leveling tracker](https://github.com/Lailloken/Lailloken-UI/wiki/Leveling-Tracker): leveling-related QoL features
| \*dynamic/automatic guide overlay based on [exile-leveling](https://heartofphos.github.io/exile-leveling/) | gear tracker with notifications (twink-leveling) |
|---|---|
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/3ae5c527-fc39-45b7-9171-b7271891a055) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/d8732c5f-dcd2-47e6-aef6-55b60afac6e0) ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/a99acf8a-1768-4487-ab1a-1bb1b7e7322f) |

| single-hotkey skilltree overlays | search-strings to bulk-buy every gem in a build |
|---|---|
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/1c13825c-becc-45a8-b6c7-ef5e0d205846) | ![image](https://user-images.githubusercontent.com/61888437/215315302-43ffc89f-6aeb-403e-adf3-cac45928137d.png) |
<br>

### [Cheat-sheet Overlay Toolkit](https://github.com/Lailloken/Lailloken-UI/wiki/Cheat-sheet-Overlay-Toolkit): create customizable, context-sensitive overlays
| types | example 1 | example 2 |
|---|---|---|
| image-based overlay | ![image](https://user-images.githubusercontent.com/61888437/223756256-1e5577a6-2690-41bc-8de9-2ac8bf66816b.png) | ![image](https://user-images.githubusercontent.com/61888437/224283025-0f17b626-0973-4d44-b80b-796613156eec.png) |
| app-based "overlay" | ![image](https://user-images.githubusercontent.com/61888437/223783668-56eb423f-2ce9-46fd-9cc3-155efc2166e2.png) | ![image](https://user-images.githubusercontent.com/61888437/224286060-20fb2b9e-9345-4c60-86ff-33a6139dcc0b.png) |
| advanced overlays | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/2c01c548-1163-4551-97da-2d5899fdba1a) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/d955f65b-b31f-4525-9fbf-9e7a6ab90eb0) |
<br>

### \*[Mapping tracker](https://github.com/Lailloken/Lailloken-UI/wiki/Mapping-tracker): collect, save, view, and export mapping-related data for statistical analysis
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/d3a59541-0c13-487e-99da-198a62777c75) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/8cdf2e78-43e1-465d-a61f-c58f263182db) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/209f7650-753f-4997-88a0-7bba23dbc6e7) |
| --- | --- | --- |
<br>

### Overhauled [map-info panel](https://github.com/Lailloken/Lailloken-UI/wiki/Map-info-panel): streamlined & customizable map-mod tooltip and panel
| tooltip for rolling maps | on-demand panel to quickly re-check mods while mapping |
|---|---|
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/d59f8c12-45df-4ac7-a1ab-1035020e9f89) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/0205cd5c-6891-4905-ae9b-7acdbf34ace0) |
<br>

### [Betrayal-info](https://github.com/Lailloken/Lailloken-UI/wiki/Betrayal-Info): streamlined & customizable info-sheet (with optional image recognition)  
| simple overlay + customization | on-hover overlay + board tracking |
|-------------------------------|-----------------|
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/c69c0459-cef7-431c-ba8a-2e39961046ec) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/7402bdce-3bdf-4d4b-8455-b523fd14ff4a) |
<br>

### [Seed-explorer](https://github.com/Lailloken/Lailloken-UI/wiki/Seed-explorer): in-client UI to quickly check the effects of a Legion seed across the skill-tree  
![Untitled 17](https://github.com/Lailloken/Lailloken-UI/assets/61888437/d96916c5-37b4-4b2c-9067-2db25a28c2ac)  
<br>

### Several minor [QoL features](https://github.com/Lailloken/Lailloken-UI/wiki/Minor-Features):  
| essence tooltip to check the next tier's stats | orb of horizons tooltips |
| --- | --- |
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/d02e44af-a2e5-47f0-a131-5911eb4e5c17) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/2cab2ac3-fde1-4231-98bd-d530a76d9775) |

| in-client notepad & free-floating sticky-notes | countdown/alarm timer & stopwatch |
| --- | --- |
| ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/24ceac77-d36a-4852-b043-78ce95aaadb7) ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/729ccd86-e053-4c8f-a98f-ff670fd2ebb9) | ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/48c1e7bf-063b-4dd3-8a3f-102d036b620e) ![image](https://github.com/Lailloken/Lailloken-UI/assets/61888437/a0376025-a5b3-496e-9266-be1490dabd12) |

| quick-access overlay and tracker for casual lab-runs |
| --- |
| ![image](https://user-images.githubusercontent.com/61888437/219877353-6b8a56b9-ae3c-4470-98c6-05f298d0ace3.png) |
<br>
<br>

## Acknowledgements
- `item-info` uses a custom version of [Path of Building's](https://github.com/PathOfBuildingCommunity/PathOfBuilding) datamined resources

- `leveling tracker` uses leveling guides generated via [exile-leveling](https://github.com/HeartofPhos/exile-leveling) and was implemented with the help of its maintainer
- `seed-explorer` uses a custom version of the timeless-jewel databases provided via [TimelessJewelData](https://github.com/KeshHere/TimelessJewelData)
<br>

## Legacy Features:
| [Archnemesis Recipe Helper/Scanner](https://github.com/Lailloken/Lailloken-UI/wiki/%5BArchive%5D-Archnemesis) | \*[Overlayke: Kalandra Planner/Preview Overlay](https://github.com/Lailloken/Lailloken-UI/wiki/%5BArchive%5D-Overlayke) |
|---|---|
| ![Archnemesis UI](https://user-images.githubusercontent.com/61888437/165942652-07ff9ee1-3108-44ce-8291-5a1afff5720f.jpg) | ![Overlayke](https://user-images.githubusercontent.com/61888437/186435575-4b67b189-25de-426f-a045-24fef5d725ed.png) |

| [Sanctum-room tooltip overlays](https://github.com/Lailloken/Lailloken-UI/releases/tag/v1.29.4-hotfix2) | [Recombinator calculator](https://github.com/Lailloken/Lailloken-UI/wiki/%5BArchive%5D-Recombinator-calculator) |
|---|---|
| ![image](https://user-images.githubusercontent.com/61888437/214906646-3a00a938-c955-48ce-8717-ec9a2d17bf4c.png) | ![image](https://user-images.githubusercontent.com/61888437/172839566-ea8295aa-b252-4889-93db-be5eca284a04.png) |

| [Delve-helper](https://github.com/Lailloken/Lailloken-UI/wiki/%5BArchive%5D-Delve-helper): in-game UI to help you find secret passages |
|---|
| ![image](https://user-images.githubusercontent.com/61888437/182579413-50e1994a-768c-4e03-ab7f-46c32ec04829.png) |
<br>
