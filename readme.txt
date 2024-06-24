Welcome to the Vendetta Online Neoloader Pre-execution Library Management Engine (NPLME)! 

The purpose of Neoloader is to assist in loading plugins in Vendetta Online, using a dependency-ordered system. Besides the obvious benefit of allowing a user to enable or disable plugins in-game, this allows common-access libraries to be better utilized, and to improve and standardize communication between plugins, all in what aims to be a dummy-proof system requiring as little user-side configuration as possible. This expansion to the loading system in Vendetta Online is implemented using base-game functionality, and does not require modification of the game's files and doesn't exploit bugs in the sandbox environment.

Documentation for plugin developers can be found at https://quasar-rce.com/Neoloader



Usage:
======================================================================================
Neoloader itself is just a loading and management system for extending Vendetta Online's functionality, and so comes bundled with "neomgr"; this is a minimal interface anyone can use to manage what plugins do or don't get loaded when the game launches. Other, better managers may be available, but when first installed, Neoloader is set to use neomgr as its current managing interface.

To open your current managing interface, type

	/neo

If no managing interface is enabled, Neoloader will attempt to use neomgr; if this fails, you can also try /neomgr to force-enable it, and then use /neo normally.



Installation:
======================================================================================
Installation of this plugin follows standard plugin procedure; no special instructions are neccesary.
Copy the "Neoloader" folder to the standard plugin directory if installing manually, or use your preferred plugin management tool.

The first time you run the game with Neoloader, the plugin will make the neccesary changes to config.ini, and then the game will reload. After that, Neoloader should detect any compatible plugins and begin managing them.



Uninstallation:
======================================================================================
If you can launch the game client without bugs, use the game command /neo to open the library management interface (provided by neomgr unless otherwise replaced). Go to settings; at the bottom, click on the button labeled "Uninstall Neoloader". Click the ok button to close the game, and then remove the plugin by deleting the Neoloader folder in your plugin directory or by using your preferred plugin manager.

Another option is to use the recovery menu to uninstall Neoloader. This will work better if Neoloader is misbehaving and you are struggling to uninstall it after a game update, but the game is still launching successfully.

Once uninstalled, the initializer will remind you that you can reinstall Neoloader through /neo, but otherwise executes no functionality.



Uninstallation due to bugs:
======================================================================================
If you cannot launch the game due to bugs, delete the Neoloader folder from your plugin directory or use your preferred plugin manager. Next, open config.ini, and find the entry "if=plugins/Neoloader/init.lua". Delete this line, and save the file. If you want to clean all Neoloader data for a clean reinstallation, you should also delete the entire sections labeled [Neoloader], [Neo-registry], and [Neo-pluginstate].

If the game STILL refuses to launch, another plugin may be the culprit, or config.ini may have corrupted data. Make a copy of config.ini before deleting it, and remove ALL of your plugins. If the game STILL cannot launch even like this, more in-depth investigation is warranted, and reinstalling the game may be neccesary.



Compatibility:
======================================================================================
Neoloader is not compatible with any custom interface; However, plugins can register themselves as a custom interface through Neoloader instead.

Neoloader should be compatible with every platform the game *actively* supports and can be pluginded. This includes Windows, Mac, Linux, Android, ChromeOS, iOS. Neoloader has also been lightly tested on the Quest 2 specifically; other VR platforms may have different results.
Not supported: ???, VendettaMark benchmarking utility



FAQ:
======================================================================================
Do I need Neoloader?

	It depends. Some plugins will require the environment that Neoloader sets up. If you want to use one of these plugins, Neoloader will be required. Otherwise, Neoloader isn't a requirement for modding Vendetta Online, but its features should still prove useful, especially to pilots who cannot access their plugin directory easily.
	
What is the performance hit to game launch for using Neoloader?
	
	Neoloader will variably increase the amount of time the game takes to first load, dependent on how many plugins can be loaded with neoloader and on how complex they are. You can actually see specifically how long Neoloader took to load inside neomgr; go to the logging section, and look for any line that starts with [timestat]. Neoloader measures (in milliseconds) how long every portion of its system takes to load.
	
	For me, Neoloader took ~550ms to "set up", and ~480ms to load with no other Neoloader-compatible plugins installed.
	Almost all of this time is actually taken by the standard game interface launching, however; when using a patched version of barebones_if and MultiUI, it only took ~70ms for the game to launch.
	
	Additionally, in a system where there are >100 plugins, the game's loading time only increased up by about three seconds. Again, almost all of that time is from those external plugins; Neoloader itself requires a very small amount of time to set up its environment.
	
