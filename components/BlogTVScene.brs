' BlogTVScene.brs

sub init()
    print "BlogTV: Starting up..."

    m.dataBaseUrl    = "https://monkeyboz.github.io/blogtv-data/data"
    m.sampleUrl      = "https://en.wikipedia.org/wiki/Television"
    m.timerTick      = 0
    m.totalTicks     = 120
    m.isZoomed       = false
    m.isNarrating    = false
    m.narrateIdx     = 0
    m.sections       = []
    m.articleKeywords= []
    m.overlayVisible = false
    m.dialogVisible  = false
    m.drawerOpen     = ""   ' which drawer is open: "" | "sections" | "actions" | "pageview"
    m.matchedChans   = []
    m.matchedClips   = []
    m.urlHistory     = []

    ' Node refs
    m.headerGroup    = m.top.findNode("headerGroup")
    m.narratorGroup  = m.top.findNode("narratorGroup")
    m.navBar         = m.top.findNode("navBar")
    m.sectionsDrawer = m.top.findNode("sectionsDrawer")
    m.sectionsGrid   = m.top.findNode("sectionsGrid")
    m.actionsDrawer  = m.top.findNode("actionsDrawer")
    m.actionPanel    = m.top.findNode("actionPanel")
    m.pipGroup       = m.top.findNode("pipGroup")
    m.statusBar      = m.top.findNode("statusBar")
    m.streamsOverlay = m.top.findNode("streamsOverlay")
    m.urlDialog      = m.top.findNode("urlDialog")
    m.s1t = m.top.findNode("stream1title")
    m.s1s = m.top.findNode("stream1sub")
    m.s2t = m.top.findNode("stream2title")
    m.s2s = m.top.findNode("stream2sub")
    m.s3t = m.top.findNode("stream3title")
    m.s3s = m.top.findNode("stream3sub")
    m.s4t = m.top.findNode("stream4title")
    m.s4s = m.top.findNode("stream4sub")
    m.s5t = m.top.findNode("stream5title")
    m.s5s = m.top.findNode("stream5sub")
    m.overlayStatus = m.top.findNode("overlayStatus")

    ' Tasks
    m.parserTask             = m.top.createChild("WebsiteParserTask")
    m.channelTask            = m.top.createChild("ChannelMatchTask")
    m.channelTask.dataBaseUrl= m.dataBaseUrl
    m.transcriptTask             = m.top.createChild("TranscriptMatchTask")
    m.transcriptTask.dataBaseUrl = m.dataBaseUrl

    m.demoTimer          = m.top.createChild("Timer")
    m.demoTimer.duration = 1
    m.demoTimer.repeat   = true

    m.narrateTimer          = m.top.createChild("Timer")
    m.narrateTimer.duration = 8
    m.narrateTimer.repeat   = true

    ' Observers
    m.parserTask.observeField("parsedContent",    "onContentParsed")
    m.parserTask.observeField("taskState",        "onTaskStateChanged")
    m.channelTask.observeField("matchedChannels", "onChannelsMatched")
    m.channelTask.observeField("taskState",       "onChannelTaskState")
    m.channelTask.observeField("taskProgress",    "onChannelProgress")
    m.channelTask.observeField("taskError",       "onChannelError")
    m.channelTask.observeField("urlHistory",      "onUrlHistoryLoaded")
    m.transcriptTask.observeField("matchedClips", "onClipsMatched")
    m.transcriptTask.observeField("taskState",    "onTranscriptTaskState")
    m.transcriptTask.observeField("taskProgress", "onTranscriptProgress")
    m.navBar.observeField("selectedTab",          "onTabSelected")
    m.actionPanel.observeField("selectedAction",  "onActionSelected")
    m.sectionsGrid.observeField("selectedSection","onSectionSelected")
    m.sectionsGrid.observeField("focusedSection", "onSectionFocused")
    m.pipGroup.observeField("selectedSection",    "onPipSectionSelected")
    m.demoTimer.observeField("fire",              "onTimerFire")
    m.narrateTimer.observeField("fire",           "onNarrateAdvance")
    m.urlDialog.observeField("selectedUrl",       "onUrlDialogDone")
    m.urlDialog.observeField("cancelled",         "onUrlDialogCancelled")

    m.headerGroup.statusText = "Initialising BlogTV..."
    startFetch(m.sampleUrl)
    m.channelTask.control    = "RUN"
    m.transcriptTask.control = "RUN"

    ' Nav bar always has focus on startup
    btvRestoreNav()
