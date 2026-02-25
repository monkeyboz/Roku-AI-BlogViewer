' ============================================================
' BlogTV - main.brs
' Entry point: creates the Screen and launches the SceneGraph
' ============================================================

sub Main(aa as Object)
    print "BlogTV: Starting up..."

    ' Create the standard SceneGraph screen
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Instantiate the root scene
    scene = screen.CreateScene("BlogTVScene")
    screen.show()

    ' Pass any deep-link parameters to the scene
    if type(aa) = "roAssociativeArray"
        if aa.DoesExist("contentId") then scene.callFunc("setDeepLink", aa)
    end if

    ' Main event loop
    while true
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed()
                print "BlogTV: Screen closed, exiting."
                return
            end if
        end if
    end while
end sub