What is the performance hit in-game for using Neoloader?
	
	Neoloader itself shouldn't noticibly impact game performace, as it doesn't have a lot to do after the game loads. However, while its provided functionality for other plugins is made to be relatively secure from bugs, that security may cost slightly if the plugin using its functions is coded inefficiently. In the end, it is up to every modder to make sure their plugin takes the user experience into account, and provides functionality in a way that doesn't lock up the user experience. 
	
Why is "Mod" and "Plugin" used interchangably in Neoloader?
	
	Because younger people and less technical people don't understand the difference or don't even understand that a "plugin" is an add-in to existing featureset, and will likely call things a "mod" anyways.	There's also half as much typing involved. All around, "mod" is just a more accepted term.
	
	Ultimately, Neoloader is a plugin and everything it loads is a plugin (however augmented), but it (and its primary author) are fine with just calling things "mods" for everyone else.
	
Why don't you enjoy Vendetta Online plugin-free?
	
	Because I enjoy customizing my experience in any game, and because I enjoy modding. I will poke fun at, but never truly knock, anyone who likes the vanilla experience - but understand that isn't the experience I personally enjoy.
	
I have this grey box opening and I can't play Vendetta Online!
	
	That's probably a bug.
	
I have a bug and I can't play Vendetta Online!
	
	Cool! There's a LOT of potential for bugs with any plugin. Neoloader itself tries to be dummy-proof, but even it might be breaking.
	If you can, please send "Luxen De'Mark" your config.ini file, your errors.log, along with a screenshot of the bug.
	If the problem is with a plugin outside of Neoloader, however, you should take it up with that plugin's author as well.
	
I have a bug and something called a recovery system appears
	
	When either Neoloader or any other plugin has a really catastrophic error that isn't caught, this should appear and offer options to automate fixing the bug. Give each of the options a shot. Do note that this recovery system is only meant to be a kind of band-aid in case you aren't able to manage your files or investigate the bug further, and it is very likely it won't be able to solve your issue.
	
I have a bug that causes Vendetta Online to close!
	
	Super cool! But actually not! This is called a CTD (Crash to Desktop) in most other games. In Vendetta Online, they can be very minor lua errors (if a plugin crashes before the game's loading screen goes away, the game closes, but the error is easily traceable), or be related to the interface or networking side of the game (this is capable of generating an extensive log of your system resources and processes, none of which is helpful to us mod developers!)
	
	Neoloader was written in a way to try and prevent this from happening with plugins (it uses a custom handler for lua errors, marking the plugin as "failed to load", and just skipping it in the loading process), but we can't guarantee everything; just like above, send the relevant files to Luxen De'Mark for investigation.
	
Something called an error reporter showed up when my game crashed!
	
	DO NOT use this! This is for crashes related to the game itself, and the developers tend to auto-delete anything submitted through this that shows plugins were loaded. Please note that while the developers of Vendetta Online allow us to make game plugins within their system, they DO NOT actually support pluginding, and shouldn't be expected to do so either. They have to work on the game itself already.
	
	When in doubt, bug Luxen De'Mark!
	
How do I contact Luxen?
	
	discord: .luxen / Luxen#0309 (preferred)
	email: Luxen@gmx.com (make sure your subject line starts with "neoloader" and/or "Vendetta Online"!)
	
	Make sure to attach your config.ini, errors.log, and a screenshot of the in-game error reporter! Otherwise, it can be difficult or impossible to determine the issue. Also, I might be at work or otherwise busy; if I don't get in touch with you, don't worry about it. If your issue prevents you from playing the game, uninstall Neoloader. I'm willing to offer some help, so be courteous in return, and understand there are some issues I just can't help with.
	
Is it safe to send people my config.ini or errors.log?
	
	Its important to note that your config.ini and errors.log will contain possibly sensitive information.
		Your config.ini stores your usernames that you log in with! It is advised to use a tool like NeoPatcher to remove this information, or to manually delete it yourself. Look for [security], and delete every username that appears below it.
		
		Your errors.log will include some details about your computer and plugins, but the most sensitive data it'll contain will be your game chat from the session you played in. If you are trying to report a bug, try to replicate it on a new character (if logging in is needed in the first place), or you might leak private chat accidentally.



Credits and special thanks:
======================================================================================
Luxen De'Mark (Main programmer and concept designer of Neoloader)
Ezra Nightwalker (Code fixes and cleanup)
Haxmeister (special thanks for consulting)
Draugath (special thanks for consulting and code improvements)
tjgaming (testing on a known-to-be-unusual mobile device)

Super special thanks to Guild Software for the creation of Vendetta Online!



Disclaimer
======================================================================================
This plugin is not made, guaranteed, or supported by Guild Software or its affiliates. It is provided as-is, and the mod's developers are not liable for any damage, real or perceived, that results in its usage. Support for issues is not guaranteed to be provided. By using this plugin, you agree that the mod's developers are not responsible for any consequences that may arise from its usage.
