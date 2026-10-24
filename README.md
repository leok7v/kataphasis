# Kataphasis

**Kataphasis** [kuh-TAF-uh-sis], *noun*: the understanding of
something unseen through the visible ways it reveals itself.
(Definition from an unattributed modern text.)

Kataphasis is a quiet way to search the web. You type a question, and
it gives you the answers as plain text: no video, no sound, nothing
that moves. You can also type a web address (https://...) and read
that one page the same way.

It was written for a person with a silent mind (aphantasia, anauralia
and anendophasia), who cannot take in a web page while video or audio
plays on it, but still needs what the page says. It may help anyone
who finds busy pages hard to read.

## What it does

- Searches DuckDuckGo (or Google, see below) in a hidden browser.
- Collects the results you ask for (10 by default; "More results"
  fetches the next batch).
- Opens every result page out of sight and keeps only its words: a
  short description and the full text.
- Shows three calm panes: the list of results, the text of the one you
  select, and a single page with every result that you can expand.

Video and audio are blocked before they load. Nothing on screen
animates. Live page thumbnails stay off unless you turn them on with
the eye button.

## Privacy

- Every session is private: cookies, cache and storage live in memory
  only. The flame button wipes them.
- The result pages are read in a separate private store, so they never
  see the search engine's cookies.
- Third-party cookies are blocked. The app sends the Global Privacy
  Control signal.
- Result links go straight to the site, not through the search
  engine's click tracking.

## A note on Google

DuckDuckGo is the default and works well. Google is available as a
choice, but Google's Terms of Service forbid automated access to its
search pages, and Kataphasis reads those pages with a script. Use the
Google option knowing that, and expect Google to ask for a captcha now
and then.

## Install

macOS 14 or later, Apple Silicon or Intel. Download Kataphasis.dmg
from the [latest release](https://github.com/leok7v/kataphasis/releases/latest),
or install it with Homebrew:

    brew tap leok7v/tap
    brew trust leok7v/tap
    brew install --cask kataphasis

The middle line is Homebrew's gate on taps that are not its own.
Homebrew asks for it by name if you skip it. The app is signed with a Developer
ID certificate and notarized by Apple.

## Build and run

macOS 14 or later, with the Swift compiler from Xcode or the command
line tools. The quickest way needs no Xcode project:

    swiftc -parse-as-library -O kataphasis.swift -o kataphasis
    ./kataphasis

For a real app bundle (Dock icon, Finder, Launchpad), generate an Xcode
project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

    xcodegen generate
    open Kataphasis.xcodeproj

## How it reads a page

Kataphasis does not depend on the class names of any site. It finds
search results by their shape (a link with a heading that leads off
the search engine) and finds the main text of a page by where the
paragraphs gather. When a site changes its design, the reader has a
good chance to keep working.

Some sites refuse automated readers, and their pages show as "could
not be read". Open those in your own browser from the result link.