end sub

' -- Focus model -------------------------------------------------------
' Nav bar always has focus when no drawer/overlay is open.
' Opening a drawer moves focus into it. Back always closes and restores nav.

sub btvRestoreNav()
    m.navBar.setFocus(true)
end sub

sub btvOpenDrawer(which as String)
    ' Close any existing drawer first
    btvCloseDrawer()
    m.drawerOpen = which

    if which = "sections"
        m.sectionsDrawer.visible = true
        m.sectionsGrid.activate  = true
        m.headerGroup.statusText = "Sections | Up/Down: browse | OK: select | Back: close"

    else if which = "actions"
        m.actionsDrawer.visible = true
        m.actionPanel.setFocus(true)
        m.headerGroup.statusText = "Actions | Up/Down: choose | OK: run | Back: close"

    else if which = "pageview"
        m.pipGroup.visible = true
        m.pipGroup.zoomed  = true
        m.pipGroup.setFocus(true)
        m.headerGroup.statusText = "Page View | Up/Down: sections | OK: select | Back: close"
    end if
end sub

sub btvCloseDrawer()
    if m.drawerOpen = "sections"
        m.sectionsGrid.activate  = false
        m.sectionsDrawer.visible = false

    else if m.drawerOpen = "actions"
        m.actionsDrawer.visible = false

    else if m.drawerOpen = "pageview"
        m.pipGroup.zoomed  = false
        m.pipGroup.visible = false
    end if

    m.drawerOpen = ""
end sub

' -- Key handler -------------------------------------------------------
function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    ' Modal: URL dialog eats everything except Back
    if m.dialogVisible = true
        if key = "back"
            hideUrlDialog()
            return true
        end if
        return false
    end if

    ' Modal: streams overlay eats everything except Back
    if m.overlayVisible = true
        if key = "back"
            hideOverlay()
            return true
        end if
        return true
    end if

    ' Drawer open: Back closes it and returns to nav
    if m.drawerOpen <> ""
        if key = "back"
            btvCloseDrawer()
            btvRestoreNav()
            m.headerGroup.statusText = "Use Left/Right to browse tabs, OK to open"
            return true
        end if
        ' Let the drawer component handle all other keys
        return false
    end if

    ' Nav bar has focus: play/options still toggles zoom
    if key = "play" or key = "options"
        toggleZoom()
        return true
    end if

    return false
end function

' -- Nav tab selected (OK pressed on nav bar) -------------------------
sub onTabSelected(event as Object)
    tab = event.getData()
    print "BlogTVScene: tab selected = " + tab

    if tab = "sections"
        btvOpenDrawer("sections")

    else if tab = "actions"
        btvOpenDrawer("actions")

    else if tab = "pageview"
        btvOpenDrawer("pageview")

    else if tab = "url"
        showUrlDialog()
    end if
end sub

' -- Section events ---------------------------------------------------
sub onSectionFocused(event as Object)
    idx = event.getData()
    if idx < 0 or idx >= m.sections.count() then return
    sec = m.sections[idx]
    m.narratorGroup.sectionTitle  = sec.heading
    m.narratorGroup.narrationText = sec.body
    m.statusBar.tickerText = "Previewing: " + sec.heading
end sub

sub onSectionSelected(event as Object)
    idx = event.getData()
    if idx < 0 or idx >= m.sections.count() then return
    sec = m.sections[idx]
    m.narratorGroup.sectionTitle  = sec.heading
    m.narratorGroup.narrationText = sec.body
    m.statusBar.tickerText = "Reading: " + sec.heading
    m.narrateIdx = idx
    btvCloseDrawer()
    btvRestoreNav()
