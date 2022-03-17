state("Hyperbolica")
{
    // This boolean is set to false when the player clicks 'new game'
    bool menuActive : "GameAssembly.dll", 0x00D802F0, 0xA0, 0x8, 0x50, 0xB8, 0x10, 0x88, 0x56C;

    int crystalsObtained : "GameAssembly.dll", 0x00DF1B38, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00D8A140, 0xD8, 0x20, 0x28, 0x20, 0xE8, 0x28, 0x1BD;

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
    // When menuActive becomes true, start the timer
    if (old.menuActive && !current.menuActive){
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
    if (!old.leverPulled && current.leverPulled) {
        vars.Log("Lever pulled, splitting");
        return true;
    }

    return false;
}
