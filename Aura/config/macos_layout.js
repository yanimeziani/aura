let allPanels = panels();
for (let i = 0; i < allPanels.length; ++i) {
    allPanels[i].remove();
}

// 1. Create Top Panel
var topPanel = new Panel("org.kde.plasma.panel");
topPanel.location = "top";
topPanel.alignment = "left";
topPanel.height = 32;

// Add Widgets to Top Panel
topPanel.addWidget("org.kde.plasma.kickoff"); // Apple Logo / Menu
topPanel.addWidget("org.kde.plasma.appmenu"); // Global Menu
topPanel.addWidget("org.kde.plasma.panelspacer"); // Spacer
topPanel.addWidget("org.kde.plasma.systemtray"); // System Tray
topPanel.addWidget("org.kde.plasma.digitalclock"); // Clock

// 2. Create Bottom Dock
var dock = new Panel("org.kde.plasma.panel");
dock.location = "bottom";
dock.alignment = "center";
dock.lengthMode = "fit"; // Fit Content
dock.floating = 1; // Floating Dock
dock.hiding = "windowscover"; // Dodge Windows / Auto-hide

// Add Widgets to Dock
dock.addWidget("org.kde.plasma.icontasks"); // Icons Only Task Manager
dock.addWidget("org.kde.plasma.trash"); // Trash Can
