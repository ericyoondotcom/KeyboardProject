# KeyboardProject

## How to install
1. Open in XCode
2. Edit your signing stuff in XCode project settings
3. `sudo chmod -R 777 /Library/Input\ Methods`
4. Run the project
5. RESTART YOUR MAC
6. Go to System Settings -> Keyboard -> Input Sources -> Add -> English -> KeyboardProject

## Reloading Without Restarting
We initially thought that you have to restart your computer every time you make a change to the project.

However, we modified the XCode build pipeline to add a Build Script phase, that runs `killall KeyboardProject`.
