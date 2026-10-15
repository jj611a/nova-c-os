// Nova-C OS default layout: slim floating top bar (launcher, clock, tray) + floating icon dock at the bottom.

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    var d = desktopsArray[j];
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    d.writeConfig('Image', 'file:///usr/share/wallpapers/NovaC');
}

// ---- top bar ----
var top = new Panel;
top.location = 'top';
top.height = 34;
top.floating = true;     // floats like the dock; Plasma docks it to the screen edge when a window is maximized

var launcher = top.addWidget('org.kde.plasma.kickoff');
launcher.currentConfigGroup = ['General'];
launcher.writeConfig('icon', 'novac-logo');

top.addWidget('org.kde.plasma.panelspacer');
top.addWidget('org.kde.plasma.digitalclock');
top.addWidget('org.kde.plasma.panelspacer');
top.addWidget('org.kde.plasma.systemtray');

// ---- bottom dock ----
var dock = new Panel;
dock.location = 'bottom';
dock.height = 60;
dock.floating = true;
dock.alignment = 'center';
dock.lengthMode = 'fit';

var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('launchers', [
    'applications:org.kde.dolphin.desktop',
    'applications:firefox-esr.desktop',
    'applications:org.kde.konsole.desktop',
    'applications:org.kde.kate.desktop',
    'applications:org.kde.discover.desktop',
    'applications:systemsettings.desktop'
]);