end sub

sub onPipSectionSelected(event as Object)
    idx = event.getData()
    if idx < 0 or idx >= m.sections.count() then return
    sec = m.sections[idx]
    m.narratorGroup.sectionTitle  = sec.heading
    m.narratorGroup.narrationText = sec.body
    m.narrateIdx = idx
    m.headerGroup.statusText = "Selected: " + left(sec.heading, 40)
    btvCloseDrawer()
    btvRestoreNav()
end sub

' -- Action buttons ---------------------------------------------------
sub onActionSelected(event as Object)
    action = event.getData()
    print "BlogTVScene: action=" + action

    if action = "AI Narrate"
        if m.isNarrating = false
            if m.sections.count() = 0 then return
            m.isNarrating = true
            m.narrateIdx  = 0
            m.narratorGroup.isNarrating = true
            m.narrateTimer.control      = "start"
            btvShowNarrateSection()
            m.headerGroup.statusText = "AI Narrating - select again to stop"
        else
            m.isNarrating = false
            m.narratorGroup.isNarrating = false
            m.narrateTimer.control      = "stop"
            m.headerGroup.statusText    = "Narration stopped"
        end if

    else if action = "Show Similar Streams"
        showStreamsOverlay()

    else if action = "Compile for Mobile"
        compileMobile()

    else if action = "Cross-Reference"
        crossReference()

    else if action = "Zoom Video"
        toggleZoom()

    else if action = "Enter URL"
        btvCloseDrawer()
        showUrlDialog()
    end if
end sub

' -- AI Narrate -------------------------------------------------------
sub btvShowNarrateSection()
    if m.narrateIdx >= m.sections.count() then m.narrateIdx = 0
    sec = m.sections[m.narrateIdx]
    m.narratorGroup.sectionTitle  = sec.heading
    m.narratorGroup.narrationText = sec.body
    m.statusBar.tickerText = "AI [" + mid(stri(m.narrateIdx + 1), 2) + "/" + mid(stri(m.sections.count()), 2) + "]: " + sec.heading
end sub

sub onNarrateAdvance(event as Object)
    if m.isNarrating = false then return
    m.narrateIdx = m.narrateIdx + 1
    if m.narrateIdx >= m.sections.count() then m.narrateIdx = 0
    btvShowNarrateSection()
end sub

' -- Zoom -------------------------------------------------------------
sub toggleZoom()
    m.isZoomed = not m.isZoomed
    m.narratorGroup.zoomToggle = m.isZoomed
    if m.isZoomed
        m.headerGroup.statusText = "Zoomed - Play or Options to restore"
    else
        m.headerGroup.statusText = "Use Left/Right to browse tabs, OK to open"
    end if
end sub

' -- Streams overlay --------------------------------------------------
sub showStreamsOverlay()
    chanState = m.channelTask.taskState
    if m.matchedChans.count() > 0
        btvPopulateOverlay(m.matchedChans, m.matchedClips)
    else if chanState = "running"
        m.s1t.text = "~ Loading channel database..."
        m.s1s.text = "This takes 5-15s on first load."
        m.s2t.text = "~"
        m.s2s.text = ""
        m.s3t.text = "~"
        m.s3s.text = ""
        m.s4t.text = "~"
        m.s4s.text = ""
        m.s5t.text = "~"
        m.s5s.text = ""
        m.overlayStatus.text = "Watch ticker bar below for progress"
    else if chanState = "failed"
        m.s1t.text = "! Channel database unreachable"
        m.s1s.text = "Configured: " + m.dataBaseUrl
        m.s2t.text = "! Check: GitHub Pages enabled, workflow has run"
        m.s2s.text = "Actions tab -> Update Channel Data -> Run workflow"
        m.s3t.text = "~"
        m.s3s.text = ""
        m.s4t.text = "~"
        m.s4s.text = ""
        m.s5t.text = "~"
        m.s5s.text = ""
        m.overlayStatus.text = "Configuration needed - Back to close"
    else
        m.s1t.text = "~ No channels matched yet"
        m.s1s.text = "Load an article first, then try again"
        m.s2t.text = "~"
        m.s2s.text = ""
        m.s3t.text = "~"
        m.s3s.text = ""
        m.s4t.text = "~"
        m.s4s.text = ""
        m.s5t.text = "~"
        m.s5s.text = ""
        m.overlayStatus.text = "Back to close"
    end if
    m.streamsOverlay.visible = true
    m.overlayVisible = true
    m.headerGroup.statusText = "Similar Streams | Back to close"
