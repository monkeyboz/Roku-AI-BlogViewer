# images/

Place the following placeholder image files here before sideloading.
Any PNG/JPG will work — BlogTV references them but Roku will show a blank
if they're missing (it will NOT crash).

Required files:
  icon_focus_hd.png   290×218 px  Channel icon (focused state)
  icon_side_hd.png    214×144 px  Channel icon (side panel)
  splash_hd.jpg       1280×720 px Splash screen
  ai_avatar.png       320×360 px  AI narrator avatar (centre panel)
  section_thumb.png   70×74 px    Section card thumbnail placeholder

Quick creation on macOS/Linux (creates solid-colour placeholders):
  convert -size 290x218  xc:#0D0D1A  icon_focus_hd.png
  convert -size 214x144  xc:#0D0D1A  icon_side_hd.png
  convert -size 1280x720 xc:#0D0D1A  splash_hd.jpg
  convert -size 320x360  xc:#12122A  ai_avatar.png
  convert -size 70x74    xc:#1A1A40  section_thumb.png

(Requires ImageMagick: brew install imagemagick  or  sudo apt install imagemagick)
