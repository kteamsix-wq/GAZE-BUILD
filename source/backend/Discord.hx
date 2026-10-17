package backend;

#if DISCORD_RPC
import hxdiscord_rpc.Discord as DiscordRpc;
import hxdiscord_rpc.Types;
import sys.thread.Thread;
#end
import lime.app.Application;

/**
 * Sistema de Discord Rich Presence (RPC) usando hxdiscord_rpc.
 * Modernizado e livre de avisos de depreciação.
 */
class Discord
{
	#if DISCORD_RPC
	private static inline final CLIENT_ID:String = "1424585130760077423";
	
	public static var isInitialized:Bool = false;
	private static var presence:DiscordRichPresence = new DiscordRichPresence();

	// Inicia o Discord Rich Presence
	public static function initializeRPC():Void
	{
		// Evita inicializar mais de uma vez e causar bugs/memory leaks
		if (isInitialized) return;

		var handlers:DiscordEventHandlers = new DiscordEventHandlers();
		handlers.ready = cpp.Function.fromStaticFunction(onReady);
		handlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
		handlers.errored = cpp.Function.fromStaticFunction(onError);
		DiscordRpc.Initialize(CLIENT_ID, cpp.RawPointer.addressOf(handlers), false, null);

		Application.current.window.onClose.add(shutdownRPC);
		isInitialized = true;

		Thread.create(function():Void
		{
			while (isInitialized)
			{
				#if DISCORD_DISABLE_IO_THREAD
				DiscordRpc.UpdateConnection();
				#end
				DiscordRpc.RunCallbacks();
				Sys.sleep(2.0);
			}
		});
	}

	static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		changePresence("In the Menus", null);
	}

	static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord Error! $errorCode : $message');
	}

	static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord Disconnected! $errorCode : $message');
		isInitialized = false;
	}

	public static function changePresence(details:String = '', state:Null<String> = null, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void
	{
		if (!isInitialized) return;

		var startTimestamp:Float = (hasStartTimestamp) ? Date.now().getTime() : 0;

		if (endTimestamp != null && endTimestamp > 0)
		{
			endTimestamp = startTimestamp + endTimestamp;
		}
		else
		{
			endTimestamp = 0;
		}

		presence.details = details;
		presence.state = state;
		presence.largeImageKey = 'icon'; // Chave da imagem grande do portal (ex: icon)
		presence.largeImageText = "Gaze Build";
		presence.smallImageKey = smallImageKey;
		presence.startTimestamp = Std.int(startTimestamp / 1000);
		presence.endTimestamp = Std.int(endTimestamp / 1000);

		DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
	}

	public static function shutdownRPC():Void
	{
		if (!isInitialized) return;
		
		isInitialized = false;
		DiscordRpc.Shutdown();
	}
	#else
	public static var isInitialized:Bool = false;
	public static function initializeRPC():Void {}
	public static function changePresence(details:String = '', state:Null<String> = null, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void {}
	public static function shutdownRPC():Void {}
	#end
}