end sub

sub btvPopulateOverlay(chans as Object, clips as Object)
    merged = []
    ci = 0
    while ci < clips.count() and merged.count() < 2
        clip = clips[ci]
        ci = ci + 1
        entry = { name: "[NEWS] " + clip.name, detail: clip.broadcaster + " | " + clip.date, url: clip.url }
        merged.push(entry)
    end while
    chi = 0
    while chi < chans.count() and merged.count() < 5
        ch = chans[chi]
        chi = chi + 1
        entry = { name: ch.name, detail: ch.source + " / " + ch.type + " | " + ch.cat, url: ch.url }
        merged.push(entry)
    end while
    labels = [m.s1t, m.s2t, m.s3t, m.s4t, m.s5t]
    subs   = [m.s1s, m.s2s, m.s3s, m.s4s, m.s5s]
    i = 0
    while i < 5
        if i < merged.count()
            labels[i].text = merged[i].name
            subs[i].text   = merged[i].detail
        else
            labels[i].text = "~"
            subs[i].text = ""
        end if
        i = i + 1
    end while
    m.overlayStatus.text = mid(stri(chans.count()), 2) + " streams, " + mid(stri(clips.count()), 2) + " clips | Back to close"
    m.overlayItems = merged
end sub

sub hideOverlay()
    m.streamsOverlay.visible = false
    m.overlayVisible = false
    btvRestoreNav()
end sub

' -- Compile for Mobile -----------------------------------------------
sub compileMobile()
    if m.sections.count() = 0 then return
    m.headerGroup.statusText = "Compiling M3U playlist..."
    m.compileStep  = 0
    m.compileTimer = m.top.createChild("Timer")
    m.compileTimer.duration = 1
    m.compileTimer.repeat   = true
    m.compileTimer.observeField("fire", "onCompileStep")
    m.compileTimer.control  = "start"
end sub

sub onCompileStep(event as Object)
    m.compileStep = m.compileStep + 1
    if m.compileStep = 1
        m.headerGroup.statusText = "Extracting section metadata..."
        m.statusBar.progress = 20
    else if m.compileStep = 2
        m.headerGroup.statusText = "Encoding thumbnails..."
        m.statusBar.progress = 45
    else if m.compileStep = 3
        m.headerGroup.statusText = "Resolving stream URLs..."
        m.statusBar.progress = 70
    else if m.compileStep = 4
        m.headerGroup.statusText = "Building M3U8 manifest..."
        m.statusBar.progress = 90
    else if m.compileStep = 5
        count = mid(stri(m.sections.count()), 2)
        m.headerGroup.statusText = "Done! " + count + " sections compiled"
        m.statusBar.tickerText = "Mobile playlist ready"
        m.statusBar.progress = 100
        m.compileTimer.control = "stop"
    end if
end sub

' -- Cross-Reference --------------------------------------------------
sub crossReference()
    if m.sections.count() = 0 then return
    sec = m.sections[m.narrateIdx]
    m.headerGroup.statusText = "Cross-referencing: " + sec.heading
    m.xrefTimer = m.top.createChild("Timer")
    m.xrefTimer.duration = 2
    m.xrefTimer.repeat   = false
    m.xrefTimer.observeField("fire", "onXrefDone")
    m.xrefTimer.control  = "start"
end sub

sub onXrefDone(event as Object)
    if m.sections.count() = 0 then return
    sec = m.sections[m.narrateIdx]
    m.headerGroup.statusText = "Cross-Ref: " + mid(stri(m.sections.count()), 2) + " sources"
    m.statusBar.tickerText   = sec.heading + " -> Wikipedia, Britannica, YouTube, Archive.org"
