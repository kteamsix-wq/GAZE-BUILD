package backend;

#if DISCORD_RPC
import discord_rpc.DiscordRpc;
#end
import lime.app.Application;

/**
 * Sistema de Discord Rich Presence (RPC).
 * Otimizado e refatorado.
 */
class Discord
{
	#if DISCORD_RPC
	// O seu novo Client ID fornecido
	private static inline final CLIENT_ID:String = "1424585130760077423";
	
	public static var isInitialized:Bool = false;

	// Inicia o Discord Rich Presence
	public static function initializeRPC():Void
	{
		// Evita inicializar mais de uma vez e causar bugs/memory leaks
		if (isInitialized) return;

		DiscordRpc.start({
			clientID: CLIENT_ID,
			onReady: onReady,
			onError: onError,
			onDisconnected: onDisconnected
		});

		Application.current.window.onClose.add(shutdownRPC);
		isInitialized = true;
	}

	static function onReady():Void
	{
		DiscordRpc.presence({
			details: "In the Menus",
			state: null,
			largeImageKey: 'icon', // Lembre-se de adicionar 'icon' nos assets do seu Discord Developer Portal
			largeImageText: "Gaze Build"
		});
	}

	static function onError(_code:Int, _message:String):Void
	{
		trace('Discord Error! $_code : $_message');
	}

	static function onDisconnected(_code:Int, _message:String):Void
	{
		trace('Discord Disconnected! $_code : $_message');
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

		DiscordRpc.presence({
			details: details,
			state: state,
			largeImageKey: 'icon', // Chave da imagem grande do portal (ex: icon)
			largeImageText: "Gaze Build",
			smallImageKey: smallImageKey,
			// Os tempos obtidos estão em milissegundos, então são divididos para o Discord poder usá-los
			startTimestamp: Std.int(startTimestamp / 1000),
			endTimestamp: Std.int(endTimestamp / 1000)
		});
	}

	public static function shutdownRPC():Void
	{
		if (!isInitialized) return;
		
		DiscordRpc.shutdown();
		isInitialized = false;
	}
	#end
}
