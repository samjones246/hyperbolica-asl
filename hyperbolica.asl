state("Hyperbolica")
{
       // This boolean is set to true when the player clicks 'new game'
    bool buttonClicked : "GameAssembly.dll", 0x00DD4648, 0xB8, 0x0, 0x70, 0x10, 0x1E0, 0x2D0, 0x138;

    int numCrystals : "GameAssembly.dll", 0x00DFA0B8, 0x760, 0x80, 0x310, 0x70, 0x1D0;

    // Number of trinkets collected since launching the game
    int numTrinkets : "GameAssembly.dll", 0x00DCA2C8, 0xB8, 0x0, 0x200, 0x10, 0xF0, 0xF0, 0xC0;

    // True once the lever is pulled
    bool leverPulled : "GameAssembly.dll", 0x00D808D8, 0x150, 0x248, 0x20, 0x28, 0x20, 0xA0, 0x1BD;

    bool isLoading : "UnityPlayer.dll", 0x019E6CC0, 0x0, 0x208, 0x10, 0x520;
}

startup
{
    // For logging (duh) 
    vars.Log = (Action<object>)((output) => print("[Hyperbolica ASL] " + output));

    // Function for deallocating memory used by this process
    vars.FreeMemory = (Action<Process>)(p => {
        vars.Log("Deallocating");
        foreach (IDictionary<string, object> hook in vars.hooks){
            if(((bool)hook["enabled"]) == false){
                continue;
            }
            p.FreeMemory((IntPtr)hook["outputPtr"]);
            p.FreeMemory((IntPtr)hook["funcPtr"]);
            p.FreeMemory((IntPtr)hook["origPtr"]);
        }
    });

    vars.hooks = new List<ExpandoObject> {
        (vars.loadLevel = new ExpandoObject()),
        (vars.newGame = new ExpandoObject()),
        //(vars.leverInteract = new ExpandoObject()),
        //(vars.trinketCollect = new ExpandoObject())
    };

    vars.loadLevel.name = "LoadLevel";
    vars.loadLevel.pattern = "D7 FF CC CC CC CC CC CC CC CC CC CC CC CC CC CC CC 48 89 5C 24 10";
    vars.loadLevel.outputSize = 0x08;
    vars.loadLevel.patternOffset = 0x11;
    vars.loadLevel.overwriteBytes = 15;
    vars.loadLevel.payload = new byte[] { 0x48, 0x89, 0x0A };
    vars.loadLevel.enabled = true;

    vars.newGame.name = "NewGame";
    vars.newGame.pattern = "40 53 48 83 EC 30 80 3D 1C 3A 59 00 00";
    vars.newGame.outputSize = 0x01;
    vars.newGame.patternOffset = 0x00;
    vars.newGame.overwriteBytes = 13;
    vars.newGame.payload = new byte[] { 0xC7, 0x02, 0x01, 0x00, 0x00, 0x00 };
    //vars.newGame.payload = new byte[] { 0x90 };
    vars.newGame.enabled = false;

    //vars.leverInteract.pattern = "";
    //vars.newGame.outputType = typeof(bool);

    //vars.trinketCollect.pattern = "";
    //vars.newGame.outputType = typeof(bool);

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

    // Find GameAssembly.dll
    ProcessModuleWow64Safe gameAssembly = null;
    foreach (ProcessModuleWow64Safe module in modules){
        if(module.ModuleName == "GameAssembly.dll"){
            gameAssembly = module;
            break;
        }
    }
    if (gameAssembly == null) {
        throw new Exception("GameAssembly.dll not found");
    }
    vars.Log("GameAssembly.dll found");
    var scanner = new SignatureScanner(game, gameAssembly.BaseAddress, gameAssembly.ModuleMemorySize);

    // Install hooks
    foreach (IDictionary<string, object> hook in vars.hooks)
    {
        if(((bool)hook["enabled"]) == false){
            continue;
        }
        vars.Log("Installing hook for " + hook["name"]);
        // AOB Scan to find injection point
        SigScanTarget target = new SigScanTarget(0, (string)hook["pattern"]);
        if ((IntPtr)(hook["injectPtr"] = scanner.Scan(target)) == IntPtr.Zero) {
            throw new Exception("[Hyperbolica ASL] Signature not matched for " + hook["name"]);
        }
        hook["injectPtr"] = (IntPtr)hook["injectPtr"] + (int)hook["patternOffset"];

        // Allocate memory for output
        hook["outputPtr"] = game.AllocateMemory((int)hook["outputSize"]);

        // Build the hook function
        var funcBytes = new List<byte>() {
            0x52,      // push rdx
            0x48, 0xBA // mov rdx, outputPtr
        };
        funcBytes.AddRange(BitConverter.GetBytes((UInt64)((IntPtr)hook["outputPtr"])));
        funcBytes.AddRange((byte[])hook["payload"]);
        funcBytes.Add(0x5A); // pop rdx

        // Allocate memory to store the function
        hook["funcPtr"] = game.AllocateMemory(funcBytes.Count + 12);
        
        // Write the detour: Injection point -> hook function -> orignal code -> injection point + 1
        game.Suspend();
        try {
            // The address where a copy of the overwritten code is stored
            hook["origPtr"] = game.WriteDetour((IntPtr)hook["injectPtr"], (int)hook["overwriteBytes"], (IntPtr)hook["funcPtr"]);
            
            // Write the hook function
            game.WriteBytes((IntPtr)hook["funcPtr"], funcBytes.ToArray());

            // Write the jump hook function to original code
            game.WriteJumpInstruction((IntPtr)hook["funcPtr"] + funcBytes.Count, (IntPtr)hook["origPtr"]);
        }
        catch {
            vars.FreeMemory(game);
            throw;
        }
        finally{
            game.Resume();
        }

        // Calcuate offset of injection point from module base address
        UInt64 offset = (UInt64)((IntPtr)hook["injectPtr"]) - (UInt64)gameAssembly.BaseAddress;

        vars.Log("Output: " + ((IntPtr)hook["outputPtr"]).ToString("X"));
        vars.Log("Injection: " + ((IntPtr)hook["injectPtr"]).ToString("X") + " (GameAssembly.dll+" + offset.ToString("X") + ")");
        vars.Log("Function: " + ((IntPtr)hook["funcPtr"]).ToString("X"));
        vars.Log("Original: " + ((IntPtr)hook["origPtr"]).ToString("X"));
    }

    vars.sceneNameOld = "Unknown";
    vars.sceneNameNew = "Unknown"; 

    vars.sceneNamePtrOld = IntPtr.Zero;
    vars.sceneNamePtrNew = IntPtr.Zero;
}

update
{
    // Get pointer to destination scene name from dump location
    vars.sceneNamePtrOld = vars.sceneNamePtrNew;
    vars.sceneNameOld = vars.sceneNameNew;
    vars.sceneNamePtrNew = game.ReadValue<IntPtr>((IntPtr)vars.loadLevel.outputPtr);
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
        if (settings["splitTrinket"] || (settings["splitMap"] && vars.trinkets == 0)){
            vars.Log("Trinkets increased from " + vars.trinkets + " to " + vars.trinkets + 1 + ", splitting");
            vars.trinkets++;
            return true;
        }
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
        vars.Log("Restoring memory");
        foreach (IDictionary<string, object> hook in vars.hooks){
            if(((bool)hook["enabled"]) == false){
                continue;
            }
            var bytes = game.ReadBytes((IntPtr)hook["origPtr"], (int)hook["overwriteBytes"]);
            game.WriteBytes((IntPtr)hook["injectPtr"], bytes);
        }
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