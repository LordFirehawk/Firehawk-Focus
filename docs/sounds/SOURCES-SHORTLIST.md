# Ambient recording shortlist

Current implementation: 34 recordings. Soft Café (`cafe`, Berwitz 263584), Croaky frogs (`bullfrogs`, reinsamba 58236 replacing rejected madamdata 750818), and Night frogs (`night-frogs`, mycompasstv 462889) were user-approved after listening on 2026-10-27. The whole Ambience library ships as Apple Lossless CAF. The dated research sections preserve earlier screening decisions; later sections supersede earlier absent or deferred statuses.

Checked 2026-10-26. Specifications below describe the acquired input, measured with macOS `afinfo`, rather than the CAF delivery. Rates are in Hz. All downloads and saved license pages are outside git under `~/FirehawkAudioWork/raw/<source>/<id>/`. Source material was treated as data; Python readers ran with `python3 -I`.

The choices are based on source descriptions, rights evidence and signal measurements. No human listening approval is claimed. Speech, music, traffic, startling events and subjective loop quality still need listening checks. Each shipped addition has an un-looped selection in `~/FirehawkAudioWork/audition/`.

## Rain

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [rain ambience, 524605](https://freesound.org/s/524605/), acquired from pinned Blankie redistribution | alex36917; Porrumentzio / Blankie edits | `ccBy4` in [pinned sounds.json](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json), meaning CC BY 4.0 | AAC/M4A, 44100, stereo, 92.261 s | Added as Gentle rain. Described as light to medium rain with some thunder. Upstream removed the later train horn. Selected seconds 33 to 73 of that derivative, away from its edges. Complete attribution, license URL and edit notice ship in the catalog. Original Freesound page was deliberately not requested. |
| [Rain at Devils Postpile](https://www.nps.gov/subjects/sound/sounds-rain.htm) | NPS | NPS credit on the item; the [gallery](https://www.nps.gov/subjects/sound/gallery.htm) explicitly puts its recordings in the public domain | MP3, 44100, mono, 4.963 s | Described as light rain drumming. Not added because five seconds gives too little variation and a very repetitive loop. |

The preferred Light Rain by soundrecorder7, 167034, is absent from both checked upstream catalogs. Its original specifications and license were not reverified because Freesound requests are prohibited. It was not downloaded.

## Fire

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Fireplace](https://soundbible.com/1543-Fireplace.html) | ezwa | The individual page states Public Domain | PCM16 WAV, 44100, mono, 25.496 s | Added. Described as small crackles, sizzling and air movement, providing recognizable fire character. Seconds 1 to 25 produce a 22 s loop. It is a different recording from the preferred ceich93 file. |
| [Woodstove](https://www.nps.gov/media/video/view.htm?id=1E69FA23-BC88-460E-8EFD-8D3BA8B06C53) | NPS & MSU Acoustic Atlas | Blankie labels its derivative Public Domain, but the original page has a joint third-party credit and warns against assuming third-party rights | MP3, 44100, stereo, 36.804 s | Excluded. Its license evidence is insufficient under this task's per-file rule. |

The preferred fire_crackling by ceich93, 263864, is absent from both checked catalogs. No request was made for it and no preview was used.

## Thunder

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Thunder](https://www.nps.gov/media/video/view.htm?id=0643C010-FA65-BB84-75FFE70DD85F8835) | NPS, Natural Sounds and Night Skies Division | Individual page credits NPS without a copyright symbol and explicitly states such material is public domain | MP3, 44100, mono, 46.028 s | Added as Rolling thunder. The transcript describes rain and rolling thunder. Seconds 3 to 43 give a 38 s loop; peak reduction controls transients. Potentially distracting for users sensitive to thunder; audition first. |

## Cafe

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Restaurant Ambiance](https://soundbible.com/1664-Restaurant-Ambiance.html), measured via Blankie's pinned coffee-shop derivative | stephan | Individual SoundBible page states Public Domain | AAC/M4A, 44100, stereo, 12.821 s | Not added. Described as people talking with indistinct words. The recording is short, and the description does not establish a quiet room free of music or frother noise. It does not meet the user's preference well enough to fill the category. |

Cafe remains unfilled. Rejected waweee 370973 was not downloaded or requested.

## Forest and wind in trees

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Yellowstone dawn chorus](https://www.nps.gov/media/video/view.htm?id=BEA6A752-BCEB-421B-8123-39917AA6223E) | NPS/Jennifer Jerrett | Individual page credits NPS without a copyright symbol and states public-domain use; Yellowstone library also explicitly permits unrestricted use | MP3, 44100, mono, 62.131 s | Added as Yellowstone dawn. Transcript identifies multiple birds and woodpecker drumming. Seconds 20 to 60 provide distinct animal sounds rather than a wind-only hiss. |
| [Forest Ambience](https://opengameart.org/content/forest-ambience) | TinyWorlds | Individual submission states CC0 | MP3, 48000, stereo, 44.760 s | Not added. Created for a game and categorized as Music. The page does not establish an unprocessed nature recording without musical content. Its license is suitable, but suitability needs listening. |

Existing Pine branches remains the wind-in-trees option. Rejected deadrobotmusic 687054 was not requested. A second OGA page, Peaceful Forest by Samza, explicitly describes a song with strings and was screened out before audio download.

## Other nature

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [American green tree frog](https://www.nps.gov/media/video/view.htm?id=8EB67639-55FE-4B2B-9A2C-D779BAAB0C73) | NPS / Theresa Thom | Individual page credits NPS and states public-domain use; also part of the explicitly public-domain Natural Sounds gallery | MP3, 44100, mono, 9.979 s | Added as Everglades tree frogs. Rhythmic calls offer distinct character with little need for a noise bed. Its eight-second loop is short and could become repetitive; this tradeoff is visible in the audition. |

No additional water recording was added. The existing Woodland stream remains available. Wikimedia Commons was not needed after these sources yielded licensed candidates.

## Network record

Zero requests to Freesound pages, API or CDN. No 403, 429 or captcha was encountered on the contacted sites, and no retry loop was used. One guessed NPS wind URL returned 404 and was not retried.

Approximate request totals, including Git protocol negotiation and research-tool page reads: github.com 18, raw.githubusercontent.com 3, nps.gov 16, soundbible.com 3 to 4 including the WAV redirect, opengameart.org 3. Two search-engine queries were used. Search results were not followed to Freesound. Counts for Git and redirects are estimates; the direct-download log is `~/FirehawkAudioWork/requests.jsonl`. New HTTP acquisitions used an identifying browser-style User-Agent and spacing of at least about two seconds per host. Git clones fetched only explicitly selected metadata blobs; no downloaded repository code was executed.

## Train on tracks, 2026-10-26

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Knocking wheels of train, recorded in wagon](https://commons.wikimedia.org/wiki/File:%D0%A1%D1%82%D1%83%D0%BA_%D0%BA%D0%BE%D0%BB%D1%91%D1%81_%D0%BF%D0%BE%D0%B5%D0%B7%D0%B4%D0%B0.ogg?oldid=456509667) | Ural-66 | The file page explicitly states CC0 1.0, with the same license in structured metadata | Downloaded Wikimedia MP3 transcode, 44100 Hz, stereo, 240.692 s estimated by afinfo; 240.664671 s decoded. Original Ogg not downloaded | Added as `train`. The source specifically identifies carriage wheel knocks. Seconds 45 to 105 have steady energy and repeated broadband transients consistent with wheel clatter, with no pass-by envelope. Two-second equal-power overlap yields 58 s. Source description and signal inspection are a good fit; absence of announcements or horns still needs listening confirmation. |
| [Trains of the Yamanote Line](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json), SDLx 259988 | SDLx; redistributed by Blankie and Blanket | Pinned per-file metadata states `ccBy3`; Blankie's License.swift maps this to CC BY 3.0. Blanket's SOUNDS_LICENSING.md independently agrees | AAC/M4A, 44100 Hz, stereo, **61.600 s measured**, despite 568.437 s in the metadata | Excluded. Two roughly 17-second passing-train groups with a quiet gap, rather than a stable 40+ second section. No original Freesound page was requested. |

`tram.fill` is available since macOS 10.15. Added the `travel` category with title Travel; existing raw category values remain unchanged.

## Calm beach waves, 2026-10-26

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [oceanwavescrushing.wav, 48412, via pinned Blankie metadata](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json) | Luftrum; edited by Porrumentzio / Blankie | Per-file `ccBy4` label, mapped to CC BY 4.0 by License.swift | AAC/M4A, 44100 Hz, stereo, 115.429138 s | Added as `beach-waves`. The description identifies waves on a stony fjord shore and water retreating through stones. Seconds 20 to 80 avoid the strongest group at 84 to 93 seconds. One-second energy varies by about 15 dB in this selection, consistent with separate breaking/retreating events rather than a constant noise bed. A two-second overlap produces 58 s. Gentle character and audible individual waves require listening approval; level matching alone cannot establish either. This is a different recording from rejected Rmutt 156598, which was never requested. |

`water.waves` is available since macOS 13.0. Full CC BY 4.0 attribution, source, license link and edit notice are in the catalog and CREDITS.md. The original master was not acquired; the hash pins Blankie's AAC derivative.

## Seagulls, 2026-10-26

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Shoreline Rhapsody](https://www.nps.gov/media/video/view.htm?id=F5650E68-1DD8-B71C-07CF2F535745CB8E) | H. Lentfer / NPS | Individual page credits NPS without a copyright symbol and explicitly states that such material is public domain | MP3, 44100 Hz, stereo, 344.933 s estimated by afinfo; 345.313 s decoded | Added as `seagulls`. Transcript identifies Bonaparte's gulls above gently lapping water, with other seabirds and occasional animal breaths across the full recording. Selects 48 to 108 seconds, before the dense later calls. Both one-second overlap regions have low energy and no sustained tonal call in spectral inspection. The 59 s loop preserves several separated events. This remains a coastal recording with water underneath, rather than isolated gull stems. Species identity, absence of distractions and intact calls across repeated seams need listening confirmation. |
| [Sounds Along the Seashore](https://www.nps.gov/media/video/view.htm?id=575B29C3-A2BB-4D59-9E33-24959C588469) | NPS hosting program, Island of the Blue Dolphins; no individual recording credit on the file page | Page gives conditional NPS public-domain guidance but omits a Credit field. Hosting alone is insufficient to establish authorship | MP3, 48000 Hz, stereo, 601.944 s | Excluded. Transcript identifies western gulls and waves, but the missing per-file creator credit leaves the rights evidence incomplete. The downloaded file remains outside the app. |

`bird` is available since macOS 13.0. It is an independently controlled layer, so gull volume can be set separately from beach waves.

## Farm, 2026-10-26

| Candidate and source | Creator | Per-file license evidence | Input | Fit and decision |
| --- | --- | --- | --- | --- |
| [Farm](https://soundbible.com/1662-Farm.html) | stephan | Individual page states Public Domain | PCM16 WAV, 44100 Hz, stereo, 16.661542 s | Not added. Farm animals, primarily sheep and goats, match the subject. Too short for varied sparse calls without a prominent repeat. |
| [On The Farm](https://soundbible.com/1632-On-The-Farm.html) | stephan | Individual page states Public Domain | PCM16 WAV, 44100 Hz, stereo, 7.784490 s | Not added. Sheep, goats and birds, but less than eight seconds of material. |
| [Chickens](https://www.nps.gov/subjects/sound/sounds-chickens.htm) | NPS | Individual item credits NPS; the Natural Sounds gallery expressly places its recordings in the public domain | MP3, 44100 Hz, mono, 5.329 s | Not added. Only a short chicken squawk effect, not calm varied farmyard ambience. |

Farm is left out rather than stretching or repeating short animal effects. No `farm` placeholder or catalog entry was added.

## Acquisition and inspection record for this pass

Zero requests to Freesound pages, API or CDN. No blocked site, 403, 429 or captcha challenge was encountered. No retry loops, bulk scraping or downloaded code execution. The Commons page includes its normal upload-captcha configuration; no captcha was presented for these read/download requests.

Direct HTTP requests were logged in `~/FirehawkAudioWork/requests-coast-farm.jsonl`, with a browser-style User-Agent and at least 2.1 seconds between requests to a host. Totals were raw.githubusercontent.com 2, www.nps.gov 6, soundbible.com 5 plus approximately 2 WAV redirects, commons.wikimedia.org 1, upload.wikimedia.org 1. Research-tool page opens add 2 SoundBible, 1 Commons and 1 OpenGameArt reads. Twenty-one search queries were used; search-result links to Freesound were never opened. Per-site counts remain below 40. Existing local Git metadata supplied Blankie and Blanket credits without additional GitHub requests. Download inputs and page evidence are under `~/FirehawkAudioWork/raw/<source>/<id>/`; all Python readers used `python3 -I`.

No listening audition was possible in this agent session. Selection uses source descriptions/transcripts, decoded duration, energy and spectral inspection. The three additions remain audition assets, with un-looped level-matched AAC copies at `~/FirehawkAudioWork/audition/{train,beach-waves,seagulls}.m4a`. Automated tests verify format, measured levels, file completeness and sample continuity. They cannot certify absence of voices, gentle timbre, or whether an animal call becomes repetitive.

Symbol minimum versions were checked against Apple's installed public CoreGlyphs `name_availability.plist` and `year_to_release` mapping. Asset tests also resolve all catalog symbols through AppKit.

## Lazy-library acquisition pass, 2026-10-26

This pass adds six layers. The following decisions supersede earlier capacity
limits, not earlier provenance. All source inputs remain outside the repository.
The choices use descriptions, per-file rights evidence, and signal inspection;
no human listening approval is claimed.

### Rain on a tent or window

- Added **Rain on a tent**, luc de bruijn's [Regen in de tent](https://commons.wikimedia.org/wiki/File:Regen_in_de_tent_-_SoundCloud_-_luc_de_bruijn.ogg), CC BY 3.0. The file page identifies rain heard inside a tent in the Netherlands. The 481 s source gives ample selection room. Acquired its Wikimedia MP3 transcode, selected 21–75 s, prepared a 52 s loop. This is a different recording from soundrecorder7's Light Rain. Complete attribution and edit notice ship in the catalog.
- [Rain Inside House](https://soundbible.com/2065-Rain-Inside-House.html), Mark DiAngelo, CC BY 3.0, is described as rain without background noise. Not acquired because the page does not establish a tent/window surface or distinct drop character beyond the selected tent recording.

### Rain on a tin roof

- [Moderate rain on a tin roof loop](https://opengameart.org/content/moderate-rain-tin-roof-loop), thebardofblasphemy, GPL 2.0. Excluded: OpenGameArt is permitted only for CC0 here, and the published loop is only a few seconds. The longer original is not posted.
- Rain Inside House above is allowed but its recording surface is unspecified. Not renamed as tin-roof rain. This slot stays empty.

### Library / reading room

No suitable long, quiet, speech-free recording was identified in the checked Blankie/Blanket metadata or the targeted Commons search. The existing Restaurant Ambiance explicitly contains conversation and is not a substitute for a reading room. No layer added.

### Typing and turning pages

- Added a combined **Typing and turning pages** layer from [Keyboard Soundpack #1](https://opengameart.org/content/keyboard-soundpack-1-typing-and-single-keystrokes), unicaegames, CC0, and [Page Turn](https://soundbible.com/2066-Page-Turn.html), Mark DiAngelo, CC BY 3.0. Five distinct human typing takes, 001–005, are separated by pauses and three quieter page turns in a 52 s montage. No generated typing take is used. The recording description identifies a Cherry KC 1000 recorded with a Shure SM7B. Complete attribution names both creators and both sources.
- [Paper Pages Sounds](https://opengameart.org/content/paper-pages-sounds) is CC BY 3.0, so excluded under the OpenGameArt CC0-only rule.
- [Book Pages](https://opengameart.org/content/book-pages) is also CC BY 3.0, so excluded for the same reason.

### Distant city at night

- Blankie's [City metadata](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json), gezortenplotz, CC BY 3.0, describes street-level New York, only 21.417 s. It does not establish a distant night bed free from nearby voices and horns. Not acquired.
- A targeted Commons search found a Cebu Capitol night soundscape, but its media could not be evaluated after the Wikimedia rate limit. No night-city layer added.

### Cabin hum

Added **Cabin hum**, ikbenraar's Interior airplane.WAV, CC0, via the [pinned Blankie per-file metadata](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json). Metadata explicitly describes steady cabin hum in flight. The 54.841 s AAC derivative provides a 1–53 s selection and 50 s prepared loop. No original Freesound request was made. No announcement is described in the metadata; listening approval remains outstanding.

### Wind chimes

- Added **Wind chimes**, Membeth's [Windglockenspiel.Koshi.ogg](https://commons.wikimedia.org/wiki/File:Windglockenspiel.Koshi.ogg), CC0. The 58 s recording identifies a rod chime and its eight notes. Downloaded the MP3 transcode, selected 1–55 s for a 52 s loop. Sparse high peaks receive the existing soft knee; subjective gentleness and decay continuity still need listening.
- [Windchime.ogg](https://commons.wikimedia.org/wiki/File:Windchime.ogg), stephan, Public Domain, 67 s. Not acquired. It was hand-played indoors with refrigerator noise reduction, a weaker fit for natural sparse wind-driven chimes.
- [Windchimes.ogg](https://commons.wikimedia.org/wiki/File:Windchimes.ogg), Esc861, Public Domain, is only 5.4 s. Not acquired.

### Winter

Added **Walking through snow** from [42 Snow and Gravel Footsteps](https://opengameart.org/content/42-snow-and-gravel-footsteps), Corsica_S, extracted by Iwan Gabovitch with explicit permission to release the extracts as CC0. The individual submission states this permission. Eighteen lossless snow-covered-gravel variations are arranged into 64 footfalls at an even 0.8 s cadence, lasting 51.2 s. Each event fits inside its slot, including at the loop seam. This is an edited walking sequence, with gravel under the snow, not snowy wind. No new category is needed.

### Cat purring

- [Cat purring.ogg](https://commons.wikimedia.org/wiki/File:Cat_purring.ogg), Peter Hull, 53.052 s. The file allows CC BY-SA 4.0, which would require the derivative audio to remain under that licence. **BY-SA flagged; not shipped.** Its download returned HTTP 429. All Wikimedia network use stopped immediately, with no retry or alternate mirror.
- [Cat Purring](https://soundbible.com/707-Cat-Purring.html), Mike Koenig, CC BY 3.0, 11.089 s. Allowed licence but too short for the requested varied 40–60 s recording. Download stays outside the app.
- [Purring Cat](https://soundbible.com/979-Purring-Cat.html), Jim Mowatt / Mike Koenig, CC BY 3.0, 7.201 s. Also too short. No cat layer added.

### Clock ticking

Added **Clock ticking** from [Ticking Clock](https://soundbible.com/1580-Ticking-Clock.html), KevanGC, Public Domain. The original is a 21.814 s stereo 22.05 kHz mechanical clock recording. Its ticks have alternating, slightly uneven spacing. Seventy distinct recorded ticks are retained, edge-faded, and arranged as 160 alternating events every 14,112 delivery frames, exactly 0.32 s. The 51.2 s loop has the same spacing across the seam, with no chime. Its un-looped audition is the original continuous run, converted to AAC, so the user can compare the edit.

### Rowing boat on a lake

- [Rowing A Boat](https://soundbible.com/1297-Rowing-A-Boat.html), hazure, explicitly describes a small boat on a calm lake. Its licence is **Sampling Plus 1.0**, which is not allowed. Excluded. A downloaded research copy remains outside the app.
- Blankie's [Boat metadata](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json), Falcet, CC0, 40.603 s, describes sea-boat rope squeaks at night. It is not oar strokes on a lake. No rowing layer added.

### Campfire at night

- [Fire Crackling](https://opengameart.org/content/fire-crackling), AntumDeluge, CC0. Described as a popping and crackling **fireplace**, with a 253 KB mono WAV. It supplies neither an outdoor night bed nor a sufficiently long distinct campfire recording. Not acquired or added.
- Commons search identified Campfire sound ambience, CC BY 3.0, but the Wikimedia media block prevented evaluation. No campfire layer added.

### Farm retry

- The cached [Farm](https://soundbible.com/1662-Farm.html) and [On The Farm](https://soundbible.com/1632-On-The-Farm.html) recordings are both by stephan and Public Domain. Combining them yields only 24.446 s before crossfades, still well short of 45–60 s. Repeating the same short animal calls would not satisfy the requested variation. No farm montage added.
- [Farm animals](https://opengameart.org/content/farm-animals) has a CC BY-SA 3.0 submission notice and describes short animal extracts processed for Tux Paint. Excluded under the OpenGameArt CC0-only rule, regardless of its small archive size.

### Network and symbol record

Direct requests logged in `~/FirehawkAudioWork/requests-expansion.jsonl`: SoundBible 16, Commons 11, OpenGameArt 8, Wikimedia media host 3, GitHub raw 1. There were no GitHub website requests. Search-engine queries supplied additional indexed primary-page leads; no Freesound result was followed. These counts are for this pass, separate from historical sections above. All direct requests used a normal browser User-Agent, at least 2.1 s spacing per host, no crawling, and no retry loop. There were no new requests to NPS.

Wikimedia media returned one HTTP 429 on the third request, the cat purr. No later request was made to any Wikimedia host. No 403 or captcha challenge occurred. Zero direct requests to Freesound pages, API, or CDN.

Symbols were checked against Apple's installed CoreGlyphs `name_availability.plist`. `cloud.rain`, `airplane`, `bell`, `clock` and `keyboard` date to macOS 10.15; `snowflake` dates to macOS 12.0. All support macOS 14. AppKit symbol-resolution checks cover every catalog entry. The seven existing categories are unchanged.

## Requested listening-feedback batch, 2026-10-27

Six additions, 26 recordings total. These selections use per-file rights evidence,
source descriptions and decoded signal inspection. No human listening approval
is claimed. Auditions are provided for the six shipped additions. Four slots
remain empty because the checked candidates fail the length, subject or licence
requirements. No short ambience was tiled to disguise its source length.

### Campfire

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Campfire sound ambience](https://commons.wikimedia.org/wiki/File:Campfire_sound_ambience.ogg), Glaneur de sons | CC BY 3.0, explicit on the file page; Commons records a passed original-source licence review | Added as `campfire`. A real small fire described as suitable for a summer camp. The Commons MP3 transcode decodes to about 60.25 s; select 1–59 s, giving a 56 s loop. Low-level recording with sharp transients; use the 3× RMS soft knee to preserve headroom while reaching -23 dBFS RMS. Catalog gain -4.5 dB deliberately lowers playback relative to Fireplace. Relative crackle character and background noise need listening review. |
| [Crackling Fireplace](https://soundbible.com/2178-Crackling-Fireplace.html), Daniel Simion | Per-file CC BY 3.0 | 64.832 s WAV downloaded as a backup. Popping and snapping are explicitly described, but the recording is identified as a fireplace. Not selected for the outdoor slot. |
| [Fire Crackling](https://opengameart.org/content/fire-crackling), AntumDeluge | Per-file CC0 | Cached page identifies a fireplace and a 253 KB mono WAV. Short indoor effect; not acquired in this pass. |

### Big fire

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [WWS Bonfireburning](https://commons.wikimedia.org/wiki/File:WWS_Bonfireburning.ogg), Kimmo Kestinen / Work With Sounds / Werstas | File page explicitly grants CC BY 4.0 | Added as `bonfire`, Big fire. A real Finnish Midsummer bonfire at Lake Näsijärvi. The MP3 transcode decodes to about 51.88 s. Select 1–50 s for a 47 s loop. This is an outdoor field recording from a family event, so the audition must be checked for distracting distant people as well as deep roar/crackle balance. |

### Croaky frogs

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Frog Call Recordings, Cape Cod](https://www.nps.gov/caco/learn/photosmultimedia/frog-call-recordings.htm), NPS | Per-item credit NPS | Not selected. A 3:33 field recording includes bullfrog grunts, but the page explicitly says they are faint and the loudest species is the grey treefrog. It would not reliably distinguish this layer from the existing chirping frogs. No media download. |
| [Banded Bull Frog Call](https://commons.wikimedia.org/wiki/File:Banded_Bull_Frog_Call.ogg), Inspector | CC BY-SA 3.0 / GFDL, flagged | A 44.5 s group recording has promising subject and length, but BY-SA is not authorized. Not downloaded or shipped. |
| [Night Chorus of Frogs and Toads in Niger Delta](https://commons.wikimedia.org/wiki/File:Night_Chorus_of_Frogs_and_Toads_in_Niger_Delta.ogg), ElemePodcast | Per-file CC BY 4.0 | Only 26.389 s, with no identification of deep-croaking species. Page checked, media not downloaded. Not stretched or repeated to create a longer sparse-call loop. |

`bullfrogs` remains absent. The NPS pig-frog page was also checked as a lead,
but no media was acquired or bundled.

### Waterfall

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Large Waterfall](https://soundbible.com/2201-Large-Waterfall.html), Daniel Simion | Per-file CC BY 3.0 | Added as `waterfall`. Original WAV is 44.157574 s, stereo 44.1 kHz. The source describes water roaring over a cliff into a river. Select 1–43.5 s; a 2 s overlap gives 40.5 s. No peak reduction needed. Subjective texture remains for audition. |

### Fountain

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Water Fountain Noise](https://soundbible.com/1435-Water-Fountain-Noise.html), Caroline Ford | Per-file CC BY 3.0 | Described as water/trickle from a fountain. Downloaded WAV is only 21.900771 s. Not shipped: insufficient distinct material for the requested 40–60 s loop. |
| [Fountainnoise2](https://commons.wikimedia.org/wiki/File:Fountainnoise2.ogg), Secretlondon | CC BY-SA 3.0 / GFDL, flagged | 18 s, recorded at Kagyu Samye Ling. Both length and unauthorised BY-SA rule it out. No download. |

`fountain` remains absent.

### Close thunder

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Elaborate Thunder](https://soundbible.com/2005-Elaborate-Thunder.html), Mike Koenig | Per-file CC BY 3.0 | Added as `thunder-close`. The 115.356735 s source contains multiple different strikes and echoes. Select 0–54 s, retaining separate clap groups near 5, 28, 38 and 41 s. The 2 s overlap uses the quieter head/tail, away from attacks and main decays, yielding a 52 s loop. It does not repeat one extracted clap. Rolling thunder remains untouched. |
| [Thunder](https://soundbible.com/1907-Thunder.html), Mike Koenig | Per-file CC BY 3.0 | 17.000998 s, downloaded. Good crack/clap description, but a single short event. Not selected. |
| [Thunder HD](https://soundbible.com/1913-Thunder-HD.html), Mark DiAngelo | Per-file CC BY 3.0 | 8.8985 s, downloaded. Another short storm event; no need to repeat it after finding the longer source. |

### Thunderstorm

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [2 Minute Storm](https://soundbible.com/1908-2-Minute-Storm.html), Mike Koenig, plus the existing [Wind derivative metadata](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json), felix.blume | Per-file CC BY 3.0 for storm; pinned CC0 per-file metadata for wind | Added as `thunderstorm`, explicitly a composite. Storm WAV is 151.703401 s. Use 20–80 s, with separate thunder events near source seconds 33, 55 and 75, and add wind seconds 140–200 at RMS 8 dB below the storm. A 2 s overlap yields 58 s. Both sources and all prior editors ship in structured attribution. |
| [Blankie Storm metadata](https://github.com/codybrom/blankie/blob/a106b8de559344fe3e6dff0a626e5a21a74a344e/Blankie/Resources/sounds.json), Digifish music, Infinite Storm.wav | Pinned per-file CC BY 4.0 | Only 25.663 s in the redistributed recording. Rain/thunder described, wind unspecified. Metadata checked locally; no new download or Freesound access. |

### Clock and Fast clock

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Ticking Clock](https://soundbible.com/1580-Ticking-Clock.html), KevanGC | Cached per-file Public Domain notice and original WAV | Added `clock`, Clock, as a 50 s edited sequence. Retain one clean 180 ms recorded tick, apply 4 ms outer event fades, and repeat its identical waveform on exact 44,100-frame slots. A single tick avoids the varied attack timing of the original recording. No pitch/time stretching. Each next attack is exactly 1.000 s later, including across the seam. |

Rename the existing `clock-ticking` display name to **Fast clock**, retaining its
id, CAF file, original structured source title and 0.32 s grid. The normal clock's
un-looped audition is one pass of the newly spaced sequence.

### Washing machine

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Washing machine mid program](https://commons.wikimedia.org/wiki/File:Washing_machine_mid_program.ogg), ezwa | Per-file Public Domain dedication | Only 27 s; tags include “spin”, without establishing gentle wash/tumble without banging. File page checked, media not downloaded. Not repeated to fill 40 s. |
| [Washing machine last spin](https://commons.wikimedia.org/wiki/File:Washing_machine_last_spin.ogg), ezwa | Indexed per-file Public Domain notice | 60 s, but explicitly a spin cycle. Not downloaded or shipped. |
| [Lavadora en acción](https://commons.wikimedia.org/wiki/File:Lavadora_en_acci%C3%B3n.ogg), Hippocampuz | Indexed per-file CC BY-SA 4.0, flagged | 31 s wash recording, but unauthorised licence and short length. Not downloaded or shipped. |

`washing-machine` remains absent. Blankie and Blanket contain no washer source.
The targeted SoundBible page and OpenGameArt search produced no suitable audio.

### Café

| Candidate | Rights | Fit and decision |
| --- | --- | --- |
| [Restaurant Ambiance](https://soundbible.com/1664-Restaurant-Ambiance.html), stephan | Cached individual page explicitly states Public Domain and says no words are discernible | New original WAV download is 16.666689 s, longer than the previously checked 12.821 s derivative, but still too short for a 40–60 s varied room bed. Low indistinct conversation is now acceptable; speech presence alone is **not** the rejection reason. The page does not establish absence of music, frother or close voices. Not shipped. |
| Blankie / Blanket Coffee Shop | Blankie pinned per-file `publicDomain`; Blanket SOUNDS_LICENSING.md independently names stephan and the same SoundBible source | Same recording, not an independent longer candidate. Cached Blankie metadata reports 12.820771 s; cached derivative and Blanket metadata inspected locally. No GitHub requests. |
| [Geroezemoes van publiek in een restaurant](https://commons.wikimedia.org/wiki/File:Geroezemoes_van_publiek_in_een_restaurant_-_SoundCloud_-_Beeld_en_Geluid.ogg), Beeld en Geluid | Per-file CC BY-SA 3.0, flagged | 11:54, but unauthorised BY-SA. Description also explicitly mentions a toddler's cries. No download or shipment. |

`cafe` remains absent. No intelligible speech was invented or added, and the
short restaurant effect was not multiplied into a nominally longer loop.

### Network and symbols

Direct acquisition log: `~/FirehawkAudioWork/requests-requested.jsonl`.
36 successful requests: SoundBible 20, Commons 12, Wikimedia upload 2, NPS 2.
GitHub/raw 0, OpenGameArt direct 0, Freesound pages/API/CDN 0. Twenty-one search
queries used the research tool's index; no primary page was opened with that
tool and no Freesound result was followed. All direct downloads used a normal
browser User-Agent. No 403, 429 or captcha challenge occurred; no retries or
bulk scraping occurred. Cached Git objects supplied the two mirror catalogs.

Pacing audit: same-host requests were separated by at least about 2 s, with
Wikimedia same-host spacing over 5 s. One Wikimedia upload-to-Commons transition
had a logged completion gap of 1.3 s because the guard originally tracked hosts
separately. This violated the intended cross-host 5 s spacing. The helper was
corrected to share Wikimedia timing; no further Wikimedia requests were made.
All other logged Wikimedia gaps were over 6 s. No site received 60 requests.

Raw audio and page evidence are under `~/FirehawkAudioWork/raw/<source>/<id>/`.
Downloaded files were treated only as data. All Python readers used `python3 -I`.
No downloaded code was executed. No BY-SA file was shipped.

Installed public CoreGlyphs `name_availability.plist` / `year_to_release` verify
`flame`, `flame.fill`, `cloud.bolt`, `cloud.bolt.rain` and `clock` since macOS
10.15; `water.waves` since macOS 13. Asset tests also resolve every symbol via
AppKit. All new entries use existing categories and explicit `sources`/`editors`.

## Freesound shortlist (2026-10-27)

This section records the earlier APIv2 metadata and HQ MP3 preview research. Original acquisition and final implementation decisions follow below. These are ranked audition candidates, not listening-approved assets; no app code or catalog entries changed. The API specifications below describe original uploads, not the lossy previews. All shortlisted licences are CC0 or CC BY 3.0/4.0; NC and Sampling+ results were excluded.

Previews were fetched sequentially with a 2,400,000-byte Range limit to keep transfers bounded. Long recordings therefore have only an opening excerpt here; the two approximately 61 s skyko fountain previews fit in full. The first unbounded café transfer was interrupted for slow delivery and its body discarded. Copied audition files preserve the preview bytes and may retain a full-length MP3 duration header despite containing only the opening excerpt.

Measurements use locally compiled Swift with AVFoundation and Accelerate, without executing downloaded material. RMS and peaks use decoded channels in one-second blocks; flatness uses one 2048-sample Hann-windowed FFT per second, the first channel, 200–8000 Hz. Flatness approaches 1 for a flat noise spectrum, but water naturally has broadband energy. These metrics flag level variation and noise-like spectra; they do not detect intelligible words, identify frogs or certify absence of music, frothers, beeps or traffic. Detailed per-second results and API evidence are outside git under `~/FirehawkAudioWork/freesound-shortlist-2026-10-27/` and `~/FirehawkAudioWork/raw/freesound-previews/<id>/`.

### Café

| Rank and source | Creator and licence | Original upload | Rating | Fit and preview analysis |
| --- | --- | --- | --- | --- |
| **#1 pick**: [Cafe Ambience](https://freesound.org/s/732984/), 732984 | bittermelonheart; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 96000 Hz; 2 channels; 1699.9000 s | 5.00/5, 20 ratings | Crowded Bay Area café, recorded on a Tascam DR-100 mkiii. Best-supported café candidate by rating count and source length. The description does not establish absence of music, grinders, frothers or close intelligible voices. Provisional #1 for listening, not cleared for use. Start by auditioning source 1–61 s. Analysed first 108.0 s of the HQ MP3 preview. Median RMS -41.3 dBFS; one-second RMS P95–P05 span 6.9 dB; maximum sample peak -15.5 dBFS; median 200–8000 Hz spectral flatness 0.044. |
| #2: [Ambience Coffee](https://freesound.org/s/689957/), 689957 | Matias44; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 48000 Hz; 2 channels; 171.7760 s | 5.00/5, 13 ratings | Argentinian bar-café. Steadier measured bed than the first café candidate, but the brief description gives no assurance about music or close speech. Source 34–94 s is a relatively stable measured window. Strong alternative if its voices and background pass listening. Analysed first 106.0 s of the HQ MP3 preview. Median RMS -31.0 dBFS; one-second RMS P95–P05 span 4.7 dB; maximum sample peak -8.8 dBFS; median 200–8000 Hz spectral flatness 0.046. |
| #3: [ambient-coffee-shop-sounds.wav](https://freesound.org/s/216138/), 216138 | Somersethypnotherapy; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 16-bit; 44100 Hz; 2 channels; 425.5870 s | 5.00/5, 5 ratings | Café Nero in Yeovil, recorded with Olympus LS11. Male/female voice tags and higher preview peaks make this a lower-confidence fit. Source 29–89 s is relatively stable; inspect close voices and café machinery. No music-free claim is made by the creator. Analysed first 105.0 s of the HQ MP3 preview. Median RMS -23.5 dBFS; one-second RMS P95–P05 span 6.3 dB; maximum sample peak -2.9 dBFS; median 200–8000 Hz spectral flatness 0.051. |

Audition copy: `~/FirehawkAudioWork/audition/freesound-preview-cafe.mp3`.

### Fountain

| Rank and source | Creator and licence | Original upload | Rating | Fit and preview analysis |
| --- | --- | --- | --- | --- |
| **#1 pick**: [Fountain_2.wav](https://freesound.org/s/169254/), 169254 | skyko; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 48000 Hz; 2 channels; 60.8880 s | 5.00/5, 27 ratings | Explicitly a small fountain; garden, bubbling and drip tags match the requested home/garden scale. Full preview has stable RMS. Higher flatness is consistent with splashing water and is not itself evidence of unwanted hiss. Check audible bubble detail and any pump hum at matched playback level. Analysed first 60.9 s of the HQ MP3 preview. Median RMS -47.6 dBFS; one-second RMS P95–P05 span 1.9 dB; maximum sample peak -24.3 dBFS; median 200–8000 Hz spectral flatness 0.391. |
| #2: [Fountain_5.wav](https://freesound.org/s/169251/), 169251 | skyko; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 48000 Hz; 2 channels; 60.7680 s | 5.00/5, 4 ratings | Another small garden fountain take from the same creator, recorded on a Tascam DR100 MKII. Full preview is even steadier in RMS, but has a larger peak above its median level and fewer ratings. Useful same-location fallback, not an independent source. Analysed first 60.8 s of the HQ MP3 preview. Median RMS -45.4 dBFS; one-second RMS P95–P05 span 1.2 dB; maximum sample peak -19.7 dBFS; median 200–8000 Hz spectral flatness 0.321. |
| #3: [small fountain 1.wav](https://freesound.org/s/542259/), 542259 | jerry.berumen; [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | WAV, 24-bit; 96000 Hz; 2 channels; 67.2967 s | 5.00/5, 4 ratings | Explicitly described as a small relaxing fountain. Independent creator and 96 kHz original. Less rating evidence than #1. Assess whether the water has distinct trickling/bubbling rather than a continuous wash. Analysed first 67.3 s of the HQ MP3 preview. Median RMS -44.4 dBFS; one-second RMS P95–P05 span 1.2 dB; maximum sample peak -19.1 dBFS; median 200–8000 Hz spectral flatness 0.438. |

Audition copy: `~/FirehawkAudioWork/audition/freesound-preview-fountain.mp3`.

### Croaky frogs

| Rank and source | Creator and licence | Original upload | Rating | Fit and preview analysis |
| --- | --- | --- | --- | --- |
| **#1 pick**: [Frogs at Sungei Buloh 2](https://freesound.org/s/750818/), 750818 | madamdata; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 48000 Hz; 2 channels; 119.3440 s | 5.00/5, 1 ratings | Creator believes these are bullfrogs at Sungei Buloh, Singapore; species identification is explicitly uncertain. Em-273 electrets with a helmet baffle into a Zoom H1. Provisional #1 for its frog-specific subject and strongly low-frequency excerpt: median power below 500 Hz is 88.7%, versus 43.4% for 80840 and 0.1% for 584044. This supports a lower-pitched candidate but could include background rumble, so deep croaks require listening. Start with 38–98 s. Just one rating and uncertain species identification limit confidence. Analysed first 104.0 s of the HQ MP3 preview. Median RMS -32.7 dBFS; one-second RMS P95–P05 span 5.9 dB; maximum sample peak -5.2 dBFS; median 200–8000 Hz spectral flatness 0.030. |
| #2: [Night Crickets & Bullfrogs.wav](https://freesound.org/s/80840/), 80840 | sunsinger; [CC BY 3.0](http://creativecommons.org/licenses/by/3.0/) | WAV, 16-bit; 44100 Hz; 2 channels; 337.8130 s | 4.82/5, 11 ratings | Actual night field recording at Bosque del Apache, with bullfrogs and crickets. Crown SASS-P microphone and Tascam DAT. Stronger rating evidence than the other two frog choices, but the cricket layer may weaken the intended distinction from the existing high-pitched frogs. Analysed first 104.0 s of the HQ MP3 preview. Median RMS -45.9 dBFS; one-second RMS P95–P05 span 8.6 dB; maximum sample peak -19.2 dBFS; median 200–8000 Hz spectral flatness 0.128. |
| #3: [Frog Pond 2 - Harvest Moon Trail - Wolfville NS.wav](https://freesound.org/s/584044/), 584044 | greysound; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 48000 Hz; 2 channels; 295.3850 s | 4.00/5, 2 ratings | Creator identifies bullfrogs with loose-banjo-string calls. Prefer source 0–60 s as the first audition window. The description flags a louder chorus around 150 s and a bicycle at 270 s; those later sections were not covered by the excerpt. Noise reduction was applied to distant traffic. Only 0.1% of median measured spectral power is below 500 Hz in the excerpt, and peaks are pronounced. This weakens the deep-croak fit; keep as a conditional third choice only, with traffic and louder events requiring rejection if audible. Only two ratings. Analysed first 106.0 s of the HQ MP3 preview. Median RMS -40.5 dBFS; one-second RMS P95–P05 span 10.2 dB; maximum sample peak -4.4 dBFS; median 200–8000 Hz spectral flatness 0.029. |

Audition copy: `~/FirehawkAudioWork/audition/freesound-preview-frogs.mp3`.

### Washing machine

| Rank and source | Creator and licence | Original upload | Rating | Fit and preview analysis |
| --- | --- | --- | --- | --- |
| **#1 pick**: [washer-agitate-close.aif](https://freesound.org/s/125307/), 125307 | alienistcog; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | AIFF, 16-bit; 44100 Hz; 2 channels; 187.2460 s | 5.00/5, 3 ratings | Explicit wash/agitate cycle with laundry and water sloshing. Best subject match and no spin or completion tune described. Microphone moves from almost inside the machine to a few feet away, so choose a stable section wholly on one side of that change. The opening 1–61 s window has a roughly 2 dB RMS span, but full-scale preview peaks occur near 9 and 49 s, with more later. This is a material transient/clipping concern. The original is a later-download audition candidate only; reject if those peaks are bangs or persistent distortion. No beep-free or bang-free claim can be certified by level measurements. Analysed first 102.0 s of the HQ MP3 preview. Median RMS -24.3 dBFS; one-second RMS P95–P05 span 10.6 dB; maximum sample peak 0.0 dBFS; median 200–8000 Hz spectral flatness 0.263. |
| #2: [Washing Machine.wav](https://freesound.org/s/131356/), 131356 | nahmandub; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 32-bit; 96000 Hz; 2 channels; 191.4370 s | 5.00/5, 3 ratings | Water movement and motor recorded from the top of a washer. 32-bit WAV metadata does not establish recorder bit depth or improve a noisy source. The creator mentions shaking of the motor, and the preview reaches full scale with a 17.2 dB RMS span. Mechanical rumble or knocks are a listening concern. Analysed first 105.0 s of the HQ MP3 preview. Median RMS -29.5 dBFS; one-second RMS P95–P05 span 17.2 dB; maximum sample peak 0.0 dBFS; median 200–8000 Hz spectral flatness 0.104. |
| #3: [Washing machine-000.wav](https://freesound.org/s/180159/), 180159 | FEAMEIS; [CC BY 3.0](http://creativecommons.org/licenses/by/3.0/) | WAV, 16-bit; 48000 Hz; 2 channels; 84.6507 s | 5.00/5, 6 ratings | Washing machine at work, with no cycle identified. Six ratings are useful, but the vague description cannot rule out spin, beeps or banging. The 28.1 dB RMS span is inconsistent with a steady full-recording bed; no stable 60 s window was established. Lower subject confidence than the explicit agitate-cycle #1. Analysed first 84.7 s of the HQ MP3 preview. Median RMS -46.3 dBFS; one-second RMS P95–P05 span 28.1 dB; maximum sample peak -19.6 dBFS; median 200–8000 Hz spectral flatness 0.020. |

Audition copy: `~/FirehawkAudioWork/audition/freesound-preview-washing-machine.mp3`.

### Confirmed user favourites for later original download

| Source | Creator and licence | Original upload | Rating | Notes |
| --- | --- | --- | --- | --- |
| [Light Rain](https://freesound.org/s/167034/), 167034 | soundrecorder7; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 16-bit; 44100 Hz; 2 channels; 26.3198 s | 4.88/5, 51 ratings | Creator describes light rain without thunder or other background noise. Under the preferred 60 s length, but explicitly requested by the user. Metadata confirmed through the sound-instance API; no preview or original downloaded for this favourite. |
| [fire_crackling.wav](https://freesound.org/s/263864/), 263864 | ceich93; [CC0-1.0](http://creativecommons.org/publicdomain/zero/1.0/) | WAV, 24-bit; 44100 Hz; 2 channels; 59.9607 s | 4.71/5, 69 ratings | Creator warns that squeaks or artifacts in the compressed preview are absent from the original download. Slightly under 60 s; explicitly requested by the user. Metadata confirmed through the sound-instance API; no preview or original downloaded for this favourite. |

### Decisions and request accounting

Original-download shortlist, after listening review: **732984, 169254, 750818, 125307, 167034, 263864**. The four new picks are provisional. Café especially needs a music/frother/close-speech check; no clean 60 s segment of Anya_Media 437461 has been established. Rejected waweee 370973 and its remaster 453074 were excluded, and neither was downloaded.

21 Freesound HTTP requests total: 6 search requests, 2 favourite metadata requests, 12 bounded preview requests and 1 interrupted preview request. No automatic redirects or retries. The interrupted café request was deliberately replaced once with a bounded excerpt request. Requests shared one pacing guard with a minimum 3.2 s start-to-start delay; the logged minimum between completed request entries is 3.201 s. The interrupted request was also counted by the same guard. No 403, 429, captcha or HTML response was encountered. The slow transfer interruption and normal EOF at the ends of truncated MP3 excerpts are the only acquisition/decoding limitations. Request ledger: `~/FirehawkAudioWork/freesound-shortlist-2026-10-27/requests.jsonl`; guard state: `state.json`. API token read at runtime from the private config file and never written into research evidence, the repository or the report.

## Original acquisition and implementation, 2026-10-27

All six shortlisted originals were acquired from the authenticated API download
endpoint and its signed HTTPS CDN redirect. Fresh sound-instance metadata verified
CC0-1.0 for every original before download. Each original passed RIFF/WAVE or
FORM/AIFF signature checks and a complete-transfer SHA256 check. Raw originals,
metadata and analysis evidence remain in `~/FirehawkAudioWork/raw/freesound/<id>/`.
No Freesound preview was substituted for an original.

The earlier attempt stopped after two requests because it checked the expected
HTML-typed HTTP 302 before checking its destination. The corrected task explicitly
authorized resuming the same ledger. Only HTTP 301/302 download redirects to
exactly `https://cdn.freesound.org` are accepted. Authorization is sent only to
freesound.org; CDN requests use their pre-signed URL without that header. Signed
URL queries and credentials are never recorded. HTTP 403/429, captcha, HTML 200
bodies and unexpected redirects remain stop conditions.

| Requested catalogue entry | Freesound ID | Licence | Decision |
| --- | --- | --- | --- |
| Light rain (`rain-light`) | 167034 | CC0-1.0 | Added. Full 26.319796 s original, 2 s overlap, then exact double repetition yields 48.639592 s. The true recurrence is 24.319796 s, disclosed because this short recording is the user's favourite. Existing Gentle rain retained. |
| Crackling fire (`fire-crackling`) | 263864 | CC0-1.0 | Added. Selected 0.8–58.8 s; 2 s overlap yields 56 s. Peak knee at 4 times RMS permits the library RMS target with headroom. Existing Fireplace, Campfire and Big fire retained. |
| Café (`cafe`) | 732984 | CC0-1.0 | Excluded. No qualifying 45 s segment was established. Offline Apple SoundAnalysis flagged music at confidence ≥0.3 in 145 of 566 three-second windows; speech in 497 windows. Classifier scores do not prove music or word intelligibility, but these unresolved risks prevent clearance. A lower-score 655–715 s candidate remains available for listening. |
| Fountain (`fountain`) | 169254 | CC0-1.0 | Added. Creator explicitly identifies a small fountain. Selected 0.4–60.4 s; 2 s overlap yields 58 s. |
| Croaky frogs (`bullfrogs`) | 750818 | CC0-1.0 | **Later rejected by the user after listening** and removed. Replaced by reinsamba 58236 (CC BY 4.0) under the same catalog id; see user-approved café and frogs. |
| Washing machine (`washing-machine`) | 125307 | CC0-1.0 | Added. Stable 126–182 s agitation section after the microphone move and before the clipped ending; 2 s overlap yields 54 s. No full-scale samples; P95–P05 100 ms RMS span 3.05 dB; raw crest factor 22.80 dB. The pipeline applies a 3-times-RMS peak knee. Engine is the leading classifier label in all 19 selected windows; no beep, knock, door_slam or thump_thud appears in their top eight labels. Mechanical engine_knocking secondary labels remain, so human listening is still required to assess timbre. |

The five additions use stereo 44.1 kHz PCM16 CAF, -23 dBFS RMS and at least 6 dB
sample-peak headroom. Equal-power overlap avoids a fade-to-silence seam. Signal
measurements and machine labels support selection but do not establish human
listening approval, absence of all distractions, or an inaudible croak recurrence.
No such approval is claimed. The original favourite rain's shorter recurrence is
explicit rather than disguised as 49 seconds of independent material.

Un-looped level-matched auditions are named by Freesound ID under
`~/FirehawkAudioWork/audition/`: `167034.m4a`, `263864.m4a`, `732984.m4a`,
`169254.m4a`, `750818.m4a`, `125307.m4a`. The café audition is the 655–715 s
candidate, not a shipped asset. Shipped fountain, frog and washer preview copies
were deleted. The unshipped café preview remains research material.

The offline rebuild entry point is `python3 -I scripts/audio/prepare-freesound.py`.
Its `library-freesound.json` manifest pins original hashes, selections, edits,
licences and creators. Full per-sound provenance and delivered hashes are in
[CREDITS.md](CREDITS.md). App catalogue entries include structured `sources` and
`editors`. New symbols `cloud.rain`, `flame`, `water.waves`, `leaf`, `washer` are
available by macOS 13 according to the installed public CoreGlyphs
`name_availability.plist` / `year_to_release`, within the macOS 14 minimum.

This implementation batch used **20 Freesound requests total**, including the
previous attempt's two requests: 7 metadata, 7 original endpoints and 6 CDN
transfers. This resumed run used 18 requests. Requests were sequential, at least
3.2 s apart. No retry, alternate host, 403, 429, captcha, HTML 200 body or
unexpected redirect occurred. The initial HTML-typed 302 misclassification was
the only earlier stop. Evidence: `~/FirehawkAudioWork/freesound-originals-2026-10-27/requests.jsonl`
and `state.json`. The earlier 21-request preview research was a separate batch.

The catalogue after that Freesound originals pass contained 31 recordings. Later listening approvals and lossless conversion supersede the size and café notes below.

## Cafeteria user override and soft Café search, 2026-10-27

The earlier exclusion of 732984 is superseded by the user's listening approval. It ships as **Cafeteria** (`cafeteria`, indoor), retaining its loud character. Source 936–1176 s → 234 s loop. Soft Café was later approved separately (see next section). Historical soft-Café shortlist (previews only): 746428, 478115, 263584 — detailed in CREDITS.md. That search used 9 Freesound requests.

## User-approved café and frogs + ALAC library, 2026-10-27

| Entry | Freesound ID | Licence | Decision |
| --- | --- | --- | --- |
| Café (`cafe`) | 263584, Berwitz | CC0-1.0 | **Added** after user listening. Selected 62–122 s; 2 s overlap → 58 s. Indoor / `cup.and.saucer`. |
| Croaky frogs (`bullfrogs`) | 58236, reinsamba | CC-BY-4.0 | **Replaces** rejected 750818. Selected 100–158 s; 0.5 s overlap → 57.5 s. Catalog `gainDb: -4.0` keeps it soft. Full CC BY attribution. |
| Night frogs (`night-frogs`) | 462889, mycompasstv | CC0-1.0 | **Added**. Near-full 0.5–46.0 s of the MP3 original; 0.5 s overlap → 45 s. Nature / `leaf`. |

Freesound requests this pass: **9** (3 metadata + 3 download endpoints + 3 CDN), sequential, ≥3.2 s apart, ledger `~/FirehawkAudioWork/freesound-approved-2026-10-27/`. No 403/429/captcha/HTML. Whole Ambience library converted to Apple Lossless CAF; `verify-alac-lossless.py` reports 0 differing samples vs PCM masters. Ambience: **158,649,370 bytes (151.300 MiB)**. Catalog: **34** recordings.
