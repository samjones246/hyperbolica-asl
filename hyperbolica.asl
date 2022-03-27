state("Hyperbolica")
{

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
        }
    });

    vars.hooks = new List<ExpandoObject> {
        (vars.loadLevel = new ExpandoObject()),
        (vars.newGame = new ExpandoObject()),
        //(vars.leverInteract = new ExpandoObject()),
        (vars.trinketCollect = new ExpandoObject())
    };

    vars.loadLevel.name = "LoadLevel";
    vars.loadLevel.offset = 0x420240;
    vars.loadLevel.caveOffset = 0x471;
    vars.loadLevel.outputSize = 8;
    vars.loadLevel.overwriteBytes = 5;
    vars.loadLevel.payload = new byte[] { 0x48, 0x89, 0x08 }; // mov [rax], rcx
    vars.loadLevel.enabled = true;

    vars.newGame.name = "NewGame";
    vars.newGame.offset = 0x715CD0;
    vars.newGame.caveOffset = 0x992;
    vars.newGame.outputSize = 1;
    vars.newGame.overwriteBytes = 6;
     // mov dword ptr [rax], 1
    vars.newGame.payload = new byte[] { 0xC7, 0x00, 0x01, 0x00, 0x00, 0x00 };
    vars.newGame.enabled = true;

    vars.trinketCollect.name = "TrinketCollect";
    vars.trinketCollect.offset = 0xA34B00;
    vars.trinketCollect.caveOffset = 0x90;
    vars.trinketCollect.outputSize = 12;
    vars.trinketCollect.overwriteBytes = 5;
    vars.trinketCollect.payload = new byte[] {
        0x48, 0x89, 0x08, // mov [rax], rcx
        0x89, 0x50, 0x08 // mov [rax+8], edx
    }; 
    vars.trinketCollect.enabled = true;

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

    var crystals = new string[] {
        "tetrahedron1",
        "tetrahedron2",
        "tetrahedron3",
        "tetrahedron4",
        "tetrahedron5",
    }

    var trinkets = new string[] {
        "map", "watch", "", "", "",
        "", "", "", "", "horseshoe",
        "", "", "", "", "",
        "spoon", "", "", "", "",
    }

    vars.isSubarea = (Func<string, bool>)(name => {
        return Array.Exists(subareas, e => e == name);
    });

    vars.enteredSubarea = (Func<bool>)(() => {
        return vars.sceneNameOld == "Over" && vars.isSubarea(vars.sceneNameNew);
    });

    vars.leftSubarea = (Func<bool>)(() => {
        return vars.sceneNameNew == "Over" && vars.isSubarea(vars.sceneNameOld);
    });

    vars.readString = (Func<IntPtr, Process, string>)((ptr, p) => {
        int length = p.ReadValue<int>(ptr+0x10);
        char[] nameChars = new char[length];
        for (int i=0;i<length;i++){
            IntPtr charPtr = ptr + 0x14 + (i * 2);
            nameChars[i] = p.ReadValue<char>(charPtr);
        }
        return new String(nameChars);
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

        // Get pointer to function
        hook["injectPtr"] = gameAssembly.BaseAddress + (int)hook["offset"];

        // Get pointer to cave
        hook["cavePtr"] = (IntPtr)hook["injectPtr"] + (int)hook["caveOffset"];

        // Allocate memory for output
        hook["outputPtr"] = game.AllocateMemory((int)hook["outputSize"]);

        // Build the hook function
        var funcBytes = new List<byte>() { 0x48, 0xB8 }; // mov rax, ...
        funcBytes.AddRange(BitConverter.GetBytes((UInt64)((IntPtr)hook["outputPtr"]))); // ...outputPtr
        funcBytes.AddRange((byte[])hook["payload"]);

        // Allocate memory to store the function
        hook["funcPtr"] = game.AllocateMemory(funcBytes.Count + (int)hook["overwriteBytes"] + 12);
        
        // Write the detour: Injection point -> hook function -> orignal code -> injection point + 1
        game.Suspend();
        try {
            // Copy the bytes which will be overwritten
            byte[] overwritten = game.ReadBytes((IntPtr)hook["injectPtr"], (int)hook["overwriteBytes"]);

            // Write short jump to code cave
            List<byte> caveJump = new List<byte>() { 0xE9 }; // jmp ...
            caveJump.AddRange(BitConverter.GetBytes((int)hook["caveOffset"] - 5)); // ...caveOffset - 5
            game.WriteBytes((IntPtr)hook["injectPtr"], caveJump.ToArray());
            hook["origBytes"] = overwritten;

            // NOP out excess bytes
            for(int i=0;i<(int)hook["overwriteBytes"]-5;i++){
                game.WriteBytes((IntPtr)hook["injectPtr"] + 5 + i, new byte[] { 0x90 });
            }

            // Write jump to hook function in code cave
            game.WriteJumpInstruction((IntPtr)hook["cavePtr"], (IntPtr)hook["funcPtr"]);
            
            // Write the hook function
            game.WriteBytes((IntPtr)hook["funcPtr"], funcBytes.ToArray());

            // Write the overwritten code
            game.WriteBytes((IntPtr)hook["funcPtr"] + funcBytes.Count, overwritten);

            // Write the jump to the original function
            game.WriteJumpInstruction((IntPtr)hook["funcPtr"] + funcBytes.Count + (int)hook["overwriteBytes"], (IntPtr)hook["injectPtr"] + (int)hook["overwriteBytes"]);
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
    }

    vars.Watchers = new MemoryWatcherList
    {
        (vars.loadLevel.output = new MemoryWatcher<IntPtr>((IntPtr)vars.loadLevel.outputPtr)),
        (vars.newGame.output = new MemoryWatcher<bool>((IntPtr)vars.newGame.outputPtr)),
        (vars.trinketCollect.output1 = new MemoryWatcher<IntPtr>((IntPtr)vars.trinketCollect.outputPtr)),
        (vars.trinketCollect.output2 = new MemoryWatcher<int>((IntPtr)vars.trinketCollect.outputPtr + 0x8)),  
    };

    vars.sceneNameOld = "Unknown";
    vars.sceneNameNew = "Unknown";

    vars.stateKeyOld = "";
    vars.stateKeyNew = "";
}

update
{   
    vars.Watchers.UpdateAll(game);

    // Update scene name from dumkped pointer
    vars.sceneNameOld = vars.sceneNameNew;
    if (vars.loadLevel.output.Current != vars.loadLevel.output.Old) {
        vars.sceneNameNew = vars.readString(vars.loadLevel.output.Current, game);
    }
    if (vars.sceneNameNew != vars.sceneNameOld){
        vars.Log("Transitioning from '" + vars.sceneNameOld + "' to '" + vars.sceneNameNew + "'");
    }

    // Get latest state update
    vars.stateKeyOld = vars.stateKeyNew;
    if (vars.trinketCollect.output1.Current != vars.trinketCollect.output1.Old) {
        vars.stateKeyNew = vars.readString(vars.trinketCollect.output1.Current, game);
    }
    if (vars.stateKeyNew != vars.stateKeyOld){
        vars.Log("State updated: " + vars.stateKeyNew + ", " + vars.trinketCollect.output2.Current);
    }
}

start {
    // When NewGame called, start the timer
    if (vars.newGame.output.Current && !vars.newGame.output.Old){
        vars.Log("Starting Timer");
        game.WriteBytes((IntPtr)vars.newGame.outputPtr, new byte[] { 0x00, 0x00, 0x00, 0x00 });
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
            // Restore overwritten bytes
            game.WriteBytes((IntPtr)hook["injectPtr"], (byte[])hook["origBytes"]);

            // Remove jmp from code cave
            for(int i=0;i<12;i++){
                game.WriteBytes((IntPtr)hook["cavePtr"] + i, new byte[] { 0xCC });
            }

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