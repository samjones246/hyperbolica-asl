state("Hyperbolica")
{
    // This boolean is set to true when the player clicks 'new game'
    bool buttonClicked : "GameAssembly.dll", 0x00E77E00, 0xF68, 0x150, 0x2A8, 0x110, 0x10, 0x18, 0x198;


    int numCrystals : "GameAssembly.dll", 0x00DF1B68, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // Number of trinkets collected since launching the game
    int numTrinkets : "GameAssembly.dll", 0x00DEEFD8, 0x160, 0x3C0, 0x100, 0x18, 0x120, 0xF0, 0xC0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00DE4AD8, 0x150, 0x248, 0x20, 0x28, 0x20, 0xA0, 0x1BD;

    bool isLoading : "UnityPlayer.dll", 0x019E6CC0, 0x0, 0x208, 0x10, 0x520;

    // Currently unused
    bool isPaused : "GameAssembly.dll", 0x00D80728, 0x78, 0x48, 0x40, 0x80, 0xB0, 0xB8, 0x07;
}

startup
{
    // For logging (duh) 
    vars.Log = (Action<object>)((output) => print("[Hyperbolica ASL] " + output));

    settings.Add("splitCrystal", true, "Split on crystal collection");
    settings.Add("splitMap", false, "Split on first trinket collection");
    settings.SetToolTip("splitMap", "This will be the map in an any% run");
    settings.Add("splitTrinket", false, "Split on any trinket collection");
}

init {
    // Seems to be some volatility in numCrystals pointer during loads, stable copy of last known value to fix
    vars.crystals = 0;
}

start {
    // When buttonClicked becomes true, start the timer
    if (current.buttonClicked && !old.buttonClicked){
        vars.Log("Starting Timer");
        // Trinkets collected during current run
        vars.trinkets = 0;
        return true;
    }
    return false;
}

isLoading{
    return current.isLoading;
}

split
{
    // Split when number of crystals obtained increases
    if (settings["splitCrystal"] && current.numCrystals == vars.crystals + 1){
        vars.Log("Crystals increased from " + vars.crystals + " to " + current.numCrystals + ", splitting");
        vars.crystals++;
        return true;
    }

    // Split on trinket collection
    if (current.numTrinkets == old.numTrinkets + 1){
        if (settings["splitTrinket"] || settings["splitMap"] && vars.trinkets == 0){
            vars.Log("Trinkets increased from " + vars.trinkets + " to " + vars.trinkets + 1 + ", splitting");
            return true;
        }
        vars.trinkets++;
    }

    // Split when lever pulled after boss fight
    if (vars.crystals >= 5 && !old.leverPulled && current.leverPulled) {
        vars.Log("Lever pulled, splitting");
        return true;
    }

    return false;
}
