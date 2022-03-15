state("Hyperbolica")
{
    // This boolean is set to false when the player clicks 'new game'
    bool menuActive : "GameAssembly.dll", 0x00DED008, 0x638, 0xB8, 0x8, 0x26C;

    int crystalsObtained : "GameAssembly.dll", 0x00DF0A38, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00DE39D8, 0x90, 0x28, 0x20, 0x20, 0x148, 0x1bd;
}

startup
{
    // For logging (duh)
    vars.Log = (Action<object>)((output) => print("[Hyperbolica ASL] " + output));
}

start {
    // When menuActive becomes true, start the timer
    if (old.menuActive && !current.menuActive){
        vars.Log("Starting Timer");
        return true;
    }
    return false;
}

split
{
    // Split when number of crystals obtained increases
    if (current.crystalsObtained > old.crystalsObtained){
        vars.Log("Crystal Obtained, splitting");
        return true;
    }

    // Split when lever pulled after boss fight
    if (current.leverPulled) {
        vars.Log("Lever pulled, splitting");
        return true;
    }

    return false;
}