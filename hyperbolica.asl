state("Hyperbolica")
{
    // This boolean is set to true when the player clicks 'new game'
    bool buttonClicked : "GameAssembly.dll", 0x00D82FB0, 0xB8, 0x8, 0x150, 0x10, 0x1E0, 0x2D0, 0x138;

    int numCrystals : "GameAssembly.dll", 0x00DF1B68, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // Number of trinkets collected since launching the game
    int numTrinkets : "GameAssembly.dll", 0x00D813B8, 0xB8, 0x0, 0x200, 0x10, 0xF0, 0xF0, 0xC0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00DE4AE8, 0x150, 0x248, 0x20, 0x28, 0x20, 0xA0, 0x1BD;

    bool isLoading : "UnityPlayer.dll", 0x019E6CC0, 0x0, 0x208, 0x10, 0x520;
}

startup
{
    // For logging (duh) 
    vars.Log = (Action<object>)((output) => print("[Hyperbolica ASL] " + output));

    // Function for deallocating memory used by this process
    vars.FreeMemory = (Action<Process>)(p => {
        vars.Log("Deallocating");
        p.FreeMemory((IntPtr)vars.sceneDumpPtr);
        p.FreeMemory((IntPtr)vars.destPtr);
        p.FreeMemory((IntPtr)vars.gatePtr);
    });

    // AOB signature for LoadScene
    vars.scanLoadScene = new SigScanTarget(0, "D7 FF CC CC CC CC CC CC CC CC CC CC CC CC CC CC CC 48 89 5C 24 10");

    // Create settings
    settings.Add("splitCrystal", true, "Split on crystal collection");
    settings.Add("splitMap", false, "Split on first trinket collection");
    settings.SetToolTip("splitMap", "This will be the map in an any% run");
    settings.Add("splitTrinket", false, "Split on any trinket collection");
    settings.Add("splitSubEnter", false, "Split on entering a subarea");
    settings.Add("splitSubExit", false, "Split on exiting a subarea");

    var subareas = new string[] {
        "Cafe",
        "Farm",
        "Snow",
        "Maze",
        "Gallery"
    };

    vars.isSubarea = (Func<string, bool>)(name => {
        return Array.Exists(subareas, e => e == name);
    });

    vars.enteredSubarea = (Func<bool>)(() => {
        return vars.sceneNameOld == "Over" && vars.isSubarea(vars.sceneNameNew);
    });

    vars.leftSubarea = (Func<bool>)(() => {
        return vars.sceneNameNew == "Over" && vars.isSubarea(vars.sceneNameOld);
    });

}

init {
    // Seems to be some volatility in numCrystals pointer during loads, stable copy of last known value to fix
    vars.crystals = 0;
    // Trinkets collected during current run
    vars.trinkets = 0;

    vars.sceneNameOld = "Unknown";
    vars.sceneNameNew = "Unknown"; 

    vars.sceneNamePtrOld = IntPtr.Zero;
    vars.sceneNamePtrNew = IntPtr.Zero;

    // AOB Scan for LoadScene
    vars.srcPtr = IntPtr.Zero;
    vars.Log("Scanning memory for ");
    var scanner = new SignatureScanner(game, modules[41].BaseAddress, modules[41].ModuleMemorySize);
    vars.srcPtr = scanner.Scan(vars.scanLoadScene);

    if (vars.srcPtr == IntPtr.Zero) {
        throw new Exception("[Hyperbolica ASL] LoadScene signature not matched");
    }

    // Allocate memory where pointer to scene name will be dumped
    vars.sceneDumpPtr = game.AllocateMemory(8);
    var sceneDumpPtrBytes = BitConverter.GetBytes((UInt64)vars.sceneDumpPtr);

    // Initialise injected code
    var injectedFuncBytes = new List<byte>() {
        0x52,      // push rdx
        0x48, 0xBA // mov rdx, sceneDumpPtr
    };
    injectedFuncBytes.AddRange(sceneDumpPtrBytes);
    injectedFuncBytes.AddRange(new byte[] {
        0x48, 0x89, 0x0A,             // mov [rdx], rcx
        0x5A,                         // pop rdx
        0x48, 0x89, 0x5C, 0x24, 0x10, // mov[rsp+10], rbx
    });

    var jmpOffset = injectedFuncBytes.Count;
    vars.destPtr = game.AllocateMemory(injectedFuncBytes.Count+12);

    
    vars.Log("Found injection point at " + vars.srcPtr);
    // Increment vars.srcPtr by 0x11 to get to point in signature where we want to inject
    vars.srcPtr += 0x11;

    // Overwrite 15 bytes at vars.srcPtr with jump to injected code
    game.Suspend();
    try 
    {
        vars.gatePtr = game.WriteDetour((IntPtr)vars.srcPtr, 15, (IntPtr)vars.destPtr);
        var gatePtrBytes = BitConverter.GetBytes((UInt64)vars.gatePtr); 

        // Write the injected function
        game.WriteBytes((IntPtr)vars.destPtr, injectedFuncBytes.ToArray());

        // Write the jump from end of dest to gate
        game.WriteJumpInstruction((IntPtr)vars.destPtr + jmpOffset, (IntPtr)vars.gatePtr);

    } 
    catch 
    {
        vars.FreeMemory(game);
        throw;
    } 
    finally 
    {
        game.Resume();
    }

    vars.Log("sceneDumpPtr: " + vars.sceneDumpPtr.ToString("X"));

}

update
{
    // Get pointer to destination scene name from dump location
    vars.sceneNamePtrOld = vars.sceneNamePtrNew;
    vars.sceneNameOld = vars.sceneNameNew;
    vars.sceneNamePtrNew = game.ReadValue<IntPtr>((IntPtr)vars.sceneDumpPtr);
    if (vars.sceneNamePtrOld == vars.sceneNamePtrNew){
        return;
    }
    if (vars.sceneNamePtrNew != IntPtr.Zero){
        // Read string length, then read that many characters
        int length = game.ReadValue<int>((IntPtr)vars.sceneNamePtrNew+0x10);
        char[] nameChars = new char[length];
        for (int i=0;i<length;i++){
            IntPtr charPtr = vars.sceneNamePtrNew + 0x14 + (i * 2);
            nameChars[i] = game.ReadValue<char>(charPtr);
        }
        // Put chars together to form the string
        vars.sceneNameNew = new String(nameChars);
    }
    if (vars.sceneNameNew != vars.sceneNameOld){
        vars.Log("Transitioning from '" + vars.sceneNameOld + "' to '" + vars.sceneNameNew + "'");
    }
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

    // Split on entering sub area
    if (settings["splitSubEnter"] && vars.enteredSubarea()){
        vars.Log("Entering subarea, splitting");
        return true;
    }

    if (settings["splitSubExit"] && vars.leftSubarea()){
        vars.Log("Leaving subarea, splitting");
        return true;
    }


    return false;
}

shutdown
{
    if (game == null)
        return;

    game.Suspend();
    try
    {
        // Remove hook
        vars.Log("Restoring memory");
        var bytes = game.ReadBytes((IntPtr)vars.gatePtr, 15);
        game.WriteBytes((IntPtr)vars.srcPtr, bytes);
        vars.Log("Memory restored");
    }
    catch
    {
        throw;
    }
    finally
    {
        game.Resume();
        vars.FreeMemory(game);
    }
}