end sub

' -- URL Dialog -------------------------------------------------------
sub showUrlDialog()
    m.dialogVisible = true
    if m.urlHistory.count() = 0
        m.urlHistory = [
            "https://en.wikipedia.org/wiki/Television",
            "https://en.wikipedia.org/wiki/Internet",
            "https://en.wikipedia.org/wiki/Artificial_intelligence",
            "https://en.wikipedia.org/wiki/Space_exploration",
            "https://en.wikipedia.org/wiki/Streaming_media"
        ]
    end if
    m.urlDialog.urlHistory = FormatJson(m.urlHistory)
    m.urlDialog.visible    = true
    m.urlDialog.setFocus(true)
end sub

sub hideUrlDialog()
    m.urlDialog.visible = false
    m.dialogVisible     = false
    btvRestoreNav()
end sub

sub onUrlDialogDone(event as Object)
    url = event.getData()
    if url = "" then return
    hideUrlDialog()
    found = false
    hi = 0
    while hi < m.urlHistory.count()
        if m.urlHistory[hi] = url then found = true
        hi = hi + 1
    end while
    if found = false
        m.urlHistory.unshift(url)
        if m.urlHistory.count() > 50 then m.urlHistory.pop()
    end if
    startFetch(url)
end sub

sub onUrlDialogCancelled(event as Object)
    if event.getData() = true then hideUrlDialog()
end sub

' -- Task result handlers ---------------------------------------------
sub onChannelsMatched(event as Object)
    json = event.getData()
    if json = "" then return
    parsed = ParseJson(json)
    if type(parsed) = "roArray"
        m.matchedChans = parsed
        m.headerGroup.statusText = mid(stri(parsed.count()), 2) + " streams + " + mid(stri(m.matchedClips.count()), 2) + " clips matched"
    end if
end sub

sub onClipsMatched(event as Object)
    json = event.getData()
    if json = "" then return
    parsed = ParseJson(json)
    if type(parsed) = "roArray"
        m.matchedClips = parsed
        m.headerGroup.statusText = mid(stri(m.matchedChans.count()), 2) + " streams + " + mid(stri(parsed.count()), 2) + " clips"
    end if
end sub

sub onChannelTaskState(event as Object)
    state = event.getData()
    if state = "running"
        m.statusBar.tickerText   = "Loading channel database..."
    else if state = "done"
        m.statusBar.tickerText   = "Channel database ready"
    else if state = "failed"
        btvShowError("Channel data unreachable", m.dataBaseUrl)
    end if
end sub

sub onChannelProgress(event as Object)
    msg = event.getData()
    if msg <> "" then m.statusBar.tickerText = msg
end sub

sub onChannelError(event as Object)
    err = event.getData()
    if err <> "" then btvShowError("Stream load failed", err)
end sub

sub onTranscriptTaskState(event as Object)
    state = event.getData()
    if state = "running"
        m.statusBar.tickerText = "Loading transcript database..."
    else if state = "done"
        m.statusBar.tickerText = "Transcript database ready"
    end if
end sub

sub onTranscriptProgress(event as Object)
    msg = event.getData()
    if msg <> "" then m.statusBar.tickerText = msg
end sub

sub btvShowError(title as String, detail as String)
    print "BlogTV error: " + title + " - " + detail
    m.headerGroup.statusText = title
    m.statusBar.tickerText   = "Error: " + detail
    if m.overlayVisible then m.overlayStatus.text = "! " + title
end sub

sub onUrlHistoryLoaded(event as Object)
    json = event.getData()
    if json = "" then return
    parsed = ParseJson(json)
    if type(parsed) = "roArray" then m.urlHistory = parsed
end sub

' -- Demo timer -------------------------------------------------------
sub onTimerFire(event as Object)
    m.timerTick = m.timerTick + 1
    if m.timerTick > m.totalTicks then m.timerTick = 0
    m.statusBar.progress  = int((m.timerTick / m.totalTicks) * 100)
    m.statusBar.countdown = m.totalTicks - m.timerTick
