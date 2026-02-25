' ChannelMatchTask.brs
' Fetches channels.json + url_history.json from GitHub Pages.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    baseUrl = m.top.dataBaseUrl
    if baseUrl = ""
        print "ChannelMatchTask: dataBaseUrl not set"
        m.top.taskState = "failed"
        return
    end if

    m.top.taskState    = "running"
    m.top.taskProgress = "Connecting to channel database..."

    chanJson = btvSyncGet(baseUrl + "/channels.json")
    if chanJson = ""
        m.top.taskError = "Could not fetch channels.json from " + baseUrl
        m.top.taskState = "failed"
        return
    end if

    m.top.taskProgress = "Loading URL history..."
    histJson = btvSyncGet(baseUrl + "/url_history.json")
    if histJson <> ""
        m.top.urlHistory = histJson
    end if

    m.top.taskProgress = "Parsing channel database..."
    chanData = ParseJson(chanJson)
    if type(chanData) <> "roAssociativeArray"
        m.top.taskError = "channels.json parse failed"
        m.top.taskState = "failed"
        return
    end if

    keywords = []
    if m.top.articleKeywords <> ""
        parsed = ParseJson(m.top.articleKeywords)
        if type(parsed) = "roArray" then keywords = parsed
    end if

    matchedCats = btvMatchCategories(keywords)

    scored = []
    cats   = chanData.categories
    if type(cats) <> "roAssociativeArray"
        m.top.taskError = "channels.json missing categories key"
        m.top.taskState = "failed"
        return
    end if

    ci = 0
    while ci < matchedCats.count()
        cat         = matchedCats[ci]
        ci          = ci + 1
        catChannels = cats[cat]
        if type(catChannels) = "roArray"
            chi = 0
            while chi < catChannels.count()
                ch  = catChannels[chi]
                chi = chi + 1
                if type(ch) = "roAssociativeArray"
                    score = 10
                    if ch.type   = "live"   then score = score + 20
                    if ch.source = "custom" then score = score + 15
                    if ch.source = "user"   then score = score + 25
                    ki = 0
                    while ki < keywords.count()
                        kw = lcase(keywords[ki])
                        ki = ki + 1
                        if kw <> ""
                            if lcase(ch.name) <> "" and instr(1, lcase(ch.name), kw) > 0
                                score = score + 10
                            end if
                            if (type(ch.desc) = "roString" or type(ch.desc) = "String") and instr(1, lcase(ch.desc), kw) > 0
                                score = score + 5
                            end if
                        end if
                    end while
                    entry        = {}
                    entry.name   = ch.name
                    entry.url    = ch.url
                    entry.logo   = ch.logo
                    entry.desc   = ch.desc
                    entry.source = ch.source
                    entry.type   = ch.type
                    entry.cat    = cat
                    entry.score  = score
                    scored.push(entry)
                end if
            end while
        end if
    end while

    btvSortByScore(scored)

    top10 = []
    ti = 0
    while ti < scored.count() and ti < 10
        top10.push(scored[ti])
        ti = ti + 1
    end while

    m.top.matchedChannels = FormatJson(top10)
    m.top.taskProgress    = "Done - " + mid(stri(top10.count()), 2) + " channels matched"
    m.top.taskState       = "done"
    print "ChannelMatchTask: done, " + stri(top10.count()) + " matches"
end sub

function btvSyncGet(url as String) as String
    print "ChannelMatchTask: fetching " + url
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
    print "ChannelMatchTask: result type=" + type(result) + " len=" + stri(len(result))
    if len(result) > 10
        print "ChannelMatchTask: got " + stri(len(result)) + " bytes"
        return result
    end if
    ' Try HTTP fallback
    httpUrl = "http://" + mid(url, 9)
    print "ChannelMatchTask: trying HTTP fallback " + httpUrl
    http2 = CreateObject("roUrlTransfer")
    http2.setUrl(httpUrl)
    http2.enableEncodings(true)
    http2.addHeader("User-Agent", "Roku/BlogTV/1.0")
    result2 = http2.getToString()
    if len(result2) > 10
        print "ChannelMatchTask: HTTP fallback got " + stri(len(result2)) + " bytes"
        return result2
    end if
    print "ChannelMatchTask: both HTTPS and HTTP failed for " + url
    return ""
end function

function btvMatchCategories(keywords as Object) as Object
    catNames = [
        "technology","technology","technology","technology",
        "science","science","science",
        "history","history","history",
        "news","news","news",
        "sports","sports","sports","sports",
        "music","music",
        "nature","nature","nature",
        "cooking","cooking",
        "travel","travel",
        "business","business","business",
        "health","health",
        "politics","politics",
        "kids","kids",
        "animation","animation",
        "entertainment","entertainment"
    ]
    catWords = [
        "technology","computer","software","hardware","internet",
        "science","physics","biology","chemistry",
        "history","historical","ancient","war",
        "news","current","breaking","today",
        "sport","sports","football","soccer","basketball","baseball",
        "music","song","band","concert",
        "nature","wildlife","animal","environment",
        "cook","food","recipe","chef",
        "travel","tourism","destination","adventure",
        "business","economy","finance","market",
        "health","medicine","medical","fitness",
        "politics","government","election","policy",
        "kids","children","child","educational",
        "animation","cartoon","animated",
        "entertainment","celebrity","film","movie"
    ]

    matched = []
    seen    = {}
    ki = 0
    while ki < keywords.count()
        kw = lcase(keywords[ki])
        ki = ki + 1
        wi = 0
        while wi < catWords.count()
            if instr(1, kw, catWords[wi]) > 0 or instr(1, catWords[wi], kw) > 0
                cat = catNames[wi]
                if not seen.DoesExist(cat)
                    seen[cat] = true
                    matched.push(cat)
                end if
            end if
            wi = wi + 1
        end while
    end while

    if not seen.DoesExist("general") then matched.push("general")
    return matched
end function

sub btvSortByScore(arr as Object)
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
