state("Hyperbolica")
{

    // True once the lever is pulled at the end of the NIL fight
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
        (vars.leverInteract = new ExpandoObject()),
        (vars.stateUpdate = new ExpandoObject()),
        (vars.worldReset = new ExpandoObject()) // NIL phase advance
    };

    vars.loadLevel.name = "LoadLevel";
    vars.loadLevel.offset = 0x420240;
    vars.loadLevel.outputSize = 8;
    vars.loadLevel.overwriteBytes = 5;
    vars.loadLevel.payload = new byte[] { 0x48, 0x89, 0x08 }; // mov [rax], rcx
    vars.loadLevel.enabled = true;

    vars.newGame.name = "NewGame";
    vars.newGame.offset = 0x715CD0;
    vars.newGame.outputSize = 1;
    vars.newGame.overwriteBytes = 6;
    vars.newGame.payload = new byte[] { 0xC7, 0x00, 0x01, 0x00, 0x00, 0x00 }; // mov dword ptr [rax], 1
    vars.newGame.enabled = true;

    vars.stateUpdate.name = "StateUpdate";
    vars.stateUpdate.offset = 0xA34B00;
    vars.stateUpdate.outputSize = 12;
    vars.stateUpdate.overwriteBytes = 5;
    vars.stateUpdate.payload = new byte[] {
        0x48, 0x89, 0x08, // mov [rax], rcx
        0x89, 0x50, 0x08 // mov [rax+8], edx
    };
    vars.stateUpdate.enabled = true;

    vars.worldReset.name = "WorldReset";
    vars.worldReset.offset = 0xA46090;
    vars.worldReset.outputSize = 1;
    vars.worldReset.overwriteBytes = 6;
    vars.worldReset.payload = new byte[] { 0xC7, 0x00, 0x01, 0x00, 0x00, 0x00 }; // mov dword ptr [rax], 1
    vars.worldReset.enabled = true;

    vars.leverInteract.name = "LeverInteract";
    vars.leverInteract.offset = 0x713080;
    vars.leverInteract.outputSize = 1;
    vars.leverInteract.overwriteBytes = 6;
    vars.leverInteract.payload = new byte[] { 0xC7, 0x00, 0x01, 0x00, 0x00, 0x00 }; // mov dword ptr [rax], 1
    vars.leverInteract.enabled = true;

    // Create settings
    settings.Add("splitCrystal", true, "Split on crystal collection");

    settings.Add("splitTrinket", true, "Split on trinket collection");
    settings.Add("splitTrinket_map", true, "Only Map", "splitTrinket");
    settings.Add("splitTrinket_temp", false, "Include temporary trinkets", "splitTrinket");
    settings.SetToolTip("splitTrinket_temp", "The hat, the NEMO ticket, and the blueprints/tools/note/key obtained in frosted fields.");

    settings.Add("splitQuest", false, "Split on side quest progress");
    settings.Add("splitQuest_vtuber", true, "SuperGuy137", "splitQuest");
    settings.Add("splitQuest_daisy", true, "Iris", "splitQuest");

    settings.Add("splitSubEnter", false, "Split on entering a subarea");
    settings.Add("splitEnterCafe", true, "Infinity Cafe", "splitSubEnter");
    settings.Add("splitEnterFarm", true, "De Sitter Farm", "splitSubEnter");
    settings.Add("splitEnterSnow", true, "Frosted Fields", "splitSubEnter");
    settings.Add("splitEnterMaze", true, "Maze of Apeirogon", "splitSubEnter");
    settings.Add("splitEnterGallery", true, "NEMO", "splitSubEnter");
    settings.Add("splitEnterGlitch", true, "NIL Arena", "splitSubEnter");

    settings.Add("splitSubExit", false, "Split on exiting a subarea");
    settings.Add("splitExitCafe", true, "Infinity Cafe", "splitSubExit");
    settings.Add("splitExitFarm", true, "De Sitter Farm", "splitSubExit");
    settings.Add("splitExitSnow", true, "Frosted Fields", "splitSubExit");
    settings.Add("splitExitMaze", true, "Maze of Apeirogon", "splitSubExit");
    settings.Add("splitExitGallery", true, "NEMO", "splitSubExit");

    settings.Add("splitSnowball", false, "Split on snowball fight won");
    settings.Add("splitNil", false, "Split on NIL phase advance");

    settings.Add("legacyLever", true, "Use legacy timing");
    settings.SetToolTip("legacyLever", "End timer when lever animation finishes, not when lever is pulled");

    var subareas = new string[] {
        "Cafe",
        "Farm",
        "Snow",
        "Maze",
        "Gallery",
        "Glitch"
    };

    vars.crystalNames = new string[] {
        "tetrahedron",
        "cube",
        "octahedron",
        "dodecahedron",
        "icosahedron",
        "teapot"
    };

    vars.trinketNames = new string[] {
        "map",      "watch",      "microphone", "rose",       "hypercube",
        "squeegee", "calculator", "beanie",     "sanddollar", "horseshoe",
        "tack",     "jam",        "mug",        "cereal",     "yoyo",
        "spoon",    "needles",    "chocolate",  "playbutton", "newtonscradle",
    };

    vars.temporaryTrinketNames = new string[] {
        "blueprints", "tools", "note", "key", // -> Dodecahedron
        "ticket",                             // -> Icosahedron
        "hat"                                 // -> Jam
    };

    vars.isSubarea = (Func<string, bool>)(name => {
        return Array.Exists(subareas, e => e == name);
    });

    vars.enteredSubarea = (Func<bool>)(() => {
        return (vars.sceneNameOld == "Over" || vars.sceneNameOld == "Class") && vars.isSubarea(vars.sceneNameNew);
    });

    vars.leftSubarea = (Func<bool>)(() => {
        return vars.sceneNameNew == "Over" && vars.isSubarea(vars.sceneNameOld);
    });

    // Read a System.String from a location in memory
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
    // Track sidequest progress
    vars.vtuberStage = 0;
    vars.daisyStage = 0;

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

    // Install hooks
    foreach (IDictionary<string, object> hook in vars.hooks)
    {
        if(((bool)hook["enabled"]) == false){
            continue;
        }
        vars.Log("Installing hook for " + hook["name"]);

        // Get pointer to function
        hook["injectPtr"] = gameAssembly.BaseAddress + (int)hook["offset"];

        // Find nearby 12 byte code cave to store long jmp
        int caveSize = 0;
        int dist = 0;
        hook["cavePtr"] = IntPtr.Zero;
        vars.Log("Scanning for code cave");
        for(int i=1;i<0xFFFFFFFF;i++){
            byte b = game.ReadBytes((IntPtr)hook["injectPtr"] + i, 1)[0];
            if (b == 0xCC){
                caveSize++;
                if (caveSize == 12){
                    hook["caveOffset"] = i - 11;
                    hook["cavePtr"] = (IntPtr)hook["injectPtr"] + (int)hook["caveOffset"];
                    break;
                }
            }else{
                caveSize = 0;
            }
        }
        if ((IntPtr)hook["cavePtr"] == IntPtr.Zero){
            throw new Exception("Unable to locate nearby code cave");
        }
        vars.Log("Found cave " + ((int)hook["caveOffset"]).ToString("X") + " bytes away");

        // Allocate memory for output
        hook["outputPtr"] = game.AllocateMemory((int)hook["outputSize"]);

        // Build the hook function
        var funcBytes = new List<byte>() { 0x48, 0xB8 }; // mov rax, ...
        funcBytes.AddRange(BitConverter.GetBytes((UInt64)((IntPtr)hook["outputPtr"]))); // ...outputPtr
        funcBytes.AddRange((byte[])hook["payload"]);

        // Allocate memory to store the function
        hook["funcPtr"] = game.AllocateMemory(funcBytes.Count + (int)hook["overwriteBytes"] + 12);

        // Write the detour:
        // - Copy bytes from the start of original function which will be overwritten
        // - Overwrite those bytes with a 5 byte jump instruction to a nearby code cave
        // - In the code cave, write a 12 byte jump to the memory allocated for our hook function
        // - Write the hook function
        // - Write a copy of the overwritten code at the end of the hook function
        // - Following this, write a jump back the original function
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
        (vars.stateUpdate.output1 = new MemoryWatcher<IntPtr>((IntPtr)vars.stateUpdate.outputPtr)),
        (vars.stateUpdate.output2 = new MemoryWatcher<int>((IntPtr)vars.stateUpdate.outputPtr + 0x8)),
        (vars.worldReset.output = new MemoryWatcher<bool>((IntPtr)vars.worldReset.outputPtr)),
        (vars.leverInteract.output = new MemoryWatcher<bool>((IntPtr)vars.leverInteract.outputPtr))
    };

    vars.sceneNameOld = "Unknown";
    vars.sceneNameNew = "Unknown";

    vars.stateKeyOld = "";
    vars.stateKeyNew = "";
}

