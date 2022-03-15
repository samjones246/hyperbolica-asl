state("Hyperbolica")
{
    // This boolean is set to false when the player clicks 'new game'
    // Second value is used if the player has not just launched the game
    bool menuActive : "GameAssembly.dll", 0x00DED008, 0x638, 0xB8, 0x8, 0x26C;
    bool menuActive2 : "GameAssembly.dll", 0x00D7F298, 0xA0, 0x8, 0x50, 0xB8, 0x10, 0x88, 0x56C;

    int crystalsObtained : "GameAssembly.dll", 0x00DF0A38, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // True once the lever is pulled. Second value is used if the player is returning to the boss after dying/quitting
    bool leverPulled : "GameAssembly.dll", 0x00D743D8, 0xA8, 0x68, 0x20, 0x10, 0x28, 0xA0, 0x1BD;
    bool leverPulled_retry : "GameAssembly.dll", 0x00DE39D8, 0x90, 0x28, 0x20, 0x20, 0x148, 0x1BD;

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
    if (old.menuActive && !current.menuActive || old.menuActive2 && !current.menuActive2){
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
    if (current.leverPulled || current.leverPulled_retry) {
        vars.Log("Lever pulled, splitting");
        return true;
    }

    return false;
}