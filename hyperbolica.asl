state("Hyperbolica")
{
    // This boolean is set to true when the player clicks 'new game'
    bool buttonClicked : "GameAssembly.dll", 0x00E77E00, 0xF68, 0x150, 0x2A8, 0x110, 0x10, 0x18, 0x198;

    int crystalsObtained : "GameAssembly.dll", 0x00DF1B68, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00DE4AD8, 0x150, 0x248, 0x20, 0x28, 0x20, 0xA0, 0x1BD;

    bool isLoading : "UnityPlayer.dll", 0x019E6CC0, 0x0, 0x208, 0x10, 0x520;
}

startup
{
    // For logging (duh) 
    vars.Log = (Action<object>)((output) => print("[Hyperbolica ASL] " + output));
}

init {
    // Seems to be some volatility in crystalsObtained pointer during loads, stable copy of last known value to fix
    vars.crystals = 0; 
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
    if (current.crystalsObtained == vars.crystals + 1){
        vars.Log("Crystals increased from " + vars.crystals + " to " + current.crystalsObtained + ", splitting");
        vars.crystals++;
        return true;
    }

    // Split when lever pulled after boss fight
    if (vars.crystals >= 5 && !old.leverPulled && current.leverPulled) {
        vars.Log("Lever pulled, splitting");
        return true;
    }

    return false;
}
