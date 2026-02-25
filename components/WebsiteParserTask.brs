' WebsiteParserTask.brs
' Task node - fetches URL and parses HTML into JSON string.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    url = m.top.targetUrl
    if url = ""
        m.top.taskState = "failed"
        return
    end if

    m.top.taskState = "running"

    http = CreateObject("roUrlTransfer")
    http.setUrl(url)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.enablePeerVerification(false)
    http.enableHostVerification(false)
    http.initClientCertificates()
    http.enableEncodings(true)
    http.addHeader("User-Agent", "Roku/BlogTV/1.0")
    http.addHeader("Accept", "text/html")
    html = http.getToString()

    if html = ""
        m.top.taskState = "failed"
        return
    end if

    pageTitle = btvGetTagText(html, "title")
    if pageTitle = "" then pageTitle = "Untitled Page"
    pageTitle = btvStripTags(pageTitle)

    h1arr = btvGetAllTagText(html, "h1")
    h2arr = btvGetAllTagText(html, "h2")
    parr  = btvGetAllTagText(html, "p")

    headings = []
    i = 0
    while i < h1arr.count()
        headings.push(h1arr[i])
        i = i + 1
    end while
    i = 0
    while i < h2arr.count()
        headings.push(h2arr[i])
        i = i + 1
    end while

    sections = []
    pi = 0
    hi = 0
    while hi < headings.count()
        h = btvStripTags(headings[hi])
        hi = hi + 1
        if len(h) >= 3
            body = ""
            while pi < parr.count()
                c = btvStripTags(parr[pi])
                pi = pi + 1
                if len(c) > 20
                    body = c
                    pi = pi + 0
                    exit while
                end if
            end while
            if body = "" then body = "No description available."
            if len(body) > 200 then body = left(body, 197) + "..."
            sec = {}
            sec.heading = h
            sec.body    = body
            sections.push(sec)
        end if
        if sections.count() >= 12 then exit while
    end while

    if sections.count() = 0
        body = ""
        pi2 = 0
        while pi2 < parr.count()
            c = btvStripTags(parr[pi2])
            pi2 = pi2 + 1
            if len(c) > 30
                body = c
                exit while
            end if
        end while
        if body = "" then body = "Could not parse content."
        if len(body) > 200 then body = left(body, 197) + "..."
        sec = {}
        sec.heading = pageTitle
        sec.body    = body
        sections.push(sec)
    end if

    resultAA = {}
    resultAA.url      = url
    resultAA.title    = pageTitle
    resultAA.sections = sections

    m.top.parsedContent = FormatJson(resultAA)
    m.top.taskState     = "done"
end sub

function btvGetTagText(html as String, tag as String) as String
    o = "<" + tag
    c = "</" + tag + ">"
    s = instr(1, lcase(html), lcase(o))
    if s = 0 then return ""
    g = instr(s, html, ">")
    if g = 0 then return ""
    e = instr(g, lcase(html), lcase(c))
    if e = 0 then return ""
    return mid(html, g + 1, e - g - 1)
end function

function btvGetAllTagText(html as String, tag as String) as Object
    arr = []
    o   = "<" + tag
    c   = "</" + tag + ">"
    p   = 1
    lh  = lcase(html)
    lo  = lcase(o)
    lc  = lcase(c)
    while p <= len(html)
        s = instr(p, lh, lo)
        if s = 0 then exit while
        g = instr(s, html, ">")
        if g = 0 then exit while
        e = instr(g, lh, lc)
        if e = 0 then exit while
        arr.push(mid(html, g + 1, e - g - 1))
        p = e + len(c)
        if arr.count() >= 50 then exit while
    end while
    return arr
end function

function btvStripTags(raw as String) as String
    out   = ""
    inTag = false
    i     = 1
    n     = len(raw)
    while i <= n
        ch = mid(raw, i, 1)
        if ch = "<"
            inTag = true
        else if ch = ">"
            inTag = false
        else if inTag = false
            out = out + ch
        end if
        i = i + 1
    end while
    out = btvReplaceAll(out, "&amp;",  "&")
    out = btvReplaceAll(out, "&lt;",   "<")
    out = btvReplaceAll(out, "&gt;",   ">")
    out = btvReplaceAll(out, "&quot;", chr(34))
    out = btvReplaceAll(out, "&#39;",  chr(39))
    out = btvReplaceAll(out, "&nbsp;", " ")
    out = btvCollapseSpaces(out)
    return out
end function

function btvReplaceAll(src as String, f as String, r as String) as String
    out  = ""
    p    = 1
    ls   = lcase(src)
    lf   = lcase(f)
    flen = len(f)
    while p <= len(src)
        found = instr(p, ls, lf)
        if found = 0
            out = out + mid(src, p)
            exit while
        end if
        out = out + mid(src, p, found - p) + r
        p   = found + flen
    end while
    return out
end function

function btvCollapseSpaces(s as String) as String
    out  = ""
    prev = false
    i    = 1
    n    = len(s)
    while i <= n
        ch = mid(s, i, 1)
        sp = false
        if ch = " "  then sp = true
        if ch = chr(9)  then sp = true
        if ch = chr(10) then sp = true
        if ch = chr(13) then sp = true
        if sp = true
            if prev = false
                out  = out + " "
                prev = true
            end if
        else
            out  = out + ch
            prev = false
        end if
        i = i + 1
    end while
    if left(out, 1) = " "  then out = mid(out, 2)
    if right(out, 1) = " " then out = left(out, len(out) - 1)
    return out
end function
