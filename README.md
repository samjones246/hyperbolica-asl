# hyperbolica-asl

LiveSplit autosplitter for Hyperbolica

## Usage
If you're just looking to speedrun the game, there is no need to download anything from this repository. Just make sure that the game name for your splits file is set to Hyperbolica, and then in the Edit Splits screen you should see an 'Activate' button which will enable the autosplitter. This pulls the autosplitter from the main branch of this repository so it will be kept up to date.

If you want to contribute to the autosplitter, or to test changes on a branch other than main, you will have to add the autosplitter manually. This can be done as follows:
 - Clone this repository and checkout your desired branch
 - In LiveSplit go to Edit Layout, click the plus button and select Control -> Scriptable Auto Splitter
 - Click Layout Settings, then select the Scriptable Auto Splitter tab
 - Click Browse and navigate to wherever you cloned the repository, then select hyperbolica.asl
 - Click OK on both the Layout Settings and Layout Editor windows
 - Open the Edit Splits window and ensure that the default autosplitter is not activated

## Features
 - Start timer on 'New Game' clicked
 - Split on crystal collection
 - Options for splitting on other trinket collection
   - Only map
   - All trinkets except temporary ones
   - All trinkets including temporary ones
 - Split on sub area enter/exit
 - Split on snowball fight end
 - Split on NIL phase change
 - Final split on pulling lever after boss
 - Load removal

## TODO
 - Fix bugs