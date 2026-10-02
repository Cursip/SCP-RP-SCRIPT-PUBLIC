# <SERVER NAME> - Free Scripts for All Kinds of Games

## 1. SERVER IDENTITY

Name ideas: Script Vault, FreeScripts Hub, The Script Bazaar, OpenScripts, Script Depot

Short description (Discovery field, about 120 characters):
Free scripts for all kinds of games. Clean sources, no key systems, no malware. Upload, request and share.

Long description / About:
Welcome to <SERVER NAME> - a library of free, community-made scripts for all kinds of games.

What you get here:
- Free scripts with readable source, no key systems, no ads, no paywalls
- A dedicated channel per game category, plus an archive
- Honest feature lists and real version numbers, so you always know what you run
- Requests: ask for a script and someone may build it
- A clean, moderated place: no malware, no token grabbers, no fake releases

What you will not find here:
- Anything that attacks a game's servers or other players' accounts
- Obfuscated payloads without disclosure
- Paid, key-gated or DM-botted downloads

How to start:
1. Read #rules
2. Accept the rules in #verify to get verified
3. Pick your game roles in #roles to be pinged for what you play
4. Grab scripts in the script channels

## 2. ROLES (top to bottom)

Owner          #E74C3C  - administrator, everything
Admin          #E67E22  - manage server, manage roles, ban (trusted leads only)
Moderator      #F1C40F  - kick, timeout, manage messages, manage nicknames
Helper         #2ECC71  - support only, no moderation powers
Uploader       #9B59B6  - may post in the script channels (send messages, attach files)
Tester         #1ABC9C  - checks scripts in #script-review before release
Booster        #EB459E  - Nitro boosters, cosmetic plus private chat
Verified       #3498DB  - normal member, full access to community channels
Unverified     #95A5A6  - default on join, sees #rules and #verify only
Announcements  #5865F2  - opt-in ping
Game pings              - @Roblox, @FPS, @Minecraft, @Sandbox, @Mobile (self-assign in #roles)

## 3. CHANNELS

INFORMATION
  #welcome          - welcome text plus verification button
  #rules            - the rules
  #announcements    - read-only, Announcements role pinged
  #script-updates   - new and updated scripts, Uploader only

VERIFICATION
  #verify           - rules screening or button verification
  #roles            - self-assign game ping roles

COMMUNITY
  #general
  #off-topic
  #showcase         - clips and screenshots
  #support          - questions about any script

SCRIPTS
  #scripts-roblox
  #scripts-fps
  #scripts-minecraft
  #scripts-other
  #requests         - "does anyone have a script for X?"
  #archive          - old or outdated scripts

STAFF
  #staff-chat
  #staff-logs       - moderation log webhook
  #reports
  #script-review    - staging before something goes public

TICKETS
  #open-a-ticket    - ticket panel

## 4. VERIFICATION (pick one, or combine A and C)

A. Discord's native membership screening, no bot needed
   Server Settings > Safety Setup > Membership Screening > enable, add the rules,
   require members to agree. Everyone with Unverified must accept before they can
   read anything else. Set Auto-Role to Unverified and let screening give out Verified.

B. Button verification with a bot (Wick, Carl-bot, Sapphire, MEE6)
   1. Create #verify and deny @everyone Send Messages there.
   2. Post an embed with a button:
      Title: Verification
      Text: Click below to confirm you have read #rules and agree to them.
      Button: Verify
   3. The button grants Verified and removes Unverified.
   4. Optional: require an account age of 7+ days to reduce raid and alt accounts.

C. Reaction roles in #roles (Carl-bot or MEE6)
   Checkmark: Verified
   Game pad: Roblox   Target: FPS   Pickaxe: Minecraft   Test tube: Sandbox
   Phone: Mobile      Megaphone: Announcements

## 5. RULES (#rules)

1. Be respectful. No harassment, hate speech, discrimination or drama.
2. No NSFW, no illegal content, nothing that breaks Discord's Terms of Service.
3. NO MALWARE. Token grabbers, cookie loggers, stealers, RATs, miners, hidden
   payloads and fake "key" sites are an instant permanent ban, no appeal.
4. Every script post needs: what it does, which game, a readable source link
   (GitHub, Gist or Pastebin) and a version. Obfuscated files must be labelled as
   obfuscated and may be removed without warning.
5. No .exe, .dll or other executables. Scripts only.
6. Credit the original author. Do not re-upload someone else's work as your own.
   If an author asks for removal, we remove it.
7. Free only. No selling, no paywalls, no key systems, no "join X to unlock".
8. No advertising other servers, no DM advertising, no unsolicited DMs to members.
9. No spam. Support questions go to #support, requests to #requests.
10. You use every script at your own risk. Using scripts can violate a game's rules
    and can get your account banned. That risk is yours.
11. No doxxing and no sharing of private information.
12. Staff decisions are final. Appeals go through a ticket, not the chat.

## 6. SCRIPT POST TEMPLATE (pin this in every script channel)

**<Script name>**  -  v1.0
Game(s): <game(s)>
Type: <aim / ESP / utility / automation>

Features
- <feature>
- <feature>

Load: `loadstring(game:HttpGet("<raw url>"))()`
Source: <GitHub link>
Build stamp: <e.g. shows v4.6-beta2 in the title bar>
Notes: <config location, keybinds, known limits, risk notes>

## 7. WELCOME MESSAGE (#welcome)

Welcome to <SERVER NAME>, <@user>!

You are one click away from the script library:
1. Read #rules
2. Verify in #verify to unlock the server
3. Grab your game roles in #roles
4. Browse the script channels and enjoy

Everything here is free - no keys, no ads, no paywalls.
If a script does not work, ask in #support or open a ticket.

## 8. BOTS WORTH HAVING

Verification button and auto roles - Wick, Carl-bot, Sapphire
Reaction roles - Carl-bot, MEE6
Moderation and log - Wick, Dyno
Tickets - Ticket Tool
Announcements and auto-publish - Wick, MEE6
Script hosting - GitHub raw, Gist or Pastebin links rather than Discord attachments

## 9. TWO THINGS THAT KEEP A SCRIPT SERVER ALIVE

Pinned posting format: it removes "what does this do?" and "is this a grabber?"
replies, and it makes the server look serious next to the usual chaos.

An actually enforced malware rule: script servers are the prime target for token
grabbers reposted as "free scripts". One of those and your members lose their
Discord accounts, which kills a server faster than any raid.
