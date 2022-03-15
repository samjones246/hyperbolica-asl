state("Hyperbolica")
{
    // This boolean is set to false when the player clicks 'new game'
    bool menuActive : "GameAssembly.dll", 0x00DED008, 0x638, 0xB8, 0x8, 0x26C;

    int crystalsObtained : "GameAssembly.dll", 0x00DF0A38, 0x760, 0x80, 0x310, 0x70, 0x1D0;
}

startup
{
    vars.Log = (Action<object>)((output) => print("[Process ASL] " + output));
}

start {
    // When menuActive becomes true, start the timer
    return old.menuActive && !current.menuActive;
}

split
{
    // Split when number of crystals obtained increases
    return current.crystalsObtained > old.crystalsObtained;
}