end sub

' -- Content fetch ----------------------------------------------------
sub startFetch(url as String)
    print "BlogTVScene: startFetch(" + url + ")"
    m.headerGroup.statusText = "Fetching: " + url
    m.parserTask.targetUrl   = url
    m.parserTask.control     = "RUN"
end sub

sub onTaskStateChanged(event as Object)
    state = event.getData()
    if state = "done"
        m.headerGroup.statusText = "Content loaded"
        m.demoTimer.control = "start"
    else if state = "failed"
        m.headerGroup.statusText = "Network error - using demo data"
        loadDemoContent()
        m.demoTimer.control = "start"
    end if
end sub

sub onContentParsed(event as Object)
    jsonStr = event.getData()
    if jsonStr = "" then return
    if (type(jsonStr) <> "roString" and type(jsonStr) <> "String") then return
    content = ParseJson(jsonStr)
    if type(content) <> "roAssociativeArray" then return
    populateFromContent(content)
    m.articleKeywords = btvExtractKeywords(content)
    m.channelTask.articleKeywords = FormatJson(m.articleKeywords)
    m.matchedChans = []
    m.channelTask.control    = "RUN"
    m.transcriptTask.control = "RUN"
end sub

function btvExtractKeywords(content as Object) as Object
    words   = {}
    allText = content.title + " "
    i = 0
    while i < content.sections.count() and i < 5
        allText = allText + content.sections[i].heading + " "
        i = i + 1
    end while
    current = ""
    ci = 1
    while ci <= len(allText)
        ch = mid(allText, ci, 1)
        isAlpha = (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z")
        if isAlpha
            current = current + ch
        else
            if len(current) > 3 then words[lcase(current)] = true
            current = ""
        end if
        ci = ci + 1
    end while
    result = []
    for each w in words
        result.push(w)
        if result.count() >= 20 then exit for
    end for
    return result
end function

sub populateFromContent(content as Object)
    m.headerGroup.pageTitle = content.title
    m.sections = content.sections
    if content.sections.count() > 0
        m.narratorGroup.sectionTitle  = content.sections[0].heading
        m.narratorGroup.narrationText = content.sections[0].body
    end if
    rootNode = CreateObject("roSGNode", "ContentNode")
    i = 0
    while i < content.sections.count()
        sec   = content.sections[i]
        child = CreateObject("roSGNode", "ContentNode")
        child.title       = sec.heading
        child.description = sec.body
        rootNode.appendChild(child)
        i = i + 1
    end while
    m.sectionsGrid.content = rootNode
    m.pipGroup.pageUrl     = content.url
    m.pipGroup.pageTitle   = content.title
    m.pipGroup.sectionsJson = FormatJson(m.sections)
    m.statusBar.tickerText   = "Loaded: " + content.title
    m.statusBar.sectionCount = content.sections.count()
end sub

sub loadDemoContent()
    content = {}
    content.title = "The Future of Streaming Media"
    content.url   = m.sampleUrl
    content.sections = [
        { heading: "Introduction",        body: "Streaming has fundamentally changed how audiences consume content worldwide." },
        { heading: "Rise of IPTV",        body: "Internet Protocol Television delivers channels via broadband, enabling interactive features." },
        { heading: "AI in Broadcasting",  body: "Machine learning now powers recommendation engines and real-time content summaries." },
        { heading: "Codec Wars",          body: "AV1, HEVC, and VVC compete for bandwidth-efficient delivery at 4K and beyond." },
        { heading: "Mobile First Design", body: "Over 60% of streaming hours are consumed on smartphones and tablets." },
        { heading: "The Creator Economy", body: "Independent channels rival legacy broadcasters in both reach and revenue." }
    ]
    populateFromContent(content)
end sub

function setDeepLink(params as Object) as Void
    if type(params) = "roAssociativeArray" and params.DoesExist("contentId")
        startFetch(params.contentId)
    end if
end function
