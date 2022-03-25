state("Hyperbolica")
{
    // This boolean is set to true when the player clicks 'new game'
    bool buttonClicked : "GameAssembly.dll", 0x00C1F5C8, 0xB8, 0x0, 0x70, 0x10, 0x1E0, 0x2D0, 0x138;

    int numCrystals : "GameAssembly.dll", 0x00C7F238, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // Number of trinkets collected since launching the game
    int numTrinkets : "GameAssembly.dll", 0x00C17888, 0xB8, 0x0, 0x200, 0x10, 0xF0, 0xF0, 0xC0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00C72E98, 0x150, 0x248, 0x20, 0x28, 0x20, 0xA0, 0x1BD;

    bool isLoading : "UnityPlayer.dll", 0x019E6CC0, 0x0, 0x208, 0x10, 0x520;
}

startup
{
    // For logging (duh) 
    vars.Log = (Action<object>)((output) => print("[Hyperbolica ASL] " + output));

    // Create settings
    settings.Add("splitCrystal", true, "Split on crystal collection");
    settings.Add("splitMap", false, "Split on first trinket collection");
    settings.SetToolTip("splitMap", "This will be the map in an any% run");
    settings.Add("splitTrinket", false, "Split on any trinket collection");
    settings.Add("splitSubEnter", false, "Split on entering a subarea");
    settings.Add("splitSubExit", false, "Split on exiting a subarea");

}

init {
    // Seems to be some volatility in numCrystals pointer during loads, stable copy of last known value to fix
    vars.crystals = 0;
    // Trinkets collected during current run
    vars.trinkets = 0;
}

start {
    // When buttonClicked becomes true, start the timer
    if (current.buttonClicked && !old.buttonClicked){
        vars.Log("Starting Timer");
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