update
{
    vars.Watchers.UpdateAll(game);

    // Update scene name from dumped pointer
    vars.sceneNameOld = vars.sceneNameNew;
    if (vars.loadLevel.output.Current != vars.loadLevel.output.Old) {
        vars.sceneNameNew = vars.readString(vars.loadLevel.output.Current, game);
    }
    if (vars.sceneNameNew != vars.sceneNameOld){
        vars.Log("Transitioning from '" + vars.sceneNameOld + "' to '" + vars.sceneNameNew + "'");
    }

    // Get latest state update
    vars.stateKeyOld = vars.stateKeyNew;
    if (vars.stateUpdate.output1.Current != vars.stateUpdate.output1.Old) {
        vars.stateKeyNew = vars.readString(vars.stateUpdate.output1.Current, game);
    }
    if (vars.stateKeyNew != vars.stateKeyOld){
        vars.Log("State updated: " + vars.stateKeyNew + ", " + vars.stateUpdate.output2.Current);
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
    if (vars.stateKeyNew != vars.stateKeyOld){
        // Trinket collected
        if (vars.stateKeyNew.StartsWith("has_trinket")){
            string trinketName = vars.stateKeyNew.Split('_')[2];
            vars.Log("Trinket collected: " + trinketName);

            // This is a crystal
            if (((string[])vars.crystalNames).Contains(trinketName)){
                if (settings["splitCrystal"]){
                    vars.Log("Crystal collected, splitting");
                    return true;
                }
            }
            else if (settings["splitTrinket"]){
                // Map only mode is on
                if (settings["splitTrinket_map"]){
                    if(trinketName == "map"){
                        vars.Log("In map only mode, collected map, splitting");
                        return true;
                    }else{
                        vars.Log("In map only mode, not splitting");
                    }
                }

                // This is a temporary trinket
                else if (((string[])vars.temporaryTrinketNames).Contains(trinketName)) {
                    if(settings["splitTrinket_temp"]){
                        vars.Log("Temporary trinkets allowed, splitting");
                        return true;
                    }else{
                        vars.Log("Temporary trinket, not splitting");
                    }
                }

                // This is a regular trinket
                else{
                    vars.Log("Trinket collected, splitting");
                    return true;
                }
            }
        }

        // SuperGuy137 sidequest progressed
        if(vars.stateKeyNew == "intro" + (vars.vtuberStage + 1) + "_vtuber_yes"){
            vars.Log("Vtuber stage completed");
            vars.vtuberStage++;
            if (settings["splitQuest_vtuber"]){
                vars.Log("Quest progress: vtuber, splitting");
                return true;
            }
        }

        // Iris sidequest progressed
        if(vars.stateKeyNew == "intro" + (vars.daisyStage + 1) + "_daisy_yes"){
            vars.Log("Daisy stage completed");
            vars.daisyStage++;
            if (settings["splitQuest_daisy"]){
                vars.Log("Quest progress: daisy, splitting");
                return true;
            }
        }

        // Snowball fight completed
        if (vars.stateKeyNew == "snow_fighter1_snowball_win") {
            vars.Log("Snowball fight won");
            if (settings["splitSnowball"]) {
                vars.Log("Snowball fight split enabled, splitting");
                return true;
            }
        }
    }

    // NIL phase advance
    if (vars.worldReset.output.Current) {
        vars.Log("NIL phase advanced");
        if (settings["splitNil"]) {
            vars.Log("NIL phase advance split enabled, splitting");
            game.WriteBytes((IntPtr)vars.worldReset.outputPtr, new byte[] {0x00});
            return true;
        }
    }

    // Split when lever pulled after boss fight 
    if (vars.sceneNameNew == "Glitch" && !old.leverPulled && current.leverPulled) {
        vars.Log("Lever animation finished");
        if (settings["legacyLever"]){
            vars.Log("Splitting");
            return true;
        }
    }

    if (vars.leverInteract.output.Current){
        vars.Log("Lever pulled");
        if(!settings["legacyLever"]){
            vars.Log("Splitting");
            game.WriteBytes((IntPtr)vars.leverInteract.outputPtr, new byte[] {0x00});
            return true;
        }
    }

    // Split on entering sub area
    if (vars.enteredSubarea()){
        if (settings["splitEnter"+vars.sceneNameNew]){
            vars.Log("Entering subarea, splitting");
            return true;
        }
    }

    // Split on exiting a sub area
    if (vars.leftSubarea()){
        if (settings["splitExit"+vars.sceneNameOld]){
            vars.Log("Leaving subarea, splitting");
            return true;
        }
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