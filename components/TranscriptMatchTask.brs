' TranscriptMatchTask.brs
' Fetches transcripts.json and scores clips against article keywords.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    baseUrl = m.top.dataBaseUrl
    if baseUrl = ""
        m.top.taskState = "failed"
        return
    end if

    m.top.taskState    = "running"
    m.top.taskProgress = "Connecting to transcript database..."

    json = btvTSyncGet(baseUrl + "/transcripts.json")
    if json = ""
        print "TranscriptMatchTask: could not fetch transcripts.json"
        m.top.taskState = "failed"
        return
    end if

    data = ParseJson(json)
    if type(data) <> "roAssociativeArray"
        print "TranscriptMatchTask: parse failed"
        m.top.taskState = "failed"
        return
    end if

    keywords = []
    if m.top.articleKeywords <> ""
        parsed = ParseJson(m.top.articleKeywords)
        if type(parsed) = "roArray" then keywords = parsed
    end if

    allClips   = []
    byCategory = data.byCategory
    if type(byCategory) <> "roAssociativeArray"
        m.top.taskState = "failed"
        return
    end if

    for each catName in byCategory
        catClips = byCategory[catName]
        if type(catClips) = "roArray"
            ci = 0
            while ci < catClips.count()
                clip = catClips[ci]
                ci   = ci + 1
                if type(clip) = "roAssociativeArray"
                    allClips.push(clip)
                end if
            end while
        end if
    end for

    scored = []
    ai = 0
    while ai < allClips.count()
        clip  = allClips[ai]
        ai    = ai + 1
        score = 0

        if clip.category = "keyword_match" then score = score + 30
        if clip.source   = "gdelt"         then score = score + 15
        if clip.source   = "archive-tv"    then score = score + 10

        clipName = lcase(clip.name)
        clipDesc = lcase(clip.desc)
        ki = 0
        while ki < keywords.count()
            kw = lcase(keywords[ki])
            ki = ki + 1
            if kw <> ""
                if instr(1, clipName, kw) > 0 then score = score + 20
                if instr(1, clipDesc,  kw) > 0 then score = score + 8
                if (type(clip.broadcaster) = "roString" or type(clip.broadcaster) = "String")
                    if instr(1, lcase(clip.broadcaster), kw) > 0 then score = score + 5
                end if
            end if
        end while

        hasUrl = false
        if (type(clip.url) = "roString" or type(clip.url) = "String")
            if clip.url <> "" then hasUrl = true
        end if

        if hasUrl = true
            entry             = {}
            entry.name        = clip.name
            entry.url         = clip.url
            entry.page_url    = clip.page_url
            entry.desc        = clip.desc
            entry.date        = clip.date
            entry.broadcaster = clip.broadcaster
            entry.source      = clip.source
            entry.type        = clip.type
            entry.category    = clip.category
            entry.score       = score
            scored.push(entry)
        end if
    end while

    btvTSort(scored)

    top8 = []
    ti = 0
    while ti < scored.count() and ti < 8
        top8.push(scored[ti])
        ti = ti + 1
    end while

    m.top.matchedClips = FormatJson(top8)
    m.top.taskState    = "done"
    print "TranscriptMatchTask: done, " + stri(top8.count()) + " clips"
end sub

function btvTSyncGet(url as String) as String
    print "TranscriptMatchTask: fetching " + url
    http = CreateObject("roUrlTransfer")
    http.setUrl(url)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.enablePeerVerification(false)
    http.enableHostVerification(false)
    http.initClientCertificates()
    http.enableEncodings(true)
    http.addHeader("User-Agent", "Roku/BlogTV/1.0")
    http.addHeader("Accept", "application/json, text/plain, */*")
    result = http.getToString()
    print "TranscriptMatchTask: result type=" + type(result) + " len=" + stri(len(result))
    if len(result) > 10
        print "TranscriptMatchTask: got " + stri(len(result)) + " bytes"
        return result
    end if
    ' Try HTTP fallback
    httpUrl = "http://" + mid(url, 9)
    print "TranscriptMatchTask: trying HTTP fallback " + httpUrl
    http2 = CreateObject("roUrlTransfer")
    http2.setUrl(httpUrl)
    http2.enableEncodings(true)
    http2.addHeader("User-Agent", "Roku/BlogTV/1.0")
    result2 = http2.getToString()
    if len(result2) > 10
        print "TranscriptMatchTask: HTTP fallback got " + stri(len(result2)) + " bytes"
        return result2
    end if
    print "TranscriptMatchTask: both HTTPS and HTTP failed for " + url
    return ""
end function

sub btvTSort(arr as Object)
    i = 1
    while i < arr.count()
        key = arr[i]
        j   = i - 1
        while j >= 0 and arr[j].score < key.score
            arr[j + 1] = arr[j]
            j = j - 1
        end while
        arr[j + 1] = key
        i = i + 1
    end while
end sub
